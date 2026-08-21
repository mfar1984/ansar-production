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

/** Only the test calls this. The server holds the pool open for the life of the process, which is correct there. */
async function closeSessionPool() {
  if (poolInstance) {
    await poolInstance.end();
    poolInstance = null;
  }
}

module.exports = { verifySessionHash, closeSessionPool };
