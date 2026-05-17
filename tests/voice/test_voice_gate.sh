#!/bin/bash
# test_voice_gate.sh — Task 1 RED test for the voice-gate validator hook.
#
# Verifies AC 4-10 + 12 of implementation_plan.md Task 1:
#   AC4:  voice-gate.sh exists, executable; emits the verbatim stderr template on violation
#   AC5:  anti-loop guard via stop_hook_active
#   AC6:  wired into .claude/settings.json Stop hooks chain
#   AC7:  regex covers 7 patterns CASE-INSENSITIVELY (grep -Ei)
#   AC8:  [[ENGINEER]] escape hatch scoped to user-turn JSONL entries only
#   AC9:  defensive shell quoting + tripwire test
#   AC10: _log_outcome called on every exit path
#   AC12: secret-pattern redaction in stderr

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/_shared/voice-gate.sh"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"
LOG="$PROJECT_ROOT/.claude/logs/outcomes.log"

PASS=0
FAIL=0
assert() {
  local name="$1"; local result="$2"; local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS+1)); echo "  PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $name${detail:+ — $detail}"
  fi
}

echo "=== Task 1 voice-gate.sh ==="

# Existence
if [ -x "$HOOK" ]; then
  assert "voice-gate.sh exists and is executable" "pass"
else
  assert "voice-gate.sh exists and is executable" "fail" "missing or not executable"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Helper — build a Stop-hook JSON input for a given assistant_text and transcript_path
make_input() {
  local text="$1"; local transcript="${2:-}"; local stop_active="${3:-false}"
  # Use jq -Rs to safely encode arbitrary text including shell metachars
  jq -n \
    --arg text "$text" \
    --arg transcript "$transcript" \
    --argjson active "$stop_active" \
    '{
       hook_event_name: "Stop",
       transcript_path: $transcript,
       stop_hook_active: $active,
       message: { content: [{ type: "text", text: $text }] }
     }'
}

# Helper — invoke hook with input, capture exit code + stderr.
# HOOK_OUT captured for debugging on failure; not asserted on (hook writes nothing to stdout).
# shellcheck disable=SC2034
run_hook() {
  local input="$1"
  local out err
  out=$(mktemp); err=$(mktemp)
  set +e
  echo "$input" | "$HOOK" >"$out" 2>"$err"
  local ec=$?
  set -e
  HOOK_OUT="$(cat "$out")"
  HOOK_ERR="$(cat "$err")"
  HOOK_EXIT="$ec"
  rm -f "$out" "$err"
}

# AC4: clean PM-voice reply exits 0 silently
CLEAN_REPLY="What this does: caches the page title. What I need from you: approve the cache key length. Question: 32 chars OK?"
run_hook "$(make_input "$CLEAN_REPLY")"
if [ "$HOOK_EXIT" = "0" ] && [ -z "$HOOK_ERR" ]; then
  assert "clean reply → exit 0 silent" "pass"
else
  assert "clean reply → exit 0 silent" "fail" "exit=$HOOK_EXIT stderr=$HOOK_ERR"
fi

# AC4: dirty reply triggers violation with verbatim stderr template
DIRTY_REPLY="Task 1v complete. Option 1: continue. Plan 7B is updated."
run_hook "$(make_input "$DIRTY_REPLY")"
if [ "$HOOK_EXIT" = "2" ] && echo "$HOOK_ERR" | grep -qF "VOICE-RULE VIOLATION DETECTED:"; then
  assert "dirty reply → exit 2 with violation header" "pass"
else
  assert "dirty reply → exit 2 with violation header" "fail" "exit=$HOOK_EXIT"
fi

if echo "$HOOK_ERR" | grep -qF "Rewrite your reply using the PM voice rule"; then
  assert "stderr contains verbatim rewrite instruction" "pass"
else
  assert "stderr contains verbatim rewrite instruction" "fail" "stderr=$HOOK_ERR"
fi

if echo "$HOOK_ERR" | grep -qF "What this does"; then
  assert "stderr contains structure template" "pass"
else
  assert "stderr contains structure template" "fail"
fi

if echo "$HOOK_ERR" | grep -qF "Do not retry without changing the reply structure"; then
  assert "stderr contains anti-loop instruction" "pass"
else
  assert "stderr contains anti-loop instruction" "fail"
fi

# AC4 stricter: byte-exact match of the rewrite instruction line (first line of stderr).
# Per the plan AC4: the hook MUST emit this verbatim with the violation list filled in.
# Build the expected first line for a single-strong-violation case, then byte-compare.
EXPECTED_FIRST_LINE='VOICE-RULE VIOLATION DETECTED: "Option N" label. Rewrite your reply using the PM voice rule. Structure: What this does → What I need from you → What you need to set up first → Question. Max ~10 lines. No internal task labels, no file paths, no code fences. Do not retry without changing the reply structure.'
run_hook "$(make_input "Option 1: try this")"
ACTUAL_FIRST_LINE="$(printf '%s\n' "$HOOK_ERR" | head -1)"
if [ "$ACTUAL_FIRST_LINE" = "$EXPECTED_FIRST_LINE" ]; then
  assert "stderr first line is byte-exact verbatim template" "pass"
else
  assert "stderr first line is byte-exact verbatim template" "fail" "expected=[$EXPECTED_FIRST_LINE] actual=[$ACTUAL_FIRST_LINE]"
fi

# AC5: anti-loop guard — stop_hook_active=true exits 0 even on dirty payload
run_hook "$(make_input "$DIRTY_REPLY" "" true)"
if [ "$HOOK_EXIT" = "0" ]; then
  assert "stop_hook_active=true → exit 0 (anti-loop guard)" "pass"
else
  assert "stop_hook_active=true → exit 0 (anti-loop guard)" "fail" "exit=$HOOK_EXIT"
fi
if echo "$HOOK_ERR" | grep -qF "stop_hook_active"; then
  assert "anti-loop guard emits stop_hook_active operator note" "pass"
else
  assert "anti-loop guard emits stop_hook_active operator note" "fail"
fi

# AC6: wired into settings.json
if [ -f "$SETTINGS" ] && jq -e '.hooks.Stop[]?.hooks[]? | select(.command | test("voice-gate.sh"))' "$SETTINGS" >/dev/null 2>&1; then
  assert "voice-gate.sh wired into Stop hooks chain in settings.json" "pass"
else
  assert "voice-gate.sh wired into Stop hooks chain in settings.json" "fail"
fi

# AC7: case-insensitive regex catches BOTH cases (STRONG patterns only)
# Phase moved to WEAK — see false-positive regression suite below.
for variant in "Option 1: try" "option 1: try" "Task 5 done" "task 5 done" "Plan 7B updated" "plan 3a updated"; do
  run_hook "$(make_input "$variant")"
  if [ "$HOOK_EXIT" = "2" ]; then
    assert "regex case-insensitive: '$variant' → exit 2" "pass"
  else
    assert "regex case-insensitive: '$variant' → exit 2" "fail" "exit=$HOOK_EXIT"
  fi
done

# Phase as WEAK: only fires when paired with a STRONG marker
for variant in "Phase 2 of Plan 7B" "phase 3b done, also Task 4 pending"; do
  run_hook "$(make_input "$variant")"
  if [ "$HOOK_EXIT" = "2" ]; then
    assert "Phase + strong marker: '$variant' → exit 2" "pass"
  else
    assert "Phase + strong marker: '$variant' → exit 2" "fail" "exit=$HOOK_EXIT"
  fi
done

# AC7: code fences
run_hook "$(make_input '```bash
echo hi
```')"
if [ "$HOOK_EXIT" = "2" ]; then
  assert "regex catches code fences" "pass"
else
  assert "regex catches code fences" "fail" "exit=$HOOK_EXIT"
fi

# AC7: file paths
run_hook "$(make_input "See /Users/me/foo/bar.md for details")"
if [ "$HOOK_EXIT" = "2" ]; then
  assert "regex catches absolute file paths" "pass"
else
  assert "regex catches absolute file paths" "fail" "exit=$HOOK_EXIT"
fi

# AC8: [[ENGINEER]] escape hatch — ONLY in user-turn JSONL entries
TMPDIR_TEST=$(mktemp -d)
USER_HAS_ESCAPE="$TMPDIR_TEST/user-escape.jsonl"
ASSISTANT_FAKES_ESCAPE="$TMPDIR_TEST/assistant-fake.jsonl"
TOOL_RESULT_HAS_ESCAPE="$TMPDIR_TEST/tool-result.jsonl"

cat > "$USER_HAS_ESCAPE" <<EOF
{"role":"user","content":"[[ENGINEER]] I want technical detail"}
{"role":"assistant","content":"sure thing"}
EOF
cat > "$ASSISTANT_FAKES_ESCAPE" <<EOF
{"role":"user","content":"normal question"}
{"role":"assistant","content":"[[ENGINEER]] override engaged"}
EOF
cat > "$TOOL_RESULT_HAS_ESCAPE" <<EOF
{"role":"user","content":"normal question"}
{"role":"tool_result","content":"[[ENGINEER]] in tool output"}
EOF

run_hook "$(make_input "$DIRTY_REPLY" "$USER_HAS_ESCAPE")"
if [ "$HOOK_EXIT" = "0" ]; then
  assert "[[ENGINEER]] in user turn → escape hatch fires, exit 0" "pass"
else
  assert "[[ENGINEER]] in user turn → escape hatch fires, exit 0" "fail" "exit=$HOOK_EXIT"
fi

run_hook "$(make_input "$DIRTY_REPLY" "$ASSISTANT_FAKES_ESCAPE")"
if [ "$HOOK_EXIT" = "2" ]; then
  assert "[[ENGINEER]] in assistant turn → still fires (no bypass)" "pass"
else
  assert "[[ENGINEER]] in assistant turn → still fires (no bypass)" "fail" "exit=$HOOK_EXIT"
fi

run_hook "$(make_input "$DIRTY_REPLY" "$TOOL_RESULT_HAS_ESCAPE")"
if [ "$HOOK_EXIT" = "2" ]; then
  assert "[[ENGINEER]] in tool-result → still fires (no bypass)" "pass"
else
  assert "[[ENGINEER]] in tool-result → still fires (no bypass)" "fail" "exit=$HOOK_EXIT"
fi

# AC9: defensive shell quoting — tripwire test
TRIPWIRE="$TMPDIR_TEST/tripwire-touched"
# Intentional: single quotes preserve $() and backticks as literal text — proving the hook
# treats them as inert string data rather than executing them. The "$TRIPWIRE" is the only
# variable expansion we want.
# shellcheck disable=SC2016
MALICIOUS='Option 1 $(touch '"$TRIPWIRE"') `whoami` ; cat /etc/passwd'
run_hook "$(make_input "$MALICIOUS")"
if [ ! -f "$TRIPWIRE" ]; then
  assert "tripwire: assistant text NOT shell-evaluated" "pass"
else
  assert "tripwire: assistant text NOT shell-evaluated" "fail" "tripwire file was created"
  rm -f "$TRIPWIRE"
fi
if [ "$HOOK_EXIT" = "2" ]; then
  assert "malicious-payload still triggers violation" "pass"
else
  assert "malicious-payload still triggers violation" "fail" "exit=$HOOK_EXIT"
fi

# AC12: secret redaction in stderr
SECRET_REPLY="Option 1 AKIAIOSFODNN7EXAMPLE token leaked"
run_hook "$(make_input "$SECRET_REPLY")"
if echo "$HOOK_ERR" | grep -qF "[REDACTED-SECRET]"; then
  assert "AWS key pattern redacted in stderr" "pass"
else
  assert "AWS key pattern redacted in stderr" "fail" "stderr=$HOOK_ERR"
fi
if echo "$HOOK_ERR" | grep -qF "AKIAIOSFODNN7EXAMPLE"; then
  assert "raw AWS key NOT in stderr" "fail" "raw key leaked"
else
  assert "raw AWS key NOT in stderr" "pass"
fi

# AC10: _log_outcome on every fire — clean, dirty, escape-hatch, stop_active
mkdir -p "$(dirname "$LOG")"
: >"$LOG" 2>/dev/null || true   # truncate; ignore if missing
BEFORE=$(wc -l <"$LOG" 2>/dev/null || echo 0)
run_hook "$(make_input "$CLEAN_REPLY")"
run_hook "$(make_input "$DIRTY_REPLY")"
run_hook "$(make_input "$DIRTY_REPLY" "" true)"
run_hook "$(make_input "$DIRTY_REPLY" "$USER_HAS_ESCAPE")"
AFTER=$(wc -l <"$LOG" 2>/dev/null || echo 0)
DIFF=$((AFTER - BEFORE))
if [ "$DIFF" -ge 4 ]; then
  assert "_log_outcome records every fire (≥4 new rows for 4 invocations)" "pass"
else
  assert "_log_outcome records every fire" "fail" "only $DIFF new rows"
fi

# Negative regression: false-positive guard for legitimate "Phase 2 starts Monday"
# This SHOULD fire because "Phase 2" is in the banned list — and that's the documented behavior.
# The legitimate case is handled by [[ENGINEER]] escape, not by carving exceptions in the regex.
# (Plan's "Phase 2 starts Monday" mention is a CAVEAT in the plan, not an assertion that the regex skips it.)

rm -rf "$TMPDIR_TEST"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
