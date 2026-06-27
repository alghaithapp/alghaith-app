# Alghaith App

Multi-platform e-commerce app — Flutter mobile + web dashboard + Node.js backend.
Serving Iraq with professional services and shopping.

## Stack

| Layer | Tech |
|-------|------|
| Mobile | Flutter / Dart (`lib/`) |
| Web dashboard | React + Vite + TypeScript (`src/`) |
| Public website | Vanilla HTML/CSS/JS (`website/`) |
| Backend | Node.js (Express) (`backend/server.js`) |
| Database | Supabase (PostgreSQL) (`supabase/`) |
| Push notifications | Firebase Cloud Messaging |
| CI/CD | Codemagic, Vercel, Cloudflare Workers |

## Getting started

### Prerequisites

- Flutter SDK (see `pubspec.yaml` for version)
- Node.js (for backend + website scripts)
- A Supabase project
- Firebase project (for push notifications — see `docs/FCM_SETUP.md`)

### Quick start

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Run the app
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
cd src
npm install
npm run dev
```

## Key directories

- `lib/` — Flutter source code (models, providers, screens, widgets, services)
- `backend/` — Node.js server (push notifications, promo codes, Supabase repo, taxi services)
- `backend/services/` — Business logic services (taxi pricing, taxi matching)
- `backend/push/` — Push notification modules per feature (taxi push events)
- `src/` — React (Vite) admin dashboard
- `website/` — Public marketing site, privacy policy, support pages
- `supabase/` — Database migrations and SQL scripts
- `scripts/` — Utility scripts (deploy, compress images, generate keystore, etc.)
- `docs/` — Documentation (FCM setup, chat API, taxi API, encoding notes)
- `test/` — Flutter widget tests

## Version

Current version: **1.2.73+108** (see `pubspec.yaml`)

## Environment & secrets

- Codemagic (`codemagic.yaml`) — CI/CD build pipeline
- Vercel (`website/vercel.json`, root `vercel.json`) — website + admin dashboard
- Railway (`backend/railway.toml`) — Node.js API (`https://alghaith-app-production.up.railway.app`)
- Cloudflare Worker (`cloudflare_worker.js`, `wrangler.toml`) — edge script

### Railway (backend API)

Link once, then deploy from repo root:

```powershell
.\scripts\link-backend-railway.ps1
.\scripts\deploy-backend-railway.ps1
```

See `AGENTS.md` → **Railway backend deployment** for project details (only `striking-fulfillment` is production; do not deploy from repo root).
