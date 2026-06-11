---
name: setup-langwatch
description: Get a LangWatch worktree from fresh clone to a verified-working dev server — pnpm install, Docker infra (Postgres/ClickHouse/Redis), .env credential/auth fixes, pnpm dev, health checks, and a browser smoke test. Use when the user says "set up langwatch", "get the dev server running", "pnpm dev isn't working", or hits DB auth / ClickHouse / NEXTAUTH errors on boot.
---

# Setup & Run LangWatch Dev Server

Bring a LangWatch worktree to a **verified-working** dev server. Don't stop at "process started" — verify HTTP health AND a real browser sign-in.

Work from the `langwatch/` directory inside the worktree.

## Step 1: Install dependencies

```bash
pnpm i
```

Node engine warnings (`wanted 24.x`) are harmless. Ignore "Ignored build scripts" warnings.

## Step 2: Check Docker infrastructure

The app needs Postgres (:5432), ClickHouse (:8123), and Redis (:6379) — all run as Docker containers (no host installs exist). Data lives in named volumes and survives restarts.

```bash
docker ps -a --format '{{.Names}}\t{{.Status}}'
```

- Containers may belong to **another compose project** (e.g. `langwatch-pr4272-*`) — that's fine, they're on standard ports.
- **After a WSL/Docker restart, containers often show `Exited (255)`** — restart them:
  ```bash
  docker start <postgres> <clickhouse> <redis>
  curl -s http://localhost:8123/ping       # expect "Ok."
  docker exec <redis> redis-cli ping       # expect PONG
  ```
- No containers at all? Run `make quickstart` (preset picker) from the repo root.

## Step 3: Verify .env matches reality

`langwatch/.env` is the source of truth. Three classes of mismatch cause boot failures:

### 3a. Postgres credentials (error: `P1000: Authentication failed`)

Compare `.env`'s `DATABASE_URL` user/db with the container:

```bash
docker exec <postgres> env | grep -E 'POSTGRES_(USER|DB)'
```

**Before creating anything, check where existing data lives** — the user's real account/projects may be in the container's original database:

```bash
docker exec <postgres> psql -U <pguser> -d <pgdb> -tc 'select email from <schema>."User" limit 5'
```

- Data exists there → **point `DATABASE_URL` at it** (e.g. `postgresql://prisma:prisma@localhost:5432/mydb?schema=mydb&connection_limit=5`). Never create a parallel empty DB when real data exists.
- Genuinely fresh setup → create what `.env` expects:
  ```sql
  CREATE ROLE langwatch LOGIN PASSWORD 'langwatch' SUPERUSER;
  CREATE DATABASE langwatch_db OWNER langwatch;
  ```

### 3b. ClickHouse credentials (error: `AUTHENTICATION_FAILED` or `Not enough privileges ... system.storage_policies`)

Test the `.env` URL: `curl "http://<user>:<pass>@localhost:8123/?query=SELECT%201"`. If it fails, via the `default` user (password often `langwatch`):

```sql
CREATE DATABASE IF NOT EXISTS langwatch;
CREATE USER IF NOT EXISTS langwatch IDENTIFIED WITH plaintext_password BY '<pass>';
GRANT CURRENT GRANTS ON *.* TO langwatch;  -- migrations need system.storage_policies; plain GRANT ALL may fail
```

### 3c. Auth config (symptom: sign-in page stuck on "Redirecting to Sign in..." or `403 INVALID_ORIGIN`)

For local dev these three must agree with the actual port (default 5560):

```
BASE_HOST="http://localhost:5560"
NEXTAUTH_URL="http://localhost:5560"
NEXTAUTH_PROVIDER="email"          # NOT auth0 — email gives the credentials form
```

A stale `:5570` (or any wrong port) makes better-auth reject the browser origin.

## Step 4: Start the dev server

```bash
pnpm dev   # run in background; tees to langwatch/server.log
```

Boot sequence: prepare files → Prisma migrate → ClickHouse migrate → vite (:5560) + api (:6560) + workers + Go gateway (:5563). Any migrate failure kills the whole thing — read the log tail, fix per Step 3, restart. Before restarting, kill stragglers: `lsof -tiTCP:5560 -tiTCP:6560 | xargs -r kill`.

## Step 5: Verify health (don't trust "ready" logs)

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:5560/            # expect 200
curl -s -o /dev/null -w "%{http_code}" http://localhost:6560/api/health  # expect 204
```

Poll up to ~4 minutes; migrations + cold compile are slow.

## Step 6: Browser smoke test

Run `/browser-test` (or spawn a Playwright sub-agent): navigate to :5560 → credentials form renders at `/auth/signin` → sign in / register (`browser-test@langwatch.ai` / `BrowserTest123!`, org "Browser Test Org") → app shell (sidebar + header) renders. Only then declare the setup working.

## Gotchas learned the hard way

- A 200 from vite proves nothing about the DB — the first run here served a working UI against an **empty, freshly-created** database while the user's real data sat in `mydb` in the same container.
- `.env.dev-up` overlay is written by `make quickstart` but is NOT loaded by a bare `pnpm dev` — only `.env` counts.
- A WSL/Docker daemon restart silently kills the dev server and some containers; re-check `docker ps -a` whenever connections start refusing.
- API health is `/api/health` on the **API port** (frontend port + 1000), and it returns **204**, not 200.
