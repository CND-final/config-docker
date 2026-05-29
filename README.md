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

## Quick Start

### Option A — Build from source *(recommended)*

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

### Option B — Pull from registry

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
│   └── DOCKER.md             ← full variable reference and HTTPS guide
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
