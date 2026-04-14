#!/bin/bash
# test_log_outcome_spike.sh
# Tests for the observability spike: _log_outcome function + per-hook instrumentation.
#
# Run standalone: bash tests/hooks/test_log_outcome_spike.sh
#
# This test file is not yet added to tests/run_tests.sh — run manually.

set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_LIB="$PROJECT_ROOT/.claude/skills/_shared/log-outcome.sh"

FAIL=0
PASS=0

assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s\n       expected: %s\n       actual:   %s\n' "$name" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_nonempty() {
  local name="$1" actual="$2"
  if [ -n "$actual" ]; then
    printf '  PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s (expected non-empty)\n' "$name"
    FAIL=$((FAIL + 1))
  fi
}

mk_sandbox() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/.claude"
  echo '{}' > "$dir/.claude/settings.json"
  printf '%s' "$dir"
}

# ------------------------------------------------------------
# Suite 1: _log_outcome function unit tests
# ------------------------------------------------------------
printf '\n[Suite 1] _log_outcome unit tests\n'

# Test 1.1 — library exists
[ -f "$LOG_LIB" ] && assert "library file exists" 0 0 || assert "library file exists" 0 1

# Test 1.2 — sourcing defines _log_outcome
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  type _log_outcome >/dev/null 2>&1
) && assert "sourcing defines _log_outcome" 0 0 || assert "sourcing defines _log_outcome" 0 1
rm -rf "$SBX"

# Test 1.3 — valid call writes one line
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  _log_outcome SKIP "unit-test-line"
)
LINES=$(wc -l < "$SBX/.claude/logs/outcomes.log" 2>/dev/null | tr -d ' ')
assert "valid call writes one line" "1" "$LINES"

# Test 1.4 — log dir is created if missing
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  _log_outcome ALLOW "created-dir"
)
[ -d "$SBX/.claude/logs" ] && assert "log dir created if missing" 0 0 || assert "log dir created if missing" 0 1
rm -rf "$SBX"

# Test 1.5 — output has 7 tab-separated fields
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  _log_outcome BLOCK "seven-fields"
)
FIELD_COUNT=$(tail -1 "$SBX/.claude/logs/outcomes.log" | awk -F'\t' '{print NF}')
assert "output has 7 tab-separated fields" "7" "$FIELD_COUNT"
rm -rf "$SBX"

# Test 1.6 — timestamp matches ISO-8601 UTC
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  _log_outcome PASS "ts-check"
)
TS=$(tail -1 "$SBX/.claude/logs/outcomes.log" | awk -F'\t' '{print $1}')
if echo "$TS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
  assert "timestamp matches ISO-8601 UTC" 0 0
else
  assert "timestamp matches ISO-8601 UTC ($TS)" 0 1
fi
rm -rf "$SBX"

# Test 1.7 — invalid verdict returns non-zero
SBX="$(mk_sandbox)"
RC=$(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  _log_outcome INVALID "bad-verdict" 2>/dev/null
  echo $?
)
assert "invalid verdict returns non-zero" "1" "$RC"
rm -rf "$SBX"

# Test 1.8 — newline in reason is stripped
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  _log_outcome SKIP "$(printf 'line1\nline2\tfake-field')"
)
LINES=$(wc -l < "$SBX/.claude/logs/outcomes.log" 2>/dev/null | tr -d ' ')
assert "newline in reason → still one line" "1" "$LINES"
# And the emitted line still has 7 fields (no injected tabs)
FIELD_COUNT=$(tail -1 "$SBX/.claude/logs/outcomes.log" | awk -F'\t' '{print NF}')
assert "tabs in reason stripped → 7 fields" "7" "$FIELD_COUNT"
rm -rf "$SBX"

# Test 1.9 — concurrent invocations produce correct line count
SBX="$(mk_sandbox)"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  source "$LOG_LIB"
  for i in 1 2 3; do _log_outcome SKIP "concurrent-$i" & done
  wait
)
LINES=$(wc -l < "$SBX/.claude/logs/outcomes.log" 2>/dev/null | tr -d ' ')
assert "3 concurrent invocations → 3 lines" "3" "$LINES"
rm -rf "$SBX"

# ------------------------------------------------------------
# Suite 2: per-hook instrumentation end-to-end tests
# ------------------------------------------------------------
printf '\n[Suite 2] per-hook instrumentation\n'

# Test 2.1 — tdd-gate with no active-code logs SKIP no-active-session? NO:
# per design, we don't log when breadcrumb absent (would be too noisy).
# But we DO log when breadcrumb present. So set breadcrumb and test empty tool input.
SBX="$(mk_sandbox)"
echo "plans/p1" > "$SBX/.active-code"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  export CLAUDE_TOOL_INPUT=""
  bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/tdd-gate.sh" >/dev/null 2>&1
)
if [ -f "$SBX/.claude/logs/outcomes.log" ]; then
  LAST=$(tail -1 "$SBX/.claude/logs/outcomes.log")
  VERDICT=$(echo "$LAST" | awk -F'\t' '{print $3}')
  HOOK=$(echo "$LAST" | awk -F'\t' '{print $2}')
  assert "tdd-gate empty tool input → logs event" "tdd-gate.sh" "$HOOK"
  # The silent-pass case: empty input currently exits 0. We want SKIP logged.
  if [ "$VERDICT" = "SKIP" ] || [ "$VERDICT" = "ALLOW" ]; then
    assert "tdd-gate empty input verdict is SKIP/ALLOW" 0 0
  else
    assert "tdd-gate empty input verdict is SKIP/ALLOW (got $VERDICT)" 0 1
  fi
else
  assert "tdd-gate empty tool input → logs event" 0 1
fi
rm -rf "$SBX"

# Test 2.2 — hedge-language-gate with non-plan file path
SBX="$(mk_sandbox)"
echo "plans/p1" > "$SBX/.active-plan"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/not-a-plan.md","content":"hi"}'
  bash "$PROJECT_ROOT/.claude/skills/serious-plan/hooks/hedge-language-gate.sh" >/dev/null 2>&1
)
if [ -f "$SBX/.claude/logs/outcomes.log" ]; then
  HOOK=$(tail -1 "$SBX/.claude/logs/outcomes.log" | awk -F'\t' '{print $2}')
  assert "hedge-gate non-plan file → logs event" "hedge-language-gate.sh" "$HOOK"
else
  assert "hedge-gate non-plan file → logs event" 0 1
fi
rm -rf "$SBX"

# Test 2.3 — review-theater-gate with non-verdict filename
SBX="$(mk_sandbox)"
echo "plans/p1" > "$SBX/.active-review"
(
  export CLAUDE_PROJECT_DIR="$SBX"
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/not-verdict.md","content":"LGTM"}'
  bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/review-theater-gate.sh" >/dev/null 2>&1
)
if [ -f "$SBX/.claude/logs/outcomes.log" ]; then
  HOOK=$(tail -1 "$SBX/.claude/logs/outcomes.log" | awk -F'\t' '{print $2}')
  assert "review-theater-gate non-verdict → logs event" "review-theater-gate.sh" "$HOOK"
else
  assert "review-theater-gate non-verdict → logs event" 0 1
fi
rm -rf "$SBX"

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
printf '\n'
printf '==============================\n'
printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
printf '==============================\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
