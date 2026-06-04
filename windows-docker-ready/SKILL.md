---
name: windows-docker-ready
description: Bring up the LangWatch dev stack (or any Node/Docker monorepo with similar shape) on Windows + Docker Desktop without hitting the usual papercuts — long paths, CRLF in shell scripts, npm/pnpm TLS leaf-cert failures, Node-from-bash path mismatches, and the per-worktree compose env overlay. Apply before `docker compose up`, not after it crashes.
---

# windows-docker-ready

Use this when the user wants to run a Node/Docker monorepo (especially LangWatch / langwatch-saas) on **Windows + Docker Desktop + Git Bash**. It encapsulates every Windows-specific gotcha you'd otherwise hit serially over 20+ minutes.

Trigger phrases: "set up langwatch on windows", "docker won't start", "init container fails", "init failed with ELIFECYCLE", "scripts/*.sh not found", "TLS leaf cert error", "UNABLE_TO_VERIFY_LEAF_SIGNATURE", "Cannot find module" pointing at `/c/...`, fresh worktree on Windows.

## What this mode does

It runs a **pre-flight pass** that fixes the host environment, then brings up the stack. The fixes are idempotent — safe to re-run.

Apply ALL of the following before `docker compose up`. Don't skip any "because it might already be set" — verifying takes 2 seconds; debugging an inherited misconfig takes 20 minutes.

## 1. Git on Windows

Run from the **worktree root** (or wherever `.git` lives):

```bash
git config core.longpaths true       # MAX_PATH 260 — needed for python-sdk's deeply-nested generated client
git config http.sslBackend schannel  # use Windows cert store; fixes "unable to get local issuer certificate"
git config core.autocrlf false       # NEXT clone won't insert CRLF
```

For submodules, repeat in each one:

```bash
for d in langwatch langevals; do
  [ -d "$d/.git" ] || continue
  ( cd "$d" && git config core.longpaths true && git config http.sslBackend schannel && git config core.autocrlf false )
done
```

**Why core.longpaths:** the langwatch python-sdk auto-generates files with names like `post_api_prompts_by_id_sync_response_200_conflict_info_remote_config_data_prompting_technique_demonstrations_inline_column_types_item.py`. Concatenated with the repo path, these exceed Windows' legacy 260-char MAX_PATH. Git refuses the checkout. The flag tells Git to use the Win32 `\\?\` extended-path API.

**Why schannel:** git-for-windows ships with `openssl` as the default HTTPS backend, using a bundled CA bundle. That CA bundle doesn't trust your machine's corp/local roots, so even github.com fails with "unable to verify the first certificate". `schannel` is the Windows native HTTPS backend — it reads from the OS cert store, which already trusts whatever your machine trusts.

## 2. Fix CRLF on every `.sh` in the working tree

Linux containers can't exec scripts whose shebang ends in `\r\n` — the kernel tries to find `/bin/sh\r` and reports "not found".

```bash
find . -name "*.sh" -not -path "*/node_modules/*" -not -path "*/.git/*" \
  -exec sed -i 's/\r$//' {} \;
```

Run this in the **worktree root**. There are ~50 .sh files in the langwatch wrapper; all of them must be LF for `init` and `app` containers to work.

This is required even if `core.autocrlf=false` is set now, because the existing checkout was made when `autocrlf` was still `true`.

## 3. Node / pnpm / npm TLS (when network calls hit registry.npmjs.org)

If you'll run anything on the **host** that fetches packages (`npm i -g`, `pnpm install`, `npx -y …`), the same root-cert issue Git hits applies to Node. Fix:

```bash
export NODE_OPTIONS="--use-system-ca"   # Node 22+ flag: read from OS cert store
```

Make it persistent for the user so future tool launches inherit it:

```powershell
# PowerShell, one-time per machine
[Environment]::SetEnvironmentVariable('NODE_OPTIONS', '--use-system-ca', 'User')
```

For MCP servers configured in `~/.claude.json` that launch via `npx`, patch their env block:

```json
"playwright": {
  "command": "npx",
  "args": ["@playwright/mcp@latest"],
  "env": { "NODE_OPTIONS": "--use-system-ca" }
}
```

After editing, run `/mcp` in Claude and reconnect, or restart Claude. **Failed MCPs stay failed until the session reconnects** — Claude only probes at startup.

For the container side (the `init` container's pnpm install), no fix is needed — Linux containers have working CA bundles. The Windows-specific TLS issue lives only on the host.

## 4. Don't run host-only prepare:files scripts when going docker-only

LangWatch's `scripts/dev.sh ensure_prepared()` does `pnpm install` + `pnpm start:prepare:files` on the **host** before bringing up compose. That hits a script bug on Windows: `scripts/generate-sdk-versions.sh` calls `node -e "require('$REPO_ROOT/typescript-sdk/package.json')"` where `$REPO_ROOT` is a Git Bash `/c/...` path. Node on Windows can't resolve those.

For docker-only workflows, **bypass `dev.sh`** and call compose directly:

```bash
VOLUME_PREFIX="$(basename "$PWD")" \
  docker compose -f compose.dev.yml --profile <PROFILE> up -d
```

Profile mapping (from `compose.dev.yml`):
| Preset       | --profile arg | Services                                                          |
|--------------|---------------|-------------------------------------------------------------------|
| all-local    | (none)        | postgres + redis + clickhouse + init + app                        |
| all-local-nlp| nlp           | + langwatch_nlp + langevals                                       |
| full-local   | full          | + workers + bullboard + ai-server                                 |

`VOLUME_PREFIX` is what `dev.sh` would have exported — it isolates per-worktree volumes (`app_modules`, `goose_bin`, `bullboard_modules`). Without it, every worktree collapses onto `langwatch-app-modules` and they trample each other's installed deps.

**The `init` container** handles `pnpm install` + `prisma generate` + `types:zod:generate` inside Linux Node 24, so the host doesn't need to. `app` waits on `init: service_completed_successfully`.

## 5. The `.env.dev-up` overlay (docker URLs)

`dev.sh` writes `langwatch/.env.dev-up` listing the service URLs that should be overridden to in-network DNS names (`redis:6379`, `postgres:5432`, etc.). If you bypassed `dev.sh`, this overlay doesn't exist, so the app container reads `langwatch/.env` which still says `redis://localhost:6379` — the api process times out trying to ping Redis and the container crash-loops.

Create the overlay manually before `up`. For **full-local**:

```bash
cat > langwatch/.env.dev-up <<'EOF'
NEXTAUTH_PROVIDER=email
DATABASE_URL=postgresql://prisma:prisma@postgres:5432/mydb?schema=mydb
REDIS_URL=redis://redis:6379
CLICKHOUSE_URL=http://default:langwatch@clickhouse:8123/langwatch
LANGWATCH_NLP_SERVICE=http://langwatch_nlp:5561
LANGEVALS_ENDPOINT=http://langevals:5562
EOF
```

For **all-local** (no NLP), drop the last two lines. For **all-local-nlp**, keep them.

The compose `env_file:` list loads `.env` first, then `.env.dev-up` — the overlay wins for the keys it defines, and `.env` keeps everything else (API keys, feature flags, ...).

## 6. Other `.env` preconditions

```bash
# Required by the SaaS-mode SSRF guard
grep -q '^BLOCK_LOCAL_HTTP_CALLS=true' langwatch/.env \
  || echo 'BLOCK_LOCAL_HTTP_CALLS=true' >> langwatch/.env

# Required by full-local / all-local-nlp presets
[ -f langwatch_nlp/.env ] || cp langwatch_nlp/.env.example langwatch_nlp/.env
```

## 7. Docker Desktop running + free RAM

`langevals` is a Python ML service that loads several embedding models. On Docker Desktop's default 4 GB RAM limit, it gets OOM-killed (exit 137) on cold start. If the user needs evaluators:

- Docker Desktop → Settings → Resources → bump Memory to **8 GB**, Swap to **2 GB**.
- Or skip the NLP/evals profile if the user's task doesn't need them (`--profile workers` instead of `--profile full`).

`bullboard` (BullMQ debug UI) has a separate workspace-root error on Windows and tends to crash; safe to ignore unless the user is actively debugging queues.

## 8. Bring-up sequence

After steps 1–7:

```bash
# Run once per machine (already done? still cheap to re-run)
export NODE_OPTIONS="--use-system-ca"

# In the worktree root
VOLUME_PREFIX="$(basename "$PWD")" \
  docker compose -f compose.dev.yml --profile full up -d

# Watch init progress
docker logs -f langy-persist-nav-init-1   # exits 0 when prep done

# Poll the app — Vite (5560) comes up before Hono API (6560 via proxy)
until [ "$(curl -sS -o /dev/null -w '%{http_code}' http://localhost:5560/api/auth/session)" != "502" ]; do
  sleep 4
done
echo "ready: http://localhost:5560"
```

## 9. Diagnostic recipes

| Symptom                                  | Root cause                                | Fix                                    |
|------------------------------------------|-------------------------------------------|----------------------------------------|
| `init` exits 1 with `scripts/*.sh: not found` | CRLF in shebang                       | Step 2 sed `s/\r$//`                   |
| `init` ELIFECYCLE on `generate-sdk-versions.sh` while building on Windows host | bash path passed to Node | Use docker-only path (Step 4 — bypass dev.sh) |
| `npm i` → UNABLE_TO_VERIFY_LEAF_SIGNATURE | Node bundled CA doesn't trust your root  | `NODE_OPTIONS=--use-system-ca`         |
| `git clone` → "unable to verify the first certificate" | Same, on git's openssl backend | `git -c http.sslBackend=schannel clone …` |
| `git checkout` → "Filename too long"     | Windows MAX_PATH                          | `git config core.longpaths true`       |
| `Cannot find module 'C:\…\package.json'` from bash | Node-from-bash path mismatch    | Use `cygpath -w "$path"` before passing to Node, or do it inside container |
| App container logs `PING timeout` for Redis | `.env` has `localhost:6379` for docker | Step 5 overlay (`redis://redis:6379`)  |
| `/api/*` returns 502 in browser, Vite logs `ECONNREFUSED 127.0.0.1:6560` | Hono api process not bound yet, or crashed | Watch `docker logs app` — usually warming up; if crashed, check overlay URLs |
| `langevals` container exits 137 (OOM)    | Docker Desktop memory < model needs       | Step 7 — raise to 8 GB, or drop the nlp profile |

## What this mode does NOT do

- It does not modify global `~/.gitconfig` — fixes are per-repo.
- It does not install Docker / WSL2 / Node — assumes those are present.
- It does not run `pnpm install` on the host. The container handles it.
- It does not touch the user's `.env` values (secrets) — only appends `BLOCK_LOCAL_HTTP_CALLS=true` if missing and creates the `.env.dev-up` overlay.

## Activating

When the user invokes `/windows-docker-ready` (or asks to set up langwatch on Windows for the first time, or shows symptoms from Section 9):

1. State which steps you're applying (1–8).
2. Run them in order; don't skip Step 2 (CRLF) — it's the most common silent killer.
3. Poll until `/api/auth/session` returns non-502.
4. Hand back with the app URL.

If a step's prerequisite isn't met (e.g., Docker Desktop not running), tell the user what to do and stop — don't try to start Docker Desktop programmatically.
