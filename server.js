/**
 * PRODUCTION SERVER — the one that ships inside the standalone package.
 *
 * ── WHY THIS IS NOT THE `server.js` IN THE PROJECT ROOT ──
 *
 * The root `server.js` is a development-and-PM2 server. It calls `next({ dev, dir })`, which makes Next look for
 * `next.config.mjs` ON DISK — and the standalone package deliberately contains no config file, because it contains
 * no source. Dropped in as-is it boots with default configuration: no 50mb server-action body limit, and image
 * optimisation switched back on, on a host with no `sharp`.
 *
 * ── WHY IT IS NOT THE `server.js` NEXT GENERATES EITHER ──
 *
 * `next build` writes its own `.next/standalone/server.js`, and that one is correct about configuration and wrong
 * about everything else this application needs: it calls `startServer()`, which creates the HTTP server itself and
 * never hands it back. Socket.IO has to attach to that server object, so a generated server means no notifications
 * at all.
 *
 * So this keeps the two things the generated server does that matter, and then does what the application needs.
 */

const path = require('path');
const fs = require('fs');
const { createServer } = require('http');

/*
 * ── 1. THE WORKING DIRECTORY ──
 *
 * `process.chdir(__dirname)` is the first thing the generated server does, and it is load-bearing here rather than
 * tidy: roughly twenty API routes build upload paths as `path.join(process.cwd(), 'public', 'uploads', ...)`. If
 * the process starts with a different working directory — which is exactly what a process manager does — every
 * upload is written outside the application and every download 404s, with no error at the point of the mistake.
 */
process.chdir(__dirname);
process.env.NODE_ENV = 'production';

/*
 * ── 2. THE BUILD'S OWN CONFIGURATION ──
 *
 * Read from `.next/required-server-files.json`, which the build writes and standalone includes. Setting
 * `__NEXT_PRIVATE_STANDALONE_CONFIG` is what stops Next reading `next.config.mjs`, so the package needs no config
 * file and cannot drift from the build.
 *
 * READ rather than pasted in. The generated server inlines the config as a literal, and that literal contains
 * `outputFileTracingRoot` and `turbopack.root` as absolute WINDOWS paths from the build machine. They are build-time
 * only and harmless, but a value that is meaningless on the host is a value somebody will eventually act on.
 */
const requiredServerFiles = path.join(__dirname, '.next', 'required-server-files.json');
if (!fs.existsSync(requiredServerFiles)) {
  console.error(
    'FATAL: .next/required-server-files.json is missing, so this is not a complete standalone build.\n'
    + '       Rebuild with `npm run build` and repackage with `node deploy/package-production.js`.',
  );
  process.exit(1);
}
const nextConfig = JSON.parse(fs.readFileSync(requiredServerFiles, 'utf8')).config;
process.env.__NEXT_PRIVATE_STANDALONE_CONFIG = JSON.stringify(nextConfig);

const next = require('next');
const { Server } = require('socket.io');

const dev = false;
/*
 * `0.0.0.0`, not `localhost`. Under a process manager the app is reached from outside its own namespace, and a
 * server bound to the loopback interface answers nothing while looking perfectly healthy in the logs.
 */
const hostname = process.env.HOSTNAME || '0.0.0.0';
const port = parseInt(process.env.PORT || '3000', 10);

const app = next({ dev, hostname, port, dir: __dirname, conf: nextConfig });
const handle = app.getRequestHandler();

/*
 * ── SESSION VERIFICATION FOR SOCKET.IO ──
 *
 * Reads `admin_sessions` directly. It used to `fetch` this server's own `/api/auth/verify` over the loopback
 * interface, which the cPanel host refuses because Passenger binds the app to a Unix socket rather than to TCP
 * `port`. The whole argument, and the log line that proves it, is in `session-verify.js`.
 */
const { verifySessionHash, projectRoomAccess } = require('./session-verify');

/**
 * ── 3. WHAT IS MISSING, SAID AT BOOT ──
 *
 * `ENCRYPTION_KEY` is read in five places, and `lib/secret-store.ts` THROWS without it rather than falling back —
 * deliberately, because a key that ships in the source protects nothing. The symptom of it being unset is a save
 * failing later, in a screen, with a message about credentials.
 *
 * `NEXT_PUBLIC_BASE_URL` is read in nine places at runtime. It is ALSO baked into the client bundle at build time,
 * so setting it here fixes the server half only; the browser half is whatever was set when `npm run build` ran.
 *
 * Reported and not fatal. A missing key must not stop the application from serving the pages that do not need it,
 * and refusing to boot would take the site down over a feature nobody may be using today.
 *
 * ── CALLED AFTER `prepare()`, AND THAT IS THE WHOLE POINT ──
 *
 * The first version ran this at the top of the file and printed both warnings on a boot where both values were
 * correctly set in a `.env.production` beside this file. Next loads `.env*` during `next()` / `prepare()`, so
 * before that point `process.env` holds only what the process was started with. A warning that fires when nothing
 * is wrong is worse than no warning: the operator learns to scroll past it, and misses the real one.
 */
function reportMissingEnvironment() {
  for (const [name, why] of [
    ['ENCRYPTION_KEY', 'integration credentials cannot be encrypted at rest; saving one will fail'],
    ['NEXT_PUBLIC_BASE_URL', 'links in emails and printed sheets will have no host'],
  ]) {
    const value = (process.env[name] || '').trim();
    if (!value) console.warn(`WARNING: ${name} is not set - ${why}`);
    else if (name === 'ENCRYPTION_KEY' && value.length < 32) {
      console.warn(`WARNING: ENCRYPTION_KEY is only ${value.length} characters; at least 32 are required`);
    }
  }
}

app.prepare().then(() => {
  reportMissingEnvironment();

  const server = createServer(async (req, res) => {
    try {
      /*
       * No pre-parsed URL. The usual pattern passes `url.parse(req.url, true)`, and on Node 24 that prints a
       * DeprecationWarning naming `url.parse()` and stating that CVEs are not issued for it — on every boot, in
       * the production log, where it reads like a vulnerability report about this application.
       *
       * The argument is optional and Next parses the URL itself when it is omitted, using its own current
       * implementation rather than the legacy one. Nothing here needed the parsed value.
       */
      await handle(req, res);
    } catch (err) {
      console.error('Error occurred handling', req.url, err);
      res.statusCode = 500;
      res.end('internal server error');
    }
  });

  /*
   * ── SOCKET.IO ──
   *
   * `transports` keeps polling as a fallback on purpose. A reverse proxy that does not upgrade a WebSocket leaves
   * a websocket-only client retrying for ever with nothing on screen to say why; polling degrades instead.
   */
  const io = new Server(server, {
    cors: { origin: process.env.NEXT_PUBLIC_BASE_URL || '*', methods: ['GET', 'POST'] },
    path: '/socket.io/',
    transports: ['websocket', 'polling'],
  });

  /*
   * ── THE BRIDGE FROM AN API ROUTE TO THIS `io` ──
   *
   * `src/lib/project-broadcast.ts` reads this and nothing else. It exists because a project message is
   * broadcast BY THE SERVER, after an authenticated HTTP POST has authorised it and written it — the browser
   * never emits message content.
   *
   * A global is the right shape here and both alternatives are known to be wrong in this codebase:
   *
   *   - a module export cannot work. The API routes are bundled into `.next/server`, and this file is outside
   *     that graph, so a `require` from a route would load a SECOND copy with no `io` in it.
   *   - an HTTP or socket client call back into this process is the ECONNREFUSED trap recorded in
   *     `session-verify.js`: Passenger intercepts `listen()` and binds the app to a Unix socket of its own,
   *     so nothing answers on TCP `port` for the life of the process.
   *
   * Set AFTER `io` exists, so a route either finds a working server or finds nothing.
   * `project-broadcast.ts` treats nothing as a MISSED broadcast rather than an error: the message is already
   * in the database, so the next fetch shows it. A delayed message, not a lost one.
   */
  globalThis.__ansarSocketIo = io;

  const connectedUsers = new Map();

  io.on('connection', (socket) => {
    socket.on('join', async ({ sessionHash, userType, userId }) => {
      try {
        if (!sessionHash) {
          socket.emit('joined', { success: false, reason: 'missing_hash' });
          return;
        }
        /*
         * The identity is taken from the SERVER, never from the client's claim. `userType` and `userId` arrive in
         * the payload and are used only as a fallback for logging - a client that sent `userType: 'admin'` would
         * otherwise join the admin room and receive every notification in the company.
         *
         * Read straight out of `admin_sessions`, so the check cannot be skipped by anything a browser controls.
         */
        const data = await verifySessionHash(sessionHash);
        if (!data) {
          socket.emit('joined', { success: false, reason: 'invalid_hash' });
          return;
        }

        const trustedType = data.userType || userType;
        const trustedUserId = (trustedType === 'employee' ? data.employeeId
          : trustedType === 'client' ? data.clientId : data.adminId) || userId;

        connectedUsers.set(socket.id, {
          sessionHash, userType: trustedType, userId: trustedUserId, socketId: socket.id,
        });

        if (trustedType === 'admin') socket.join('admins');
        else if (trustedType === 'client') socket.join(`client_${trustedUserId}`);
        else if (trustedType === 'employee') socket.join(`employee_${trustedUserId}`);

        socket.emit('joined', { success: true });
      } catch (e) {
        console.error('join validation error:', e);
        socket.emit('joined', { success: false, reason: 'server_error' });
      }
    });

    /*
     * ── JOIN ONE PROJECT'S CONVERSATION ──
     *
     * The browser sends a session hash and a project ID. It does NOT send a room name and it does not send an
     * identity: `projectRoomAccess` derives both from `admin_sessions` and `project_participants`, and returns
     * the room only when `can_message = 1`.
     *
     * That is the difference between this listener and `new_reply` below, which reads `data.clientId` straight
     * off the payload. With message content flowing through it, that pattern would be text injection into an
     * arbitrary client's thread — so nothing here is taken from the payload except the id being asked about.
     *
     * The decision lives in `session-verify.js` so both server entry points share ONE implementation.
     * `tests/sql/socket-session.test.js` exists because a rule asserted against one of these two files
     * survived being broken in the other.
     *
     * `project_joined` is a NEW event name. The existing `notification` event still carries the bell, so there
     * is no second bell mechanism and `NotificationBell` is untouched.
     */
    socket.on('join_project', async ({ sessionHash, projectId }) => {
      try {
        if (!sessionHash) {
          socket.emit('project_joined', { success: false, projectId, reason: 'missing_hash' });
          return;
        }
        const access = await projectRoomAccess(sessionHash, projectId);
        if (!access.ok) {
          socket.emit('project_joined', { success: false, projectId, reason: access.reason });
          return;
        }
        socket.join(access.room);
        socket.emit('project_joined', { success: true, projectId });
      } catch (e) {
        console.error('join_project validation error:', e);
        socket.emit('project_joined', { success: false, projectId, reason: 'server_error' });
      }
    });

    /*
     * Leaving needs no authorisation: a socket can only leave a room it is in, and `socket.leave` on a room it
     * never joined is a no-op. Without it, opening four projects in one session leaves the socket in four rooms
     * and every message from any of them arrives.
     */
    socket.on('leave_project', ({ projectId }) => {
      const id = Number(projectId);
      if (Number.isInteger(id) && id > 0) socket.leave(`project_${id}`);
    });

    socket.on('task_submitted', (data) => {
      io.to('admins').emit('notification', {
        type: 'task_submitted',
        module: (data && data.module) || 'general',
        action: (data && data.action) || 'submitted',
        entityId: (data && data.entityId) || null,
        message: (data && data.message) || `New ${(data && data.module) || 'task'} submitted`,
        link: (data && data.link) || null,
        view: (data && data.view) || null,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('task_reviewed', (data) => {
      io.to(`employee_${data && data.employeeId}`).emit('notification', {
        type: 'task_reviewed',
        module: (data && data.module) || 'general',
        action: (data && data.action) || 'reviewed',
        entityId: (data && data.entityId) || null,
        message: (data && data.message)
          || `${(data && data.module) || 'Task'} ${(data && data.result) || 'updated'}`,
        link: (data && data.link) || null,
        view: (data && data.view) || null,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('new_ticket', (data) => {
      io.to('admins').emit('notification', {
        type: 'new_ticket',
        message: `New ticket ${data.ticketNo} from ${data.company}`,
        ticketNo: data.ticketNo,
        ticketId: data.ticketId,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('new_reply', (data) => {
      if (data.repliedByType === 'admin') {
        io.to(`client_${data.clientId}`).emit('notification', {
          type: 'admin_reply',
          message: `Admin replied to ticket ${data.ticketNo}`,
          ticketNo: data.ticketNo,
          ticketId: data.ticketId,
          timestamp: new Date().toISOString(),
        });
      } else if (data.repliedByType === 'client') {
        io.to('admins').emit('notification', {
          type: 'client_reply',
          message: `${data.company} replied to ticket ${data.ticketNo}`,
          ticketNo: data.ticketNo,
          ticketId: data.ticketId,
          timestamp: new Date().toISOString(),
        });
      }
    });

    socket.on('status_change', (data) => {
      io.to(`client_${data.clientId}`).emit('notification', {
        type: 'status_change',
        message: `Ticket ${data.ticketNo} status changed to ${data.newStatus}`,
        ticketNo: data.ticketNo,
        ticketId: data.ticketId,
        status: data.newStatus,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('ticket_assigned', (data) => {
      const assigned = Array.from(connectedUsers.values())
        .find(u => u.userType === 'admin' && u.userId === data.assignedToId);
      if (assigned) {
        io.to(assigned.socketId).emit('notification', {
          type: 'ticket_assigned',
          message: `You have been assigned ticket ${data.ticketNo}`,
          ticketNo: data.ticketNo,
          ticketId: data.ticketId,
          timestamp: new Date().toISOString(),
        });
      }
    });

    socket.on('disconnect', () => { connectedUsers.delete(socket.id); });
  });

  server.once('error', (err) => {
    console.error(err);
    process.exit(1);
  });

  /*
   * ── THE REQUEST WINDOW HAS TO BE BIG ENOUGH FOR THE UPLOAD THE APP OFFERS ──
   *
   * Node's `requestTimeout` default is 300 000 ms. A service round accepts 500 MB in one request
   * (`MAX_SERVICE_UPLOAD_BYTES`), and 500 MB inside 300 s needs 14 Mbps of SUSTAINED upstream. Below
   * that the server destroys the request part-way through and formidable raises code 1002, which the
   * screen reported as "the upload was cut off — usually a file over 10 MB or a selection over 500 MB".
   * Two numbers that contradicted each other, blamed on the user.
   *
   * 30 minutes puts the floor at about 2.3 Mbps for a full 500 MB request. Kept identical to
   * `ansarlatest/server.js`, because a limit that differs between development and production is a bug
   * that only appears on the server.
   *
   * THE PROXY IN FRONT OF THIS IS A SEPARATE CEILING. nginx `client_max_body_size` defaults to 1 MB and
   * Passenger has its own read timeout; neither can be set from here. A large upload that fails on the
   * server with a 413, or with a truncated body rather than a clean message, is that layer and not this
   * one.
   */
  server.requestTimeout = 30 * 60 * 1000;

  server.listen(port, () => {
    console.log(`Ready on http://${hostname}:${port}`);
    console.log(`Socket.IO on ws://${hostname}:${port}/socket.io/`);
  });
});
