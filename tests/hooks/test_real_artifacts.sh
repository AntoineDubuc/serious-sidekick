#!/bin/bash
# test_real_artifacts.sh — Verify hooks work against REAL workflow artifacts
# produced during this session, not test fixtures.
#
# Tests each hook against the actual research, scope, plan, review, and code
# outputs from the mechanical-enforcement-gap workflow.

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

run_test() {
  local name="$1"
  local expected_exit="$2"
  local actual_exit="$3"
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  PASS: $name (exit $actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Real Artifact Verification ==="
echo "Testing hooks against actual workflow output from this session"
echo ""

# Use the real project root as CLAUDE_PROJECT_DIR so hooks resolve
# relative breadcrumb paths against the actual repo.
export CLAUDE_PROJECT_DIR="$PROJECT_ROOT"

# --- 1. check-verdict.sh against real review_verdict.md ---
echo "1. check-verdict.sh vs real review_verdict.md"
REVIEW_DIR="Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks"
echo "$REVIEW_DIR" > "$PROJECT_ROOT/.active-review"
bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>"/tmp/check-verdict-output.txt"
EXIT_CODE=$?
rm -f "$PROJECT_ROOT/.active-review"
run_test "Real review verdict passes (all 3 agents present + file:line refs)" 0 "$EXIT_CODE"
if [ "$EXIT_CODE" -ne 0 ]; then
  echo "    STDERR:"
  cat /tmp/check-verdict-output.txt | sed 's/^/    /'
fi
echo ""

# --- 2. check-extraction.sh against real implementation_plan.md ---
echo "2. check-extraction.sh vs real implementation_plan.md"
PLAN_DIR="Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks"
echo "$PLAN_DIR" > "$PROJECT_ROOT/.active-plan"
bash "$PROJECT_ROOT/.claude/skills/serious-plan/hooks/check-extraction.sh" 2>"/tmp/check-extraction-output.txt"
EXIT_CODE=$?
rm -f "$PROJECT_ROOT/.active-plan"
run_test "Real plan passes (has _extracted_items.md + [Source:] citations + verified stamp)" 0 "$EXIT_CODE"
if [ "$EXIT_CODE" -ne 0 ]; then
  echo "    STDERR:"
  cat /tmp/check-extraction-output.txt | sed 's/^/    /'
fi
echo ""

# --- 3. check-manifest.sh against real manifest.md ---
echo "3. check-manifest.sh vs real manifest.md"
SCOPE_DIR="Research/features/mechanical-enforcement-gap"
echo "$SCOPE_DIR" > "$PROJECT_ROOT/.active-scope"
bash "$PROJECT_ROOT/.claude/skills/serious-scope/hooks/check-manifest.sh" 2>"/tmp/check-manifest-output.txt"
EXIT_CODE=$?
rm -f "$PROJECT_ROOT/.active-scope"
run_test "Real manifest passes (has manifest.md + _extracted_items.md + verified stamp)" 0 "$EXIT_CODE"
if [ "$EXIT_CODE" -ne 0 ]; then
  echo "    STDERR:"
  cat /tmp/check-manifest-output.txt | sed 's/^/    /'
fi
echo ""

# --- 4. capture-research.sh against real research.md ---
echo "4. capture-research.sh vs real research.md"
RESEARCH_DIR="Research/features/mechanical-enforcement-gap"
echo "$RESEARCH_DIR" > "$PROJECT_ROOT/.active-research"
bash "$PROJECT_ROOT/.claude/skills/serious-research/hooks/capture-research.sh" 2>"/tmp/capture-research-output.txt"
EXIT_CODE=$?
rm -f "$PROJECT_ROOT/.active-research"
run_test "Real research passes (status: done, no source so extraction skipped)" 0 "$EXIT_CODE"
if [ "$EXIT_CODE" -ne 0 ]; then
  echo "    STDERR:"
  cat /tmp/capture-research-output.txt | sed 's/^/    /'
fi
echo ""

# --- 5. verify-completion-gate.sh — no active code session, should pass ---
echo "5. verify-completion-gate.sh with no active session"
rm -f "$PROJECT_ROOT/.active-code"
bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>/dev/null
run_test "No active code session passes" 0 $?
echo ""

# --- 6. Verify the section headers match what our review agents produce ---
echo "6. Verify section header contract"
VERDICT_FILE="$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks/review_verdict.md"
ANTI_SLOP=$(grep -c '## Anti-Slop Audit Report' "$VERDICT_FILE" || true)
STRUCTURAL=$(grep -c '## Structural Review Report' "$VERDICT_FILE" || true)
SECURITY=$(grep -c '## Security Review Report' "$VERDICT_FILE" || true)
echo "  Anti-Slop Audit Report: $ANTI_SLOP occurrences"
echo "  Structural Review Report: $STRUCTURAL occurrences"
echo "  Security Review Report: $SECURITY occurrences"
ALL_PRESENT=0
[ "$ANTI_SLOP" -gt 0 ] && [ "$STRUCTURAL" -gt 0 ] && [ "$SECURITY" -gt 0 ] && ALL_PRESENT=1
run_test "All 3 section headers present in real verdict" 0 $((1 - ALL_PRESENT))
echo ""

# --- 7. Verify _extracted_items.md exists alongside research ---
echo "7. Verify extraction files exist at each pipeline stage"
SCOPE_EXTRACT="$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/_extracted_items.md"
PLAN_EXTRACT="$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks/_extracted_items.md"
[ -f "$SCOPE_EXTRACT" ] && run_test "Scope _extracted_items.md exists" 0 0 || run_test "Scope _extracted_items.md exists" 0 1
[ -f "$PLAN_EXTRACT" ] && run_test "Plan _extracted_items.md exists" 0 0 || run_test "Plan _extracted_items.md exists" 0 1
echo ""

# --- 8. Verify verified: stamps in real artifacts ---
echo "8. Verify frontmatter stamps in real artifacts"
MANIFEST_VERIFIED=$(head -20 "$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/manifest.md" | grep "^verified:" | head -1)
PLAN_VERIFIED=$(head -20 "$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks/implementation_plan.md" | grep "^verified:" | head -1)
[ -n "$MANIFEST_VERIFIED" ] && run_test "Manifest has verified: stamp ($MANIFEST_VERIFIED)" 0 0 || run_test "Manifest has verified: stamp" 0 1
[ -n "$PLAN_VERIFIED" ] && run_test "Plan has verified: stamp ($PLAN_VERIFIED)" 0 0 || run_test "Plan has verified: stamp" 0 1
echo ""

# --- 9. Verify [Source:] citations in real plan ---
echo "9. Verify [Source:] citations in real plan"
PLAN_FILE="$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks/implementation_plan.md"
CITATION_COUNT=$(grep -c '\[Source:' "$PLAN_FILE" || true)
ITEM_COUNT=$(grep -cE '^\s*[0-9]+\.' "$PROJECT_ROOT/Research/features/mechanical-enforcement-gap/plans/harden-existing-hooks/_extracted_items.md" || true)
echo "  Extracted items: $ITEM_COUNT"
echo "  [Source:] citations in plan: $CITATION_COUNT"
if [ "$ITEM_COUNT" -gt 0 ] && [ "$CITATION_COUNT" -gt 0 ]; then
  run_test "Plan has citations ($CITATION_COUNT) for items ($ITEM_COUNT)" 0 0
else
  run_test "Plan has citations ($CITATION_COUNT) for items ($ITEM_COUNT)" 0 1
fi
echo ""

# --- 10. Verify Required Output sections in agent defs ---
echo "10. Verify agent Required Output sections"
for agent in implementer reviewer test-runner runtime-checker qa; do
  AGENT_FILE="$PROJECT_ROOT/.claude/agents/serious-code-${agent}.md"
  HAS_SECTION=$(grep -c '## Required Output' "$AGENT_FILE" || true)
  run_test "serious-code-${agent}.md has Required Output" 0 $((1 - (HAS_SECTION > 0 ? 1 : 0)))
done
echo ""

# --- 11. Verify commitment diff claims removed ---
echo "11. Verify SKILL.md commitment diff claims removed"
CODE_SKILL="$PROJECT_ROOT/.claude/skills/serious-code/SKILL.md"
PLAN_SKILL="$PROJECT_ROOT/.claude/skills/serious-plan/SKILL.md"
CODE_CLAIM=$(grep -c "Stop hook diffs this commitment" "$CODE_SKILL" || true)
PLAN_CLAIM=$(grep -c "Stop hook checks the plan against this commitment" "$PLAN_SKILL" || true)
run_test "serious-code SKILL.md: no commitment diff claim ($CODE_CLAIM found)" 0 "$CODE_CLAIM"
run_test "serious-plan SKILL.md: no commitment diff claim ($PLAN_CLAIM found)" 0 "$PLAN_CLAIM"
echo ""

# --- 12. Verify settings.json timeouts ---
echo "12. Verify settings.json timeouts"
TIMEOUT_30=$(grep -c '"timeout": 30' "$PROJECT_ROOT/.claude/settings.json" || true)
TIMEOUT_10=$(grep -c '"timeout": 10' "$PROJECT_ROOT/.claude/settings.json" || true)
run_test "6 Stop hooks at timeout 30 ($TIMEOUT_30 found)" 0 $((TIMEOUT_30 < 6 ? 1 : 0))
run_test "3 PreToolUse hooks at timeout 10 ($TIMEOUT_10 found)" 0 $((TIMEOUT_10 < 3 ? 1 : 0))
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "SOME CHECKS FAILED against real artifacts. Review output above."
  exit 1
fi
echo "ALL CHECKS PASS against real workflow artifacts."
exit 0
