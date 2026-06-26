# common

Cross-cutting Flutter infrastructure and shared account UI.

## Infrastructure (re-exported)

- `lib/core/` — config, theme, network, realtime
- `lib/services/supabase_service.dart`, `image_storage_service.dart`
- `lib/data/repositories/`

## Account screens (`screens/`)

- `account_screen.dart` — main account tab shell
- `customer_account_view.dart` — logged-in customer profile
- `account_full_screen.dart`, `account_deletion_screen.dart`
- `notifications_screen.dart`, `addresses_screen.dart`, `payment_methods_screen.dart`
- `app_settings_screen.dart`, `language_selection_screen.dart`
- `force_update_screen.dart`

## Widgets (`widgets/account/`)

- `account_page_header.dart`
- `account_server_loading_view.dart`

## wallet (future)

Payment / wallet module placeholder — add `modules/wallet/` when payments ship.

## Legacy shims

`lib/screens/account_*.dart`, `lib/widgets/account/*` re-export from here (deprecated).
