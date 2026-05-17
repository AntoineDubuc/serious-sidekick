#!/bin/bash
# test_fire_rate.sh — Task 6 AC4 synthetic fire-rate measurement.
#
# Run 80 synthetic touchpoints (40 clean PM-voice + 40 dirty engineering-voice)
# through voice-gate.sh. Measure:
#   - True positive rate (TPR): dirty replies that correctly fire
#   - False positive rate (FPR): clean replies that incorrectly fire
#
# AC4 requires: FPR ≤ 5% (≤2 false positives over 40 clean replies).
#
# Writes evidence to Research/features/skill-voice-retrofit/evidence/fire-rate-synthetic.tsv

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/_shared/voice-gate.sh"
EVIDENCE="$PROJECT_ROOT/Research/features/skill-voice-retrofit/evidence/fire-rate-synthetic.tsv"

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

# 40 clean PM-voice replies. Should NOT trigger the safety net.
CLEAN_REPLIES=(
  "What this does: caches page titles. Question: 32 chars OK?"
  "What this does: ships the safety net. Question: go?"
  "Cleared the three failing tests. Question: continue?"
  "Setup is complete. Question: ready to roll?"
  "What this does: stops the loop. Question: ok?"
  "Phase 2 starts Monday. What I need from you: confirm. Question: yes?"
  "The plan is to ship Friday. Question: approve?"
  "Your task is to review the deck. Question: by EOD?"
  "We have one option left. Question: try it?"
  "The migration is complete. The team is ready. Question: ship?"
  "Done. Question: keep going?"
  "What this does: builds the API endpoint. Question: ready?"
  "I rolled out three phases. Phase 1 is users in CA. Question: continue?"
  "All set. Question: anything else?"
  "What this does: rewires the auth flow. Question: approve?"
  "Looking good — caught a small issue, fixed it. Question: continue?"
  "What this does: adds the dashboard. Question: ready?"
  "What this does: connects the email service. Question: test?"
  "I see two issues. Question: walk through them together?"
  "Done with that piece. Question: next?"
  "What this does: redesigns the settings page. Question: approve?"
  "Cache is warm. Question: go?"
  "What this does: speeds up the search. Question: deploy?"
  "Looks clean. Question: ship it?"
  "What this does: lets users export their data. Question: ready?"
  "What this does: adds dark mode. Question: approve?"
  "What this does: shows recent activity. Question: ready?"
  "What this does: handles login retries. Question: approve?"
  "What this does: adds two-factor auth. Question: ready?"
  "What this does: stores user preferences. Question: approve?"
  "What this does: filters search results. Question: ready?"
  "What this does: sends notifications. Question: approve?"
  "What this does: renders the checkout. Question: ready?"
  "What this does: validates the form. Question: approve?"
  "What this does: tracks page views. Question: ready?"
  "What this does: builds the onboarding. Question: approve?"
  "What this does: connects two systems. Question: ready?"
  "What this does: cleans up old records. Question: approve?"
  "What this does: refreshes the homepage. Question: ready?"
  "What this does: imports legacy data. Question: approve?"
)

# 40 dirty engineering-voice replies. SHOULD trigger the safety net.
DIRTY_REPLIES=(
  "Task 1v complete. Phase 3a continues."
  "Option 1: take this branch. Option 2: take that one."
  "Plan 7B was updated in light of Plan 3A review."
  "See /Users/me/foo/bar.md for details"
  '```bash
echo hi
```'
  "T1 is done, T2 in progress, T3 pending."
  "Phase 2 of Plan 3A done; moving to Task 5."
  "Option A: rollback. Option B: hotfix."
  "Task 4v failed. Task 5 blocked."
  "/etc/passwd.json contains the config"
  "Plan 01 review didn't agree with Plan 02 implementation"
  "Task 3 ACs 1-5 passing. Task 4 pending."
  "Phase 2: parallel. Phase 3: sequential."
  "Option C: combine A+B. Option D: do neither."
  "T-7 minutes to launch. Plan 5B is on track."
  "Plan 7B retry. Task 6v needs another pass."
  "Phase 3a complete. Phase 3b starting."
  "Option 1 is recommended. Option 2 has trade-offs."
  "Task 1 + Task 2 + Task 3 all done."
  "/var/log/app.log shows the error"
  "Plan 9C v2 ready for review."
  "Option E: defer. Option F: revert."
  "T-5 to deploy. Plan 4A locked."
  "Phase 1 — parallel. Phase 2 — sequential."
  "src/components/Header.tsx is broken"
  "Task 2v exit 1. Re-running."
  "Plan 12B failed review for the third time."
  "Option A through Option E all considered."
  "T5 dispatched. Awaiting T6."
  "/Users/me/project/file.md missing"
  "Phase 4a regression detected on Task 1v."
  "Option 1: ship. Option 2: hold."
  "Plan 7B has 12 tasks. Task 4 is the riskiest."
  "Task 8 is dead code. FAIL."
  "/tmp/output.json corrupted"
  "Plan A1, Plan B2, Plan C3 — pick one."
  "Task 9v: PASS. Task 10v: FAIL."
  "Phase 5 wrap-up at Plan 4A."
  "Option B over Option C."
  "/Users/admin/secrets.yaml"
)

echo "=== Synthetic fire-rate measurement (80 touchpoints) ==="
echo "# fire-rate-synthetic.tsv" > "$EVIDENCE"
echo "# category	expected	hook_exit	verdict" >> "$EVIDENCE"

CLEAN_FIRED=0
DIRTY_FIRED=0

for text in "${CLEAN_REPLIES[@]}"; do
  input=$(jq -n --arg t "$text" '{hook_event_name:"Stop",message:{content:[{type:"text",text:$t}]}}')
  set +e
  echo "$input" | "$HOOK" >/dev/null 2>/dev/null
  ec=$?
  set -e
  if [ "$ec" = "2" ]; then
    CLEAN_FIRED=$((CLEAN_FIRED + 1))
    verdict="FALSE_POSITIVE"
  else
    verdict="TRUE_NEGATIVE"
  fi
  printf "clean\tno_fire\t%d\t%s\n" "$ec" "$verdict" >> "$EVIDENCE"
done

for text in "${DIRTY_REPLIES[@]}"; do
  input=$(jq -n --arg t "$text" '{hook_event_name:"Stop",message:{content:[{type:"text",text:$t}]}}')
  set +e
  echo "$input" | "$HOOK" >/dev/null 2>/dev/null
  ec=$?
  set -e
  if [ "$ec" = "2" ]; then
    DIRTY_FIRED=$((DIRTY_FIRED + 1))
    verdict="TRUE_POSITIVE"
  else
    verdict="FALSE_NEGATIVE"
  fi
  printf "dirty\tfire\t%d\t%s\n" "$ec" "$verdict" >> "$EVIDENCE"
done

CLEAN_TOTAL=${#CLEAN_REPLIES[@]}
DIRTY_TOTAL=${#DIRTY_REPLIES[@]}
TOTAL=$((CLEAN_TOTAL + DIRTY_TOTAL))

# False-positive rate as integer percentage
FPR_PCT=$(( CLEAN_FIRED * 100 / CLEAN_TOTAL ))
# True-positive rate as integer percentage
TPR_PCT=$(( DIRTY_FIRED * 100 / DIRTY_TOTAL ))

echo ""
echo "Touchpoints:        $TOTAL"
echo "Clean replies:      $CLEAN_TOTAL"
echo "Dirty replies:      $DIRTY_TOTAL"
echo "Clean fired (FP):   $CLEAN_FIRED → FPR = ${FPR_PCT}%"
echo "Dirty fired (TP):   $DIRTY_FIRED → TPR = ${TPR_PCT}%"
echo ""
echo "Evidence: $EVIDENCE"

# AC4 enforcement: at least 50 touchpoints, FPR ≤ 5%
if [ "$TOTAL" -lt 50 ]; then
  assert "sample size ≥ 50" "fail" "only $TOTAL"
else
  assert "sample size ≥ 50 ($TOTAL)" "pass"
fi
if [ "$FPR_PCT" -le 5 ]; then
  assert "false-positive rate ≤ 5% (${FPR_PCT}%)" "pass"
else
  assert "false-positive rate ≤ 5%" "fail" "${FPR_PCT}% > 5%"
fi
# Bonus: TPR should be high (safety net actually catches the dirty stuff)
if [ "$TPR_PCT" -ge 80 ]; then
  assert "true-positive rate ≥ 80% (${TPR_PCT}%)" "pass"
else
  assert "true-positive rate ≥ 80%" "fail" "${TPR_PCT}% < 80%"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
