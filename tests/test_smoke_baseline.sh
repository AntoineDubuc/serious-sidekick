#!/bin/bash
# test_smoke_baseline.sh — Baseline smoke test proving the current update system is insufficient
#
# This test inspects the existing scripts/update.sh and filesystem state.
# It does NOT execute update.sh — no side effects.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

assert() {
  local desc="$1"
  local result="$2"  # "pass" or "fail"
  local detail="${3:-}"

  if [ "$result" = "pass" ]; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc"
    [ -n "$detail" ] && echo "        $detail"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "=== Smoke Test: Baseline Current State ==="
echo ""

# AC 1: update.sh copies skills to exactly 1 directory (~/.claude/skills/)
# Inspect the script — it should reference ~/.claude/skills/ but NOT ~/.claude-work/ or ~/.claude-alex/
if [ -f "$REPO_ROOT/scripts/update.sh" ]; then
  COPIES_TO_CLAUDE=$(grep -c 'HOME/.claude/skills\|GLOBAL_DIR.*\.claude/skills' "$REPO_ROOT/scripts/update.sh" || true)
  COPIES_TO_WORK=$(grep -c '\.claude-work' "$REPO_ROOT/scripts/update.sh" || true)
  COPIES_TO_ALEX=$(grep -c '\.claude-alex' "$REPO_ROOT/scripts/update.sh" || true)

  if [ "$COPIES_TO_CLAUDE" -gt 0 ] && [ "$COPIES_TO_WORK" -eq 0 ] && [ "$COPIES_TO_ALEX" -eq 0 ]; then
    assert "update.sh copies to ~/.claude/skills/ only (not work or alex)" "pass"
  else
    assert "update.sh copies to ~/.claude/skills/ only (not work or alex)" "fail" \
      "claude=$COPIES_TO_CLAUDE, work=$COPIES_TO_WORK, alex=$COPIES_TO_ALEX"
  fi
else
  assert "update.sh exists" "fail" "scripts/update.sh not found"
fi

# AC 2: update.sh does NOT copy any files from .claude/agents/
if [ -f "$REPO_ROOT/scripts/update.sh" ]; then
  COPIES_AGENTS=$(grep -c 'agents' "$REPO_ROOT/scripts/update.sh" || true)
  if [ "$COPIES_AGENTS" -eq 0 ]; then
    assert "update.sh does NOT copy agents" "pass"
  else
    assert "update.sh does NOT copy agents" "fail" \
      "Found $COPIES_AGENTS references to 'agents' in update.sh"
  fi
fi

# AC 3: manifest.json exists in repo root (created by Plan 1)
if [ -f "$REPO_ROOT/manifest.json" ]; then
  assert "manifest.json exists in repo root (Plan 1 created it)" "pass"
else
  assert "manifest.json exists in repo root (Plan 1 created it)" "fail" "manifest.json not found"
fi

# AC 4: No .serious-sidekick-state.json in any of the 3 global dirs
STATE_FOUND=0
for dir in "$HOME/.claude" "$HOME/.claude-work" "$HOME/.claude-alex"; do
  if [ -f "$dir/.serious-sidekick-state.json" ]; then
    STATE_FOUND=$((STATE_FOUND + 1))
  fi
done

if [ "$STATE_FOUND" -eq 0 ]; then
  assert "No .serious-sidekick-state.json in any global dir" "pass"
else
  assert "No .serious-sidekick-state.json in any global dir" "fail" \
    "Found state files in $STATE_FOUND dir(s)"
fi

echo ""
echo "=== Smoke Test Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
