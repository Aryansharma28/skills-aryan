# skills-aryan

skills i actually use with [claude code](https://claude.com/claude-code). nothing fancy. each folder is one skill with a `SKILL.md` inside.

## what's in here

| skill | what it does |
|---|---|
| [`babysit-pr/`](./babysit-pr) | takes a PR all the way to done — CI green, every comment resolved, `/review` run, and a code-quality pass (DRY / YAGNI / blast radius / does this even belong here). pings me when it's actually finished or genuinely stuck. |
| [`goated-review/`](./goated-review) | the deep review for the PRs that actually matter — big refactors, mass deletions, dep/lockfile churn, anything coderabbit gave up on. reads the room first (existing reviewers, CI, the description's own claims), buckets files by risk, grills every "every consumer migrated"-style claim, **adversarially verifies each finding** before saying anything, dedupes against what reviewers already raised, and ships `[BLOCKER]` / `[NON-BLOCKER]` inline comments with file:line evidence. shows the plan before posting. |
| [`junior-mode/`](./junior-mode) | pair-programming mode. claude still does the work but narrates the *why* and names the concepts as it goes, so i learn while shipping. also drops a 4.5-min status ping so i don't lose track during long runs. |
| [`understand-pr/`](./understand-pr) | walks me through a PR (someone else's *or* my own when i've made a pile of changes) — what it does, the shape, architectural shifts, idioms in play, what's worth knowing vs. what to ignore. ends by offering to turn the walkthrough into post-ready review comments if i want them. |

### picking a PR skill

three skills touch PRs. quick decoder:

- **i want to *learn* this PR** → [`understand-pr`](./understand-pr)
- **i want to *gate* this PR** (deep review, blockers vs nits, posted as comments) → [`goated-review`](./goated-review)
- **the PR is mine and i want to *land* it** → [`babysit-pr`](./babysit-pr)

## stuff i also use

- [rogeriochaves/skills](https://github.com/rogeriochaves/skills) — rogerio's collection. `browser-qa` is the one i lean on constantly.

## install

one liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Aryansharma28/skills-aryan/main/install.sh | bash
```

clones to `~/.local/share/skills-aryan` and symlinks each skill into `~/.claude/skills/`. re-run to update.

variants:

```bash
# just one skill
curl -fsSL https://raw.githubusercontent.com/Aryansharma28/skills-aryan/main/install.sh | bash -s -- babysit-pr

# project-local instead of global
curl -fsSL https://raw.githubusercontent.com/Aryansharma28/skills-aryan/main/install.sh | LOCAL=1 bash
```

if you'd rather do it by hand:

```bash
git clone https://github.com/Aryansharma28/skills-aryan.git ~/code/skills-aryan
mkdir -p ~/.claude/skills
for d in ~/code/skills-aryan/*/; do ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"; done
```

restart claude code after installing — skills load at session start.

## new laptop

same one-liner. done.

## adding your own

new folder, drop a `SKILL.md` with `name` and `description` in the frontmatter, write the prompt. the `description` is what claude reads to decide when to fire the skill, so be specific about trigger phrases.

MIT — see [LICENSE](./LICENSE).
