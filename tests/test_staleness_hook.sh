#!/bin/bash
# test_staleness_hook.sh — Tests for bin/serious-staleness-hook.sh
#
# Uses SERIOUS_SIDEKICK_HOME override to test with temp directories.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# cross-platform: paths handed to native exes (python) must be readable on Windows; no-op on macOS/Linux
source "$REPO_ROOT/tests/lib/portable.sh"
REPO_ROOT="$(winpath "$REPO_ROOT")"
ERRORS=0
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert() {
  local desc="$1"
  local result="$2"
  local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc"
    [ -n "$detail" ] && echo "        $detail"
    ERRORS=$((ERRORS + 1))
  fi
}

HOOK_SCRIPT="$REPO_ROOT/bin/serious-staleness-hook.sh"

echo "=== Test: serious-staleness-hook ==="
echo ""

# ---------------------------------------------------------------
# Test 1: No staleness.json → exit 0, no output
# ---------------------------------------------------------------
echo "--- No staleness.json ---"
echo ""

EMPTY_HOME="$TMP_DIR/empty_home"
mkdir -p "$EMPTY_HOME"

T1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$EMPTY_HOME" bash "$HOOK_SCRIPT" 2>&1)
T1_EXIT=$?

if [ "$T1_EXIT" -eq 0 ]; then
  assert "No staleness.json: exits 0" "pass"
else
  assert "No staleness.json: exits 0" "fail" "exit=$T1_EXIT"
fi

if [ -z "$T1_OUTPUT" ]; then
  assert "No staleness.json: no output" "pass"
else
  assert "No staleness.json: no output" "fail" "output: $T1_OUTPUT"
fi

echo ""

# ---------------------------------------------------------------
# Test 2: staleness.json with stale_count=0 → exit 0, no output
# ---------------------------------------------------------------
echo "--- stale_count=0 ---"
echo ""

FRESH_HOME="$TMP_DIR/fresh_home"
mkdir -p "$FRESH_HOME"
cat > "$FRESH_HOME/staleness.json" <<'JSON'
{
  "checked_at": "2026-04-02T10:00:00Z",
  "local_commit": "abc1234",
  "remote_commit": "abc1234",
  "stale_count": 0,
  "summary": "up to date"
}
JSON

T2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$FRESH_HOME" bash "$HOOK_SCRIPT" 2>&1)
T2_EXIT=$?

if [ "$T2_EXIT" -eq 0 ]; then
  assert "stale_count=0: exits 0" "pass"
else
  assert "stale_count=0: exits 0" "fail" "exit=$T2_EXIT"
fi

if [ -z "$T2_OUTPUT" ]; then
  assert "stale_count=0: no output" "pass"
else
  assert "stale_count=0: no output" "fail" "output: $T2_OUTPUT"
fi

echo ""

# ---------------------------------------------------------------
# Test 3: staleness.json with stale_count=4 → prints nudge
# ---------------------------------------------------------------
echo "--- stale_count=4 ---"
echo ""

STALE_HOME="$TMP_DIR/stale_home"
mkdir -p "$STALE_HOME"
cat > "$STALE_HOME/staleness.json" <<'JSON'
{
  "checked_at": "2026-04-02T10:00:00Z",
  "local_commit": "abc1234",
  "remote_commit": "def5678",
  "stale_count": 4,
  "summary": "Update available"
}
JSON

T3_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$STALE_HOME" bash "$HOOK_SCRIPT" 2>&1)
T3_EXIT=$?

if [ "$T3_EXIT" -eq 0 ]; then
  assert "stale_count=4: exits 0" "pass"
else
  assert "stale_count=4: exits 0" "fail" "exit=$T3_EXIT"
fi

if echo "$T3_OUTPUT" | grep -q "4 components behind"; then
  assert "stale_count=4: prints nudge with count" "pass"
else
  assert "stale_count=4: prints nudge with count" "fail" "output: $T3_OUTPUT"
fi

if echo "$T3_OUTPUT" | grep -q "serious-update"; then
  assert "stale_count=4: nudge mentions serious-update" "pass"
else
  assert "stale_count=4: nudge mentions serious-update" "fail"
fi

echo ""

# ---------------------------------------------------------------
# Test 4: staleness.json with mtime > 48h → prints outdated warning
# ---------------------------------------------------------------
echo "--- mtime > 48h ---"
echo ""

OLD_HOME="$TMP_DIR/old_home"
mkdir -p "$OLD_HOME"
cat > "$OLD_HOME/staleness.json" <<'JSON'
{
  "checked_at": "2026-03-30T10:00:00Z",
  "local_commit": "abc1234",
  "remote_commit": "abc1234",
  "stale_count": 0,
  "summary": "up to date"
}
JSON

# Set mtime to 72 hours ago
touch -t "$(date -v-72H +%Y%m%d%H%M.%S)" "$OLD_HOME/staleness.json"

T4_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$OLD_HOME" bash "$HOOK_SCRIPT" 2>&1)
T4_EXIT=$?

if [ "$T4_EXIT" -eq 0 ]; then
  assert "mtime > 48h: exits 0" "pass"
else
  assert "mtime > 48h: exits 0" "fail" "exit=$T4_EXIT"
fi

if echo "$T4_OUTPUT" | grep -q "may be outdated"; then
  assert "mtime > 48h: prints outdated warning" "pass"
else
  assert "mtime > 48h: prints outdated warning" "fail" "output: $T4_OUTPUT"
fi

if echo "$T4_OUTPUT" | grep -q "serious-update --check"; then
  assert "mtime > 48h: warning mentions --check" "pass"
else
  assert "mtime > 48h: warning mentions --check" "fail"
fi

echo ""

# ---------------------------------------------------------------
# Test 5: Both stale + old → prints both messages
# ---------------------------------------------------------------
echo "--- stale + old ---"
echo ""

BOTH_HOME="$TMP_DIR/both_home"
mkdir -p "$BOTH_HOME"
cat > "$BOTH_HOME/staleness.json" <<'JSON'
{
  "checked_at": "2026-03-30T10:00:00Z",
  "local_commit": "abc1234",
  "remote_commit": "def5678",
  "stale_count": 3,
  "summary": "Update available"
}
JSON

# Set mtime to 72 hours ago
touch -t "$(date -v-72H +%Y%m%d%H%M.%S)" "$BOTH_HOME/staleness.json"

T5_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$BOTH_HOME" bash "$HOOK_SCRIPT" 2>&1)
T5_EXIT=$?

if [ "$T5_EXIT" -eq 0 ]; then
  assert "stale+old: exits 0" "pass"
else
  assert "stale+old: exits 0" "fail" "exit=$T5_EXIT"
fi

if echo "$T5_OUTPUT" | grep -q "3 components behind"; then
  assert "stale+old: prints nudge message" "pass"
else
  assert "stale+old: prints nudge message" "fail" "output: $T5_OUTPUT"
fi

if echo "$T5_OUTPUT" | grep -q "may be outdated"; then
  assert "stale+old: prints outdated warning" "pass"
else
  assert "stale+old: prints outdated warning" "fail" "output: $T5_OUTPUT"
fi

# Count lines — should be exactly 2
T5_LINES=$(echo "$T5_OUTPUT" | wc -l | tr -d ' ')
if [ "$T5_LINES" -eq 2 ]; then
  assert "stale+old: exactly 2 output lines" "pass"
else
  assert "stale+old: exactly 2 output lines" "fail" "got $T5_LINES lines"
fi

echo ""

# ---------------------------------------------------------------
# Test 6: Invalid JSON in staleness.json → exit 0, no crash
# ---------------------------------------------------------------
echo "--- invalid JSON ---"
echo ""

BAD_HOME="$TMP_DIR/bad_home"
mkdir -p "$BAD_HOME"
echo '{corrupt json' > "$BAD_HOME/staleness.json"

T6_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$BAD_HOME" bash "$HOOK_SCRIPT" 2>&1)
T6_EXIT=$?

if [ "$T6_EXIT" -eq 0 ]; then
  assert "Invalid JSON: exits 0 (never blocks)" "pass"
else
  assert "Invalid JSON: exits 0 (never blocks)" "fail" "exit=$T6_EXIT"
fi

echo ""
echo "=== serious-staleness-hook Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
