---
name: explain-pr
description: Explain a pull request exhaustively and post the explanation as a GitHub PR comment. Use when the user says "/explain-pr", "explain PR in the comments", asks for a file-by-file PR walkthrough, or wants every PR to document what changed, why, verification, and its contribution to a secure, scalable, runnable agent or product.
---

# Explain PR

Create an evidence-backed walkthrough of the PR and post it as one durable PR comment. An explicit invocation authorizes posting the comment; otherwise prepare the comment and ask before posting.

## Inspect the actual PR

1. Resolve the repository, PR number, head branch, and base branch. For a stacked PR, compare against its declared base, not `main`.
2. Read the PR metadata, linked issue, commits, full diff, and repository guidance.
3. Enumerate changed files from Git. Account for every file, including generated files, lockfiles, docs, and tests.
4. Read enough surrounding code and relevant history to explain behavior and intent. Do not infer motivation from filenames alone.
5. Collect verification evidence from checks and commands that actually ran. Never claim an unobserved result.

Use the connected GitHub tools when available. Use `gh` for details the connector cannot supply. Keep the operation read-only until posting the final comment.

## Write the walkthrough

Use this structure, omitting only sections that truly do not apply:

```markdown
## PR walkthrough

### What this PR does
<Plain-English outcome and the user-visible or developer-visible behavior.>

### Why this change exists
<Problem, regression, goal, or operational need. Distinguish stated facts from inference.>

### How it works
<End-to-end flow through the affected components. Explain important decisions and boundaries.>

### Every changed file
| File | What changed | Why it changed |
|---|---|---|
| `path` | ... | ... |

### Value toward the product goal
- **Secure:** <validation, isolation, auth, secret handling, regression protection, or “no direct change”.>
- **Scalable:** <architecture, performance, maintainability, test scaling, or “no direct change”.>
- **Runnable:** <local setup, deterministic execution, CI, failure diagnostics, or “no direct change”.>
- **Agent quality:** <behavior, prompts, tools, scenarios, evaluation feedback, or “no direct change”.>

### Verification
| Check | Result |
|---|---|
| `<exact command or CI check>` | Pass/fail/not run, with concise evidence |

### Risks, limits, and follow-ups
<Behavior intentionally not covered, rollout concerns, known failures, and stacked-PR dependency. Say “None identified” only after checking.>

### Reviewer path
<The shortest sensible order for reviewing the files and validating the change.>
```

Keep the opening accessible, then become technically precise. Explain every touched file individually; do not hide files behind “miscellaneous.” Treat lockfiles and generated artifacts briefly but explicitly. Connect value claims to concrete changes. If a dimension receives no value, say so instead of inventing a benefit.

## Post and verify

1. Check existing PR comments for an earlier walkthrough from this skill.
2. Update the existing walkthrough when possible; otherwise post one new comment. Avoid duplicates.
3. Re-read the posted comment and confirm formatting, file coverage, base branch, and links are correct.
4. Return the PR URL and a concise note identifying any unverified claims or known failing checks.

Do not approve, merge, modify code, or resolve review threads as part of this skill.
