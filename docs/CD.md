# Continuous Deployment Guide (Backend Auto-Deploy)

This document covers the automated pipeline that rebuilds and redeploys the
backend whenever application code lands on `config-man`'s `main`. It is the
**automation layer** on top of the manual steps in
[`RENDER.md`](./RENDER.md).

---

## What this gives you

| Without CD (manual) | With CD (this guide) |
|---|---|
| `make fetch-sources` by hand | automatic on every backend change |
| `docker build --platform linux/amd64` by hand | runs in GitHub Actions |
| `docker push` to GHCR by hand | automatic |
| Render "Manual Deploy" click | triggered automatically via Deploy Hook |
| DB schema catches up only after you remember to redeploy | DB catches up on the next backend merge, hands-free |

> The frontend half is already automatic: it is a Render **Static Site** built
> from the `config-man` repo, which auto-deploys on push via Render's native
> GitHub integration. This pipeline only automates the **backend image**, which
> is deployed from a prebuilt GHCR image and therefore does *not* auto-deploy on
> its own.

---

## Architecture

```
config-man push to main (backend/** only)
        │
        │  notify-deploy.yml  (the "doorbell" — no deploy detail, just a ping)
        ▼
  repository_dispatch  ──────────────►  config-docker
                                              │
                                              │  deploy-backend.yml (the "worker")
                                              │   1. checkout config-docker (Dockerfile)
                                              │   2. checkout config-man → base/config-man
                                              │   3. docker build --platform linux/amd64
                                              │   4. push GHCR (:latest + :sha-xxxx)
                                              │   5. curl Render Deploy Hook
                                              ▼
                                     Render redeploys backend
                                              │
                                              ▼
                              backend boot → InitSchema runs
                                              │
                                              ▼
                                  Render PostgreSQL catches up
```

Two workflow files, split by concern:

| File | Repo | Role |
|---|---|---|
| `.github/workflows/notify-deploy.yml` | **config-man** | doorbell — fires on `backend/**` push, dispatches an event. Holds no deployment detail. |
| `.github/workflows/deploy-backend.yml` | **config-docker** | worker — builds the amd64 image from the existing `backend/Dockerfile` and triggers Render. All deployment knowledge lives here. |

> The existing `backend/Dockerfile` is used **unchanged**. The worker reproduces
> what `make fetch-sources` does locally by checking out config-man into
> `base/config-man`, so the Dockerfile's `COPY base/config-man/backend/` is
> satisfied exactly as in a local `make build`.

---

## One-time setup

### 1. `DISPATCH_TOKEN` secret (in config-man)

The doorbell calls another repo, so the built-in `GITHUB_TOKEN` is not enough.
Create a fine-grained PAT scoped to config-docker:

1. GitHub avatar → **Settings** → **Developer settings** →
   **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
   (Shortcut: `https://github.com/settings/personal-access-tokens`)
2. **Resource owner**: select **`CND-final`** (not your personal account).
3. **Repository access**: *Only select repositories* → **CND-final/config-docker**.
4. **Permissions** → **Repository permissions** → **Contents**: **Read and write**.
   (The `dispatches` endpoint lives under the Contents permission.)
5. **Generate token**, copy the `github_pat_...` string (shown once).
6. config-man → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**:
   - Name: `DISPATCH_TOKEN`
   - Value: the token string

### 2. `RENDER_DEPLOY_HOOK` secret (in config-docker)

1. Render Dashboard → **config-man-backend** service → **Settings** →
   **Deploy Hook** → copy the URL
   (`https://api.render.com/deploy/srv-xxxxx?key=yyyyy`).
2. config-docker → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**:
   - Name: `RENDER_DEPLOY_HOOK`
   - Value: the hook URL

### 3. Render backend Image URL must point at `:latest`

Render → **config-man-backend** → **Settings** → **Image**. Confirm the
reference ends in `:latest`. The worker pushes `:latest` (for Render) plus
`:sha-xxxx` (for audit / rollback) on every run. A Deploy Hook re-resolves the
`:latest` tag to the new digest — this is a real re-pull, unlike a *Restart*,
which reuses the cached image.

> **Rollback.** To pin an older build, set the Image URL to a specific
> `:sha-xxxx` tag and deploy. To resume auto-deploy, set it back to `:latest`.

---

## Verifying the pipeline

Bring the pipeline up **downstream-first** so the doorbell always has someone to
answer it.

1. **Worker half (manual):** config-docker → **Actions** →
   **Build and deploy backend** → **Run workflow**. All three steps
   (GHCR login, build/push, Render hook) should be green, and Render should
   start a deploy. The `workflow_dispatch` trigger exists for exactly this.
2. **Full chain (end-to-end):** make a harmless change under `config-man`'s
   `backend/` (e.g. a comment in `backend/README.md`), commit to `main`.
   - config-man → Actions → *Notify config-docker to deploy* runs green.
   - config-docker → Actions → *Build and deploy backend* is woken
     automatically by `repository_dispatch` (not a manual run).
   - Render redeploys the backend.

> A README-only change does not alter the schema, so the verification round
> won't add DB objects — that is expected. Real schema changes (edits to
> `db_store.go`) catch up automatically on the merge that contains them.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| config-man doorbell run is red on the `curl` step (401/403) | `DISPATCH_TOKEN` missing the config-docker **Contents: write** permission, or pending org approval | regenerate/approve the PAT with the correct scope |
| doorbell curl returns 404 | token can't see config-docker, or repo path typo | confirm the PAT's repository access includes config-docker |
| config-docker worker not woken after a backend merge | `deploy-backend.yml` not on config-docker's **default branch** | `repository_dispatch` only triggers workflows on the default branch; merge it to main |
| build/push step fails with **403 / denied** | config-docker's `GITHUB_TOKEN` lacks write access to the GHCR package | org → **Packages** → `config-man-backend` → Package settings → **Manage Actions access** → add **config-docker** with **Write** |
| Render didn't redeploy | `RENDER_DEPLOY_HOOK` missing or wrong | re-copy the hook from the backend service Settings |
| image runs locally but not on Render | wrong CPU arch | the worker pins `--platform linux/amd64`; never push an arm64 image to `:latest` |

---

## How the DB "catches up" (no DB-side steps)

There is no separate migration command. The backend runs `InitSchema` on every
boot, which is idempotent and forward-only: `CREATE TABLE IF NOT EXISTS` for new
tables plus `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` / `DROP COLUMN IF EXISTS`
patches and `DO $$ ... $$` backfills for changes to existing tables. A
`pg_advisory_xact_lock` guards against concurrent migration when multiple
replicas boot together. So "make the DB catch up" reduces to "boot the
new-code backend against that DB" — which is exactly what this pipeline
automates.

> **Caveat for future schema work.** A column added to an *existing* table only
> reaches an *existing* database if it has a paired
> `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`. A bare addition inside a
> `CREATE TABLE` body reaches a fresh DB but silently skips an existing one
> (the `CREATE TABLE IF NOT EXISTS` is a no-op when the table already exists).
> Keep adding the ALTER backstop, as the current schema does.
