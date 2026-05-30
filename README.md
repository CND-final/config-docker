# config-docker

> Deployment wrapper for [config-man](https://github.com/CND-final/config-man)

---

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Docker Engine | 24 |
| Docker Compose v2 | 2.20 — verify with `docker compose version` |
| GNU make | 4.x |
| Git | 2.x |

---

## Deployment guides

- **Local Docker stack** → [docs/DOCKER.md](docs/DOCKER.md)
- **Cloud (Render, HTTPS)** → [docs/RENDER.md](docs/RENDER.md)

---

## Quick Start

### Option A — Live cloud deployment *(recommended — real HTTPS)*

Already deployed on Render with a real, trusted HTTPS certificate (green lock) —
no setup required:

- **App:** https://config-man-frontend.onrender.com
- Log in with any demo account (see below).
- ⚠️ The free backend sleeps after ~15 min idle. **Before a demo, wake it** by
  opening https://config-man-backend.onrender.com/api/v1/health once
  (first request takes 30–60 s).

Full deployment steps (how it was built / how to rebuild) → [docs/RENDER.md](docs/RENDER.md).

### Option B — Build from source (local)

Clones config-man, builds images locally, and starts all services.

```cmd
git clone https://github.com/CND-final/config-docker.git
cd config-docker

:: generate local TLS certs (mkcert in a container)
make certs

make up-build
```

Wait for all services to start (30–60 s on first run).
Open **https://localhost** in your browser.
To avoid browser warnings, trust the mkcert CA at `certs/mkcert/rootCA.pem`.

### Option C — Pull from registry (local)

> Images are published to `ghcr.io/cnd-final/`. No build required.

```cmd
make pull
make certs
make up
```

'make up' automatically initializes 'config/*.env' from the examples on first run.
Open **https://localhost** in your browser.

**Demo accounts (password: `password`):**

| Email | Role |
|-------|------|
| `admin@config-man.local` | System Admin |
| `project-admin@config-man.local` | Project Admin |
| `group-admin@config-man.local` | Group Admin |
| `developer@config-man.local` | Developer |
| `reviewer@config-man.local` | Reviewer |
| `viewer@config-man.local` | Viewer |

> **Note on HTTPS:** `https://localhost` here uses a self-signed cert, so
> browsers will show a security warning. For a publicly accessible deployment
> with a real, trusted HTTPS certificate (green lock), see
> [docs/RENDER.md](docs/RENDER.md).

---

## Directory Layout

```
config-docker/
├── base/
│   ├── .gitkeep
│   └── config-man/           ← git-cloned by make fetch-sources (git-ignored)
├── backend/
│   ├── .dockerignore
│   └── Dockerfile
├── certs/                 ← TLS certs (fullchain.pem, privkey.pem)
├── config/
│   ├── backend.env.example
│   ├── frontend.env.example
│   └── postgres.env.example
├── docs/
│   ├── DOCKER.md             ← local Docker stack + local HTTPS
│   └── RENDER.md             ← cloud deployment (Render, real HTTPS)
├── frontend/
│   ├── .dockerignore
│   ├── Dockerfile
│   └── nginx.conf
├── proxy/
│   └── nginx.conf           ← TLS-terminating reverse proxy
├── .gitignore
├── docker-compose-build.yaml ← build images from source
├── docker-compose.yaml       ← pull images from registry
├── Makefile
└── README.md
```

---

## Customizing the Source Repo

`make fetch-sources` defaults to cloning `https://github.com/CND-final/config-man.git`
on branch `main`. Override without editing the Makefile:

```cmd
:: override on the command line
make up-build SOURCE_REPO=https://github.com/your-fork/config-man.git SOURCE_BRANCH=dev

:: or export before running
set SOURCE_REPO=https://github.com/your-fork/config-man.git
set SOURCE_BRANCH=dev
make up-build
```
