# Alghaith App — Project Overview

This is a **multi-platform e-commerce app** (Flutter mobile + web dashboard + Node.js backend).

## Stack

| Layer | Tech |
|-------|------|
| Mobile | Flutter / Dart (`lib/`) |
| Web dashboard | React + Vite + TypeScript (`src/`) |
| Public website | Vanilla HTML/CSS/JS (`website/`) |
| Backend | Node.js (Express) (`backend/server.js`) |
| Database | Supabase (PostgreSQL) (`supabase/`) — see `docs/DATA_AND_INFRA_ARCHITECTURE.md` |
| Push notifications | Firebase Cloud Messaging (see `docs/FCM_SETUP.md`) |
| CI/CD | Codemagic (`codemagic.yaml`), Vercel (`vercel.json`), Cloudflare Workers (`cloudflare_worker.js`) |
| iOS | Swift (Xcode project in `ios/`) |
| Android | Kotlin (`android/`) |

## Key directories

- `lib/` — Flutter source code (models, providers, screens, widgets, services)
- `lib/modules/` — **domain modules** (taxi migrated; see `docs/MODULAR_ARCHITECTURE.md`)
- `backend/` — Node.js server (push notifications, promo codes, Supabase repo, taxi services, utility & test scripts)
- `backend/domains/` — logical service registry (taxi, merchant, chat, …)
- `backend/services/` — Business logic services (taxi pricing, taxi matching)
- `backend/push/` — Push notification modules per feature (taxi push events)
- `src/` — React (Vite) admin dashboard
- `website/` — Public marketing site, privacy policy, support pages
- `supabase/` — Database migrations and SQL scripts
- `scripts/` — Utility scripts (deploy, compress images, generate keystore, etc.)
- `docs/` — Documentation (FCM setup, modular architecture, **data & infra policies**)
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

- Codemagic (`codemagic.yaml`) — CI/CD build pipeline
- Vercel (`website/vercel.json`, root `vercel.json`) — website + admin dashboard (`/admin`)
- Railway (`backend/railway.toml`) — **Node.js API only** (see below)
- Cloudflare Worker (`cloudflare_worker.js`, `wrangler.toml`) — edge script

## Railway backend deployment

There are **two Railway projects** in the workspace history; only one is the live API:

| Project | Folder link | What it runs | Use? |
|---------|-------------|--------------|------|
| `striking-fulfillment` | `backend/` | Node.js API (`backend/server.js`) | **Yes — production** |
| `alghaith-app` | repo root (accidental) | Vite admin static site + Caddy | **No — ignore/delete** |

**Production API URL:** `https://alghaith-app-production.up.railway.app`

The admin dashboard is hosted on **Vercel** (`alghaithst.com/admin`), not Railway.

### First-time CLI setup (once per machine)

```powershell
.\scripts\link-backend-railway.ps1
```

This links `backend/` to `striking-fulfillment` and unlinks the repo root if needed.

### Deploy backend

```powershell
.\scripts\deploy-backend-railway.ps1
```

Equivalent manual command (from `backend/` after linking):

```powershell
cd backend
railway up .. --path-as-root --detach
```

Upload the **full repo** archive; the Railway service root directory is `backend/`.

### Verify

```powershell
Invoke-WebRequest https://alghaith-app-production.up.railway.app/health
Invoke-WebRequest https://alghaith-app-production.up.railway.app/app/home-categories
```

**Do not** run `railway up` from the repo root — it deploys to the wrong project.

## Modular architecture

As the app grows (marketplace, taxi, delivery, chat, admin…), keep domains isolated:

- **Flutter:** `lib/modules/<domain>/` — see [`docs/MODULAR_ARCHITECTURE.md`](docs/MODULAR_ARCHITECTURE.md)
- **Backend:** `backend/domains/` — same doc; HTTP paths stay backward-compatible
