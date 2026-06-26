# chat

Customer ↔ merchant / driver messaging. Used from taxi, merchant, delivery, marketplace.

## Owns

- `services/chat_service.dart` — API for threads and messages
- `services/chat_thread_refresh.dart` — live refresh hub for open chats
- `screens/chat_screen.dart` — conversation UI
- `utils/chat_navigation.dart` — `ChatNavigation.open(...)`

## Related (other modules)

- `modules/merchant/screens/merchant_chat_inbox_screen.dart` — merchant inbox

## Legacy shims

`lib/services/chat_service.dart`, `lib/screens/chat_screen.dart`, `lib/utils/chat_navigation.dart` (deprecated).
