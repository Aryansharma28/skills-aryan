---
name: k8s
description: Bring up the Langy (and adjacent LangWatch) k8s stack on Windows + minikube + Docker Desktop + WSL2 — and recognize the recurring failure modes (stale kubeconfig after Docker/Windows restart, dead port-forward window, WSL↔Windows networking, CRLF in shell scripts, image-not-in-minikube symptom). Use when the user says "bring up langy", "set up minikube", "k8s won't start", "port-forward refused", "connection refused 30080", "WSL can't reach localhost", "apiserver stopped", "kubectl Unable to connect", or asks to install langy via helm on Windows minikube.
---

# k8s — Windows + minikube + Langy bring-up

Use this when the user wants the Langy infra running locally on **Windows 11 + Docker Desktop + WSL2 (Ubuntu) + minikube + helm + kubectl**, and especially when something in that chain has refused, timed out, or gone "Unable to connect".

The bring-up sequence is mostly idempotent. The failure modes are the real value of this skill — read the catalog at the bottom before diagnosing anything.

## Assumed layout

- Worktree:  `C:\Users\aryan\Desktop\langwatch_codebase\langwatch-pr<N>`
- `.env`:    `<worktree>\langwatch\.env` (seeded with OpenAI key, `LW_GATEWAY_*`, `NEXTAUTH`, `CREDENTIALS`, `LANGY_INTERNAL_SECRET`)
- Helm values overlay: `C:\Users\aryan\Desktop\langwatch_codebase\langwatch-saas\langy\values-langy-agent.yaml`
- minikube binary: `C:\minikube\minikube.exe` (NOT on PATH — call with the full path)
- Docker daemon: Docker Desktop (shared between Windows clients and WSL via the `\\.\pipe\dockerDesktopLinuxEngine`)

## Bring-up sequence (run in order, stop on errors)

### 1. CRLF-strip shell scripts

The #1 cause of "no such file or directory" in containers built from a Windows checkout. Strip CRLF from every `*.sh` under `services\langy-agent\` and `langwatch\scripts\`, plus `entrypoint.sh` and `server.js`.

**Use `[System.IO.File]::ReadAllBytes` + manual CRLF removal**, NOT `Get-Content` (which mangles binary content):

```powershell
$wt = 'C:\Users\aryan\Desktop\langwatch_codebase\langwatch-pr<N>'
$targets = @()
$targets += Get-ChildItem -Path "$wt\services\langy-agent" -Recurse -Filter '*.sh' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$targets += Get-ChildItem -Path "$wt\langwatch\scripts" -Recurse -Filter '*.sh' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
foreach ($extra in @("$wt\services\langy-agent\entrypoint.sh","$wt\services\langy-agent\server.js")) {
  if (Test-Path $extra) { $targets += $extra }
}
foreach ($f in ($targets | Sort-Object -Unique)) {
  $bytes = [System.IO.File]::ReadAllBytes($f)
  $out = New-Object System.Collections.Generic.List[byte]
  for ($i=0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0x0D -and ($i+1) -lt $bytes.Length -and $bytes[$i+1] -eq 0x0A) { continue }
    $out.Add($bytes[$i])
  }
  if ($out.Count -ne $bytes.Length) {
    [System.IO.File]::WriteAllBytes($f, $out.ToArray())
    "stripped: $f"
  }
}
```

Idempotent. If nothing is stripped, the worktree was already LF-only — good.

### 2. Start compose deps (postgres, clickhouse, redis)

```bash
cd /c/Users/aryan/Desktop/langwatch_codebase/langwatch-pr<N>
docker compose -f compose.dev.yml -f compose.dev.migration.yml up -d postgres clickhouse redis
```

The "volume already exists but was created for project X" warnings are **expected and harmless** — the shared volumes (`langwatch-db-data`, `langwatch-clickhouse-data`, `langwatch-redis-data`) are reused across worktrees by design.

Verify:
```bash
docker ps --filter "name=postgres" --filter "name=clickhouse" --filter "name=redis" --format "table {{.Names}}\t{{.Status}}"
```
All three should be `Up ... (healthy)`.

### 3. Start minikube

```powershell
& 'C:\minikube\minikube.exe' status
# If anything is "Stopped", run:
& 'C:\minikube\minikube.exe' start --driver=docker --cpus=4 --memory=8192 --disk-size=40g
```

After ANY Docker Desktop restart or Windows reboot, the minikube container may still show `host: Running` but `kubelet: Stopped` + `apiserver: Stopped`. **You still need `minikube start` to relight the control plane.**

### 4. Namespace + LANGY_INTERNAL_SECRET

```powershell
kubectl get ns langwatch 2>$null
# Create if missing:
kubectl create ns langwatch

# Secret carries the bearer the langwatch app uses to call the langy pod
kubectl -n langwatch get secret langwatch-langy-agent-auth 2>$null
```

If the Secret doesn't exist, generate a fresh 64-hex-char value AND patch the same value into `<worktree>\langwatch\.env`'s `LANGY_INTERNAL_SECRET=` line. **The value in `.env` and the Secret MUST match** — that's the app-to-pod auth. Use byte-level write to `.env` (not `Set-Content`) to avoid touching encoding.

To reconcile when both exist:
```powershell
$envPath = '<worktree>\langwatch\.env'
$b64 = kubectl -n langwatch get secret langwatch-langy-agent-auth -o jsonpath='{.data.LANGY_INTERNAL_SECRET}'
$val = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
# Then read .env bytes, replace the LANGY_INTERNAL_SECRET= line, write bytes back.
```

### 5. Build the langy image directly into minikube

```powershell
& 'C:\minikube\minikube.exe' image ls | Select-String 'langy-agent'
# If present, skip the rebuild. Otherwise:
& 'C:\minikube\minikube.exe' image build -t langwatch/langy-agent:local -f '<worktree>\Dockerfile.langy_agent' '<worktree>'
```

Cold build ~5–10 min; layers cache on rebuild. **Do NOT try to pull from docker.io** — the image isn't public; that's a sure sign step 5 was skipped on a cluster where the image isn't already there.

### 6. helm install + wait for rollout

```powershell
helm upgrade --install langy '<worktree>\charts\langy-agent' -n langwatch -f 'C:\Users\aryan\Desktop\langwatch_codebase\langwatch-saas\langy\values-langy-agent.yaml'
kubectl -n langwatch rollout status deploy/langy-langwatch-langy-agent --timeout=180s
kubectl -n langwatch get pods -l app.kubernetes.io/name=langwatch-langy-agent
```

Pod should be `1/1 Running`. Log line confirming success:
```
langy manager listening on :8080, MAX_WORKERS=20
```

### 7. Port-forward in a new PowerShell window

```powershell
Start-Process powershell -ArgumentList '-NoExit','-Command','$host.UI.RawUI.WindowTitle="langy port-forward — do not close"; kubectl -n langwatch port-forward svc/langy-langwatch-langy-agent 30080:80'
```

The titled window is intentional — closing it kills the forward, and 30080-refused failures are otherwise mysterious. **Tell the user explicitly: do not close this window.**

Verify Windows-side:
```powershell
Invoke-WebRequest http://127.0.0.1:30080/health -UseBasicParsing
```
Expect `200` with body `ok (0/20 workers)`.

## End-to-end usability check

The langwatch app (in `pnpm dev`) reads:
- `OPENCODE_AGENT_URL` — must be `http://localhost:30080`
- `LANGY_INTERNAL_SECRET` — must match the k8s Secret

Probe the chain with the real secret:

```powershell
$secret = (Select-String -Path '<worktree>\langwatch\.env' -Pattern '^LANGY_INTERNAL_SECRET=').Line -replace '^LANGY_INTERNAL_SECRET=',''
Invoke-RestMethod -Uri 'http://127.0.0.1:30080/chat' -Method POST `
  -Headers @{ Authorization = "Bearer $secret" } `
  -Body '{}' -ContentType 'application/json' `
  -SkipHttpErrorCheck -StatusCodeVariable code
"status=$code"
```

Expected: `400 {"error":"missing required: conversationId, prompt, credentials"}` — proves the bearer matched (passed auth gate, reached body validation).

If `401 unauthorized`: `.env` and Secret are out of sync — redo step 4.

## Done criteria

- `kubectl -n langwatch get pods` shows `1/1 Running`
- Pod log: `langy manager listening on :8080, MAX_WORKERS=20`
- Port-forward window prints: `Forwarding from 127.0.0.1:30080 -> 8080`
- `GET http://127.0.0.1:30080/health` → 200
- `POST /chat` with the real bearer → 400 (body-validation error, NOT 401)

---

## Failure mode catalog

These are recurring and high-cost-if-misdiagnosed. Match symptom → diagnosis → fix.

### A. "kubectl Unable to connect to the server: dial tcp 127.0.0.1:NNNNN" after a reboot/Docker restart

**Symptom:** Every kubectl/helm command returns `Unable to connect to the server: dial tcp 127.0.0.1:<port>: connectex: No connection could be made`.

**Cause:** Docker Desktop or Windows restarted. The minikube container came back up but its apiserver inside is down, AND the host-port mapping changed — kubeconfig now points at a stale port.

**Diagnosis:**
```powershell
& 'C:\minikube\minikube.exe' status
# Look for:  host: Running / kubelet: Stopped / apiserver: Stopped / kubeconfig: Misconfigured
# And a warning: "kubeconfig endpoint: got: 127.0.0.1:OLD, want: 127.0.0.1:NEW"
```

**Fix:**
```powershell
& 'C:\minikube\minikube.exe' start --driver=docker
& 'C:\minikube\minikube.exe' update-context
```
`start` relights kubelet/apiserver; `update-context` rewrites the kubeconfig port. **Then the port-forward window is also dead** — restart it (step 7).

### B. "Connection refused on 30080" with no errors anywhere

**Symptom:** `curl http://localhost:30080/...` (from either WSL or Windows) returns `Connection refused`. Pod is healthy in `kubectl get pods`.

**Cause:** The port-forward window died (user closed it, or it crashed when kubectl lost the apiserver in failure mode A).

**Diagnosis:**
```powershell
Get-NetTCPConnection -LocalPort 30080 -State Listen -ErrorAction SilentlyContinue
```
Empty result = no listener. The port-forward is gone.

**Fix:** Restart it (step 7). If `kubectl` itself errors before the forward starts, fix failure mode A first.

### C. WSL can't reach localhost:30080 (but Windows can)

**Symptom:** From Windows, `Invoke-WebRequest http://127.0.0.1:30080/health` → 200. From WSL, `curl http://localhost:30080/health` → `Connection refused`. WSL also can't reach Windows host IPs like `172.22.160.1` or `10.255.255.254`.

**Cause:** WSL2 in classic NAT mode has its own network namespace; `localhost` in WSL is WSL's loopback, not Windows's. The Windows host IPs are blocked by Windows Defender Firewall by default on the WSL adapter.

**Fix — preferred (mirrored networking):**
1. Create/edit `C:\Users\aryan\.wslconfig`:
   ```
   [wsl2]
   networkingMode=mirrored
   ```
2. In a PowerShell prompt (NOT inside WSL): `wsl --shutdown` — this kills everything inside WSL distros (`pnpm dev` etc.), but Docker Desktop's daemon, compose containers, minikube, and the port-forward window are all on the Windows side and survive.
3. Reopen WSL. `localhost:30080` in WSL now maps directly to Windows's `127.0.0.1:30080`. `.env`'s `OPENCODE_AGENT_URL=http://localhost:30080` works as-is.

**Verify mirrored mode is active in the running distro:**
```bash
ip -4 addr show eth0 | grep inet      # should show 169.254.x.x link-local, NOT 172.x classic-NAT
ip route show default                 # should show default via your Windows LAN gateway on eth1
uname -r                              # need 6.6.x+
```

If `.wslconfig` already has mirrored mode set but WSL still behaves like NAT, the distro was started before the config landed — `wsl --shutdown` and reopen.

**Anti-pattern:** rebinding the port-forward to `0.0.0.0` and putting the (changing) Windows host IP into `.env`. It works, but the IP drifts and you need a firewall exception. Use mirrored mode instead.

### D. Pod CrashLoops with "fatal: LANGY_INTERNAL_SECRET is required"

**Cause:** The Secret was created but its `LANGY_INTERNAL_SECRET` data key is empty or unset.

**Fix:** Delete and recreate the Secret with a real 64-hex value (step 4), then `kubectl -n langwatch rollout restart deploy/langy-langwatch-langy-agent`. Don't forget to patch the same value into `.env`.

### E. Pod `ImagePullBackOff` for `langwatch/langy-agent:local`

**Cause:** The image was built into a different minikube instance, or was never built. There is no public registry for this image.

**Fix:** Rebuild into the current minikube (step 5). Do NOT add a registry pull secret or try to pull from docker.io — the image is local-only.

### F. Compose containers belong to a different project name

**Symptom:** Compose prints `volume "langwatch-X-data" already exists but was created for project "langwatch" (expected "langwatch-pr<N>")`.

**Cause:** Stateful volumes are intentionally shared across worktrees. The warning is informational.

**Action:** Ignore. Confirmed safe — `langwatch-db-data`, `langwatch-clickhouse-data`, `langwatch-redis-data` are designed to persist across worktree switches so sign-up state survives.

### G. `pnpm dev` returns "Agent not configured" from the Langy route

**Cause:** Either `OPENCODE_AGENT_URL` or `LANGY_INTERNAL_SECRET` is missing from the process env — `.env` was edited after `pnpm dev` started.

**Fix:** Restart `pnpm dev` after any `.env` change. Node only reads `.env` at process start.

### H. Langy chat returns 409 "No model configured" or credential errors despite healthy pod

**Cause:** Not a langy-infra issue. The langwatch route's pre-flight requires:
- An AI Gateway up on `LW_GATEWAY_BASE_URL` (default `http://localhost:5560`) — auto-started by `pnpm dev` when Go is on PATH
- The project has a configured model (`getVercelAIModel(projectId)`)
- The user has `evaluations:view` on the project (staff @langwatch.ai bypasses the feature flag)

**Action:** Don't rebuild k8s. Check the dev app first.
