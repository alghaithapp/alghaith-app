# Alghaith App — Project Overview

This is a **multi-platform e-commerce app** (Flutter mobile + web dashboard + Node.js backend).

## Stack

| Layer | Tech |
|-------|------|
| Mobile | Flutter / Dart (`lib/`) |
| Web dashboard | React + Vite + TypeScript (`src/`) |
| Public website | Vanilla HTML/CSS/JS (`website/`) |
| Backend | Node.js (Express) (`backend/server.js`) |
| Database | Supabase (PostgreSQL) (`supabase/`) |
| Push notifications | Firebase Cloud Messaging (see `docs/FCM_SETUP.md`) |
| CI/CD | Codemagic (`codemagic.yaml`), Vercel (`vercel.json`), Cloudflare Workers (`cloudflare_worker.js`) |
| iOS | Swift (Xcode project in `ios/`) |
| Android | Kotlin (`android/`) |

## Key directories

- `lib/` — Flutter source code (models, providers, screens, widgets, services)
- `backend/` — Node.js server (push notifications, promo codes, Supabase repo, taxi services)
- `backend/services/` — Business logic services (taxi pricing, taxi matching)
- `backend/push/` — Push notification modules per feature (taxi push events)
- `src/` — React (Vite) admin dashboard
- `website/` — Public marketing site, privacy policy, support pages
- `supabase/` — Database migrations and SQL scripts
- `scripts/` — Utility scripts (deploy, compress images, generate keystore, etc.)
- `docs/` — Documentation (FCM setup, encoding notes)
- `test/` — Flutter widget tests (`widget_test.dart`)
- `web/` — Flutter web target assets (`index.html`, `manifest.json`)
- `.refact/` — Refact AI coding assistant configuration (`project_information.yaml`)

## Getting started

### Prerequisites
- Flutter SDK (see `pubspec.yaml` for version)
- Node.js (for backend + website scripts)
- A Supabase project (configure credentials in `backend/`)
- Firebase project (for push notifications — see `docs/FCM_SETUP.md`)

### Quick start

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Install backend dependencies
cd backend && npm install

# 3. Run the Flutter app
flutter run
```

### Backend server
```bash
cd backend
npm install
node server.js
```

### Web dashboard
```bash
npm install
npm run dev
```

## Environment & secrets

- Shorebird (`shorebird.yaml`) — Flutter code push
- Codemagic (`codemagic.yaml`) — CI/CD build pipeline
- Vercel (`website/vercel.json`, root `vercel.json`) — website + API deploys
- Railway (`backend/railway.toml`) — backend deployment
- Cloudflare Worker (`cloudflare_worker.js`, `wrangler.toml`) — edge script
