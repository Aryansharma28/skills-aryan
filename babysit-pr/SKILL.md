---
name: babysit-pr
description: Take a PR all the way to "done" — CI green, all review/CodeRabbit comments resolved, /review run, and code quality (DRY, YAGNI, blast radius, architecture) personally verified. Use when the user says "babysit PR N", "watch this PR", "finish this PR", "keep pushing until green", or asks you to stay on a PR until it's truly ready.
---

# babysit-pr

Stay on a pull request until it is *actually done* — not just green CI, but: every required check passing, every review comment resolved or consciously dismissed, `/review` (or equivalent) run and addressed, and the diff itself reviewed by you for code quality. The user hands you a PR number (or URL) and expects you to come back only when it's done or genuinely stuck.

## Definition of done

A PR is only "done" when **all** of these are true. Do not declare done until you have explicitly verified each one.

1. **CI fully green.** All non-skipped workflow runs on the latest commit = `success`.
2. **All review comments resolved.** Every CodeRabbit / Copilot / human reviewer comment is either fixed in code or has a written reason for being dismissed.
3. **`/review` has been run** on the latest commit and its findings addressed (or dismissed with reason).
4. **Code quality pass done by you.** You read the diff with the lens below and either fixed issues or surfaced them to the user.
5. **Mergeable** (`mergeable: MERGEABLE`, no conflicts with base).

If any of these is unmet, the PR is not done — keep working or surface a blocker.

## Inputs you need

- PR number (and repo, if not obviously the current one) — ask if ambiguous.
- Authorization scope: can you push fixes directly, or only suggest them? Default to **push low-risk fixes directly**; escalate anything that touches public behavior, schemas, or security.

## Core loop

1. **Snapshot state.** `gh pr view <N> --json headRefName,state,mergeable,reviewDecision` and `gh run list --branch <branch> --limit 20 --json ...`. Use `gh run list` — not just `gh pr checks` — because the latter deduplicates by name and can hide failing runs behind later passing ones (project rule).
2. **Classify each check:**
   - `success` / `skipped` / `neutral` — leave alone.
   - `in_progress` / `queued` / `pending` — keep watching, don't act.
   - `failure` / `cancelled` / `timed_out` / `action_required` — pull logs, diagnose, fix.
3. **Pull review comments** on every iteration: `gh api repos/OWNER/REPO/pulls/N/comments` and `.../issues/N/comments`. Track seen IDs so you only act on new ones.
4. **Act on what you find** (see triage rules below).
5. **Watch, don't poll.** Use the Monitor tool with a persistent loop that emits only on *state change* (new run, new conclusion, new comment). Never chain sleeps from the main thread. Pick a 45–90s poll cadence — faster wastes API quota, slower misses early-warning signal.
6. **Stop when terminal.** Either: all five "definition of done" conditions met (report done), or repeated fixes fail to clear the same failure (stuck — report with what you tried).

## When CI is green

Going green is *not* the finish line — it's when the real "done" check starts. Once everything is `success`:

1. Run `/review` (or invoke the review skill) on the latest commit. Wait for results. Address findings.
2. Re-pull review comments — sometimes CodeRabbit posts late, after CI finishes.
3. Run the **code quality pass** (section below). Fix or surface.
4. Re-check mergeable state — base may have moved.
5. Only then report done.

## Code quality pass (the YAGNI/DRY/blast-radius gate)

Before declaring done, read the diff yourself — `gh pr diff <N>` — and apply this checklist. Fix what you find directly (low-risk) or surface it (anything touching public behavior).

- **YAGNI.** Any code added for a hypothetical future requirement? Any flag/abstraction/config knob with no current caller? Delete it.
- **DRY — but only where it earns its keep.** Three near-identical blocks may still be fine. A premature abstraction with one caller is worse than the duplication it tries to remove. Flag genuine repetition; don't invent shared helpers for the sake of it.
- **Blast radius.** What else does this touch? Shared utilities, exported types, DB schemas, public APIs, CI config — does the PR scope match the change's reach? If a "small fix" mutates a function with 40 callers, surface that.
- **Architecture fit.** Does the change live in the right layer? Are concerns leaking (HTTP code in a domain module, SQL in a controller)? Is it consistent with how the surrounding code is organized?
- **Scope creep.** Are there refactors, renames, or cleanups bundled in that aren't related to the stated purpose? Either split or call them out in the PR description.
- **Dead code, stale comments, debug prints.** Remove.
- **Error handling at boundaries only.** Trust internal calls; validate at user input / external APIs. Defensive code on every internal call is noise.
- **Comments.** Remove WHAT-comments and PR-context comments ("added for ticket X"). Keep only WHY-comments where the reason is non-obvious.
- **Tests.** Does the new behavior have a test? Was an existing test deleted or weakened to make the build pass? If yes, flag it.
- **Security smell.** Any new user input not validated? Secrets in logs? SQL/HTML concatenation? Don't auto-fix — surface.

Commit fixes from this pass with messages like `cleanup: remove unused FeatureFlag plumbing (YAGNI)` so the human reviewer can see the rationale.

## Triage rules for failures

Match in order; apply the first that fits.

| Signal | Action |
|---|---|
| Lint / format / typecheck failure with obvious fix in the log | Apply the fix locally, commit, push. |
| Flaky test (transient infra, network, OOM) | Re-run once via `gh run rerun <id> --failed`. Don't re-run more than once per run — that hides real bugs. |
| Test failure that clearly maps to a change in this PR | Read the test, diagnose, fix the code (not the test). If the test is wrong for a legitimate reason documented in the PR, fix the test — but call it out in the commit message. |
| CodeRabbit / reviewer comment that's valid and low-risk | Apply the fix. Commit with a message that references the comment and what you changed. Verify against current code first — don't apply blindly if the code already addresses it. |
| CodeRabbit / reviewer comment that's wrong, stale, or low-value | Leave it alone. Don't argue in-PR unless the user asks. |
| Failure you can't reproduce or understand | Stop and surface it. Include the run ID, the failing step, the last 30 relevant log lines, and what you think is happening. Don't guess-and-push. |
| Security-review / compliance workflow failure | Stop and surface. Never auto-fix. |

## Rebasing safely

The upstream branch may get rebased while you're working (common on shared PRs). When `git push` rejects:

1. `git fetch origin <branch>`
2. Compare local and remote histories.
3. If remote has diverged because of an upstream rebase, `git reset --hard origin/<branch>` then cherry-pick your unpushed commits onto the new tip.
4. Verify `git log` before pushing.
5. Push again.

Never `git push --force` without confirming the scope with the user.

## Commits

- One concern per commit. Don't batch a typo fix and a logic change.
- Commit message: `<type>(<scope>): <what>`. Body explains *why* and, where relevant, links the review comment or failing check.
- Always create new commits — never `--amend` on a pushed branch unless the user explicitly asks.

## Push cadence

- Don't push every tiny change. Batch obviously related fixes into one push to avoid retriggering CI thrash.
- But don't sit on a fix waiting for more — if a fix addresses a red check, get it out so CI can start moving.

## When to surface to the user

Always report when:
- All checks are green (done).
- You got stuck (same failure recurring, or a fix you don't trust).
- A new human reviewer (not a bot) posted a comment — their feedback often warrants human judgment.
- The PR was closed or merged out from under you.

Don't report on:
- Every run that turns green.
- Routine "fix applied, pushed, CI rerunning" loops — those are the job.

## Tooling

- `gh` CLI for everything GitHub. Use `gh api repos/OWNER/REPO/pulls/N -X PATCH` to edit PR bodies (avoids the deprecated Projects warning from `gh pr edit --body`).
- Monitor tool (persistent, stdout-line-per-event) for the watch loop. Filter must emit on every terminal state, not just success — silence on a crash looks identical to "still running."
- For log fetching: `gh run view <id> --log-failed` for just the failing step; full log via `gh run view <id> --log` only when necessary (big output).

## Non-goals

- Don't merge the PR. Even if all checks pass, leave merging to the human.
- Don't `force-push` main/master or any branch the user didn't explicitly name.
- Don't touch `.github/workflows/*.yml` unless the user asked — CI-config changes are a category the human owns.
- Don't reply inline to review comments. Commit-message references are how you acknowledge feedback.
