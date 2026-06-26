# Flutter modules

Each domain owns its models, providers, services, screens, and widgets.

## Layout

```
modules/<name>/
├── models/
├── providers/
├── services/
├── screens/
├── widgets/
├── utils/          (optional)
├── <name>_module.dart   # public exports
└── README.md
```

## Status

| Module | Path | Status |
|--------|------|--------|
| `taxi` | `modules/taxi/` | **Migrated** (was `features/taxi`) |
| `auth` | `modules/auth/` | **Migrated** |
| `marketplace` | `modules/marketplace/` | **Migrated** — home, cart, stores, catalog, `customer_service` |
| `restaurants` | `modules/restaurants/` | Re-exports restaurant menus from `marketplace` |
| `courier` | `modules/courier/` | **Migrated** — delivery screens |
| `real_estate` | `modules/real_estate/` | **Migrated** — listings, forms, deal hubs |
| `chat` | `modules/chat/` | **Migrated** — chat service, screen, navigation |
| `notifications` | `modules/notifications/` | **Migrated** — FCM, hub, banners |
| `admin` | `modules/admin/` | **Migrated** |
| `merchant` | `modules/merchant/` | **Migrated** — screens + widgets |
| `driver` | `modules/driver/` | **Migrated** — shell, account, `driver_service` |
| `real_estate` | `modules/real_estate/` | **Migrated** — listings, forms, deal hubs |
| `common` | `modules/common/` | **Migrated** — account screens, shared account widgets + infra exports |

## Import convention

Prefer package imports for cross-module boundaries:

```dart
import 'package:alghaith_app/modules/taxi/taxi_module.dart';
import 'package:alghaith_app/modules/taxi/models/taxi_request.dart';
```

## Migration order

1. taxi (done)
2. ~~merchant + courier~~ (done)
3. ~~admin + auth~~ (done)
4. ~~`marketplace` + `restaurants` screens~~ (done — partial `AppProvider` split: `app_navigation_state.dart`)
5. ~~chat + notifications~~ (done — `app_ui_preferences` extracted)
6. Further split `AppProvider` (`app_navigation_state`, `app_ui_preferences`, `app_notification_inbox_state`, `app_cart_state`, `app_customer_orders_state` done)
