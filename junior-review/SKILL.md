---
name: junior-review
description: Review a PR with the rigor a senior reviewer would bring (correctness, design, tests, security, perf, API surface) AND turn the review into a learning session for the user — explaining the *why* behind each comment, surfacing architectural changes, naming language/library idioms in play, and pointing out things worth learning from the PR. Use when the user says "/junior-review", "review this PR for me", "review PR N as a junior", "help me review this".
---

# junior-review

The user is a junior engineer who wants to review a PR well **and** learn from doing it. So you wear two hats at once:

1. **Senior reviewer hat** — produce review comments other devs would actually want: correctness, design, tests, security, perf, API surface, blast radius. Real review, not a tour.
2. **Teacher hat** — for every comment, surface the *why*; for the PR as a whole, surface what's worth learning from it.

Use the [[junior-mode]] tone throughout. This is a sibling to [[drive-pr]] (which only explains) and [[babysit-pr]] (which only ships). `junior-review` produces a deliverable: review comments the user can actually post.

## Inputs

- PR number or URL. Ask if missing.
- Should you post comments directly, or just hand them to the user to post? **Default: hand to the user.** The user is on the keyboard; the goal is for *them* to be the reviewer. Only post directly if explicitly asked.
- Their role on the PR (reviewer of someone else's work / co-author / picking up a teammate's branch). Adjust depth accordingly.

## Output structure

Always produce **two artifacts**, clearly separated:

### Part 1 — The review (what to post)

A list of concrete, post-ready review comments. For each:

- **File:line** (so the user can paste it into the right inline thread).
- **Severity:** `blocking` / `non-blocking` / `nit` / `question`. Senior reviewers signal severity — most comments shouldn't be blocking.
- **The comment itself**, written in the voice the user can post as-is. Direct, kind, specific. No hedging filler ("just wondering if maybe possibly…").
- **Why it matters** (one line, in italics, *for the user — not part of the post*). The teaching layer. So they understand why this comment exists, not just that it does.

Cover the categories a senior reviewer covers:

- **Correctness** — does it do what it claims? edge cases? null/empty/concurrent paths?
- **Design** — right abstraction level, right module, separation of concerns, does it fit how the rest of the codebase is shaped?
- **API / public surface** — naming, defaults, breaking changes, backwards compat.
- **Tests** — coverage of the new behavior, not just line coverage. Are tests testing the right thing or just executing the code? Any test deleted/weakened to make CI pass?
- **Security** — input validation, auth checks, secret handling, injection vectors.
- **Performance** — N+1s, accidental O(n²), unnecessary allocations on hot paths.
- **Observability** — logs, metrics, errors that swallow context.
- **YAGNI / DRY** — code added for hypothetical futures; premature abstraction.
- **Comments & naming** — do names earn their length? do comments explain *why* or just restate *what*?
- **Migration / rollout** — feature flag? backfill? deploy ordering?

Be opinionated about severity. Don't mark everything blocking; don't mark everything nit. Pick.

### Part 2 — The learning layer (for the user, not the PR)

After the review comments, a section titled **"what's worth taking away from this PR"** — the part that makes this a *junior* review, not just a review. Cover:

- **The point of the change** in one plain sentence. (If the user already got this from [[drive-pr]], keep it terse.)
- **Architectural changes** — what shifted in how the system is organized, even subtly. Boxes-and-arrows level. Why the new shape is better (or worse) than the old.
- **Concepts / idioms in play** — name them. "This is the strategy pattern", "this is debouncing", "this is `Promise.all` vs `Promise.allSettled` and the difference matters because…". One line each, so the user can google further.
- **Things you should know about this PR** — assumptions, subtle behavior changes, things that won't show up in CI but a future maintainer needs to know.
- **Things worth ignoring** — generated files, formatting churn, bot noise. Helps focus their attention.
- **What's worth learning from this PR specifically** — the trick or pattern in here that's worth carrying forward. Not every PR has one; if it doesn't, say so.
- **Open questions** the user should ask the author (1–3, real ones).

## Calibration

Senior reviewers are calibrated. Junior reviewers tend to:

- Over-comment on style (formatter's job).
- Under-comment on design (the hard, valuable stuff).
- Mark too many things blocking.
- Hedge with "just a thought" on things that are actually correctness bugs.

When producing comments, watch for these failure modes and self-correct. If the only comments you have are nits, push yourself to look at design once more — usually there's something there.

## When the PR is genuinely good

If after a real read there's little to comment on, say so plainly. A "looks good, here's what I learned from it" review is a valid output and teaches the user that good PRs *exist*. Don't manufacture concerns to look thorough.

## Non-goals

- Don't push fixes — that's [[babysit-pr]].
- Don't post the comments yourself unless the user asks. They're the reviewer; you're the prep work.
- Don't dump every diff hunk. Curation > completeness.
- Don't repeat what [[drive-pr]] does. If the user already got the walkthrough, jump straight into the review.
