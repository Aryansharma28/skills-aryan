---
name: understand-pr
description: Walk the user through a PR like a patient senior would — what it does, the shape of the change, architectural shifts, idioms in play, what's worth knowing vs. what to safely ignore. Explains in plain language with real-world analogies and ASCII diagrams whenever 3+ pieces interact or a topology changes — dumbed down without being condescending. Works on any PR (someone else's *or* the user's own, when they've made a pile of changes and want to read them back). Ends by offering to turn the walkthrough into post-ready review comments. Use when the user says "/understand-pr", "explain this PR", "walk me through PR N", "review this PR", "help me understand my own changes", "dumb this down", "explain with diagrams", or hands you a PR for a tour rather than action.
---

# understand-pr

The user wants to *understand* a PR — possibly someone else's (reviewing), possibly their own (reading back a big batch of changes). Default mode is walkthrough-and-teaching. Only produce post-ready review comments if the user opts in at the end.

This is the **inbound** PR skill (understanding + optional reviewing). The **outbound** counterpart is [[babysit-pr]], which actually ships a PR to done. Use the [[junior-mode]] tone here by default — peer, not professor; dumb it down for clarity without ever being condescending.

## Inputs

- PR number or URL — ask if missing.
- Whose PR is it? Theirs, a teammate's, the user's own, a dependency bump, a bot. Changes how much architectural context to give and how to frame the "what to learn" section.

## Diagrams — when and how

Default to drawing, not just naming. Render a small ASCII diagram whenever any of these are true:

- 3+ pieces interact (services, pods, files, functions, processes) and the reader needs to see who talks to whom.
- The PR changes a *topology* or *sequence* — before/after states, a request path, an ordering of steps/hooks/events.
- You catch yourself about to write "X calls Y which then triggers Z" in prose — that sentence is a diagram.

Keep it small and boxy — this is a whiteboard sketch, not art:

    [App pod] --RWO PVC--> [Disk]
        ^                    ^
        |                    |
    [Worker pod] ------------+

For before/after, stack two small diagrams with an arrow or "becomes" between them rather than cramming both states into one cluttered picture.

Skip the diagram if the change is genuinely linear (A always leads to B, nothing branches, nothing shares state) — a diagram for a straight line just adds noise. Prose is fine there.

## Part 1 — the walkthrough (always)

Structure roughly in this order. Skip sections that genuinely don't apply — don't pad.

### 1. The one-liner

What this PR *actually* does, in one plain-English sentence. Not the title — the real thing. If the title is misleading or vague, say so.

### 2. Why it exists

The motivation. Link the bug / ticket / Slack thread / incident if visible. If you can't find one, say "no stated reason, here's my guess from the diff."

### 3. The shape of the change

Where in the codebase it lives, which layers/modules it touches, roughly how big it is (files / lines / blast radius). One paragraph. The user should be able to picture the change before reading code. If multiple pieces now interact, draw the map here (see Diagrams above) instead of describing it in prose.

### 4. Walk the diff — dumbed down

Pick the 3–6 most important hunks (not all of them). For each:

- **what changed** in plain language
- **why** that specific change
- **the concept it rests on**, named *and* explained. Naming it isn't enough — give a one-clause plain-English restatement right after the name (e.g. "pod affinity — a rule that pins a pod to run next to another pod"), and reach for a real-world analogy when the mechanism itself is non-obvious, not just the label. The reader should be able to explain the concept back to someone else, not just recognize the term.
- **a diagram, if the hunk is about how pieces relate** rather than a single self-contained piece of logic (see Diagrams above). A relationship ("these three pods now have to agree on X") is almost always clearer drawn than narrated.

One new concept per paragraph — if a hunk needs two unfamiliar concepts explained, that's two short paragraphs, not one dense one.

Skip mechanical/boilerplate hunks unless they hide something important.

### 5. Architectural shifts

What changed in *how the system is organized*, even subtly. Draw it — an actual ASCII before/after diagram (see Diagrams above), not just the phrase "boxes and arrows." Then say why the new shape is better (or worse) than the old. Skip this section if it's a pure bugfix with no structural impact.

### 6. ⭐ Stuff worth knowing about this PR

The things a thoughtful reviewer or future maintainer should carry forward:

- Subtle behavior changes that aren't obvious from the diff.
- Assumptions the code makes that aren't enforced anywhere.
- A pattern in this PR worth copying elsewhere.
- A trick / API / idiom the user probably hasn't seen before.
- Migration / rollout considerations (feature flag? backfill? deploy ordering?).
- Tests that look thorough vs. tests that look like they're for show.

### 7. 🚫 Stuff you can safely ignore

Just as important. Tell the user what *not* to spend brain cycles on:

- Auto-generated files (lockfiles, snapshots, type defs).
- Pure formatting / lint churn.
- Bot comments that are noise.
- Renames / mechanical moves with no behavior change.
- Diff hunks that look scary but are mechanically refactored from elsewhere.

### 8. Open questions

1–3 actual questions worth asking the author (or themselves, if it's their own PR). If there are none, say so — don't manufacture concerns.

### 9. Close with the offer

End with one line: *"want me to turn this into post-ready review comments?"* If they say yes, move to Part 2. If they say no (or don't answer), you're done.

## Part 2 — review comments (only when asked)

Produce post-ready review comments the user can paste. For each:

- **File:line** (so they can paste it into the right inline thread).
- **Severity:** `blocking` / `non-blocking` / `nit` / `question`. Senior reviewers signal severity — most comments shouldn't be blocking.
- **The comment itself**, written in the voice the user can post as-is. Direct, kind, specific. No hedging filler ("just wondering if maybe possibly…").
- **Why it matters** — one line in italics, *for the user, not part of the post*. This is the teaching layer per comment.

By default, **hand the comments to the user to post** — don't post them yourself. The user is the reviewer; you're the prep work. Post directly only if explicitly asked.

Cover the categories a senior reviewer covers:

- **Correctness** — does it do what it claims? edge cases? null/empty/concurrent paths?
- **Design** — right abstraction level, right module, separation of concerns, fits the rest of the codebase?
- **API / public surface** — naming, defaults, breaking changes, backwards compat.
- **Tests** — coverage of the new *behavior*, not just lines. Are tests testing the right thing or just executing the code? Any test deleted/weakened to make CI pass?
- **Security** — input validation, auth checks, secret handling, injection vectors.
- **Performance** — N+1s, accidental O(n²), unnecessary allocations on hot paths.
- **Observability** — logs, metrics, errors that swallow context.
- **YAGNI / DRY** — code added for hypothetical futures; premature abstraction.
- **Comments & naming** — do names earn their length? do comments explain *why* or just restate *what*?
- **Migration / rollout** — feature flag? backfill? deploy ordering?

### Calibration

Senior reviewers are calibrated. Junior reviewers tend to:

- Over-comment on style (formatter's job).
- Under-comment on design (the hard, valuable stuff).
- Mark too many things blocking.
- Hedge with "just a thought" on things that are actually correctness bugs.

When producing comments, self-check against these failure modes. If the only comments you have are nits, push yourself to look at design once more — usually there's something there.

### When the PR is genuinely good

If after a real read there's little to comment on, say so plainly. A "looks good, here's why" review is a valid output. Don't manufacture concerns to look thorough.

## When it's the user's own PR

Same structure, slightly different framing:

- The "why it exists" section becomes "what you set out to do" — and you can call out if the diff drifted from that intent (scope creep is the #1 own-PR smell).
- "Open questions" become "things you should decide before opening for review."
- Review comments mode becomes a self-review: things to clean up before others see it. Still apply the severity / why-it-matters format.

## Tone

Peer, not professor. Dumbing down is about *clarity*, not talking down. Assume the user is smart and busy — they just haven't touched this specific corner of the system yet.

Concretely, "dumbed down" means:

- Every acronym and piece of jargon gets defined in the same clause it's first used — don't assume the term landed.
- Reach for a real-world analogy when a mechanism is unfamiliar (a lock, a queue, a relay race, a shared kitchen) — pick whichever actually fits, don't force one.
- Draw it (see Diagrams) before you narrate it, whenever 3+ pieces interact.
- One new idea at a time. If you need a concept to explain a concept, explain the dependency first, in its own sentence.

Avoid: "as you may know", "simply", "obviously", "just". Those are tells that you're either condescending or hiding complexity.

## Non-goals

- Don't push fixes — that's [[babysit-pr]].
- Don't post review comments by default — the user drives the keyboard here.
- Don't summarize every diff hunk. Curation is the job; an exhaustive list is a failure.
