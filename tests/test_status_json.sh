#!/bin/bash
# test_status_json.sh — Schema-compliance test harness for status.json
#
# Validates a status.json file against the schema defined in
# .claude/skills/_shared/status-schema.md
#
# Usage:
#   bash tests/test_status_json.sh <path_to_status.json>
#   FIX_ROOT=/tmp/fixtures bash tests/test_status_json.sh   # run against all fixtures
#
# Reads $FIX_ROOT from env or from evidence/task_00/FIX_ROOT.path.
# Uses python3 for JSON validation (NOT jq).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Color output (if terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  RESET=''
fi

# Detect working python command
if command -v python3 >/dev/null 2>&1 \
   && [ "$(python3 -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1 \
   && [ "$(python -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  PYTHON_CMD="python"
else
  echo "SKIP: No working python found" >&2
  exit 0
fi

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "  ${GREEN}PASS${RESET}  $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "  ${RED}FAIL${RESET}  $1"
  [ -n "${2:-}" ] && echo "        $2"
}

# --- Single file validation mode ---

validate_status_json() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "ERROR: File not found: $file" >&2
    return 1
  fi

  # Step 1: Valid JSON parse
  local parse_result
  if ! parse_result=$($PYTHON_CMD -c "
import json, sys
try:
    with open('$file') as f:
        d = json.load(f)
    print('OK')
except json.JSONDecodeError as e:
    print(f'invalid JSON: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1); then
    echo "ERROR: $parse_result" >&2
    return 1
  fi

  # Step 2: Full schema validation via python3
  $PYTHON_CMD << PYEOF
import json, sys, re

with open('$file') as f:
    d = json.load(f)

errors = []

# Required fields
required = ['version', 'plan_name', 'phase', 'task', 'agents', 'worktree_name', 'timestamp']
for field in required:
    if field not in d:
        errors.append(f"missing required field: {field}")

if errors:
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

# Type checks
if not isinstance(d['version'], int):
    errors.append(f"version must be integer, got {type(d['version']).__name__}")

if not isinstance(d['plan_name'], str):
    errors.append(f"plan_name must be string, got {type(d['plan_name']).__name__}")

if not isinstance(d['phase'], dict):
    errors.append(f"phase must be object, got {type(d['phase']).__name__}")
else:
    for k in ('current', 'total'):
        if k not in d['phase']:
            errors.append(f"phase missing '{k}'")
        elif not isinstance(d['phase'][k], int):
            errors.append(f"phase.{k} must be integer, got {type(d['phase'][k]).__name__}")
        elif d['phase'][k] < 0:
            errors.append(f"phase.{k} must be >= 0, got {d['phase'][k]}")

if not isinstance(d['task'], dict):
    errors.append(f"task must be object, got {type(d['task']).__name__}")
else:
    for k in ('current', 'total'):
        if k not in d['task']:
            errors.append(f"task missing '{k}'")
        elif not isinstance(d['task'][k], int):
            errors.append(f"task.{k} must be integer, got {type(d['task'][k]).__name__}")
        elif d['task'][k] < 0:
            errors.append(f"task.{k} must be >= 0, got {d['task'][k]}")

if not isinstance(d['agents'], dict):
    errors.append(f"agents must be object, got {type(d['agents']).__name__}")
else:
    expected_agents = ['implementer', 'reviewer', 'test_runner', 'runtime_checker', 'qa']
    valid_states = ['idle', 'running', 'done', 'error']
    for agent in expected_agents:
        if agent not in d['agents']:
            errors.append(f"agents missing '{agent}'")
        elif d['agents'][agent] not in valid_states:
            errors.append(f"agents.{agent} has invalid state '{d['agents'][agent]}', must be one of: {valid_states}")

if not isinstance(d['worktree_name'], str):
    errors.append(f"worktree_name must be string, got {type(d['worktree_name']).__name__}")

if not isinstance(d['timestamp'], str):
    errors.append(f"timestamp must be string, got {type(d['timestamp']).__name__}")

# Sanitization checks on string fields
for field_name in ('plan_name', 'worktree_name'):
    val = d.get(field_name, '')
    if not isinstance(val, str):
        continue
    # Check for C0 control characters (0x00-0x1F and 0x7F)
    for i, ch in enumerate(val):
        code = ord(ch)
        if code <= 0x1F or code == 0x7F:
            errors.append(f"control character U+{code:04X} found in {field_name} at position {i}")
    # Check for bidi codepoints
    bidi_ranges = [
        (0x202A, 0x202E),  # LRE, RLE, PDF, LRO, RLO
        (0x2066, 0x2069),  # LRI, RLI, FSI, PDI
        (0x200B, 0x200F),  # ZWSP, ZWNJ, ZWJ, LRM, RLM
    ]
    for i, ch in enumerate(val):
        code = ord(ch)
        for lo, hi in bidi_ranges:
            if lo <= code <= hi:
                errors.append(f"bidi/invisible codepoint U+{code:04X} found in {field_name} at position {i}")

if errors:
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

print("VALID")
PYEOF
}

# --- Fixture-based test suite mode ---

run_fixture_tests() {
  local fix_root="$1"

  echo "=== status.json schema compliance tests ==="
  echo "Fixtures: $fix_root"
  echo ""

  # Test 1: valid_status.json should pass
  if validate_status_json "$fix_root/valid_status.json" >/dev/null 2>&1; then
    pass "valid_status.json passes validation"
  else
    fail "valid_status.json should pass validation"
  fi

  # Test 2: complete_status.json should pass (all agents done)
  if validate_status_json "$fix_root/complete_status.json" >/dev/null 2>&1; then
    pass "complete_status.json passes validation (all agents done)"
  else
    fail "complete_status.json should pass validation"
  fi

  # Test 3: dirty_status.json should fail (control characters)
  local dirty_err
  if dirty_err=$(validate_status_json "$fix_root/dirty_status.json" 2>&1); then
    fail "dirty_status.json should fail validation (control characters)" "got: VALID"
  else
    if echo "$dirty_err" | grep -qi "control character"; then
      pass "dirty_status.json fails with control character error"
    else
      fail "dirty_status.json fails but error doesn't mention control character" "$dirty_err"
    fi
  fi

  # Test 4: bidi_status.json should fail (bidi codepoints)
  local bidi_err
  if bidi_err=$(validate_status_json "$fix_root/bidi_status.json" 2>&1); then
    fail "bidi_status.json should fail validation (bidi codepoints)" "got: VALID"
  else
    if echo "$bidi_err" | grep -qi "bidi\|U+202"; then
      pass "bidi_status.json fails with bidi/U+202 error"
    else
      fail "bidi_status.json fails but error doesn't mention bidi" "$bidi_err"
    fi
  fi

  # Test 5: incomplete_status.json should fail (invalid JSON)
  local inc_err
  if inc_err=$(validate_status_json "$fix_root/incomplete_status.json" 2>&1); then
    fail "incomplete_status.json should fail validation (invalid JSON)" "got: VALID"
  else
    if echo "$inc_err" | grep -qi "invalid JSON"; then
      pass "incomplete_status.json fails with invalid JSON error"
    else
      fail "incomplete_status.json fails but error doesn't mention invalid JSON" "$inc_err"
    fi
  fi

  # Test 6: Missing required field
  local missing_field_file
  missing_field_file=$(mktemp)
  cat > "$missing_field_file" << 'HEREDOC'
{
  "version": 1,
  "plan_name": "test",
  "phase": {"current": 1, "total": 1},
  "task": {"current": 1, "total": 1},
  "agents": {
    "implementer": "idle",
    "reviewer": "idle",
    "test_runner": "idle",
    "runtime_checker": "idle",
    "qa": "idle"
  },
  "timestamp": "2026-04-12T10:30:00Z"
}
HEREDOC
  local missing_err
  if missing_err=$(validate_status_json "$missing_field_file" 2>&1); then
    fail "JSON missing worktree_name should fail" "got: VALID"
  else
    if echo "$missing_err" | grep -qi "missing.*worktree_name"; then
      pass "JSON missing worktree_name fails correctly"
    else
      fail "JSON missing worktree_name fails but wrong error" "$missing_err"
    fi
  fi
  rm -f "$missing_field_file"

  # Test 7: Invalid agent state enum
  local bad_state_file
  bad_state_file=$(mktemp)
  cat > "$bad_state_file" << 'HEREDOC'
{
  "version": 1,
  "plan_name": "test",
  "phase": {"current": 1, "total": 1},
  "task": {"current": 1, "total": 1},
  "agents": {
    "implementer": "banana",
    "reviewer": "idle",
    "test_runner": "idle",
    "runtime_checker": "idle",
    "qa": "idle"
  },
  "worktree_name": "",
  "timestamp": "2026-04-12T10:30:00Z"
}
HEREDOC
  local state_err
  if state_err=$(validate_status_json "$bad_state_file" 2>&1); then
    fail "JSON with invalid agent state 'banana' should fail" "got: VALID"
  else
    if echo "$state_err" | grep -qi "invalid state.*banana\|banana.*invalid"; then
      pass "JSON with agent state 'banana' fails correctly"
    else
      fail "JSON with agent state 'banana' fails but wrong error" "$state_err"
    fi
  fi
  rm -f "$bad_state_file"

  echo ""
  echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed, $TOTAL_COUNT total"

  if [ "$FAIL_COUNT" -gt 0 ]; then
    return 1
  fi
  return 0
}

# --- Main ---

# If a single file argument is passed, validate it directly
if [ $# -ge 1 ] && [ -n "$1" ]; then
  validate_status_json "$1"
  exit $?
fi

# Fixture-based test suite: resolve FIX_ROOT
FIX_ROOT_PATH="$PROJECT_ROOT/Research/features/live-status-line/plans/status-json-orchestrator/evidence/task_00/FIX_ROOT.path"

if [ -n "${FIX_ROOT:-}" ]; then
  : # Use env var
elif [ -f "$FIX_ROOT_PATH" ]; then
  FIX_ROOT="$(cat "$FIX_ROOT_PATH")"
else
  echo "ERROR: FIX_ROOT env var is not set and $FIX_ROOT_PATH does not exist." >&2
  echo "Set FIX_ROOT to the fixture directory path, or run Task 0 to create FIX_ROOT.path." >&2
  exit 1
fi

if [ ! -d "$FIX_ROOT" ]; then
  echo "ERROR: FIX_ROOT directory does not exist: $FIX_ROOT" >&2
  exit 1
fi

run_fixture_tests "$FIX_ROOT"
exit $?
