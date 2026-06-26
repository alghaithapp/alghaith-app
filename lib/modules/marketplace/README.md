# marketplace

Customer catalog: home categories, stores, products, cart, bazaar.

## Owns

- `screens/` — home, cart, shopping hubs, catalog browse, orders, favorites
- `services/customer_service.dart` — catalog, cart, orders, favorites for customers
- `marketplace_router.dart` — category → screen routing

## Shared (global)

- `lib/core/catalog/marketplace_catalog.dart` — category definitions
- `lib/core/storage/catalog_cache.dart` — offline catalog cache

## Sub-modules

- `restaurants/` — re-exports restaurant menu screens from this module

## Legacy shims

`lib/screens/home_screen.dart`, `cart_screen.dart`, etc. re-export from here (deprecated).
