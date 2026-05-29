# Docker Deployment Guide

This document covers running config-man as a fully containerized stack using Docker Compose.

---

## Two Operating Modes

| | Local dev (`make dev`) | Docker stack (`make up-build`) |
|---|---|---|
| **Backend** | `go run ./cmd` on host | Alpine container |
| **Frontend** | Vite dev server (HMR) | nginx serving `dist/` |
| **PostgreSQL** | Docker container | Docker container |
| **Config file** | `base/config-man/backend/.env` | `config/*.env` |
| **DATABASE_URL host** | `localhost` | `postgres` (service name) |
| **Frontend port** | 5173 | 80 (internal) |
| **Proxy ports** | n/a | 80 → 443 |
| **Hot reload** | Yes (backend + frontend) | No (rebuild required) |
| **Started from** | `base/config-man/` directory | project root |

Use **local dev** when actively writing code. Use **Docker stack** to verify the full deployment chain or to hand off to teammates who don't have Go/Node installed.

> Both modes start a PostgreSQL container on host port 5432. Running them simultaneously causes a port conflict. Use one at a time.

---

## Quick Start

```cmd
:: From the project root
make up-build
```

Wait for all three services to become healthy (30–60 seconds on first run — images are built from source).

Open `https://localhost` in your browser.

Demo accounts (all use password `password`):

| Email | Role |
|-------|------|
| `admin@config-man.local` | System Admin |
| `project-admin@config-man.local` | Project Admin |
| `group-admin@config-man.local` | Group Admin |
| `developer@config-man.local` | Developer |
| `reviewer@config-man.local` | Reviewer |
| `viewer@config-man.local` | Viewer |

---

## Roles

| Role | Scope |
|------|-------|
| `admin` | System-wide — full control over all resources and users |
| `group-admin` | Group-scoped — full control within their own group(s) |
| `user` | Standard user — access determined by group membership |

### group-admin

- All `admin` permissions, **scoped to their own group(s)**
- Cannot affect groups they don't admin
- Can promote `user` to `admin` within their group
- Reports to system-wide `admin` for cross-group decisions

---

## Environment Variables

Each app service (postgres, backend, frontend) reads its vars from a dedicated file in `config/`.
These files are git-ignored; create them before the first run:

```cmd
copy config\postgres.env.example config\postgres.env
copy config\backend.env.example  config\backend.env
copy config\frontend.env.example config\frontend.env
```

The defaults in the `.env.example` files work out of the box for local development.
All variables also have inline fallbacks in `docker-compose-build.yaml`, so the stack
starts even without the `config/*.env` files — but having them makes values explicit and editable.

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgres://config_man:config_man@postgres:5432/config_man?sslmode=disable` | Must use `postgres` (Docker service name), not `localhost` |
| `POSTGRES_DB` | `config_man` | PostgreSQL database name |
| `POSTGRES_USER` | `config_man` | PostgreSQL user |
| `POSTGRES_PASSWORD` | `config_man` | PostgreSQL password |
| `POSTGRES_PORT` | `5432` | Host port mapped to PostgreSQL |
| `CONFIG_MAN_HOST` | `0.0.0.0` | Backend listen address |
| `CONFIG_MAN_PORT` | `3000` | Backend internal port |
| `PROXY_HTTP_PORT` | `80` | Host port mapped to proxy HTTP (redirect to HTTPS) |
| `PROXY_HTTPS_PORT` | `443` | Host port mapped to proxy HTTPS |

---

## Starting and Stopping

```cmd
:: Build images from source and start all services
make up-build

:: Stop all services (data volume is preserved)
make down

:: Stop and delete data volumes (full reset — all data is lost)
docker compose -f docker-compose-build.yaml down -v

:: Rebuild and restart one service after a code change
docker compose -f docker-compose-build.yaml up -d --build backend
docker compose -f docker-compose-build.yaml up -d --build frontend
```

---

## Viewing Logs

```bash
# Stream logs from all services
docker compose logs -f

# Stream logs from one service
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f proxy
docker compose logs -f postgres
```

---

## Cleaning Up

```cmd
:: Remove containers and network; keep data volume
make down

# Remove containers, network, and data volume
docker compose down -v

# Remove locally built images (forces full rebuild next time)
docker compose down --rmi local

# Nuclear option: remove everything including cached layers
docker compose down -v --rmi local
docker system prune -f
```

---

## HTTPS via nginx reverse proxy

TLS is terminated at the `proxy` service. The frontend and backend stay on plain HTTP behind it.

1. Provide certificates at `./certs/fullchain.pem` and `./certs/privkey.pem`.
2. Start the stack: `make up-build` or `make up`.
3. Access the app at `https://localhost` (or your domain).

The proxy routes `/api` directly to the backend and all other paths to the frontend, keeping same-origin HTTPS for the browser.
