---
name: drive-pr
description: Take a PR all the way through merge AND clean up the local artifacts it leaves behind. The "babysit-pr" sister skill that also tears down the worktree + docker volumes + temp branches — but ONLY after the merge actually lands. Use when the user says "drive PR N", "/drive-pr N", "merge and cleanup", "ship it then tear it down", or asks you to land a PR and not leave debris on disk.
---

# drive-pr

Driving a PR is more than getting it green. The local cost of a feature PR — a worktree on disk, per-worktree docker volumes (10s of GB), a feature branch — sticks around forever unless someone cleans up. This skill drives the PR through merge and then, **and only then**, tears down the local artifacts it created.

If you only want "get it merged," use `babysit-pr`. If you also want "no debris on disk afterward," use `drive-pr`.

## The hard rule

**Cleanup runs ONLY after the merge state is confirmed.** Not after CI passes, not after the merge command returns, not after the queue accepts an auto-merge. The PR's actual `state` must read `MERGED` via `gh pr view` before a single `docker volume rm` or `git worktree remove` runs.

This protects against:
- Auto-merge that gets dequeued by a late failing check.
- Network blips that hang the merge mid-flight.
- A reviewer hitting "request changes" between the `gh pr merge` call and CI completion.
- The user changing their mind during the gap.

If `state != MERGED`, **stop**. Don't clean. Report status and hand back.

## Sequence

### 1. Drive the PR

Same as `babysit-pr` — get CI green, resolve conflicts, address review comments, run `/review`, etc. See that skill if the PR needs deep babysitting.

Resolve merge conflicts only with the user's standing authorization. For conflicts in auth / routes / feature-flag registries / migrations / security code, **ask before guessing** — wrong calls here are silent.

### 2. Merge

Use whichever method the repo accepts:

```bash
gh pr merge <N> --repo <owner>/<repo> --squash    # most repos
gh pr merge <N> --repo <owner>/<repo> --rebase    # if squash is blocked
gh pr merge <N> --repo <owner>/<repo> --merge     # if merge commits allowed
```

Add `--auto` if the repo has branch-protection rules that require all checks; otherwise it errors with "Auto merge is not allowed for this repository". When `--auto` fails, drop the flag and re-run (immediate merge).

### 3. CONFIRM merged

```bash
gh pr view <N> --repo <owner>/<repo> --json state,mergedAt,mergeCommit
```

Block on `state == "MERGED"`. If `state == "OPEN"` (merge queue, stuck CI, declined request), report and STOP. Do not proceed to cleanup.

### 4. Cleanup (ONLY after state == MERGED)

Cleanup happens in the worktree the PR was driven from. Steps:

#### 4a. Stop the local dev stack tied to this worktree

```bash
# Use the same VOLUME_PREFIX the user originally launched with so we
# target this worktree's containers, not a sibling worktree's stack.
VOLUME_PREFIX="$(basename "$PWD")" \
  docker compose -f compose.dev.yml --profile full down
```

If the worktree didn't run any compose stack (e.g. the PR was tooling-only), `docker compose down` is a no-op — safe.

#### 4b. Remove per-worktree docker volumes

```bash
# Worktree-isolated volumes (declared with ${VOLUME_PREFIX:-langwatch}-* names
# in compose.dev.yml). Removing these reclaims the GBs of node_modules,
# bullboard deps, and goose binaries that this worktree alone used.
for v in app-modules bullboard-modules goose-bin; do
  docker volume rm "${PWD##*/}-${v}" 2>/dev/null || true
done
```

**Do NOT remove** the SHARED stateful volumes (`langwatch-db-data`, `langwatch-clickhouse-data`, `langwatch-redis-data`) — other worktrees use them, and they hold the user's signed-up account + project data. The shared volumes survive across worktrees by design.

#### 4c. Remove the git worktree

```bash
# From the *parent* repo's directory, not the worktree itself.
# `git worktree remove` refuses to nuke the worktree you're standing in.
cd "$(git rev-parse --git-common-dir)/.." 2>/dev/null || cd ..
git worktree remove <worktree-path> --force
```

`--force` because the .env, .env.dev-up overlay, and other locally-created files are intentional artifacts you want gone.

#### 4d. Delete the merged feature branch

```bash
gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch-name>" 2>/dev/null || true
# Local copy:
git branch -D <branch-name> 2>/dev/null || true
```

Skip this step for stacked PRs whose head branch is the BASE of another open PR.

### 5. Report

After cleanup, give the user a one-paragraph summary:

```
PR #N merged at <timestamp>. Local cleanup:
  ✓ docker compose --profile full down
  ✓ removed volumes: <worktree>-app-modules, <worktree>-bullboard-modules, <worktree>-goose-bin
  ✓ git worktree remove <path>
  ✓ branch <name> deleted (origin + local)

Shared stateful volumes preserved: langwatch-db-data,
langwatch-clickhouse-data, langwatch-redis-data.
```

## What this skill does NOT do

- It does not clean if the merge didn't happen. Ever. The check at step 3 is non-negotiable.
- It does not touch the shared stateful db/redis/clickhouse volumes — those hold the user's data across worktrees.
- It does not delete the SOURCE repo (the parent clone), only the worktree.
- It does not stop or remove containers belonging to OTHER worktrees. The `VOLUME_PREFIX` scoping ensures we only touch this PR's stack.
- It does not delete the head branch when the PR is stacked and its head is some other PR's base. Check before deleting.

## When the user wants partial cleanup

If the user says "drive PR but keep the worktree, just stop docker" — honor that. The standard sequence is the default, not a mandate. The hard rule (no cleanup before merge) still applies regardless.

## Activating

When the user invokes `/drive-pr N` (or asks to land + clean up):

1. Confirm the PR number and base/target.
2. Drive it to merge per Section 1–2 (delegating to `babysit-pr` behaviors as needed).
3. Block on `state == MERGED` per Section 3.
4. If MERGED → run cleanup Section 4. If not → stop and report.
5. Summarize per Section 5.
