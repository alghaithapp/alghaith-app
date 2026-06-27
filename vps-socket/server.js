/**
 * Socket.io server — يُشغَّل على VPS لتوفير الاتصال الفوري (WebSocket)
 * بين المستخدمين بدلاً من HTTP polling.
 *
 * التشغيل:
 *   node server.js
 *
 * متغيرات البيئة:
 *   PORT              — منفذ الاستماع (3001)
 *   REDIS_URL         — اتصال Redis (redis://127.0.0.1:6379)
 *   BROADCAST_KEY     — مفتاح أمان لـ POST /api/broadcast
 */

const http = require('http');
const { Server } = require('socket.io');
const redis = require('redis');

const PORT = process.env.PORT || 3001;
const REDIS_URL = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
const BROADCAST_KEY = process.env.BROADCAST_KEY || 'alghaith-socket-broadcast-key';

async function main() {
  const subscriber = redis.createClient({ url: REDIS_URL });
  const publisher = redis.createClient({ url: REDIS_URL });
  await subscriber.connect();
  await publisher.connect();
  console.log('Redis connected');

  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const path = url.pathname;

    if (req.method === 'POST' && path === '/api/broadcast') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        try {
          const data = JSON.parse(body);
          if (data.key !== BROADCAST_KEY) {
            res.writeHead(403);
            res.end(JSON.stringify({ error: 'Invalid key' }));
            return;
          }
          const { room, event, payload } = data;
          if (room && event) {
            publisher.publish(`alghaith:${room}`, JSON.stringify({ event, payload }));
            res.writeHead(200);
            res.end(JSON.stringify({ ok: true }));
          } else {
            res.writeHead(400);
            res.end(JSON.stringify({ error: 'Missing room or event' }));
          }
        } catch (e) {
          res.writeHead(400);
          res.end(JSON.stringify({ error: 'Invalid JSON' }));
        }
      });
      return;
    }

    if (path === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, service: 'alghaith-socket', clients: 0 }));
      return;
    }

    res.writeHead(404);
    res.end('Not found');
  });

  const io = new Server(server, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
    pingInterval: 10000,
    pingTimeout: 5000,
  });

  io.on('connection', (socket) => {
    console.log(`Client connected: ${socket.id}`);

    socket.on('join', (room) => {
      if (typeof room === 'string' && room.trim()) {
        socket.join(room.trim());
      }
    });

    socket.on('leave', (room) => {
      if (typeof room === 'string') socket.leave(room.trim());
    });

    socket.on('message', (data) => {
      const parsed = typeof data === 'string' ? JSON.parse(data) : data;
      if (parsed.room && parsed.event) {
        publisher.publish(`alghaith:${parsed.room}`, JSON.stringify({ event: parsed.event, payload: parsed.payload }));
      }
    });

    socket.on('disconnect', (reason) => {
      console.log(`Client disconnected: ${socket.id} (${reason})`);
    });
  });

  await subscriber.subscribe('alghaith:*', (message, channel) => {
    const room = channel.replace('alghaith:', '');
    try {
      const parsed = JSON.parse(message);
      io.to(room).emit(parsed.event, parsed.payload);
    } catch (e) {
      io.to(room).emit('message', message);
    }
  });

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Socket.io server running on port ${PORT}`);
  });
}

main().catch(console.error);
