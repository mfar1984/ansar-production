const { createServer } = require('http');
const next = require('next');
const { Server } = require('socket.io');

const dev = false; // Force production mode to avoid watchpack issues
const hostname = process.env.HOSTNAME || 'localhost';
const port = parseInt(process.env.PORT || '3000', 10);

// Explicitly set the project directory to avoid Next dev watcher path issues
const app = next({ dev, hostname, port, dir: __dirname });
const handle = app.getRequestHandler();

// Token rotation scheduler (loaded after build)
let tokenRotationScheduler;
if (!dev) {
  // Only run in production to avoid multiple instances in dev mode
  try {
    const tokenRotation = require('./.next/server/app/lib/token-rotation.js');
    if (tokenRotation && tokenRotation.startTokenRotationScheduler) {
      tokenRotation.startTokenRotationScheduler();
      console.log('🔄 Token rotation scheduler initialized');
    } else {
      console.log('⚠️  Token rotation scheduler not found in build');
    }
  } catch (err) {
    console.log('⚠️  Token rotation scheduler will start with first API call');
  }
}

app.prepare().then(() => {
  const server = createServer(async (req, res) => {
    try {
      // No `url.parse()` here. Node deprecated it (DEP0169) because its behaviour
      // is not standardised and CVEs are not issued for it, and Next's request
      // handler parses the URL itself with the WHATWG API when none is passed.
      await handle(req, res);
    } catch (err) {
      console.error('Error occurred handling', req.url, err);
      res.statusCode = 500;
      res.end('internal server error');
    }
  });

  // Initialize Socket.IO
  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST']
    },
    path: '/socket.io/',
    transports: ['websocket', 'polling']
  });

  // Store connected users with their roles
  const connectedUsers = new Map();

  io.on('connection', (socket) => {
    console.log('✅ Client connected:', socket.id);

    // User joins with their session hash and role (validated)
    socket.on('join', async ({ sessionHash, userType, userId }) => {
      try {
        if (!sessionHash) {
          socket.emit('joined', { success: false, reason: 'missing_hash' });
          return;
        }
        const verifyUrl = `http://localhost:${port}/api/auth/verify?hash=${encodeURIComponent(sessionHash)}`;
        const resp = await fetch(verifyUrl, { method: 'GET' });
        const data = await resp.json().catch(() => ({}));
        if (!resp.ok || !data?.valid) {
          console.log('❌ join rejected (invalid hash)', { userType, userId });
          socket.emit('joined', { success: false, reason: 'invalid_hash' });
          return;
        }
        // Derive trusted identity from server
        const trustedType = data.userType || userType;
        const trustedUserId = (trustedType === 'employee' ? data.employeeId : (trustedType === 'client' ? data.clientId : data.adminId)) || userId;
        console.log(`👤 User joined (validated): ${trustedUserId} (${trustedType})`);

        connectedUsers.set(socket.id, {
          sessionHash,
          userType: trustedType,
          userId: trustedUserId,
          socketId: socket.id
        });

        if (trustedType === 'admin') {
          socket.join('admins');
        } else if (trustedType === 'client') {
          socket.join(`client_${trustedUserId}`);
        } else if (trustedType === 'employee') {
          socket.join(`employee_${trustedUserId}`);
        }

        socket.emit('joined', { success: true });
      } catch (e) {
        console.error('join validation error:', e);
        socket.emit('joined', { success: false, reason: 'server_error' });
      }
    });

    // Generic HR/public task submitted (notify all admins)
    socket.on('task_submitted', (data) => {
      try {
        const payload = {
          type: 'task_submitted',
          module: data?.module || 'general',
          action: data?.action || 'submitted',
          entityId: data?.entityId || null,
          message: data?.message || `New ${data?.module || 'task'} submitted`,
          link: data?.link || null,    // optional deeplink/hash
          view: data?.view || null,    // optional dashboard view name
          timestamp: new Date().toISOString()
        };
        console.log('📨 task_submitted received:', payload);
        
        // Check how many admins are in the room
        const adminRoom = io.sockets.adapter.rooms.get('admins');
        const adminCount = adminRoom ? adminRoom.size : 0;
        console.log(`👥 Admins in room: ${adminCount}`);
        
        io.to('admins').emit('notification', payload);
        console.log('✅ Notification sent to admins room');
      } catch (e) {
        console.error('❌ task_submitted error:', e);
      }
    });

    // Generic HR task reviewed (notify specific employee)
    socket.on('task_reviewed', (data) => {
      try {
        const employeeRoom = `employee_${data?.employeeId}`;
        const payload = {
          type: 'task_reviewed',
          module: data?.module || 'general',
          action: data?.action || 'reviewed',
          entityId: data?.entityId || null,
          message: data?.message || `${data?.module || 'Task'} ${data?.result || 'updated'}`,
          link: data?.link || null,
          view: data?.view || null,
          timestamp: new Date().toISOString()
        };
        console.log('✅ task_reviewed received:', payload);
        
        // Check how many employees are in the room
        const empRoom = io.sockets.adapter.rooms.get(employeeRoom);
        const empCount = empRoom ? empRoom.size : 0;
        console.log(`👤 Employee ${data?.employeeId} in room: ${empCount}`);
        
        io.to(employeeRoom).emit('notification', payload);
        console.log('✅ Notification sent to employee room:', employeeRoom);
      } catch (e) {
        console.error('❌ task_reviewed error:', e);
      }
    });

    // New ticket notification (client → admins)
    socket.on('new_ticket', (data) => {
      console.log('📩 New ticket created:', data.ticketNo);
      io.to('admins').emit('notification', {
        type: 'new_ticket',
        message: `New ticket ${data.ticketNo} from ${data.company}`,
        ticketNo: data.ticketNo,
        ticketId: data.ticketId,
        timestamp: new Date().toISOString()
      });
    });

    // New reply notification (admin → client OR client → admins)
    socket.on('new_reply', (data) => {
      console.log('💬 New reply:', data);
      
      if (data.repliedByType === 'admin') {
        // Admin replied → notify client
        io.to(`client_${data.clientId}`).emit('notification', {
          type: 'admin_reply',
          message: `Admin replied to ticket ${data.ticketNo}`,
          ticketNo: data.ticketNo,
          ticketId: data.ticketId,
          timestamp: new Date().toISOString()
        });
      } else if (data.repliedByType === 'client') {
        // Client replied → notify all admins
        io.to('admins').emit('notification', {
          type: 'client_reply',
          message: `${data.company} replied to ticket ${data.ticketNo}`,
          ticketNo: data.ticketNo,
          ticketId: data.ticketId,
          timestamp: new Date().toISOString()
        });
      }
    });

    // Status change notification (admin → client)
    socket.on('status_change', (data) => {
      console.log('🔄 Status changed:', data);
      io.to(`client_${data.clientId}`).emit('notification', {
        type: 'status_change',
        message: `Ticket ${data.ticketNo} status changed to ${data.newStatus}`,
        ticketNo: data.ticketNo,
        ticketId: data.ticketId,
        status: data.newStatus,
        timestamp: new Date().toISOString()
      });
    });

    // Ticket assigned notification
    socket.on('ticket_assigned', (data) => {
      console.log('👨‍💼 Ticket assigned:', data);
      // Notify specific admin who got assigned
      const assignedUser = Array.from(connectedUsers.values()).find(
        u => u.userType === 'admin' && u.userId === data.assignedToId
      );
      
      if (assignedUser) {
        io.to(assignedUser.socketId).emit('notification', {
          type: 'ticket_assigned',
          message: `You've been assigned ticket ${data.ticketNo}`,
          ticketNo: data.ticketNo,
          ticketId: data.ticketId,
          timestamp: new Date().toISOString()
        });
      }
    });

    socket.on('disconnect', () => {
      const user = connectedUsers.get(socket.id);
      if (user) {
        console.log(`❌ User disconnected: ${user.userId} (${user.userType})`);
        connectedUsers.delete(socket.id);
      }
    });
  });

  server.once('error', (err) => {
    console.error(err);
    process.exit(1);
  });

  server.listen(port, () => {
    console.log(`🚀 > Ready on http://${hostname}:${port}`);
    console.log(`🔌 > Socket.IO ready on ws://${hostname}:${port}/socket.io/`);
  });
});
