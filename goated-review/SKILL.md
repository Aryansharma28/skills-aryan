---
name: goated-review
description: The deep, bulletproof PR review skill. Pulls every signal in the room first (existing reviews, CodeRabbit/Copilot, CI, the PR description's own claims, related /code-review and /review output if available), buckets files by risk, audits the diff across ALL review dimensions (architecture, business logic, regression/break risk, code quality, code smells, YAGNI/DRY/KISS, SOLID, security, performance, tests, docs), adversarially verifies every finding before posting, and POSTS the result directly to the PR as one summary review plus N inline comments tagged P0–P5 with file:line evidence. Use when the user says "goated-review N", "do a deep review on PR N", "bulletproof review", "review and post comments on PR N", or hands you a PR they want torn down to studs (large refactors, mass deletions, supply-chain changes, security-adjacent code, anything CodeRabbit skipped, or anything the user explicitly says is high-stakes).
---

# goated-review

Default `/review` and `/code-review` are fine for normal PRs. This skill is for the PRs that *matter* — large refactors, mass deletions, dependency bumps with supply-chain risk, security-adjacent changes, anything CodeRabbit/Copilot skipped because the diff is too big, or anything the user explicitly wants bulletproofed. The output IS the review: every claim cited with file:line evidence, every finding adversarially verified, severities explicitly assigned on a P0–P5 ladder, all of it posted directly to the PR — not drafted, not paraphrased, not held in chat. The user invoked goated-review because they want the review LIVE on the PR.

The output is not a vibes paragraph. It is a structured PR review with:

- ONE summary review comment containing the verdict, the P-counts, and grouped findings.
- N inline comments anchored to specific `file:line` locations, each one explicitly tagged `[P0]`–`[P5]`.
- Zero duplicates of what existing reviewers (humans, CodeRabbit, Copilot, /review, /code-review) already flagged.
- Zero hallucinations — every claim quotes the actual code or links to the exact line.

## Mandate — POST DIRECTLY

When the user invokes `goated-review` they are asking you to **post the review to the PR**. Not to draft it in chat. Not to summarize what you would say. Not to ask for permission for each comment. The default behavior is:

1. Do the full investigation.
2. Run the plan past the user ONCE (Stage 7) so they can adjust or veto before fan-out.
3. As soon as they greenlight (a "yes", "post it", "go", "ship it", any affirmative), POST every comment via `gh api .../reviews` immediately — summary review and all inline comments together when the API allows it.
4. Reply in chat with the posted-review URL and a one-line recap.

The only times you DO NOT post directly are:
- The user explicitly said "draft only", "show me first, don't post", or "I'll post myself".
- You hit a hard API rejection (e.g. a line you tried to anchor isn't in the diff — see Stage 8 on how to recover).
- The PR is closed/merged/draft and posting would be meaningless — surface that and stop.

If you find yourself writing "Here is what I would post if you confirm…" three times, you're doing it wrong. The user already confirmed by invoking the skill.

## When to use this vs the alternatives

| Skill | When | Output |
|---|---|---|
| `/code-review` | Quick gate on your own LOCAL working diff. LangWatch-specific rules (IDs, multitenancy, layering, naming, SRP). | Local findings, often auto-applied. NOT a PR comment. |
| `/review` | Standard PR review on a normal-sized GitHub PR. One-shot pass, no adversarial verification, no review-of-the-room. | Posts a single review pass to the PR. |
| **`goated-review`** | Large refactor, mass deletion, lockfile/dep change, security-adjacent, CodeRabbit skipped, "make it bulletproof", or the user said "P0–P5". | Structured P0–P5 findings posted as summary review + inline comments. **Composes** with /code-review and /review (reads their output as inputs, never re-raises what they flagged). |
| `understand-pr` | The user wants to *learn* the PR, not gate it. | Teaching walkthrough. |
| `babysit-pr` | The PR is the user's and they want to land it. | Drives PR to green. |

If the user says "deep", "bulletproof", "thorough", "tear apart", "rip into", "P0 through P5", "post comments", or the PR is >150 files / >5k lines / has mass deletions — default to this.

### Composing with /code-review and /review

`/code-review` and `/review` are NOT replacements for goated-review — they are inputs and complementary surfaces:

- **`/code-review`** runs LangWatch-project rules on the local working diff (multitenancy guards, naming, layering, SRP, etc.). If the PR is checked out locally and the user hasn't already run it, run `/code-review` once and feed its findings into Stage 1 as if they were existing comments — same dedupe rules. Project-rule violations that `/code-review` already named are P1/P2 in goated-review's ladder; do not re-raise them, reference them.
- **`/review`** is the one-shot GitHub PR review pass. If a PR already has a `/review` comment from a teammate or from a prior session, treat that as an existing review surface and dedupe against it the same way you dedupe against CodeRabbit. goated-review's value-add is the dimensions `/review` doesn't systematically hit (architecture, business-logic correctness, cross-PR consequences, YAGNI/SOLID, adversarial verification).

The mental model: `/code-review` and `/review` are spot-checks. `goated-review` is the audit that also reads what those spot-checks found.

## Inputs you need

- **PR number** and repo (assume the obvious one if unambiguous; ask otherwise).
- **Authorization scope** — default for `goated-review` is "post the review directly." Only ask if the user explicitly invoked it with "draft only" / "show me first."
- **Severity convention** — default to the **P0–P5 ladder defined below**. If the project clearly uses something else (`BLOCKER`/`NON-BLOCKER`, `🔴`/`🟡`/`🟢`, `must-fix`/`nice-to-have`), still tag each finding with its P-level in the comment body so the prioritization is unambiguous, and mirror the project's surface label in the prefix (e.g. `[P0 BLOCKER]`).

## The severity ladder — P0 through P5

EVERY finding MUST get a P-level. This is the spine of the skill — no untagged findings, no "minor" or "nit" hand-waving, no vague "consider…" with no priority attached. The reader scans P-levels to triage.

| Level | Meaning | Merge gate? | Typical examples |
|---|---|---|---|
| **P0 BLOCKER** | Ship-stopper. Merge will break prod, lose data, leak secrets, bypass auth, fail CI, or violate a hard project rule. The PR cannot land until this is fixed. | YES — must fix before merge. | Auth bypass, SQL injection, missing tenant filter, deleted route still called by cron, downgraded dependency, CI failing because of this PR, schema-incompatible migration with no rollback, broken public API contract. |
| **P1 HIGH** | Serious correctness or behavior bug. Won't necessarily block merge if there's a stated follow-up window, but must be fixed in this PR or as a same-day follow-up. | Usually yes (push back if the author wants to defer). | Business-logic bug for a non-rare input, silent error swallowing, race condition, performance regression on a hot path, missing rollback path, broken UX for the golden path, important test deleted/weakened without justification. |
| **P2 MEDIUM** | Real defect or design issue that should be fixed in this PR. Not catastrophic, but leaving it accumulates debt that future PRs will compound. | Strong recommend — fix in PR. | Architectural inconsistency (route bypassing service layer), violated layering / SRP, missing-but-cheap test for a behavior change, code smell (long method, primitive obsession, leaky abstraction) materially hurting readability, doc/runbook drift on a feature the team relies on. |
| **P3 LOW** | Cleanup, polish, follow-up suggestion. Worth doing but not blocking. | No. | DRY opportunity, YAGNI cleanup, naming improvement, dead-code removal, comment that explains the wrong thing, minor test gap on an edge case, a clearer variable name, splitting a too-busy function. |
| **P4 NIT** | Pure preference / style. No correctness implication. | No. | Stylistic alternative ("could use `const` instead of `let`"), formatting preference, ordering of imports, comment phrasing. Use sparingly — too many P4s drown the real findings. |
| **P5 PRAISE / OBSERVATION** | Non-defect commentary. Either calling out something done well (genuinely useful — reinforces the pattern), or flagging a cross-PR observation that isn't actionable here. | N/A. | "Nice precedent — `workflows.commit_message` should adopt this pattern next", "this test is a great regression anchor for the bug in #4321", "for context: the new error shape will affect the analytics dashboard's parser, which already handles it but is worth knowing." |

**Calibration rules:**
- **Default down, not up.** When in doubt between P1 and P2, pick P2. Inflated P0s/P1s train the author to ignore your severity tags entirely.
- **Lead with the highest P-level in the summary.** Order findings P0 → P5 in both the summary review and the inline-comment list.
- **A P0 must have an adversarial-verification trail.** If you cannot articulate why your refutation attempt failed, downgrade it to P1 or drop it. False P0s are the most expensive mistake this skill can make.
- **P5 PRAISE is allowed — and encouraged when warranted.** A goated review that finds nothing wrong should still post a P5 calling out what's specifically good. Reviews that are pure negativity hurt review culture.
- **P4 NITs are rationed.** No more than ~3 P4s per review. Above that, the noise overwhelms the signal.

## The core loop

```
1. Read the room         (existing reviews, CodeRabbit, /review, /code-review, CI, description claims)
2. Slice the diff        (paginated file list → risk buckets)
3. Audit each dimension  (architecture, business logic, regression risk, quality, smells, YAGNI, SOLID, security, perf, tests, docs)
4. Verify adversarially  (try to refute each finding; drop if uncertain)
5. Dedupe                (drop anything an existing reviewer or /review or /code-review already raised)
6. Classify P0–P5        (explicit severity per finding; calibration rules above)
7. Show the plan         (ONE pause to let the user adjust)
8. Post directly         (summary review + inline comments via gh api)
9. Loop until dry        (re-sweep; stop after two consecutive dry passes)
```

The loop stages are NOT optional — skipping verify is how you ship false-positive P0s that destroy reviewer trust.

## Stage 1 — Read the room

Before reading a single line of diff, get the surrounding signal. **You will absolutely embarrass yourself if you re-raise what an existing reviewer flagged three weeks ago.**

```bash
# PR metadata + CI snapshot
gh pr view <N> --repo <owner/repo> \
  --json title,body,author,baseRefName,headRefName,state,mergeable,reviewDecision,additions,deletions,changedFiles,labels,url,headRefOid

# CI status — failing CI is P0 by default until proven otherwise (flake / pre-existing)
gh pr checks <N> --repo <owner/repo>

# PR-level reviews (CodeRabbit summary, Copilot, /review output, humans)
gh api repos/<owner>/<repo>/pulls/<N>/reviews --paginate \
  -q '.[] | {user: .user.login, state, submitted_at, body: (.body[0:1000])}'

# Inline review comments — the existing finding list you must dedupe against
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate \
  -q '.[] | {path, line, user: .user.login, body}' > /tmp/existing-comments.jsonl

# Issue-level comments (CodeRabbit summary, "review skipped" notes, /code-review output)
gh api repos/<owner>/<repo>/issues/<N>/comments --paginate \
  -q '.[] | {user: .user.login, body: (.body[0:1500])}'
```

Capture from this stage:

- **Did CodeRabbit skip?** ("Too many files!" / "exceeds the maximum number of lines") — if yes, you cannot lean on it; your own coverage matters more.
- **Did Copilot skip?** Same.
- **Has `/review` or `/code-review` already run?** Their findings get the same dedupe treatment as a human reviewer. Reference them in your summary instead of re-raising.
- **Is CI failing?** Failing CI is P0 by default. Pull failing job logs (`gh run view <id> --log-failed`) and decide whether it is flake, pre-existing, or caused by this PR.
- **What did existing reviewers raise?** Build a `path:line → comment` map so you never re-post the same finding. Quote their concern in your summary ("@reviewer's P1 still open") rather than re-raising it independently.
- **What does the author flag as surprising?** Read the PR description's "Anything surprising?" / "Notes" / "Caveats" / "Things I am unsure about" section in full. Every claim there is a candidate for verification.

## Stage 2 — Slice the diff

GitHub's diff API caps at ~20k lines. For large PRs `gh pr diff` returns HTTP 406. Use the files API and paginate:

```bash
gh api repos/<owner>/<repo>/pulls/<N>/files --paginate \
  -q '.[] | .filename + "\t" + (.additions|tostring) + "\t" + (.deletions|tostring) + "\t" + .status' \
  > /tmp/pr-files.tsv
```

Note: `gh pr view --json files` truncates at 100 files. Always use the paginated `/files` endpoint for anything large.

Bucket every file into risk areas. The bucket determines how hard to look — not all files deserve the same scrutiny.

| Bucket | What's in it | Scrutiny |
|---|---|---|
| **Lockfile / package.json / workspace files** | `*-lock.yaml`, `package.json`, `pnpm-workspace.yaml`, `Cargo.lock`, `requirements.txt`, `go.mod` | **High.** New transitive deps, removed deps, weird importers, unrelated bumps, downgrades. Check supply-chain policy if one exists. |
| **DB schema / migrations** | `schema.prisma`, `migrations/*`, ClickHouse DDL, SQL files | **High.** Backward compat, dual-write windows, dropped columns vs orphaned columns, rollback story, index churn. |
| **Public API surface** | REST/GraphQL/tRPC routers, OpenAPI, public types, exported package entries, SDK surface | **High.** Breaking changes, deprecated paths still in use, error contract changes, response shape mutations. |
| **Mass deletions** | Status `removed`, large negative diffs | **High.** Did the author find every caller? Orphaned references in tests, docs, CI, dashboards, runbooks, alert rules? |
| **Auth / security-adjacent** | Auth middleware, session/token code, secrets handling, CORS, CSP, RBAC, sanitization | **High.** Never auto-trust; always verify. |
| **Infra / CI / Docker / Helm** | `.github/workflows/*`, `Dockerfile`, helm charts, terraform | **High.** Failure mode changes, image size, secret exposure, runner permissions. |
| **Cron / scheduled jobs** | `/cron/*`, queue handlers, schedules | **Medium-High.** Removing a cron without confirming nothing depends on it is a classic incident. |
| **Behavior-changing refactors** | Service classes, facade collapses, throw-vs-null changes, error contract shifts | **Medium-High.** Read every caller of changed-semantic methods. |
| **Component / UI** | `*.tsx` page/component changes | **Medium.** A11y, error states, loading states, mobile, copy. |
| **Tests** | `__tests__`, `*.test.*`, `*.spec.*`, feature files | **Medium.** Was a test deleted to make the build pass? Was a real assertion weakened to a mock? Did coverage shrink for a behavior that still ships? |
| **Internal refactors (pure renames, moves)** | File moves, identifier renames | **Low.** Skim; check for missed references. |
| **Docs / generated** | `*.md`, generated types | **Low.** Skim. Generated files: confirm regeneration is consistent with the source change. |

Write the bucket map to scratch so you can work through it methodically — don't try to hold 262 files in your head.

## Stage 3 — Audit each dimension

For each bucket, do not just "read the code." Walk it through every review dimension below. These dimensions are the spine of what makes this review goated — most superficial reviews only hit 2–3 of them, miss the rest, and ship.

### Dimension A — Architecture & layering

- Does the new code respect the project's layering rules? (Routes → services → repositories, not routes → repositories directly.)
- Are responsibilities placed at the right level? (Validation at the boundary, business logic in services, persistence in repositories.)
- Did the change introduce a cross-cutting concern (logging, telemetry, error wrapping) that should be a middleware/decorator instead of being sprinkled inline?
- Are public abstractions stable? Were any internal-only types/functions accidentally exposed via re-export?
- Does it integrate with existing systems or duplicate them? (Greppable smell: a new util that already exists three folders over.)
- For UI: does it follow the established component patterns (drawers, scope pickers, row-actions menus) or hand-roll a new one?

### Dimension B — Business logic correctness

- Read the change as the USER. Does it actually do what the PR description says it does?
- Trace at least one happy path end-to-end through the new code, naming the inputs and the output.
- Trace at least one realistic failure path. Where does the error go? Is the state mutation reversed?
- Are edge cases handled or implicitly assumed away? (Empty input, single-element list, max-sized input, unicode, timezone-sensitive value.)
- For features tied to a spec (`specs/*.feature`), does the diff match the scenarios? If the spec doesn't exist and the change is non-trivial, flag the missing spec (P2 or P3 depending on size).

### Dimension C — Regression / break risk ("does anything break that wasn't already broken")

- For every changed function signature, contract, or error shape: grep every caller and confirm each one still works.
- For every removed file, route, column, env var, feature flag: grep across the WHOLE repo (tests, configs, docs, runbooks, dashboards, CI workflows, helm values, terraform) for orphaned references.
- For every dependency change: confirm peer-dep ranges still resolve and no consumer is silently downgraded.
- For every changed serialization/wire format (tRPC `data.cause`, REST response body, event payload): confirm both sides of the wire are updated atomically.
- For every changed UI surface that other features link into: open the linker and confirm the link still resolves.

### Dimension D — Code quality

- Naming: do identifiers say WHAT not HOW? Can a stranger read this in six months and know what it does?
- SRP: is each function / class doing one thing, or has it accumulated three responsibilities?
- Readability: is there a sequence of nested ternaries / clever one-liners that should be a few `if`s?
- Magic values: numeric/string literals that should be named constants.
- Error handling: are errors handled where they have context, or rewrapped into a generic message that strips the cause?
- Defensive code: are there `if`s guarding against impossible states, or is the impossible state actually possible?

### Dimension E — Code smells

- **Long method / God object** — function or class doing too much.
- **Primitive obsession** — passing five `string` args where a typed object would be safer.
- **Feature envy** — function reaches deeply into another object's internals.
- **Leaky abstraction** — caller has to know implementation details to use the API.
- **Shotgun surgery** — one logical change required edits in many unrelated files (architectural smell).
- **Speculative generality** — abstraction introduced "in case we need it" with no current second caller (see YAGNI).
- **Comment lies** — comment describes behavior the code doesn't implement.
- **Dead code** — branches, functions, parameters that are never reached or used.
- **Misleading naming** — `getUserById` that also creates a user as a side effect.

### Dimension F — YAGNI / DRY / KISS / SOLID

- **YAGNI** (You Aren't Gonna Need It): does the PR add config flags, abstraction layers, hook points, or "extension points" for things no current caller uses? Flag and recommend removal.
- **DRY** (Don't Repeat Yourself): is the SAME logic duplicated in two places? (Two similar lines is fine; three is a pattern; the rule of three.)
- **Anti-DRY trap:** do not push for DRY when the two callsites are *coincidentally* similar but semantically distinct — coupling them via shared code creates worse problems than the duplication.
- **KISS** (Keep It Simple): does the implementation use a complex pattern when a straight-line implementation would do?
- **SOLID:** SRP (covered above), Open-Closed (does adding a new variant require modifying existing code in N places?), Liskov (does the subclass break the parent's contract?), Interface Segregation (is a consumer being forced to depend on methods it doesn't use?), Dependency Inversion (is high-level policy depending on low-level detail?).

### Dimension G — Security

- Authn / authz checks at every protected boundary.
- Multitenancy: every tenant-scoped query must filter by tenant/project ID.
- Input validation at all external boundaries (HTTP, queue, file upload). Internal code can trust upstream.
- No secrets in logs, errors, or response bodies that leak to unauthorized callers.
- No SSRF / SQLi / XSS / SSRF / path traversal / open redirect.
- Dependency: any new package from an unknown publisher, unmaintained repo, or with a recent ownership change?

### Dimension H — Performance

- Hot-path changes: did a previously O(1) lookup become O(N)?
- Database: new query without an index? `SELECT *` over a wide row? Missing partition key filter?
- N+1 patterns introduced (loop calling a fetch).
- Caching: a cache key that's not unique enough, or a TTL that creates a thundering-herd risk.
- Frontend: large bundle additions, unnecessary re-renders, synchronous heavy work on the main thread.

### Dimension I — Tests

- Did real tests get deleted to make CI green? (Read the deleted test files, not just the diff stats.)
- Were assertions weakened to mocks? (Was a `toEqual(realValue)` swapped for `toHaveBeenCalled()`?)
- New behavior with no test — flag and recommend (P2/P3 based on risk).
- Tests that don't actually exercise the new code path — they parse, they pass, but they prove nothing.
- For BDD projects: does the spec exist? Does the test reference it?

### Dimension J — Docs, runbooks, observability

- New feature flag / env var with no doc entry.
- Removed route still referenced in a runbook or dashboard.
- Customer-facing copy that exposes implementation details ("uses the in-process analysis service") instead of user-meaningful description.
- Observability: did the change remove a log/metric/span that on-call relies on? Did it add a high-cardinality label that will blow up Prometheus?

### Capturing findings

For each finding, write a row in a scratch file:

```
file:line | claim | evidence | (proposed P-level)
```

Don't lock in the P-level yet — that's Stage 6, after dedupe and adversarial verification.

## Stage 4 — Verify adversarially

Every finding is suspect until proven. For each one:

1. **Re-read the code at the cited `file:line`.** Did you misread it?
2. **Try to refute the finding.** "What if X handles this elsewhere? What if there is a different code path? What if this is intentional and documented? What if a middleware further up catches it?"
3. **Grep the surrounding context** — README, CHANGELOG, comments, related test names, sibling files, configs.
4. **For anything you plan to tag P0 or P1:** write the refutation attempt down explicitly and state why it doesn't hold. If you cannot articulate the failure of the refutation, downgrade or drop.
5. **If you cannot refute AND the evidence is concrete (line number + actual code) → keep.** Otherwise drop.

Default to **drop on uncertainty**. A wrong P0 is worse than a missed P3 — false high-severity findings waste author time and destroy the credibility of every future finding you post.

## Stage 5 — Dedupe against existing reviewers

For each surviving finding, scan `/tmp/existing-comments.jsonl` AND the issue-level comments:

- Same `path` + nearby `line` + similar claim → drop yours.
- Same root issue raised by an existing reviewer, CodeRabbit, `/review`, or `/code-review` → drop yours; reference theirs in the summary ("@reviewer's P1 about X is still open and load-bearing").
- Existing reviewer's finding was withdrawn after author rebuttal → re-evaluate. If the rebuttal genuinely closes the issue, drop yours too. If the rebuttal handwaved, you can re-raise — but explain in your comment why you think the rebuttal was incomplete (be specific, cite the code).

You're not competing with existing reviewers — you are filling the gaps they missed.

## Stage 6 — Classify P0–P5

Apply the severity ladder from the top of this file to every surviving finding. Re-read the **Calibration rules** — default down, not up; lead with the highest in summaries; P0 needs an adversarial trail; P5 is allowed and encouraged for praise / cross-PR observations.

Sanity-check yourself:
- If you have more than ~2 P0s in a single PR, re-read each one — are they really ship-stoppers, or did you inflate?
- If you have zero findings above P3, reconsider whether the review is going far enough — or whether the PR really is clean (often it is, and then say so).
- If you have more than ~3 P4 NITs, cut them. Pick the top three; the rest are drowning the signal.

## Stage 7 — Show the plan (ONE pause)

Before any `gh api .../comments` call, present the full plan to the user:

```
Plan to post on PR #<N>:

Summary review (PR-level, event=COMMENT or REQUEST_CHANGES):
  Verdict: <approve / comment / request changes>
  P0: <count> | P1: <count> | P2: <count> | P3: <count> | P4: <count> | P5: <count>
  <one-paragraph executive summary>

Inline comments (<count> total, ordered P0 → P5):
  [P0] path/to/file.ts:42 — <one-line claim>
  [P1] path/to/other.ts:117 — <one-line claim>
  [P2] path/to/third.ts:88 — <one-line claim>
  [P3] ...
  [P4] ...
  [P5] ...

Existing findings I'm NOT re-raising:
  @rogeriochaves P1 (lockfile) — referenced in summary
  CodeRabbit's auth-middleware comment — addressed in commit abc1234
  /code-review's naming flag — referenced in summary
```

**Pause here for ONE round of edits.** Let the user adjust, drop, or rewrite anything. As soon as they say "yes" / "ship it" / "post" / "go" — POST IMMEDIATELY. Do not ask again. Do not re-paste the plan.

The single exception: the user explicitly said "draft only" or "don't post" — then stop here and hand the plan over for them to use.

## Stage 8 — Post directly

Two posting strategies work. Pick based on count:

**A) Single combined review** — summary + all inline in one API call. Cleaner timeline. Use when ≤ ~10 inline comments and they all anchor to lines that ARE in the PR's diff.

For the JSON body approach (more robust than `-f` flag escaping when comments contain quotes/backticks/newlines):

```bash
# Write the review payload to a JSON file, then POST it.
cat > /tmp/review.json <<'JSON'
{
  "event": "COMMENT",
  "body": "## Review summary\n\n<verdict>\n\n### P0 BLOCKER (n)\n- ...\n\n### P1 HIGH (n)\n- ...\n\n### P5 PRAISE / OBSERVATION (n)\n- ...",
  "comments": [
    {
      "path": "path/to/file.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "[P0] <one-line claim>\n\n**Why:** <2-4 sentences of evidence>\n\n**Evidence:** <quoted code>\n\n**Suggested fix:** <concrete change>"
    }
  ]
}
JSON
gh api repos/<owner>/<repo>/pulls/<N>/reviews --input /tmp/review.json
```

**B) Summary first, inline second** — easier to iterate; useful when comments are many or anchors might fail. Same JSON-body approach for each call.

Pick the right `event`:

- `APPROVE` — only when you have zero P0/P1 and the change is well-scoped. Rare for the kind of PR this skill targets.
- `REQUEST_CHANGES` — at least one P0 and you have authority to gate. Note: requesting changes on someone else's PR is forceful; default to `COMMENT` unless the user explicitly said to request changes.
- `COMMENT` — the default. Findings posted as commentary; author and maintainer decide what to act on.

**Always use the PR's current `headRefOid`** if you fall back to single-comment `gh api .../comments` calls — older SHAs produce "outdated" comments that scroll off the thread.

### When the inline anchor fails ("Path could not be resolved")

GitHub rejects inline comments on lines that aren't in the PR's diff. This will happen for cross-PR observations (P5 commonly). When it does:

1. DO NOT silently drop the finding.
2. Move it into the summary review body under a `### Cross-PR observations (P5)` section.
3. Include a permalink to the line on the current head SHA (`https://github.com/owner/repo/blob/<sha>/<path>#L<line>`).
4. Note in your reply to the user that the comment was moved (not lost).

### Comment template

Every comment follows the same shape — predictable, easy to scan, easy to act on:

```
[P<n>] <one-line claim>

**Why:** <2-4 sentences of evidence — what's wrong, why it matters, what breaks (or for P5: what's good and why it's worth amplifying)>

**Evidence:** <quoted code or file:line references>

**Suggested fix:** <concrete change, if you have one — otherwise omit>
```

Skip "Suggested fix" rather than pad with vague handwaving. The comment is still valuable without it.

## Stage 9 — Loop until dry

After posting, do one more pass:

1. Pick the **highest-risk bucket** and re-scan with a fresh question — "what would I miss if I were tired?"
2. Pick the **PR description's surprising-things section** and verify one claim you didn't get to.
3. Re-read your own posted comments — anything you'd downgrade or retract now?
4. If you find anything new, repeat Stages 4–7 for it (post as a follow-up review).

Stop when **two consecutive sweeps produce zero new findings**.

## Anti-patterns — what makes a review NOT goated

These are the things that turn deep review into noise. Don't.

- **Padding the count.** "I should have at least 5 findings." → No, you should have the findings that exist. Empty review is fine if the PR is clean (post a P5 calling that out).
- **Vibes without evidence.** "This feels brittle." → Quote the line and say what breaks.
- **Re-raising existing findings.** Double-check `/tmp/existing-comments.jsonl` before each post.
- **Style nits when P0s exist.** If the PR has a data-loss bug, don't bury it under P4 formatting nits. Lead with the highest P-level.
- **Hallucinated APIs / functions.** Don't suggest fixes that reference identifiers that don't exist. Grep before suggesting.
- **Demanding speculative tests.** "Add a test for X" is only useful if X is currently untested AND the test is straightforward AND the risk is real. Don't ask for test sprawl.
- **Inflating P0/P1.** A P3 mislabeled as P0 trains the author to ignore your P0 label. Default DOWN.
- **Bikeshedding the description.** Unless the description is actively misleading, don't ask for prose changes.
- **Cross-PR scope creep posted as P0/P1.** "While you're at it, also fix Y in module Z" belongs as a P5 OBSERVATION or a separate issue, not a blocker on this PR.
- **Posting before showing the plan.** Always pause at Stage 7 for the single round of edits.
- **Asking for permission per comment.** One pause at Stage 7. Then post the whole batch.
- **Draft-only behavior by default.** The user invoked `goated-review`. They want it posted. Drafting is opt-in, not opt-out.

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

# 5. Post a review with the JSON-body approach (handles quotes / backticks / newlines cleanly)
# Write /tmp/review.json with { event, body, comments[] }, then:
gh api repos/<owner>/<r>/pulls/<N>/reviews --input /tmp/review.json

# 6. Single inline comment outside a review (fallback)
gh api repos/<owner>/<r>/pulls/<N>/comments \
  -f body='[P3] <claim>' \
  -f commit_id="$(gh pr view <N> --json headRefOid -q .headRefOid)" \
  -f path='path/to/file.ts' \
  -F line=42 \
  -f side=RIGHT
```

## When to stop and surface instead of pushing through

- The PR is in your domain but you don't have enough context to evaluate a key claim (e.g., "this won't affect ClickHouse perf" but you don't know the prod workload) → say so explicitly in the summary, don't fake confidence.
- The PR depends on environment / infra knowledge you don't have access to → say so.
- The PR has CI failing for unrelated infrastructure reasons → flag as pre-existing, don't blame the author.
- The PR author is the user and clearly knows the area better than you → frame findings as questions, not declarations.

Always end the review with **"Things I couldn't verify from the diff alone"** — that honesty is what makes the goated parts trusted.

## Links

- [[babysit-pr]] — the outbound counterpart; once findings are addressed, this drives the PR to merge.
- [[drive-pr]] — like babysit-pr but also cleans up the local artifacts after merge.
- [[understand-pr]] — when the user wants to learn the PR before reviewing it. Run that first if the user is the reviewer and unfamiliar with the area.
- `/code-review` — LangWatch-project rules on the local working diff; goated-review reads its output as input, dedupes against it.
- `/review` — standard one-shot GitHub PR review pass; goated-review composes with it (reads its output as input, fills the dimensions it doesn't systematically hit).
