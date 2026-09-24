/**
 * Session verification for the Socket.IO handshake, answered from the database instead of over HTTP.
 *
 * ── WHY THIS FILE EXISTS ──
 *
 * The production server used to validate a socket `join` by calling its own HTTP API:
 *
 *     fetch(`http://127.0.0.1:${port}/api/auth/verify?hash=...`)
 *
 * On the cPanel host that call is refused, and the production log says so exactly:
 *
 *     join validation error: [TypeError: fetch failed] {
 *       [cause]: Error: connect ECONNREFUSED 127.0.0.1:3000 ... errno: -111, code: 'ECONNREFUSED'
 *
 * `server.listen(port)` is not what makes the site reachable there. Passenger starts the app, intercepts
 * `listen()`, binds it to a Unix socket of its own and proxies the domain to that, so nothing is listening on TCP
 * 3000 even while the same process is serving the page that opened the socket. Every `join` was answered
 * `{ success: false, reason: 'server_error' }` - no notification ever reached a browser, and the only outward sign
 * was this log growing.
 *
 * ── WHY READING THE TABLE IS THE SAME ANSWER ──
 *
 * `pages/api/auth/verify.ts` answers from an in-process Map when it can and falls back to `admin_sessions`. That
 * table is written by EVERY login path in `pages/api/auth/login.ts` - client, employee and admin all INSERT before
 * returning the hash - so the table is the authority and the Map is only a shortcut past one query. This performs
 * the route's fallback path, including the client-account check and the deletion of a session whose client is no
 * longer active, so a suspended client cannot hold a live notification channel.
 *
 * Separate from `server.production.js` so `tests/socket-session-verify.test.js` can exercise it against a real
 * database. The previous version could only be tested by deploying it.
 */

let poolInstance = null;

/**
 * Built on first use, never at module load.
 *
 * Next reads `.env.production` during `prepare()`. At the time `server.js` is required, `DB_HOST`, `DB_USER`,
 * `DB_PASSWORD` and `DB_NAME` are all still undefined, so a pool created then would silently take mysql2's
 * defaults - root@localhost with no database - and fail on the first join with an access-denied error that names
 * a user nobody configured.
 */
function sessionPool() {
  if (!poolInstance) {
    const mysql = require('mysql2/promise');
    poolInstance = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || 'root',
      database: process.env.DB_NAME || 'ansar',
      waitForConnections: true,
      /*
       * 2, where `lib/db.ts` uses 10. This pool serves handshakes only, and shared hosting counts connections per
       * account against the same ceiling the application pool is already spending.
       */
      connectionLimit: 2,
      queueLimit: 0,
    });
  }
  return poolInstance;
}

/**
 * @param {string} hash session hash sent by the browser
 * @returns {Promise<null | {username: string, userType: 'admin'|'client'|'employee',
 *                           clientId: number|null, employeeId: number|null}>}
 *          null when the hash is unknown, expired, or belongs to a client whose account is not active.
 *
 * `adminId` is absent on purpose: the HTTP route never returned one either, because `admin_sessions` has no admin
 * id column. Admins are addressed through the `admins` room rather than by id, so nothing reads it.
 */
async function verifySessionHash(hash) {
  if (!hash || typeof hash !== 'string') return null;

  const db = sessionPool();
  const [rows] = await db.query(
    'SELECT username, user_type, client_id, employee_id, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1',
    [hash],
  );
  if (!rows || rows.length === 0) return null;

  const row = rows[0];
  /* Expiry compared in JavaScript, not SQL, so it uses the same clock the route used. */
  if (!row.expires_at || new Date(row.expires_at).getTime() <= Date.now()) return null;

  if (row.user_type === 'client') {
    const [accounts] = await db.query(
      'SELECT status, email_verified FROM client_users WHERE id = ? LIMIT 1',
      [row.client_id],
    );
    if (!accounts.length || accounts[0].status !== 'active' || Number(accounts[0].email_verified) !== 1) {
      await db.query('DELETE FROM admin_sessions WHERE hash = ?', [hash]);
      return null;
    }
  }

  return {
    username: row.username,
    userType: row.user_type,
    clientId: row.client_id,
    employeeId: row.employee_id,
  };
}

/**
 * May this session join the socket room for one project?
 *
 * @param {string} hash session hash sent by the browser
 * @param {number} projectId the project the browser asked to join
 * @returns {Promise<{ok: true, room: string, party: 'employee'|'client'|'admin', username: string}
 *                   | {ok: false, reason: string}>}
 *
 * ══════════════════════════════════════════════════════════════════════════════
 * WHY THE ROOM DECISION LIVES HERE AND NOT IN THE TWO SERVER FILES
 * ══════════════════════════════════════════════════════════════════════════════
 *
 * `server.js` and `deploy/server.production.js` are two entry points, and `tests/sql/socket-session.test.js`
 * exists because a rule asserted against one of them survived being broken in the other for months. A
 * participation query written twice is a second place for a mistake to live, so both servers call this and
 * hold none of the SQL.
 *
 * It also makes the decision TESTABLE against a real database, which is the whole reason
 * `verifySessionHash` was moved out of the server files in the first place.
 *
 * ══════════════════════════════════════════════════════════════════════════════
 * THE ROOM NAME IS BUILT HERE, FROM A VERIFIED SESSION
 * ══════════════════════════════════════════════════════════════════════════════
 *
 * The browser sends a project ID and nothing else that matters. It never sends a room name, and it never
 * sends an identity — `verifySessionHash` produces that from `admin_sessions`.
 *
 * That is deliberate, and it is the difference between this listener and every other one on those two
 * servers. `new_reply` reads `data.clientId` straight off the payload with no check at all: today that
 * costs a false notification, and with message CONTENT flowing through it, it would be text injection into
 * an arbitrary client's conversation. So the room this returns is derived, never accepted.
 *
 * ══════════════════════════════════════════════════════════════════════════════
 * `can_message`, AND WHY AN ADMIN DOES NOT NEED A ROW
 * ══════════════════════════════════════════════════════════════════════════════
 *
 * A client or an employee must hold a `project_participants` row for this project with `can_message = 1`.
 * That column is separate from merely being listed, because an engineer can be named on a project for
 * resource reporting without being authorised to write to the client, and a client representative can be
 * held out of the conversation during a dispute.
 *
 * An admin session holds no `employees.id` — `admin_sessions` has no admin id column at all, which is why
 * `verifySessionHash` returns no `adminId` — so it cannot have a participant row. Admins are authorised by
 * PERMISSION instead, and the HTTP endpoints check `project_chat_view` before they will return or accept a
 * message. Reading the room is therefore allowed for a verified admin session; posting is not, and posting
 * is the part that goes through HTTP.
 *
 * `party_type` is in the WHERE clause, and it is LOAD-BEARING. `database/project_management_chat.sql`
 * records why: MySQL refused both a CHECK constraint and a STORED generated column over `client_user_id`,
 * because that column carries a CASCADE foreign key. So nothing in the schema stops a row setting both
 * ids, and this filter is what keeps the match unambiguous.
 */
async function projectRoomAccess(hash, projectId) {
  const id = Number(projectId);
  if (!Number.isInteger(id) || id < 1) return { ok: false, reason: 'bad_project' };

  const session = await verifySessionHash(hash);
  if (!session) return { ok: false, reason: 'invalid_hash' };

  const db = sessionPool();

  /* The project has to exist. Joining a room for a deleted project is a socket that will never receive
     anything, retried for ever by a client that has no way to know why. */
  const [projects] = await db.query('SELECT id FROM projects WHERE id = ? LIMIT 1', [id]);
  if (!projects.length) return { ok: false, reason: 'no_project' };

  if (session.userType === 'admin') {
    return { ok: true, room: `project_${id}`, party: 'admin', username: session.username };
  }

  const [rows] = await db.query(
    `SELECT id FROM project_participants
      WHERE project_id = ? AND can_message = 1
        AND ((party_type = 'client'   AND client_user_id = ?)
          OR (party_type = 'employee' AND employee_id    = ?))
      LIMIT 1`,
    [id, session.clientId, session.employeeId],
  );
  if (!rows.length) return { ok: false, reason: 'not_a_participant' };

  return {
    ok: true,
    room: `project_${id}`,
    party: session.userType,
    username: session.username,
  };
}

/** Only the test calls this. The server holds the pool open for the life of the process, which is correct there. */
async function closeSessionPool() {
  if (poolInstance) {
    await poolInstance.end();
    poolInstance = null;
  }
}

module.exports = { verifySessionHash, projectRoomAccess, closeSessionPool };
