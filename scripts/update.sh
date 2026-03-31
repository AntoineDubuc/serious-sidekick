#!/bin/bash
# update.sh — Pull latest and sync skills to global directories
#
# Usage: Run from the serious-sidekick repo root.
#   ./scripts/update.sh
#
# What it does:
#   1. Pulls the latest from git
#   2. Copies all skills to ~/.claude/skills/ (personal global)
#   3. Reports what changed

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_SRC="$REPO_DIR/.claude/skills"
GLOBAL_DIR="$HOME/.claude/skills"

echo "=== Serious Sidekick Update ==="
echo ""

# Step 1: Pull latest
echo "Pulling latest..."
cd "$REPO_DIR"
git pull
echo ""

# Step 2: Sync skills to global
echo "Syncing skills to ~/.claude/skills/..."
mkdir -p "$GLOBAL_DIR"

UPDATED=0
ADDED=0
for skill_dir in "$SKILL_SRC"/serious-*/; do
  [ ! -d "$skill_dir" ] && continue
  skill_name=$(basename "$skill_dir")

  if [ -d "$GLOBAL_DIR/$skill_name" ]; then
    # Check if content differs
    if ! diff -rq "$skill_dir" "$GLOBAL_DIR/$skill_name" > /dev/null 2>&1; then
      cp -R "$skill_dir" "$GLOBAL_DIR/$skill_name"
      echo "  updated: $skill_name"
      UPDATED=$((UPDATED + 1))
    fi
  else
    cp -R "$skill_dir" "$GLOBAL_DIR/$skill_name"
    echo "  added:   $skill_name"
    ADDED=$((ADDED + 1))
  fi
done

# Step 3: Copy shared files
for file in _implementation_plan_template_v6.md _anti-rationalization-core.md; do
  [ -f "$REPO_DIR/$file" ] && cp "$REPO_DIR/$file" "$GLOBAL_DIR/../$file" 2>/dev/null || true
done

# Step 4: Report
TOTAL=$(ls -d "$GLOBAL_DIR"/serious-*/ 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Done. $TOTAL skills in ~/.claude/skills/"
[ "$ADDED" -gt 0 ] && echo "  $ADDED new skill(s) added"
[ "$UPDATED" -gt 0 ] && echo "  $UPDATED skill(s) updated"
[ "$ADDED" -eq 0 ] && [ "$UPDATED" -eq 0 ] && echo "  Everything already up to date."
echo ""
echo "Skills are now available globally. For project-specific setup, run /serious-init."
