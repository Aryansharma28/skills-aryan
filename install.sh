#!/usr/bin/env bash
# Install skills-aryan into ~/.claude/skills (or $CLAUDE_SKILLS_DIR).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Aryansharma28/skills-aryan/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- babysit-pr        # install one skill
#   curl -fsSL .../install.sh | LOCAL=1 bash                 # install into ./.claude/skills
set -euo pipefail

REPO="${SKILLS_REPO:-https://github.com/Aryansharma28/skills-aryan.git}"
BRANCH="${SKILLS_BRANCH:-main}"
SRC_DIR="${SKILLS_SRC:-$HOME/.local/share/skills-aryan}"

if [[ "${LOCAL:-0}" == "1" ]]; then
  DEST="$PWD/.claude/skills"
else
  DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
fi

ONLY=("$@")

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }

if [[ -d "$SRC_DIR/.git" ]]; then
  echo "→ updating $SRC_DIR"
  git -C "$SRC_DIR" fetch --quiet origin "$BRANCH"
  git -C "$SRC_DIR" reset --hard --quiet "origin/$BRANCH"
else
  echo "→ cloning into $SRC_DIR"
  mkdir -p "$(dirname "$SRC_DIR")"
  git clone --quiet --branch "$BRANCH" "$REPO" "$SRC_DIR"
fi

mkdir -p "$DEST"

installed=0
for d in "$SRC_DIR"/*/; do
  name="$(basename "$d")"
  [[ -f "$d/SKILL.md" ]] || continue
  if (( ${#ONLY[@]} > 0 )); then
    skip=1
    for want in "${ONLY[@]}"; do [[ "$want" == "$name" ]] && skip=0; done
    (( skip )) && continue
  fi
  ln -sfn "$d" "$DEST/$name"
  echo "  ✓ $name → $DEST/$name"
  installed=$((installed + 1))
done

if (( installed == 0 )); then
  echo "no skills installed (check the name?)" >&2
  exit 1
fi

echo
echo "Installed $installed skill(s) into $DEST"
echo "Restart Claude Code to pick them up."
