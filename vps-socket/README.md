# VPS Socket.io Server

خادم WebSocket فوري للدردشة والإشعارات الداخلية، يستبدل HTTP polling.

## البنية

```
Internet → NAT (10035) → Nginx (80) → Socket.io (3001) → Redis
```

## التشغيل

```bash
cd vps-socket
npm install
node server.js

# أو عبر PM2
pm2 start server.js --name alghaith-socket
```

## متغيرات البيئة

| المتغير | القيمة الافتراضية | الشرح |
|---------|-------------------|-------|
| PORT | 3001 | منفذ الاستماع |
| REDIS_URL | redis://127.0.0.1:6379 | اتصال Redis |
| BROADCAST_KEY | (مفتاح سري) | مفتاح أمان لـ API |

## الـ API

| المسار | الطريقة | الاستخدام |
|--------|---------|-----------|
| `/health` | GET | فحص الصحة |
| `/socket.io/` | WebSocket | اتصال Socket.io |
| `/api/broadcast` | POST | بث رسالة إلى غرفة |

### `/api/broadcast`

```json
POST /api/broadcast
{
  "key": "المفتاح السري",
  "room": "store:9647...",
  "event": "message",
  "payload": { "id": "...", "content": "مرحبا" }
}
```

## الاتصال من Flutter

```dart
final socket = io.io('http://IP:PORT/socket.io/', OptionBuilder()
    .setTransports(['websocket'])
    .build());

socket.emit('join', 'roomId');
socket.on('message', (data) => print(data));
```

## الإعداد من الصفر

```bash
# VPS جديد (Ubuntu 24.04)
apt update && apt upgrade -y
apt install -y nginx nodejs redis-server
npm install -g pm2

cd /opt/alghaith-socket
npm init -y
npm install socket.io redis

# انسخ server.js
# انسخ nginx.conf إلى /etc/nginx/sites-available/
# ln -sf /etc/nginx/sites-available/alghaith-socket /etc/nginx/sites-enabled/
# systemctl reload nginx

pm2 start server.js --name alghaith-socket
pm2 save
pm2 startup
```
