# skills-aryan

A personal collection of [Claude Code](https://claude.com/claude-code) skills.

Each subdirectory is a self-contained skill with its own `SKILL.md`. Install one at a time or all at once.

## Skills

| Skill | What it does |
|---|---|
| [`babysit-pr/`](./babysit-pr) | Watches a pull request until CI is fully green. Triages failures, applies low-risk review-comment fixes, re-pushes, and reports only on terminal state or genuine blockers. |

## Install

### One skill

```bash
mkdir -p ~/.claude/skills
cp -r babysit-pr ~/.claude/skills/
```

### All skills

```bash
mkdir -p ~/.claude/skills
cp -r */ ~/.claude/skills/
```

Project-local install: replace `~/.claude/skills` with `.claude/skills` in your repo root.

## License

MIT — see [LICENSE](./LICENSE).
