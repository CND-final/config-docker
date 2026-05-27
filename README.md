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

make up-build
```

Wait for all three services to become healthy (30–60 s on first run).
Open **http://localhost** in your browser.

### Option B — Pull from registry *(requires CI push first)*

> ⚠ Images are not yet published to the registry.
> Use Option A until CI is configured to push to `ghcr.io/cnd-final/`.

```cmd
make pull
make up
```

'make up' automatically initializes 'config/*.env' from the examples on first run.

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
├── .gitignore
├── docker-compose-build.yaml ← build images from source
├── docker-compose.yaml       ← pull images from registry (needs CI first)
├── Makefile
└── README.md
```

---

## Customising the Source Repo

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
