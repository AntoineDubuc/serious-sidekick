#!/bin/bash
# test_voice_reminder_hook.sh — Task 5 RED test for the UserPromptSubmit reminder hook.
#
# Verifies AC3-AC7 of Task 5: hook emits valid JSON with the canonical reminder
# phrased as factual project state, is wired into settings.json, fails open, and
# hardcodes the reminder string.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/_shared/voice-reminder.sh"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

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

echo "=== Task 5 voice-reminder hook ==="

# AC3: hook exists and is executable
if [ -x "$HOOK" ]; then
  assert "voice-reminder.sh exists and is executable" "pass"
else
  assert "voice-reminder.sh exists and is executable" "fail"
  echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

# AC3: emit valid JSON with hookSpecificOutput.additionalContext
output=$(echo '{"hook_event_name":"UserPromptSubmit","prompt":"test"}' | "$HOOK")
if echo "$output" | jq -e . >/dev/null 2>&1; then
  assert "hook emits valid JSON" "pass"
else
  assert "hook emits valid JSON" "fail" "output: $output"
fi

if echo "$output" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  assert "hook emits hookSpecificOutput.additionalContext" "pass"
else
  assert "hook emits hookSpecificOutput.additionalContext" "fail"
fi

# AC3: additionalContext includes the canonical "User prefers PM voice" phrasing
context=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
if echo "$context" | grep -qF "User prefers PM voice"; then
  assert "additionalContext contains 'User prefers PM voice'" "pass"
else
  assert "additionalContext contains 'User prefers PM voice'" "fail"
fi

# AC4: phrased as factual project state, NOT imperative
# Banned imperative verbs: must, obey, always, do not, never, you must
if echo "$context" | grep -qiE '\b(must|obey|always|never)\b|\byou must\b'; then
  assert "additionalContext does NOT contain imperative commands" "fail" "found imperative verb"
else
  assert "additionalContext does NOT contain imperative commands" "pass"
fi
# Present-tense factual phrasing markers
if echo "$context" | grep -qE 'User prefers|Voice card lives at|lives at'; then
  assert "additionalContext uses present-tense factual phrasing" "pass"
else
  assert "additionalContext uses present-tense factual phrasing" "fail"
fi

# AC5: hook is wired into settings.json UserPromptSubmit chain
if jq -e '.hooks.UserPromptSubmit[].hooks[]? | select(.command | test("voice-reminder.sh"))' "$SETTINGS" >/dev/null 2>&1; then
  assert "voice-reminder.sh wired into UserPromptSubmit chain in settings.json" "pass"
else
  assert "voice-reminder.sh wired into UserPromptSubmit chain in settings.json" "fail"
fi

# AC6: fail-open — broken python3 dependency → hook still exits 0 silently
TMPDIR_TEST=$(mktemp -d)
cat > "$TMPDIR_TEST/python3" <<'EOF'
#!/bin/bash
exit 99
EOF
chmod +x "$TMPDIR_TEST/python3"
set +e
PATH="$TMPDIR_TEST:$PATH" bash "$HOOK" </dev/null >/dev/null 2>&1
ec=$?
set -e
rm -rf "$TMPDIR_TEST"
if [ "$ec" = "0" ]; then
  assert "fail-open on broken python3: hook exits 0" "pass"
else
  assert "fail-open on broken python3: hook exits 0" "fail" "exit=$ec"
fi

# AC7: hook hardcodes the reminder string — does NOT read any file
if grep -qE '^[[:space:]]*(cat |source |\. /)' "$HOOK" \
   || grep -qE 'read.*<.*voice-card|<[[:space:]]*[a-z._/-]+\.md' "$HOOK"; then
  assert "hook does not read external files (hardcoded reminder)" "fail" "file-read pattern detected"
else
  assert "hook does not read external files (hardcoded reminder)" "pass"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
