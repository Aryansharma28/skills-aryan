# skills-aryan

A personal collection of [Claude Code](https://claude.com/claude-code) skills, shared publicly so anyone can use them.

Each subdirectory is a self-contained skill with its own `SKILL.md`. Install one at a time or all at once, globally (every project) or per-project.

## Skills

| Skill | What it does |
|---|---|
| [`babysit-pr/`](./babysit-pr) | Takes a PR all the way to *done*: CI green, every review/CodeRabbit comment resolved, `/review` run, and a code-quality pass (DRY / YAGNI / blast radius / architecture fit). Triages failures, applies low-risk fixes, and surfaces only terminal state or genuine blockers. |
| [`junior-mode/`](./junior-mode) | Pair-programming mode for junior engineers. Claude does the work but narrates the WHY at each step, names the concepts in play, and asks questions at real decision points so you learn while shipping. Also sets up a 4.5-minute background ping so you don't lose track during long-running work. |

## Install

Claude Code loads skills from two locations:

- **Global** (available in every project): `~/.claude/skills/<skill-name>/SKILL.md`
- **Project-local** (only inside one repo): `<repo>/.claude/skills/<skill-name>/SKILL.md`

### Quickest path — clone & symlink (recommended)

This way `git pull` inside one folder updates the skills on every machine:

```bash
git clone https://github.com/Aryansharma28/skills-aryan.git ~/code/skills-aryan
mkdir -p ~/.claude/skills
for d in ~/code/skills-aryan/*/; do
  name=$(basename "$d")
  [ "$name" = ".git" ] && continue
  ln -sfn "$d" ~/.claude/skills/"$name"
done
```

To update later:

```bash
cd ~/code/skills-aryan && git pull
```

### Copy a single skill

```bash
mkdir -p ~/.claude/skills
cp -r babysit-pr ~/.claude/skills/
```

### Copy all skills

```bash
mkdir -p ~/.claude/skills
cp -r */ ~/.claude/skills/
```

### Project-local install

Replace `~/.claude/skills` with `.claude/skills` from your repo root. Useful when a skill should only apply inside one project.

### Verify the install

Inside any project, start Claude Code and run `/help` — installed skills are listed under the available-skills section. The slash form (`/babysit-pr`, `/junior-mode`) becomes invokable.

## Installing on a second laptop

Same steps. If you used the symlink approach, you only need to:

```bash
git clone https://github.com/Aryansharma28/skills-aryan.git ~/code/skills-aryan
```

…and run the symlink loop above. After that, every `git pull` propagates skill changes everywhere.

## Contributing your own

1. Make a new directory: `mkdir my-skill && cd my-skill`
2. Create `SKILL.md` with YAML frontmatter (`name`, `description`) and the prompt body.
3. Add a row to the Skills table above.
4. PR.

The `description` is what Claude uses to decide when to apply the skill — be specific about the trigger phrases.

## License

MIT — see [LICENSE](./LICENSE).
