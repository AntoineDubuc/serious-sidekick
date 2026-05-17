#!/bin/bash
# test_voice_gate_false_positives.sh — explicit false-positive regression suite.
#
# Every entry is a CLEAN PM-voice reply that the validator must NOT fire on.
# Source: plan's negative-test requirement + manual audit 2026-05-17.
#
# If any of these starts firing, the regex got too aggressive.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/_shared/voice-gate.sh"

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

run_clean() {
  local text="$1"
  local input
  input=$(jq -n --arg t "$text" '{hook_event_name:"Stop",message:{content:[{type:"text",text:$t}]}}')
  local err exit_code
  err=$(echo "$input" | "$HOOK" 2>&1 >/dev/null) || true
  echo "$input" | "$HOOK" >/dev/null 2>/dev/null
  exit_code=$?
  HOOK_EXIT="$exit_code"
  HOOK_ERR="$err"
}

echo "=== False-positive regression suite ==="

# Each entry: case name | clean reply text that MUST NOT fire
declare -a CLEAN_CASES=(
  "Phase as calendar prose|Phase 2 starts Monday. What I need from you: confirm the date. Question: ok?"
  "Phase as rollout stage|We're rolling out in three phases. Phase 1 is users in CA. Question: ready to start?"
  "Plan as English noun|The plan is to ship Friday. What I need from you: approval. Question: go?"
  "Task as English verb|Your task is to review the deck. Question: by EOD?"
  "Option as English noun|We have one option left. Question: try it?"
  "T-prefix in time expression|T-minus 5 to launch. Question: ready?"
  "Hyphenated single letter|The plan-A approach. Question: continue?"
  "Slash in URL-like text|Visit ai-entourage.ca for the demo. Question: send link?"
  "Numbers in plain prose|We need 2 more reviewers and 3 more testers. Question: send invites?"
  "Common project terms|The migration is complete. The team is ready. Question: ship?"
)

for entry in "${CLEAN_CASES[@]}"; do
  name="${entry%%|*}"
  text="${entry#*|}"
  run_clean "$text"
  if [ "$HOOK_EXIT" = "0" ]; then
    assert "$name → exit 0 (clean)" "pass"
  else
    assert "$name → exit 0 (clean)" "fail" "exit=$HOOK_EXIT stderr=$HOOK_ERR text=\"$text\""
  fi
done

# Symmetry check: confirm the same cases WOULD fire if combined with a strong marker
# (sanity — Phase alone clean, Phase + Plan 7B dirty)
run_clean "Phase 2 starts Monday and Plan 7B is on track"
if [ "$HOOK_EXIT" = "2" ]; then
  assert "Phase + Plan together → exit 2 (paired weak+strong)" "pass"
else
  assert "Phase + Plan together → exit 2 (paired weak+strong)" "fail" "exit=$HOOK_EXIT"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
