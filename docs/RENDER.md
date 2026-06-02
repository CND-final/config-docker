# Render Cloud Deployment Guide (HTTPS)

This document covers deploying config-man to [Render](https://render.com) as a
public, HTTPS-enabled stack. It is the **cloud counterpart** to the local
Docker / Kubernetes setups.

---

## Why a separate cloud deployment

| Deployment | Proves | HTTPS |
|---|---|---|
| **Local Docker** (`https://localhost`) | full container stack | self-signed only — browser always warns |
| **Local K8s** (`config-helm`) | **High Availability** (kill-a-pod survives) | n/a |
| **Render** (`*.onrender.com`) | **public access + real HTTPS** | ✅ automatic, real green-lock cert |

Self-signed certificates on `localhost` are *always* flagged by browsers and
cannot be fixed without installing a local CA on every demo machine. Render
issues real, trusted TLS certificates automatically for every `onrender.com`
service, so **HTTPS is demonstrated on the cloud deployment**, while HA is
demonstrated on local K8s. Two demos, each proving one thing.

---

## Architecture

```
Browser ──HTTPS──> Render Static Site (frontend, global CDN)
                        │
                        ├── /api/*  ──rewrite──> Render Web Service (backend, Go)
                        │                              │
                        └── /*      ──rewrite──> index.html (SPA fallback)
                                                       │
                                            Render PostgreSQL (managed)
```

Three Render services:

| Service | Type | Source |
|---|---|---|
| `config-man-db` | PostgreSQL (Free) | managed by Render |
| `config-man-backend` | Web Service (Free) | prebuilt GHCR image |
| `config-man-frontend` | Static Site (Free) | built from `config-man` repo |

> The local `proxy` service (nginx + self-signed certs) is **not used** in the
> cloud. Render terminates TLS itself; there is no nginx layer on Render.

---

## Prerequisites

- A Render account (sign in with GitHub — no credit card required for free tier)
- The backend image published to GHCR as a **public**, **amd64** image:
  `ghcr.io/cnd-final/config-man-backend:latest`
- GitHub access to the `CND-final/config-man` repo (for the frontend build)

> **amd64 matters.** Render runs amd64. If the image was built on an ARM
> machine (e.g. Apple Silicon) without `--platform`, it will not run. Rebuild
> explicitly when in doubt:
> ```
> docker build --platform linux/amd64 -f backend/Dockerfile -t ghcr.io/cnd-final/config-man-backend:latest .
> docker push ghcr.io/cnd-final/config-man-backend:latest
> ```

---

## Step 1 — PostgreSQL

1. Render Dashboard → **+ New** → **Postgres**
2. Name `config-man-db`, choose a Region (remember it), Plan **Free**
3. **Create Database**, wait for *Available*
4. Copy the **Internal Database URL** from the *Connections* section
   (format: `postgres://USER:PASSWORD@dpg-xxxxx-a/DBNAME`)

> The Internal URL only works for services **in the same region**. The backend
> must be created in this same region.

> Free PostgreSQL expires after 30 days and is then deleted. For a one-off
> demo this is fine; just don't create it weeks in advance.

---

## Step 2 — Backend (Web Service)

1. Render Dashboard → **+ New** → **Web Service** → **Deploy an existing image**
2. Image URL: `ghcr.io/cnd-final/config-man-backend:latest`
3. Settings:
   - **Region**: same as the database
   - **Instance Type**: Free
   - **Health Check Path**: `/api/v1/health`
4. Environment variables:

   | Key | Value |
   |---|---|
   | `CONFIG_MAN_HOST` | `0.0.0.0` |
   | `CONFIG_MAN_PORT` | `10000` |
   | `DATABASE_URL` | *(the Internal URL from Step 1)* |

5. **Create Web Service**

> **Port.** Render expects the service to listen on the port it assigns.
> Setting `CONFIG_MAN_PORT=10000` makes the Go backend bind there. The backend
> reads this env var directly — no code change needed.

> **SSL.** Use the Internal URL as-is first. If the logs show an SSL error,
> append `?sslmode=require` to `DATABASE_URL`. (Locally the stack uses
> `sslmode=disable`; Render's managed Postgres differs.)

> **Scheme.** The backend accepts both `postgres://` and `postgresql://`.

A healthy startup log looks like:
```
msg="DATABASE_URL detected; opening PostgreSQL connection"
msg="start config-man server" addr=0.0.0.0:10000
==> Your service is live 🎉
```

The backend auto-runs its migrations and seeds the demo accounts on first
start against the empty Render database — no manual migration step required.

Verify: open `https://config-man-backend.onrender.com/api/v1/health` → should
return OK. Note the backend URL for Step 3.

> Services deployed from a prebuilt image do **not** auto-deploy. To ship a new
> image, push to GHCR then trigger a manual deploy in Render.

---

## Step 3 — Frontend (Static Site)

1. Render Dashboard → **+ New** → **Static Site** → connect the
   **`CND-final/config-man`** repo *(not config-docker — the frontend source
   lives in config-man)*
2. Settings:
   - **Root Directory**: `frontend`
   - **Build Command**: `npm ci && npm run build`
   - **Publish Directory**: `dist`
3. **Create Static Site**, wait for the build to finish

### Rewrite rules (required)

The frontend calls the backend at the relative path `/api`. On Render there is
no nginx to proxy that, so two **Rewrite** rules replace what the local
`frontend/nginx.conf` did. Add them under the static site's
**Redirects/Rewrites**. **Order matters — `/api` must come first:**

| # | Source | Destination | Action |
|---|---|---|---|
| 1 | `/api/*` | `https://config-man-backend.onrender.com/api/*` | **Rewrite** |
| 2 | `/*` | `/index.html` | **Rewrite** |

- **Rewrite, not Redirect.** A rewrite is a server-side proxy: the browser
  stays on the frontend origin, so there is **no CORS issue** and HTTPS stays
  same-origin.
- Rule 1 proxies API calls to the backend.
- Rule 2 is the SPA fallback so client-side routes resolve to `index.html`.
- Render skips a rewrite when a real file exists at that path, so static
  assets (JS/CSS) are served normally and not swallowed by rule 2.

> If the **Redirects/Rewrites** section is hard to find in the dashboard, the
> equivalent can be committed to the repo as `frontend/public/_redirects`:
> ```
> /api/*  https://config-man-backend.onrender.com/api/:splat  200
> /*      /index.html                                          200
> ```
> (`200` = rewrite. Same order: `/api` first.)

---

## Step 4 — Verify

Open `https://config-man-frontend.onrender.com`:

- Green-lock HTTPS, no warning ✅ *(this is the graded requirement)*
- Log in with a demo account (see below)
- Exercise a core action (create/view a config) to confirm backend ↔ DB writes
- Optionally test the other roles (admin / developer / viewer)

---

## Demo accounts (password: `password`)

| Email | Role |
|-------|------|
| `admin@config-man.local` | System Admin |
| `project-admin@config-man.local` | Project Admin |
| `group-admin@config-man.local` | Group Admin |
| `developer@config-man.local` | Developer |
| `reviewer@config-man.local` | Reviewer |
| `viewer@config-man.local` | Viewer |

---

## Free-tier notes & demo-day gotchas

- **Cold start.** A free Web Service spins down after ~15 min of inactivity and
  takes 30–60 s to wake on the next request. **Wake the backend right before
  the demo** — open the site or hit
  `https://config-man-backend.onrender.com/api/v1/health` a minute beforehand.
- **Postgres lifespan.** Free Postgres is deleted after 30 days. Don't
  provision it far ahead of the demo.
- **No auto-deploy for image-based backend.** Push to GHCR, then manually
  deploy in Render — or set up the automated pipeline (see
  [`CD.md`](./CD.md)) so backend changes on `main` build and redeploy
  themselves.
- **Frontend auto-deploys** on push to the connected branch. Confirm the latest
  deploy matches the intended commit before demoing.

---

## Service URLs

| Service | URL |
|---|---|
| Frontend | `https://config-man-frontend.onrender.com` |
| Backend | `https://config-man-backend.onrender.com` |
| Backend health | `https://config-man-backend.onrender.com/api/v1/health` |

---

> **Automating redeploys.** These steps are the manual path. To rebuild and
> redeploy the backend automatically whenever code lands on `config-man`'s
> `main`, see [`CD.md`](./CD.md).
