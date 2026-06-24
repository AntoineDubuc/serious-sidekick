#!/bin/bash
# test_dispatch_audit.sh — Dispatch audit trail tests (PreToolUse/Agent hook)
#
# Tests log-dispatch.sh hook script + settings.json registration.
# Covers: core behavior, input sanitization, fail-open, settings.json, script quality, performance.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# cross-platform: paths handed to native exes (python) must be readable on Windows; no-op on macOS/Linux
source "$REPO_ROOT/tests/lib/portable.sh"
REPO_ROOT="$(winpath "$REPO_ROOT")"
HOOK_SCRIPT="$REPO_ROOT/.claude/skills/serious-code/hooks/log-dispatch.sh"
SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures/dispatch-audit"

ERRORS=0
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

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

# Helper: run hook with given JSON input, breadcrumb, and plan dir
# Usage: run_hook <json_file_or_string> <plan_dir_relative> [create_breadcrumb=yes|no] [create_evidence_dir=yes|no]
#
# Writes the breadcrumb to the new per-PID path
# ($project_dir/.claude-active/{PID}-code) so the hook does NOT emit the
# Task-4 dual-read WARN. Computing the breadcrumb_path inside a child bash
# that shares the same PPID as the hook's child bash means claude_pid's
# fallback resolves to the same PID in both places.
run_hook() {
  local input="$1"
  local plan_dir="${2:-test-plan}"
  local create_breadcrumb="${3:-yes}"
  local create_evidence_dir="${4:-yes}"
  local project_dir="$TMP_DIR/project"

  rm -rf "$project_dir"
  mkdir -p "$project_dir"

  if [ "$create_breadcrumb" = "yes" ]; then
    # Compute the per-PID path the hook will resolve at runtime.
    local bc_path
    bc_path=$(CLAUDE_PROJECT_DIR="$project_dir" bash -c "
      source '$REPO_ROOT/.claude/skills/_shared/path-resolve.sh'
      breadcrumb_path code
    " 2>/dev/null)
    if [ -n "$bc_path" ]; then
      mkdir -p "$(dirname "$bc_path")"
      echo "$plan_dir" > "$bc_path"
    else
      # Fallback: write to legacy path (will trigger the dual-read WARN).
      echo "$plan_dir" > "$project_dir/.active-code"
    fi
  fi

  if [ "$create_evidence_dir" = "yes" ]; then
    mkdir -p "$project_dir/$plan_dir/evidence"
  fi

  local input_data
  if [ -f "$input" ]; then
    input_data=$(cat "$input")
  else
    input_data="$input"
  fi

  # Run hook with CLAUDE_PROJECT_DIR set, capture exit code and stderr
  local exit_code=0
  local stderr_output
  stderr_output=$(CLAUDE_PROJECT_DIR="$project_dir" bash "$HOOK_SCRIPT" <<< "$input_data" 2>&1 >/dev/null) || exit_code=$?

  # Export results for caller
  HOOK_EXIT=$exit_code
  HOOK_STDERR="$stderr_output"
  HOOK_PROJECT_DIR="$project_dir"
  HOOK_LOG_FILE="$project_dir/$plan_dir/evidence/dispatch_log.md"
}

echo "=== Test: dispatch audit trail ==="
echo ""

# ─── Core behavior ──────────────────────────────────────────────────────────

echo "--- Core behavior ---"

# AC: log-dispatch.sh exists
if [ -f "$HOOK_SCRIPT" ]; then
  assert "log-dispatch.sh exists" "pass"
else
  assert "log-dispatch.sh exists" "fail" "File not found: $HOOK_SCRIPT"
fi

# AC: Valid dispatch input with .active-code → appends log line
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  assert "Valid dispatch creates log file" "pass"
else
  assert "Valid dispatch creates log file" "fail" "Log file not created: $HOOK_LOG_FILE"
fi

# AC: Log line format: {ISO timestamp} | {task_id} | {subagent_type} | {tool_use_id}
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  # Check 4-column pipe-separated format with ISO timestamp
  if echo "$LOG_LINE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
    assert "Log line starts with ISO timestamp" "pass"
  else
    assert "Log line starts with ISO timestamp" "fail" "Line: $LOG_LINE"
  fi

  if echo "$LOG_LINE" | grep -qF '|'; then
    FIELD_COUNT=$(echo "$LOG_LINE" | awk -F'|' '{print NF}')
    if [ "$FIELD_COUNT" -eq 4 ]; then
      assert "Log line has 4 pipe-separated fields" "pass"
    else
      assert "Log line has 4 pipe-separated fields" "fail" "Got $FIELD_COUNT fields: $LOG_LINE"
    fi
  else
    assert "Log line has 4 pipe-separated fields" "fail" "No pipe chars found: $LOG_LINE"
  fi
fi

# AC: TASK_ID parsed from prompt field
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  if echo "$LOG_LINE" | grep -qF 'task_01'; then
    assert "TASK_ID task_01 parsed from prompt" "pass"
  else
    assert "TASK_ID task_01 parsed from prompt" "fail" "Line: $LOG_LINE"
  fi
fi

# AC: subagent_type extracted from tool_input.subagent_type
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  if echo "$LOG_LINE" | grep -qF 'serious-code-implementer'; then
    assert "subagent_type extracted correctly" "pass"
  else
    assert "subagent_type extracted correctly" "fail" "Line: $LOG_LINE"
  fi
fi

# AC: tool_use_id extracted
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  if echo "$LOG_LINE" | grep -qF 'toolu_xyz'; then
    assert "tool_use_id extracted correctly" "pass"
  else
    assert "tool_use_id extracted correctly" "fail" "Line: $LOG_LINE"
  fi
fi

# AC: Missing TASK_ID → logged as "unscoped"
run_hook "$FIXTURES_DIR/no_taskid_dispatch.json" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  if echo "$LOG_LINE" | grep -qF 'unscoped'; then
    assert "Missing TASK_ID logged as 'unscoped'" "pass"
  else
    assert "Missing TASK_ID logged as 'unscoped'" "fail" "Line: $LOG_LINE"
  fi
else
  assert "Missing TASK_ID logged as 'unscoped'" "fail" "Log file not created"
fi

# ─── Input sanitization ────────────────────────────────────────────────────

echo ""
echo "--- Input sanitization ---"

# AC: Pipe chars in subagent_type replaced with underscore
run_hook "$FIXTURES_DIR/pipe_chars_dispatch.json" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  # Should NOT contain "bad|type|here" — pipes should be replaced
  if echo "$LOG_LINE" | grep -qF 'bad_type_here'; then
    assert "Pipe chars in subagent_type replaced with underscore" "pass"
  else
    assert "Pipe chars in subagent_type replaced with underscore" "fail" "Line: $LOG_LINE"
  fi
  # tool_use_id pipe also replaced
  if echo "$LOG_LINE" | grep -qF 'toolu_pipe_test'; then
    assert "Pipe chars in tool_use_id replaced with underscore" "pass"
  else
    assert "Pipe chars in tool_use_id replaced with underscore" "fail" "Line: $LOG_LINE"
  fi
fi

# AC: Control chars in fields stripped
run_hook "$FIXTURES_DIR/control_chars_dispatch.json" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  # Control chars should be stripped — no \x01, \x07, \x1b in output
  CTRL_COUNT=$(echo "$LOG_LINE" | LC_ALL=C tr -d '\040-\176' | wc -c | tr -d ' ')
  if [ "$CTRL_COUNT" -le 1 ]; then
    # 1 for trailing newline
    assert "Control chars stripped from fields" "pass"
  else
    assert "Control chars stripped from fields" "fail" "Found $CTRL_COUNT non-printable bytes in: $LOG_LINE"
  fi
fi

# AC: Raw prompt body is NEVER written to dispatch_log.md
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  if echo "$LOG_LINE" | grep -qF 'You are the implementer'; then
    assert "Raw prompt body NOT written to log" "fail" "Prompt body found in: $LOG_LINE"
  else
    assert "Raw prompt body NOT written to log" "pass"
  fi
fi

# AC: Fields truncated to 200 bytes
LONG_TYPE=$($PYTHON_CMD -c "print('A' * 300)")
LONG_JSON="{\"session_id\":\"abc\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Agent\",\"tool_input\":{\"prompt\":\"TASK_ID: task_01\",\"subagent_type\":\"$LONG_TYPE\"},\"tool_use_id\":\"toolu_long\"}"
run_hook "$LONG_JSON" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  # Extract subagent_type field (third field)
  FIELD3=$(echo "$LOG_LINE" | awk -F'|' '{print $3}' | tr -d ' ')
  FIELD3_LEN=${#FIELD3}
  if [ "$FIELD3_LEN" -le 200 ]; then
    assert "subagent_type truncated to 200 bytes" "pass"
  else
    assert "subagent_type truncated to 200 bytes" "fail" "Field length: $FIELD3_LEN"
  fi
fi

# AC: dispatch_log.md written with mode 0600
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "yes" "yes"
if [ -f "$HOOK_LOG_FILE" ]; then
  FILE_PERMS=$(stat -f "%Lp" "$HOOK_LOG_FILE" 2>/dev/null || stat -c "%a" "$HOOK_LOG_FILE" 2>/dev/null)
  if [ "$FILE_PERMS" = "600" ]; then
    assert "dispatch_log.md has mode 0600" "pass"
  else
    assert "dispatch_log.md has mode 0600" "fail" "Mode: $FILE_PERMS"
  fi
fi

# ─── Fail-open ──────────────────────────────────────────────────────────────

echo ""
echo "--- Fail-open behavior ---"

# AC: No .active-code breadcrumb → exit 0, no log, no stderr
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "no" "yes"
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "No breadcrumb: exit 0" "pass"
else
  assert "No breadcrumb: exit 0" "fail" "Exit code: $HOOK_EXIT"
fi
if [ -f "$HOOK_LOG_FILE" ]; then
  assert "No breadcrumb: no log written" "fail" "Log file was created"
else
  assert "No breadcrumb: no log written" "pass"
fi
if [ -z "$HOOK_STDERR" ]; then
  assert "No breadcrumb: no stderr" "pass"
else
  assert "No breadcrumb: no stderr" "fail" "Stderr: $HOOK_STDERR"
fi

# AC: Malformed JSON → exit 0, no log, no stderr
run_hook "this is not json at all {{{" "test-plan" "yes" "yes"
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "Malformed JSON: exit 0" "pass"
else
  assert "Malformed JSON: exit 0" "fail" "Exit code: $HOOK_EXIT"
fi
if [ ! -f "$HOOK_LOG_FILE" ]; then
  assert "Malformed JSON: no log written" "pass"
else
  LOG_CONTENT=$(cat "$HOOK_LOG_FILE")
  if [ -z "$LOG_CONTENT" ]; then
    assert "Malformed JSON: no log written" "pass"
  else
    assert "Malformed JSON: no log written" "fail" "Log content: $LOG_CONTENT"
  fi
fi
if [ -z "$HOOK_STDERR" ]; then
  assert "Malformed JSON: no stderr" "pass"
else
  assert "Malformed JSON: no stderr" "fail" "Stderr: $HOOK_STDERR"
fi

# AC: Missing jq → exit 0
# Test by creating a temp dir with only essential binaries (no jq)
run_hook_no_jq() {
  local project_dir="$TMP_DIR/project-nojq"
  local fake_bin="$TMP_DIR/fake-bin"
  rm -rf "$project_dir" "$fake_bin"
  mkdir -p "$project_dir/test-plan/evidence"
  mkdir -p "$fake_bin"
  # Write breadcrumb to the per-PID path (matches run_hook's approach) so the
  # hook does NOT emit the Task-4 dual-read WARN under the no-jq env.
  local bc_path
  bc_path=$(CLAUDE_PROJECT_DIR="$project_dir" bash -c "
    source '$REPO_ROOT/.claude/skills/_shared/path-resolve.sh'
    breadcrumb_path code
  " 2>/dev/null)
  if [ -n "$bc_path" ]; then
    mkdir -p "$(dirname "$bc_path")"
    echo "test-plan" > "$bc_path"
  else
    echo "test-plan" > "$project_dir/.active-code"
  fi

  # Symlink essential commands but NOT jq
  for cmd in bash cat date grep head sed tr cut printf; do
    CMD_PATH=$(command -v "$cmd" 2>/dev/null) || true
    [ -n "$CMD_PATH" ] && ln -sf "$CMD_PATH" "$fake_bin/$cmd"
  done

  local exit_code=0
  local stderr_output
  stderr_output=$(PATH="$fake_bin" CLAUDE_PROJECT_DIR="$project_dir" bash "$HOOK_SCRIPT" < "$FIXTURES_DIR/valid_dispatch.json" 2>&1 >/dev/null) || exit_code=$?

  HOOK_EXIT=$exit_code
  HOOK_STDERR="$stderr_output"
  HOOK_LOG_FILE="$project_dir/test-plan/evidence/dispatch_log.md"
}
run_hook_no_jq
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "Missing jq: exit 0" "pass"
else
  assert "Missing jq: exit 0" "fail" "Exit code: $HOOK_EXIT"
fi
if [ ! -f "$HOOK_LOG_FILE" ]; then
  assert "Missing jq: no log written" "pass"
else
  assert "Missing jq: no log written" "fail" "Log file was created"
fi

# AC: Evidence dir doesn't exist → exit 0, no log (don't create dirs)
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "yes" "no"
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "No evidence dir: exit 0" "pass"
else
  assert "No evidence dir: exit 0" "fail" "Exit code: $HOOK_EXIT"
fi
# Evidence dir should NOT have been created
if [ -d "$HOOK_PROJECT_DIR/test-plan/evidence" ]; then
  assert "No evidence dir: dir not created by hook" "fail" "evidence/ was created"
else
  assert "No evidence dir: dir not created by hook" "pass"
fi

# AC: Exit code always 0 on all inputs
echo ""
echo "--- Exit code always 0 ---"
for fixture in valid_dispatch.json no_taskid_dispatch.json bash_call.json pipe_chars_dispatch.json control_chars_dispatch.json; do
  if [ -f "$FIXTURES_DIR/$fixture" ]; then
    run_hook "$FIXTURES_DIR/$fixture" "test-plan" "yes" "yes"
    if [ "$HOOK_EXIT" -eq 0 ]; then
      assert "Exit 0 on $fixture" "pass"
    else
      assert "Exit 0 on $fixture" "fail" "Exit code: $HOOK_EXIT"
    fi
  fi
done

# Also test with empty stdin
run_hook "" "test-plan" "yes" "yes"
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "Exit 0 on empty stdin" "pass"
else
  assert "Exit 0 on empty stdin" "fail" "Exit code: $HOOK_EXIT"
fi

# ─── settings.json ──────────────────────────────────────────────────────────

echo ""
echo "--- settings.json registration ---"

# AC: settings.json has Agent matcher in PreToolUse
if [ -f "$SETTINGS_FILE" ]; then
  AGENT_MATCHER=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Agent") | .matcher' "$SETTINGS_FILE" 2>/dev/null || echo "")
  if [ "$AGENT_MATCHER" = "Agent" ]; then
    assert "settings.json has Agent matcher in PreToolUse" "pass"
  else
    assert "settings.json has Agent matcher in PreToolUse" "fail" "No Agent matcher found"
  fi

  # AC: Agent hook has correct command
  AGENT_CMD=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Agent") | .hooks[0].command' "$SETTINGS_FILE" 2>/dev/null || echo "")
  EXPECTED_CMD='bash "$CLAUDE_PROJECT_DIR/.claude/skills/serious-code/hooks/log-dispatch.sh"'
  if [ "$AGENT_CMD" = "$EXPECTED_CMD" ]; then
    assert "Agent hook command is correct" "pass"
  else
    assert "Agent hook command is correct" "fail" "Got: $AGENT_CMD"
  fi

  # AC: Agent hook type is command
  AGENT_TYPE=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Agent") | .hooks[0].type' "$SETTINGS_FILE" 2>/dev/null || echo "")
  if [ "$AGENT_TYPE" = "command" ]; then
    assert "Agent hook type is 'command'" "pass"
  else
    assert "Agent hook type is 'command'" "fail" "Got: $AGENT_TYPE"
  fi

  # AC: Agent hook timeout is 5
  AGENT_TIMEOUT=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Agent") | .hooks[0].timeout' "$SETTINGS_FILE" 2>/dev/null || echo "")
  if [ "$AGENT_TIMEOUT" = "5" ]; then
    assert "Agent hook timeout is 5" "pass"
  else
    assert "Agent hook timeout is 5" "fail" "Got: $AGENT_TIMEOUT"
  fi

  # AC: settings.json is valid JSON
  if jq empty "$SETTINGS_FILE" 2>/dev/null; then
    assert "settings.json is valid JSON" "pass"
  else
    assert "settings.json is valid JSON" "fail"
  fi

  # AC: Existing Edit|Write matcher still present
  EDITWRITE_MATCHER=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Edit|Write") | .matcher' "$SETTINGS_FILE" 2>/dev/null || echo "")
  if [ "$EDITWRITE_MATCHER" = "Edit|Write" ]; then
    assert "Existing Edit|Write matcher preserved" "pass"
  else
    assert "Existing Edit|Write matcher preserved" "fail"
  fi

  # AC: Existing Stop hooks still present
  STOP_COUNT=$(jq '.hooks.Stop | length' "$SETTINGS_FILE" 2>/dev/null || echo "0")
  if [ "$STOP_COUNT" -gt 0 ]; then
    assert "Existing Stop hooks preserved" "pass"
  else
    assert "Existing Stop hooks preserved" "fail" "Stop hook count: $STOP_COUNT"
  fi
else
  assert "settings.json exists" "fail" "File not found: $SETTINGS_FILE"
fi

# ─── Script quality ─────────────────────────────────────────────────────────

echo ""
echo "--- Script quality ---"

# AC: shellcheck passes
if [ -f "$HOOK_SCRIPT" ]; then
  SHELLCHECK_OUTPUT=$(shellcheck --severity=error "$HOOK_SCRIPT" 2>&1 || true)
  SHELLCHECK_EXIT=$(shellcheck --severity=error "$HOOK_SCRIPT" >/dev/null 2>&1; echo $?)
  if [ "$SHELLCHECK_EXIT" -eq 0 ]; then
    assert "shellcheck --severity=error passes" "pass"
  else
    assert "shellcheck --severity=error passes" "fail" "$SHELLCHECK_OUTPUT"
  fi

  # AC: No eval, no backticks, no local var=$(cmd)
  EVAL_COUNT=$(grep -cE '\beval\b' "$HOOK_SCRIPT" || true)
  BACKTICK_COUNT=$(grep -c '`' "$HOOK_SCRIPT" || true)
  LOCAL_SUBCMD=$(grep -cE 'local [a-zA-Z_]+=\$\(' "$HOOK_SCRIPT" || true)
  if [ "$EVAL_COUNT" -eq 0 ]; then
    assert "No eval in script" "pass"
  else
    assert "No eval in script" "fail" "Found $EVAL_COUNT eval(s)"
  fi
  if [ "$BACKTICK_COUNT" -eq 0 ]; then
    assert "No backticks in script" "pass"
  else
    assert "No backticks in script" "fail" "Found $BACKTICK_COUNT backtick(s)"
  fi
  if [ "$LOCAL_SUBCMD" -eq 0 ]; then
    assert "No local var=\$(cmd)" "pass"
  else
    assert "No local var=\$(cmd)" "fail" "Found $LOCAL_SUBCMD instance(s)"
  fi

  # AC: jq pinned at script start
  JQ_PIN=$(grep -c 'JQ=.*(command -v jq)' "$HOOK_SCRIPT" || true)
  if [ "$JQ_PIN" -gt 0 ]; then
    assert "jq pinned via JQ=\$(command -v jq)" "pass"
  else
    assert "jq pinned via JQ=\$(command -v jq)" "fail" "Pattern not found"
  fi
else
  assert "Hook script exists for quality checks" "fail"
fi

# AC: Performance — completes in < 100ms
if [ -f "$HOOK_SCRIPT" ]; then
  run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "yes" "yes"
  # Time the hook execution
  PERF_PROJECT="$TMP_DIR/perf-project"
  rm -rf "$PERF_PROJECT"
  mkdir -p "$PERF_PROJECT/test-plan/evidence"
  # Write breadcrumb to the per-PID path so the perf measurement reflects the
  # production happy path (no dual-read WARN, no legacy fallback overhead).
  PERF_BC=$(CLAUDE_PROJECT_DIR="$PERF_PROJECT" bash -c "
    source '$REPO_ROOT/.claude/skills/_shared/path-resolve.sh'
    breadcrumb_path code
  " 2>/dev/null)
  if [ -n "$PERF_BC" ]; then
    mkdir -p "$(dirname "$PERF_BC")"
    echo "test-plan" > "$PERF_BC"
  else
    echo "test-plan" > "$PERF_PROJECT/.active-code"
  fi

  START_MS=$($PYTHON_CMD -c "import time; print(int(time.time() * 1000))")
  CLAUDE_PROJECT_DIR="$PERF_PROJECT" bash "$HOOK_SCRIPT" < "$FIXTURES_DIR/valid_dispatch.json" >/dev/null 2>&1 || true
  END_MS=$($PYTHON_CMD -c "import time; print(int(time.time() * 1000))")
  ELAPSED=$((END_MS - START_MS))

  if [ "$ELAPSED" -lt 100 ]; then
    assert "Performance: completes in < 100ms (${ELAPSED}ms)" "pass"
  else
    assert "Performance: completes in < 100ms (${ELAPSED}ms)" "fail"
  fi
fi

# ─── Negative tests ────────────────────────────────────────────────────────

echo ""
echo "--- Negative tests ---"

# NEG: No .active-code → zero file writes, exit 0
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "no" "yes"
if [ "$HOOK_EXIT" -eq 0 ] && [ ! -f "$HOOK_LOG_FILE" ]; then
  assert "NEG: No breadcrumb → zero writes + exit 0" "pass"
else
  assert "NEG: No breadcrumb → zero writes + exit 0" "fail" "exit=$HOOK_EXIT, log_exists=$([ -f \"$HOOK_LOG_FILE\" ] && echo yes || echo no)"
fi

# NEG: Broken JSON → exit 0
run_hook "{broken" "test-plan" "yes" "yes"
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "NEG: Broken JSON → exit 0" "pass"
else
  assert "NEG: Broken JSON → exit 0" "fail" "Exit code: $HOOK_EXIT"
fi

# NEG: Missing prompt field → unscoped, exit 0
NOPROMPT='{"session_id":"x","hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"test"},"tool_use_id":"toolu_np"}'
run_hook "$NOPROMPT" "test-plan" "yes" "yes"
if [ "$HOOK_EXIT" -eq 0 ]; then
  assert "NEG: Missing prompt field → exit 0" "pass"
else
  assert "NEG: Missing prompt field → exit 0" "fail" "Exit code: $HOOK_EXIT"
fi
if [ -f "$HOOK_LOG_FILE" ]; then
  LOG_LINE=$(cat "$HOOK_LOG_FILE")
  if echo "$LOG_LINE" | grep -qF 'unscoped'; then
    assert "NEG: Missing prompt field → task_id=unscoped" "pass"
  else
    assert "NEG: Missing prompt field → task_id=unscoped" "fail" "Line: $LOG_LINE"
  fi
fi

# ─── Zero stderr on all inputs ─────────────────────────────────────────────

echo ""
echo "--- Zero stderr on all inputs ---"

for fixture in valid_dispatch.json no_taskid_dispatch.json pipe_chars_dispatch.json control_chars_dispatch.json; do
  if [ -f "$FIXTURES_DIR/$fixture" ]; then
    run_hook "$FIXTURES_DIR/$fixture" "test-plan" "yes" "yes"
    if [ -z "$HOOK_STDERR" ]; then
      assert "Zero stderr on $fixture" "pass"
    else
      assert "Zero stderr on $fixture" "fail" "Stderr: $HOOK_STDERR"
    fi
  fi
done

# Also no stderr with missing breadcrumb
run_hook "$FIXTURES_DIR/valid_dispatch.json" "test-plan" "no" "yes"
if [ -z "$HOOK_STDERR" ]; then
  assert "Zero stderr with no breadcrumb" "pass"
else
  assert "Zero stderr with no breadcrumb" "fail" "Stderr: $HOOK_STDERR"
fi

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "=== Results: $((ERRORS)) error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
