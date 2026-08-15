#!/bin/bash
# test_smoke_baseline.sh — Structural smoke test of the update system's shape
#
# AC1/AC2 were inverted 2026-08-15: they characterised deficiencies that are now FIXED.
# This test inspects scripts/update.sh and filesystem state.
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

# ⛔ AC1 and AC2 WERE INVERTED ON 2026-08-15, AND THAT IS THE POINT.
#
# They were written as RED-phase characterisation assertions — this file's header still says
# "proving the current update system is insufficient". They pinned two deficiencies:
# update.sh reached only ~/.claude, and it never copied agents. Both are now FIXED
# (scripts/update.sh is manifest-driven), so the old assertions failed precisely BECAUSE the
# work they were written to motivate had been done. A characterisation test that outlives the
# behaviour it characterises reports a regression where there is a fix.
#
# They now pin the GREEN state. Behavioural coverage — real syncing, backups, ownership,
# idempotence, spaced paths — lives in tests/test_update_sync.sh; these two stay cheap and
# structural so a revert of update.sh is caught immediately.

# AC 1: update.sh is NOT hardcoded to a single profile directory
if [ -f "$REPO_ROOT/scripts/update.sh" ]; then
  READS_MANIFEST=$(grep -c 'manifest.json' "$REPO_ROOT/scripts/update.sh" || true)
  HARDCODED_ONLY=$(grep -c 'GLOBAL_DIR="\$HOME/.claude/skills"' "$REPO_ROOT/scripts/update.sh" || true)
  DISCOVERS=$(grep -c 'ROOTS' "$REPO_ROOT/scripts/update.sh" || true)

  if [ "$READS_MANIFEST" -gt 0 ] && [ "$HARDCODED_ONLY" -eq 0 ] && [ "$DISCOVERS" -gt 0 ]; then
    assert "update.sh is manifest-driven and discovers multiple installations" "pass"
  else
    assert "update.sh is manifest-driven and discovers multiple installations" "fail" \
      "manifest refs=$READS_MANIFEST, hardcoded-single-dir=$HARDCODED_ONLY, discovery=$DISCOVERS"
  fi
else
  assert "update.sh exists" "fail" "scripts/update.sh not found"
fi

# AC 2: the synced file set covers agents (it is the manifest's, not a hardcoded skills glob)
if [ -f "$REPO_ROOT/scripts/update.sh" ] && [ -f "$REPO_ROOT/manifest.json" ]; then
  AGENT_ENTRIES=$(python3 -c "
import json,sys
f=json.load(open('$REPO_ROOT/manifest.json'))['files']
print(sum(1 for p,m in f.items() if m.get('ownership')=='template' and '/agents/' in p))
" 2>/dev/null || echo 0)
  SKILLS_GLOB=$(grep -c 'SKILL_SRC"/serious-\*/' "$REPO_ROOT/scripts/update.sh" || true)

  if [ "$AGENT_ENTRIES" -gt 0 ] && [ "$SKILLS_GLOB" -eq 0 ]; then
    assert "update.sh covers agents ($AGENT_ENTRIES template-owned agent files)" "pass"
  else
    assert "update.sh covers agents" "fail" \
      "template agent entries=$AGENT_ENTRIES, legacy skills-only glob=$SKILLS_GLOB"
  fi
fi

# AC 3: manifest.json exists in repo root (created by Plan 1)
if [ -f "$REPO_ROOT/manifest.json" ]; then
  assert "manifest.json exists in repo root (Plan 1 created it)" "pass"
else
  assert "manifest.json exists in repo root (Plan 1 created it)" "fail" "manifest.json not found"
fi

# AC 4: State files consistent — either none (pre-update) or all 3 (post-update)
STATE_FOUND=0
for dir in "$HOME/.claude" "$HOME/.claude-work" "$HOME/.claude-alex"; do
  if [ -f "$dir/.serious-sidekick-state.json" ]; then
    STATE_FOUND=$((STATE_FOUND + 1))
  fi
done

if [ "$STATE_FOUND" -eq 0 ]; then
  assert "State files: none (pre-update baseline)" "pass"
elif [ "$STATE_FOUND" -eq 3 ]; then
  assert "State files: all 3 present (post-update)" "pass"
else
  assert "State files: consistent (all or none)" "fail" \
    "Found state files in $STATE_FOUND of 3 dir(s) — partial state"
fi

echo ""
echo "=== Smoke Test Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
