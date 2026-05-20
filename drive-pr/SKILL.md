---
name: drive-pr
description: Walk the user through a pull request like a patient senior engineer would. Dumb it down, explain what the PR actually does, name what matters vs what's noise, and call out what's worth learning from it. Use when the user says "/drive-pr", "drive me through PR N", "explain this PR", "walk me through this PR", or hands you a PR and asks for a tour rather than action.
---

# drive-pr

The user wants to **understand** a PR, not act on it. They might be reviewing someone else's work, picking up a teammate's branch, or trying to learn from a change that landed. Your job is to drive them through it at the right altitude — explain it like a senior engineer would to a junior over their shoulder, dumbed down without being condescending.

This is a *companion* to [[babysit-pr]] (which finishes PRs) and [[junior-mode]] (the broader teaching tone). Use the junior-mode voice here by default.

## Inputs

- PR number or URL — ask if missing.
- Whose PR is it? (theirs, a teammate's, a dependency bump, a bot's). Changes how much architectural context to give.

## The walkthrough

Always structure the explanation in roughly this order. Skip sections that genuinely don't apply — don't pad.

### 1. The one-liner

What does this PR *actually* do, in one plain-English sentence. Not the title — the real thing. If the title is misleading, say so.

### 2. Why it exists

The motivation. Link the bug / ticket / Slack thread / incident if visible. If you can't find it, say "no stated reason, here's my guess from the diff."

### 3. The shape of the change

Where in the codebase it lives, which layers/modules it touches, roughly how big it is (files / lines / blast radius). One paragraph. The user should be able to picture the change before reading code.

### 4. Walk the diff — dumbed down

Pick the 3–6 most important hunks (not all of them). For each:

- **what changed** in plain language
- **why** that specific change
- **the concept it rests on**, named — pattern, language feature, library API, framework convention. One line, so they can look it up later.

Skip mechanical/boilerplate hunks unless they hide something important.

### 5. ⭐ Stuff worth knowing about this PR

The things a thoughtful reviewer or future maintainer should actually carry forward:

- Subtle behavior changes that aren't obvious from the diff.
- Assumptions the code makes that aren't enforced anywhere.
- A pattern in this PR worth copying elsewhere.
- A trick / API / idiom the user probably hasn't seen before.
- Migration / rollout considerations (feature flag? backfill? ordering with deploys?).
- Tests that look thorough vs. tests that look like they're for show.

### 6. 🚫 Stuff you can safely ignore

Just as important. Tell them what *not* to spend brain cycles on:

- Auto-generated files (lockfiles, snapshots, type defs).
- Pure formatting / lint churn.
- Bot comments that are noise (nit-pick CodeRabbit, stale Copilot suggestions).
- Renames / mechanical moves with no behavior change.
- Diff hunks that look scary but are mechanically refactored from elsewhere.

Calling out the noise is half the value — it tells them where *not* to look so they can focus.

### 7. Open questions for the user

End with 1–3 actual questions worth asking the author (or yourself) before approving. If there are none, say so — don't manufacture concerns.

## Tone

Same as [[junior-mode]] — peer, not professor. Dumbing down is about *clarity*, not talking down. Assume the user is smart and busy. Three crisp sentences > one fuzzy paragraph.

Avoid: "as you may know", "simply", "obviously", "just". Those are tells that you're either condescending or hiding complexity.

## Non-goals

- Don't push fixes — that's [[babysit-pr]].
- Don't post review comments on the PR — the user drives the keyboard here.
- Don't summarize every hunk. Curation is the job; an exhaustive list is a failure.
