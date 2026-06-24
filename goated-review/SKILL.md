---
name: goated-review
description: Deep, bulletproof PR review — pull the full room first (existing reviews, CodeRabbit/Copilot, CI, the description's own claims), bucket files by risk, grep every "every consumer migrated"-type claim, adversarially verify each finding before posting, and ship one summary review + N inline comments tagged [BLOCKER] / [NON-BLOCKER] with file:line evidence. Use when the user says "goated-review N", "do a deep review on PR N", "bulletproof review", "review and post comments on PR N", or hands you a PR they want torn down to studs (especially large refactors, deletions, or anything CodeRabbit skipped).
---

# goated-review

Default `/review` and `/code-review` are fine for normal PRs. This skill is for the PRs that *matter* — large refactors, mass deletions, dependency bumps with supply-chain risk, security-adjacent changes, anything CodeRabbit/Copilot skipped because the diff is too big. The user wants a review that will hold up: every claim cited, every finding adversarially verified, blockers separated from polish, posted as PR comments.

The output is not a vibes paragraph. It's a structured PR review with:
- A summary comment with verdict + grouped findings.
- Inline comments at specific file:line locations, tagged `[BLOCKER]` or `[NON-BLOCKER]`.
- Zero duplicates of what existing reviewers already flagged.
- Zero hallucinations — every claim quotes the code.

## When to use this vs the alternatives

| Skill | When | Output |
|---|---|---|
| `/code-review` | Quick gate on your own working diff | Local findings, often auto-applied |
| `/review` | Standard PR review on a normal-sized GitHub PR | One-shot review pass |
| **`goated-review`** | Large refactor, mass deletion, lockfile/dep change, security-adjacent, CodeRabbit skipped, "needs to be bulletproof" | Structured BLOCKER / NON-BLOCKER posted as inline + summary comments |
| `understand-pr` | You want to *learn* the PR, not gate it | Teaching walkthrough |
| `babysit-pr` | The PR is yours and you want to land it | Drives PR to green |

If the user says "deep", "bulletproof", "thorough", "tear apart", "rip into", or the PR is >150 files / >5k lines / has mass deletions — default to this.

## Inputs you need

- **PR number** and repo (assume the obvious one if unambiguous, ask otherwise).
- **Authorization scope** — usually "post the comments yourself." If the user said "draft only" or "show me first", *show the full plan before posting*. Posting PR comments is shared-state and visible to others; default to confirming before fanning out comments on someone else's PR. The user's own PR is lower stakes.
- **Severity convention** — default to `[BLOCKER]` / `[NON-BLOCKER]`. Mirror the project if it uses P1/P2/P3 (grep recent PR comments to see). Tell the user which convention you're using.

## The core loop

```
1. Read the room      (existing reviews, CodeRabbit, CI, description claims)
2. Slice the diff     (paginated file list → risk buckets)
3. Find               (deep-read each bucket; capture findings with file:line + evidence)
4. Verify             (adversarially refute each finding; drop if uncertain)
5. Dedupe             (drop anything an existing reviewer already raised)
6. Classify           (blocker vs non-blocker; severity-tag)
7. Show               (present the full plan to the user before posting)
8. Post               (one summary review + N inline comments)
9. Loop until dry     (re-sweep; stop after two consecutive dry passes)
```

The loop stages are NOT optional — skipping verify is how you ship false-positive comments that destroy reviewer trust.

## Stage 1 — Read the room

Before reading a single line of diff, get the surrounding signal. **You will absolutely embarrass yourself if you re-raise what Rogerio flagged three weeks ago.**

```bash
# PR metadata + CI snapshot
gh pr view <N> --repo <owner/repo> \
  --json title,body,author,baseRefName,headRefName,state,mergeable,reviewDecision,additions,deletions,changedFiles,labels,url

# CI status — note any failing checks; failing CI is a blocker by default
gh pr checks <N> --repo <owner/repo>

# PR-level reviews (CodeRabbit summary, Copilot, humans)
gh api repos/<owner>/<repo>/pulls/<N>/reviews --paginate \
  -q '.[] | {user: .user.login, state, submitted_at, body: (.body[0:500])}'

# Inline review comments — the existing P1/P2 list you must dedupe against
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate \
  -q '.[] | {path, line, user: .user.login, body}' > /tmp/existing-comments.jsonl

# Issue-level comments (CodeRabbit summary lives here, sometimes "review skipped" too)
gh api repos/<owner>/<repo>/issues/<N>/comments --paginate \
  -q '.[] | {user: .user.login, body: (.body[0:1500])}'
```

Things to capture from this stage:
- **Did CodeRabbit skip?** ("Too many files!" or "exceeds the maximum number of lines") — if yes, you can't lean on it; your own coverage matters more.
- **Did Copilot skip?** Same.
- **Is CI failing?** Failing CI is a blocker by default. Pull the failing job logs (`gh run view <id> --log-failed`) and decide whether it's flake or real.
- **What did existing reviewers raise?** Build a `path:line → comment` map so you never re-post the same finding. Quote their concern in your summary ("@reviewer's P1 still open") rather than re-raising it independently.
- **What does the author flag as surprising?** Read the PR description's "Anything surprising?" / "Notes" / "Caveats" section in full. Every claim there is a candidate for verification.

## Stage 2 — Slice the diff

GitHub's diff API caps at ~20k lines. For large PRs `gh pr diff` returns HTTP 406. Use the files API and paginate:

```bash
gh api repos/<owner>/<repo>/pulls/<N>/files --paginate \
  -q '.[] | .filename + "\t" + (.additions|tostring) + "\t" + (.deletions|tostring) + "\t" + .status' \
  > /tmp/pr-files.tsv
```

Also note: `gh pr view --json files` truncates at 100 files. Always use the paginated `/files` endpoint for anything large.

Bucket every file into risk areas. The bucket is what tells you how hard to look — not all files deserve the same scrutiny.

| Bucket | What's in it | Scrutiny |
|---|---|---|
| **Lockfile / package.json / workspace files** | `*-lock.yaml`, `package.json`, `pnpm-workspace.yaml`, `Cargo.lock`, etc. | **High.** New transitive deps, removed deps, weird importers, unrelated bumps. Check supply-chain policy if the repo has one. |
| **DB schema / migrations** | `schema.prisma`, `migrations/*`, ClickHouse DDL | **High.** Backward compat, dual-write windows, dropped columns vs orphaned columns, rollback story. |
| **Public API surface** | REST/GraphQL/tRPC routers, OpenAPI, public types, exported package entries | **High.** Breaking changes, deprecated paths still in use, error contract changes. |
| **Mass deletions** | Status `removed`, large negative diffs | **High.** Did the author find every caller? Are there orphaned references in tests, docs, CI, dashboards, runbooks? |
| **Auth / security-adjacent** | Auth middleware, session/token code, secrets handling, CORS, CSP | **High.** Never auto-trust; always verify. |
| **Infra / CI / Docker / Helm** | `.github/workflows/*`, `Dockerfile`, helm charts, terraform | **High.** Failure mode changes, image size, secret exposure. |
| **Cron / scheduled jobs** | `/cron/*`, queue handlers, schedules | **Medium-High.** Removing a cron without confirming nothing depends on it is a classic incident. |
| **Behavior-changing refactors** | Service classes, facade collapses, throw-vs-null changes | **Medium-High.** Read every caller of changed-semantic methods. |
| **Component / UI** | `*.tsx` page/component changes | **Medium.** A11y, error states, loading states, mobile. |
| **Tests** | `__tests__`, `*.test.*`, `*.spec.*` | **Medium.** Was a test deleted to make the build pass? Was a real assertion weakened to a mock? |
| **Internal refactors (pure renames, moves)** | File moves, identifier renames | **Low.** Skim; check for missed references. |
| **Docs / generated** | `*.md`, generated types | **Low.** Skim. |

Write the bucket map to scratch so you can work through it methodically — don't try to hold 262 files in your head.

## Stage 3 — Find

For each bucket, the question changes. These are the prompts that produce real findings, not generic AI slop.

**Lockfile / deps:**
- Are there NEW importers that don't correspond to a workspace in the repo?
- Did any package version *downgrade*?
- Did unrelated minor/patch bumps sneak in alongside the stated change?
- Does the repo have a supply-chain allowlist/policy file (`.pnpm-supply-chain-policy.yaml`, `audit-ci.json`, custom denylist)? Diff against it.
- Are removed dependencies actually unimported everywhere? `rg "from ['\\\"]<dep>['\\\"]"` across the repo.

**Mass deletions:**
- Search for every deleted symbol/file path across the codebase: `rg -F "<deleted-name>" --type-add 'cfg:*.{json,yaml,yml,toml,md,sh}' --type ts --type js --type cfg`.
- Check **dashboards, runbooks, docs, error-tracking config, alerts** — these often reference deleted route paths / metric names and rot silently.
- Check Helm values, k8s manifests, terraform — they may still mount or expect the deleted resource.

**Behavior changes (throw vs null, removed fallbacks, semantic shifts):**
- For every changed method signature or semantic change, grep all callers: `rg "\\.<methodName>\\("`.
- Read the caller. Does it handle the new behavior? Try-catch in the right place? Falls-back path actually defensible?

**PR description claims:**
- Author says "every consumer migrated" → grep every consumer and verify.
- Author says "deleted routes return 404" → if you have a local checkout, hit them; otherwise read the router config and confirm.
- Author says "the column is unused after this PR" → grep for the column name.
- If a claim is unverifiable from the diff alone, *say so* in the review rather than trusting it.

**The "what's NOT in this PR" check:**
- Should there be a follow-up migration to actually drop the orphaned column?
- Should the changelog / runbook / docs be updated alongside?
- Is there a feature flag that should be flipped / removed in the same PR?
- Are there alerts / dashboards / SLOs that need to follow?

Capture each finding as a row in a scratch file:

```
file:line | severity | claim | evidence
```

Don't classify severity yet — that's Stage 6.

## Stage 4 — Verify (adversarial)

Every finding is suspect until proven. For each one:

1. **Re-read the code** at the cited file:line. Did you misread it?
2. **Try to refute the finding.** "What if X handles this? What if there's a different code path? What if this is intentional and documented?"
3. **Grep the surrounding context** — README, CHANGELOG, comments, related test names.
4. **If you can't refute and the evidence is concrete (the line numbers, the actual code) → keep.** Otherwise drop.

Default to **drop on uncertainty**. A wrong blocker is worse than a missed nit — it wastes the author's time and erodes review credibility.

For the highest-stakes findings (anything you'll tag BLOCKER), explicitly write down the refutation attempt and why it failed. If you can't articulate why the refutation doesn't hold, downgrade or drop.

## Stage 5 — Dedupe against existing reviewers

For each surviving finding, scan `/tmp/existing-comments.jsonl`:
- Same `path` + nearby `line` + similar claim → drop yours.
- Same root issue raised by an existing reviewer → drop yours and instead **reference theirs** in the summary ("@reviewer's P1 about X is still open and load-bearing").

You're not competing with existing reviewers — you're filling the gaps they missed.

## Stage 6 — Classify

For each finding, ask:

**BLOCKER** if any of:
- Build will break / CI is failing because of this change.
- Behavior is wrong for users at runtime (data loss, wrong response, 500s, auth bypass).
- Supply-chain / security risk (untrusted package, secret leak, missing validation at boundary).
- Backward-incompatibility with deployed clients without a stated migration.
- Orphaned references that will break at runtime (deleted route still called by cron, deleted column still queried, etc.).
- Required follow-up that *must* land with this PR (e.g., the migration to drop the column the app no longer writes to — only if leaving it would actively break something).

**NON-BLOCKER** for everything else:
- Naming / readability nits.
- Missing tests for a low-risk change.
- Stale comments / TODOs.
- Refactor opportunities (DRY / YAGNI / simpler implementation).
- Doc / runbook drift that doesn't break runtime.
- Suggestions that improve the code but aren't required to merge.

Be conservative with BLOCKER. Inflating severity is how you become the reviewer everyone ignores.

## Stage 7 — Show the plan before posting

Before any `gh api .../comments` call, present the full plan to the user:

```
Plan to post on PR #<N>:

Summary comment (PR-level, will be posted as a REQUEST_CHANGES / COMMENT review):
  Verdict: <approve / comment / request changes>
  <N> blockers, <M> non-blockers
  <one-paragraph executive summary>

Inline comments (<count> total):
  [BLOCKER] path/to/file.ts:42 — <one-line claim>
  [BLOCKER] path/to/other.ts:117 — <one-line claim>
  [NON-BLOCKER] path/to/file.ts:88 — <one-line claim>
  ...

Existing findings I'm NOT re-raising:
  @rogeriochaves P1 (lockfile) — referenced in summary
  @0xdeafcafe's self-comments — context only, not flagged
```

**Pause here.** Let the user adjust, drop, or rewrite anything before posting.

This step is non-negotiable for someone else's PR. For the user's own PR, you can skip the pause if they explicitly said "just post."

## Stage 8 — Post

Two-stage posting works best:

**A) Summary review** — one PR-level review with grouped blockers/non-blockers.

```bash
gh api repos/<owner>/<repo>/pulls/<N>/reviews \
  -f event=COMMENT \
  -f body="$(cat <<'EOF'
## Review summary

<one-paragraph verdict>

### Blockers
- [<file:line>] <one-line claim with link>
- [<file:line>] <one-line claim with link>

### Non-blockers
- [<file:line>] <one-line claim with link>

### Existing findings still open
- @rogeriochaves P1 on the lockfile importer — still load-bearing, addressing it should unblock supply-chain CI.

<note about anything you couldn't verify from the diff alone>
EOF
)"
```

Pick the right `event`:
- `APPROVE` — only when you have zero blockers and the change is well-scoped. Rare for the kind of PR this skill targets.
- `REQUEST_CHANGES` — at least one BLOCKER and you have authority to gate. Note: requesting changes on someone else's PR is forceful; default to `COMMENT` unless the user explicitly said to request changes.
- `COMMENT` — the default. Findings posted as commentary; the author and maintainer decide what to act on.

**B) Inline comments** — one per finding, anchored to a specific line. Use the same review API in one call to keep them grouped:

```bash
gh api repos/<owner>/<repo>/pulls/<N>/reviews \
  -f event=COMMENT \
  -f body="Inline findings — see comments." \
  -f 'comments[][path]=path/to/file.ts' \
  -f 'comments[][line]=42' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=[BLOCKER] <claim>

**Why:** <one-paragraph evidence with quoted code>

**Suggested fix:** <if you have one>' \
  -f 'comments[][path]=other.ts' \
  -f 'comments[][line]=117' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=[NON-BLOCKER] <claim>...'
```

Two posting strategies work — pick one:
1. **Single combined review** — summary + all inline in one API call. Cleaner for the PR timeline. Use when comments are tightly related.
2. **Summary first, inline second** — easier to iterate. Use when you have many inline comments and want to verify the summary lands before fanning out.

For single inline comments outside a review:

```bash
gh api repos/<owner>/<repo>/pulls/<N>/comments \
  -f body='[NON-BLOCKER] <claim>' \
  -f commit_id="$(gh pr view <N> --json headRefOid -q .headRefOid)" \
  -f path='path/to/file.ts' \
  -F line=42 \
  -f side=RIGHT
```

**Always use the PR's current `headRefOid` as `commit_id`** — using an older SHA produces "outdated" comments that scroll off the review thread.

### Comment template

Every comment follows the same shape — predictable, easy to scan:

```
[BLOCKER|NON-BLOCKER] <one-line claim>

**Why:** <2-4 sentences of evidence — what's wrong, why it matters, what breaks>

**Evidence:** <quoted code or file:line references>

**Suggested fix:** <concrete change, if you have one — otherwise omit>
```

Skip "Suggested fix" rather than pad with vague hand-waving. If you don't have one, the comment is still valuable.

## Stage 9 — Loop until dry

After posting (or before, depending on context), do one more pass:
1. Pick the **highest-risk bucket** and re-scan it with a fresh question — "what would I miss if I were tired?"
2. Pick the **PR description's surprising-things section** and verify one claim you didn't get to.
3. If you find anything new, repeat Stages 4–7 for that finding.

Stop when **two consecutive sweeps produce zero new findings**. Then you're done.

## Anti-patterns — what makes a review NOT goated

These are the things that turn deep review into noise. Don't.

- **Padding the count.** "I should have at least 5 findings" → no, you should have the findings that exist. Empty review is fine if the PR is clean.
- **Vibes without evidence.** "This feels brittle." → quote the line and say what breaks.
- **Re-raising existing findings.** Double-check `/tmp/existing-comments.jsonl` before each post.
- **Style nits when blockers exist.** If the PR has a data-loss bug, don't bury it under three formatting nits. Lead with blockers.
- **Hallucinated APIs.** Don't suggest fixes that reference functions that don't exist. Grep before suggesting.
- **Demanding speculative tests.** "Add a test for X" is only useful if X is currently untested *and* the test is straightforward. Don't ask for test sprawl.
- **Inflating BLOCKER.** A NON-BLOCKER mislabeled as a BLOCKER trains the author to ignore your BLOCKER label entirely.
- **Bikeshedding the description.** Unless the description is actively misleading, don't ask for prose changes.
- **Cross-PR scope creep.** "While you're at it, also fix X in module Y." → that's a separate PR; mention as a follow-up at most.
- **Posting before showing the plan.** Always pause at Stage 7 for someone else's PR.

## Severity tag conventions

Default to `[BLOCKER]` / `[NON-BLOCKER]`. If the project clearly uses something else (grep recent PRs' comments to find out — common variants: `P1`/`P2`/`P3`, `🔴`/`🟡`/`🟢`, `must-fix`/`nice-to-have`), mirror it. Tell the user which convention you're using before posting.

## Quick-reference command palette

```bash
# 1. Context
gh pr view <N> --repo <r> --json title,body,author,baseRefName,headRefName,state,mergeable,reviewDecision,additions,deletions,changedFiles,labels,url,headRefOid
gh pr checks <N> --repo <r>
gh api repos/<owner>/<r>/pulls/<N>/reviews --paginate
gh api repos/<owner>/<r>/pulls/<N>/comments --paginate > /tmp/existing-comments.jsonl
gh api repos/<owner>/<r>/issues/<N>/comments --paginate

# 2. Files (paginated — `gh pr view --json files` caps at 100)
gh api repos/<owner>/<r>/pulls/<N>/files --paginate \
  -q '.[] | .filename + "\t" + (.additions|tostring) + "\t" + (.deletions|tostring) + "\t" + .status'

# 3. CI failure logs
gh run view <run-id> --log-failed

# 4. Per-file patch
gh api repos/<owner>/<r>/pulls/<N>/files --paginate \
  -q '.[] | select(.filename == "<path>") | .patch'

# 5. Post a review with multiple inline comments in one call
gh api repos/<owner>/<r>/pulls/<N>/reviews \
  -f event=COMMENT -f body='<summary>' \
  -f 'comments[][path]=<p>' -F 'comments[][line]=<n>' -f 'comments[][side]=RIGHT' -f 'comments[][body]=<b>'
```

## When to stop and surface instead of pushing through

- The PR is in your domain but you don't have enough context to evaluate a key claim (e.g., "this won't affect ClickHouse perf" but you don't know the prod workload) → say so explicitly, don't fake confidence.
- The PR depends on environment / infra knowledge you don't have access to → say so.
- The PR has CI failing for unrelated infrastructure reasons → flag as pre-existing, don't blame the author.
- The PR author is the user and clearly knows the area better than you → frame findings as questions, not declarations.

Always end the review with what you couldn't verify — that honesty is what makes the goated parts trusted.

## Links

- [[babysit-pr]] — the outbound counterpart; once findings are addressed, this drives the PR to merge.
- [[understand-pr]] — when the user wants to learn the PR before reviewing it. Run that first if the user is the reviewer and unfamiliar with the area.
