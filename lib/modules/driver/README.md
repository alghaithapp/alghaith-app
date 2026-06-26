# driver

Taxi driver role shell — approval gate, bottom nav, account (trip UI is in `taxi`).

## Owns

- `services/driver_service.dart` — driver profile state
- `screens/driver_shell.dart` — main driver app shell
- `screens/driver_pending_approval_screen.dart` — waiting for admin approval
- `screens/driver_account_screen.dart` — driver account tab
- `screens/driver_shared_widgets.dart` — shared driver UI pieces

## Related

- `modules/taxi/` — trip screens, matching, earnings detail

## Legacy shims

`lib/screens/driver/*` and `lib/providers/services/driver_service.dart` (deprecated).
