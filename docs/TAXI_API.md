# Taxi API — Ride Hailing

Ride-hailing service with customer request, driver matching, and real-time status tracking.

## Endpoints

All endpoints are mounted at `/db/taxi` and require a valid session token in the `Authorization` header.

### `POST /db/taxi/create`

Create a new taxi ride request. Fare is calculated automatically based on distance and taxi type.

**Request body:**

```json
{
  "pickupAddress": "string (required)",
  "dropoffAddress": "string (required)",
  "pickupLat": "number (required)",
  "pickupLng": "number (required)",
  "dropoffLat": "number (required)",
  "dropoffLng": "number (required)",
  "distanceKm": "number (required)",
  "taxiType": "economic | super (default: economic)"
}
```

**Response:**

```json
{
  "requestId": "uuid",
  "requestNumber": "TX-XXXXXX",
  "status": "pending",
  "fare": 1250,
  "fareEconomic": 1250,
  "fareSuper": 1750
}
```

On creation, push notifications are sent to the nearest available drivers (up to 5).

### `POST /db/taxi/accept`

Driver accepts a pending request.

**Request body:**

```json
{
  "requestId": "uuid (required)",
  "driverName": "string",
  "vehicleModel": "string",
  "plateNumber": "string"
}
```

The customer receives a push notification confirming the driver is on their way.

### `POST /db/taxi/reject`

Driver rejects a pending request. The system automatically searches for the next nearest available driver with expanding radius (5 km → 10 km → all).

**Request body:**

```json
{
  "requestId": "uuid (required)"
}
```

### `POST /db/taxi/cancel`

Customer cancels their request.

**Request body:**

```json
{
  "requestId": "uuid (required)",
  "reason": "string (optional)"
}
```

### `POST /db/taxi/status`

Update the trip status. Available status keys:

| statusKey | Meaning |
|-----------|---------|
| `arrived` | Driver arrived at pickup location |
| `picked_up` | Passenger picked up, trip started |
| `completed` | Trip completed |
| `cancelled` | Trip cancelled |

**Request body:**

```json
{
  "requestId": "uuid (required)",
  "statusKey": "string (required)"
}
```

The customer receives push notifications for `arrived` and `completed` events.

### `GET /db/taxi/active`

Get the customer's currently active (non-completed, non-cancelled) request.

### `GET /db/taxi/driver-active`

Get the driver's currently active request (status: accepted, arrived, or picked_up).

### `GET /db/taxi/history`

Get the customer's ride history, sorted newest first.

### `GET /db/taxi/driver-history`

Get the driver's ride history, sorted newest first.

### `GET /db/taxi/nearby-drivers`

Find nearby available drivers.

**Query parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `lat` | number | — | Pickup latitude |
| `lng` | number | — | Pickup longitude |
| `pickupLat` | number | same as `lat` | Alias |
| `pickupLng` | number | same as `lng` | Alias |
| `taxiType` | string | `economic` | `economic` or `super` |

## Fare Calculation

Fares are calculated by `backend/services/taxi_pricing_service.js`.

| Tier | Formula | Min | Max |
|------|---------|-----|-----|
| 🟢 Economic | First 1 km = 1,000 IQD, then 500 IQD/km | 1,000 IQD | 50,000 IQD |
| 🔵 Super | Economic × 1.3 | 1,500 IQD | 50,000 IQD |

Fares are rounded up to the nearest 250 IQD.

## Driver Matching

When a driver rejects a request, `backend/services/taxi_matching_service.js` searches for an alternative driver with expanding radius:
1. 5 km radius
2. 10 km radius
3. All available drivers

## Push Notifications

Push events are sent via `backend/push/taxi_push_events.js`. All taxi push data includes `category: 'taxi'` for client-side routing.

| Event | Recipient | eventKey |
|-------|-----------|----------|
| New request available | Nearby drivers | `taxi:pool_new` |
| Driver accepted | Customer | `taxi:driver_accepted` |
| Driver arrived | Customer | `taxi:driver_arrived` |
| Trip completed | Both parties | `taxi:trip_completed` |
| Driver rejected | Driver | `taxi:driver_rejected` |

## Database

Ride requests are stored in the `taxi_requests` table in Supabase. Each row stores the full request payload in a `request_payload` JSONB column alongside indexed columns (`phone`, `driver_phone`, `status_key`, `pickup_lat`, `pickup_lng`, etc.).

## Flutter Client

The taxi feature lives in `lib/features/taxi/` with screens for customer (request, waiting, live tracking, history) and driver (home, requests, trip, earnings).
