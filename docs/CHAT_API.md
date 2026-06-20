# Chat API — Order Messaging

Real-time messaging between customers and merchants/couriers for a specific order.

## Endpoints

All endpoints are mounted at `/db/chat` and require a valid session token in the `Authorization` header.

### `GET /db/chat/:orderId`

Retrieve all chat messages for an order, sorted chronologically.

**Response** — array of message objects:

```json
[
  {
    "id": "uuid",
    "order_id": "string",
    "sender_phone": "9647xxxxxxxxx",
    "receiver_phone": "9647xxxxxxxxx",
    "message_type": "text",
    "content": "string",
    "created_at": "ISO timestamp"
  }
]
```

### `POST /db/chat/:orderId`

Send a new chat message.

**Request body:**

```json
{
  "content": "string (required)",
  "senderPhone": "9647xxxxxxxxx (auto-populated from session)",
  "receiverPhone": "9647xxxxxxxxx (optional, for push notification)",
  "messageType": "text | audio (default: text)",
  "orderId": "string (auto-populated from URL param)"
}
```

**Response** — the saved message object (with `id` and `created_at`).

## Database

Messages are stored in the `chat_messages` table in Supabase. Run the migration in `supabase/` to create the table.

## Push notifications

When a message has a `receiverPhone`, a push notification (`رسالة جديدة`) is sent to the receiver via FCM.

## Flutter client

The `ChatScreen` in `lib/screens/chat_screen.dart` consumes this API. It is navigated to with the `orderId`, `otherPartyName`, and `otherPartyPhone`.
