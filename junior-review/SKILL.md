---
name: junior-review
description: Produce post-ready PR review comments with the rigor a senior reviewer would bring (correctness, design, tests, security, perf, API surface), each tagged with severity and paired with a *why-it-matters* line so the user learns from posting them. Pairs with [[drive-pr]] (for understanding the PR first) and [[babysit-pr]] (for actually shipping it). Use when the user says "/junior-review", "review this PR for me", "give me comments to post", "review PR N".
---

# junior-review

The user is a junior engineer reviewing someone else's PR. They need actual review comments — the kind other devs would want — and they want to understand *why* each comment exists so they get better at reviewing over time.

**This skill produces a deliverable: review comments the user can post.** For walkthrough-and-understanding (no deliverable), use [[drive-pr]]. For actually finishing a PR (their own), use [[babysit-pr]]. Don't duplicate those skills' work here — if the user has already done `/drive-pr` on this PR, skip the explanation and jump straight to comments.

Use the [[junior-mode]] tone throughout.

## Inputs

- PR number or URL. Ask if missing.
- Should you post comments directly, or hand them to the user to post? **Default: hand to the user.** The user is on the keyboard; the goal is for *them* to be the reviewer. Only post directly if explicitly asked.

## Output: the review comments

A list of concrete, post-ready review comments. For each:

- **File:line** (so the user can paste it into the right inline thread).
- **Severity:** `blocking` / `non-blocking` / `nit` / `question`. Senior reviewers signal severity — most comments shouldn't be blocking.
- **The comment itself**, written in the voice the user can post as-is. Direct, kind, specific. No hedging filler ("just wondering if maybe possibly…").
- **Why it matters** — one line, in italics, *for the user, not part of the post*. This is the teaching layer per comment.

Cover the categories a senior reviewer covers:

- **Correctness** — does it do what it claims? edge cases? null/empty/concurrent paths?
- **Design** — right abstraction level, right module, separation of concerns, does it fit how the rest of the codebase is shaped?
- **API / public surface** — naming, defaults, breaking changes, backwards compat.
- **Tests** — coverage of the new *behavior*, not just lines. Are tests testing the right thing or just executing the code? Any test deleted/weakened to make CI pass?
- **Security** — input validation, auth checks, secret handling, injection vectors.
- **Performance** — N+1s, accidental O(n²), unnecessary allocations on hot paths.
- **Observability** — logs, metrics, errors that swallow context.
- **YAGNI / DRY** — code added for hypothetical futures; premature abstraction.
- **Comments & naming** — do names earn their length? do comments explain *why* or just restate *what*?
- **Migration / rollout** — feature flag? backfill? deploy ordering?

## Calibration

Senior reviewers are calibrated. Junior reviewers tend to:

- Over-comment on style (formatter's job).
- Under-comment on design (the hard, valuable stuff).
- Mark too many things blocking.
- Hedge with "just a thought" on things that are actually correctness bugs.

When producing comments, self-check against these failure modes. If the only comments you have are nits, push yourself to look at design once more — usually there's something there.

## When the PR is genuinely good

If after a real read there's little to comment on, say so plainly. A "looks good, here's why" review is a valid output and teaches the user that good PRs *exist*. Don't manufacture concerns to look thorough.

## What this skill does NOT do

- **Doesn't walk you through the PR** — that's [[drive-pr]]. If you don't understand the change yet, run that first.
- **Doesn't fix anything** — that's [[babysit-pr]] (and only on your own PRs).
- **Doesn't post comments by default** — you're the reviewer; this is your prep.
