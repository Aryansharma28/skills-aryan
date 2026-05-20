# skills-aryan

skills i actually use with [claude code](https://claude.com/claude-code). nothing fancy. each folder is one skill with a `SKILL.md` inside.

## what's in here

| skill | what it does |
|---|---|
| [`babysit-pr/`](./babysit-pr) | takes a PR all the way to done — CI green, every comment resolved, `/review` run, and a code-quality pass (DRY / YAGNI / blast radius / does this even belong here). pings me when it's actually finished or genuinely stuck. |
| [`junior-mode/`](./junior-mode) | pair-programming mode. claude still does the work but narrates the *why* and names the concepts as it goes, so i learn while shipping. also drops a 4.5-min status ping so i don't lose track during long runs. |
| [`drive-pr/`](./drive-pr) | walks me through a PR like a patient senior would — what it does, the shape of the change, stuff worth knowing, and just as important: stuff i can safely ignore. for when i want to *understand* a PR, not finish one. |

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
