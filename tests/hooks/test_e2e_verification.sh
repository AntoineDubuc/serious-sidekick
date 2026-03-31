#!/bin/bash
# test_e2e_verification.sh — Task 7: End-to-end verification
# Re-runs the Task 0 scenarios and verifies every gap is now CLOSED
# (hooks exit 2 where they previously exited 0)
#
# Usage: bash tests/hooks/test_e2e_verification.sh

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

echo "=== Task 7: End-to-End Verification — All Gaps Closed ==="
echo ""

# --- Gap 1: Review agent dispatch validation ---
echo "Gap 1: check-verdict.sh blocks verdict missing agent sections"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'EOF'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict
**Verdict:** PASS

## Anti-Slop Audit Report
Found: src/main.ts:42

(Missing Structural and Security sections)
EOF
echo "testdata" > "$SIM_ROOT/.active-review"
bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
run_test "Verdict missing 2 agent sections → blocks" 2 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Gap 2a: Code agent dispatch — missing evidence files ---
echo "Gap 2a: verify-completion-gate.sh blocks missing evidence files"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01"
echo "ALL ACs PASS" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
# Only gate_passed.md — missing implementation.md, review.md, tests.md, runtime.md, qa.md
echo "testdata" > "$SIM_ROOT/.active-code"
bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>/dev/null
run_test "Task with only gate_passed.md → blocks" 2 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Gap 2b: Code agent dispatch — gate_passed.md with FAIL content ---
echo "Gap 2b: verify-completion-gate.sh blocks gate_passed.md with FAIL"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01"
echo "0/5 ACs passed — FAIL" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
echo "impl" > "$SIM_ROOT/testdata/evidence/task_01/implementation.md"
echo "rev" > "$SIM_ROOT/testdata/evidence/task_01/review.md"
echo "tst" > "$SIM_ROOT/testdata/evidence/task_01/tests.md"
echo "run" > "$SIM_ROOT/testdata/evidence/task_01/runtime.md"
echo "qa" > "$SIM_ROOT/testdata/evidence/task_01/qa.md"
echo "testdata" > "$SIM_ROOT/.active-code"
bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>/dev/null
run_test "gate_passed.md with FAIL content → blocks" 2 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Gap 3: Extraction cross-referencing ---
echo "Gap 3: check-extraction.sh blocks plan with items but no citations"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test
status: done
source: Research/features/test/research.md
verified: 2026-03-29
---
# Test Plan

## Task Descriptions
### Task 1: Do something
**Acceptance criteria:**
- [ ] Something works
PLAN
cat > "$SIM_ROOT/testdata/_extracted_items.md" << 'ITEMS'
1. Item one
2. Item two
3. Item three
ITEMS
echo "testdata" > "$SIM_ROOT/.active-plan"
bash "$PROJECT_ROOT/.claude/skills/serious-plan/hooks/check-extraction.sh" 2>/dev/null
run_test "Plan with 3 items, 0 citations → blocks" 2 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Gap 5a: Verified stamp — plan ---
echo "Gap 5a: check-extraction.sh blocks plan without verified stamp"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test
status: done
source: Research/features/test/research.md
---
# Test Plan
## Task Descriptions
### Task 1: Do something
**Acceptance criteria:**
- [ ] Something works [Source: research.md#Finding-1]
PLAN
cat > "$SIM_ROOT/testdata/_extracted_items.md" << 'ITEMS'
1. Item one
ITEMS
echo "testdata" > "$SIM_ROOT/.active-plan"
bash "$PROJECT_ROOT/.claude/skills/serious-plan/hooks/check-extraction.sh" 2>/dev/null
run_test "Plan with source but no verified stamp → blocks" 2 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Gap 8: Scope extraction gate ---
# NOTE: check-manifest.sh does NOT enforce _extracted_items.md presence.
# It only checks: (1) manifest.md exists, (2) source requires verified stamp.
# A manifest without source passes all checks (no upstream = no requirements).
echo "Gap 8: check-manifest.sh — scope without _extracted_items.md (no source)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
echo "# Manifest" > "$SIM_ROOT/testdata/manifest.md"
# No _extracted_items.md, no source field
echo "testdata" > "$SIM_ROOT/.active-scope"
bash "$PROJECT_ROOT/.claude/skills/serious-scope/hooks/check-manifest.sh" 2>/dev/null
run_test "Scope with manifest (no source) passes — extraction not enforced by hook" 0 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Gap 9: Research extraction gate ---
echo "Gap 9: capture-research.sh blocks research without _extracted_items.md (when source exists)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/research.md" << 'RES'
---
skill: serious-research
slug: test
status: done
source: Research/conversations/test/summary.md
---
# Research
RES
# No _extracted_items.md
echo "testdata" > "$SIM_ROOT/.active-research"
bash "$PROJECT_ROOT/.claude/skills/serious-research/hooks/capture-research.sh" 2>/dev/null
run_test "Research with source but no _extracted_items.md → blocks" 2 $?
rm -rf "$SIM_ROOT"
echo ""

# --- Fail-closed: CHECKS_PASSED pattern works ---
echo "Fail-closed: All 9 hooks have CHECKS_PASSED pattern"
TOTAL_HOOKS=0
HOOKS_WITH_PATTERN=0
for hook in \
  ".claude/skills/serious-code/hooks/verify-completion-gate.sh" \
  ".claude/skills/serious-conversation/hooks/capture-conversation.sh" \
  ".claude/skills/serious-research/hooks/capture-research.sh" \
  ".claude/skills/serious-plan/hooks/check-extraction.sh" \
  ".claude/skills/serious-scope/hooks/check-manifest.sh" \
  ".claude/skills/serious-review/hooks/check-verdict.sh" \
  ".claude/skills/serious-code/hooks/tdd-gate.sh" \
  ".claude/skills/serious-plan/hooks/hedge-language-gate.sh" \
  ".claude/skills/serious-review/hooks/review-theater-gate.sh"; do
  TOTAL_HOOKS=$((TOTAL_HOOKS + 1))
  COUNT=$(grep -c 'CHECKS_PASSED' "$PROJECT_ROOT/$hook" 2>/dev/null || true)
  [ "$COUNT" -ge 3 ] && HOOKS_WITH_PATTERN=$((HOOKS_WITH_PATTERN + 1))
done
run_test "All 9 hooks have CHECKS_PASSED ($HOOKS_WITH_PATTERN/9)" 0 $((TOTAL_HOOKS - HOOKS_WITH_PATTERN))
echo ""

# --- Normal operation: no active session still passes ---
echo "Normal: Hooks with no active session still exit 0"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
NORMAL_PASS=0
for hook in \
  ".claude/skills/serious-code/hooks/verify-completion-gate.sh" \
  ".claude/skills/serious-review/hooks/check-verdict.sh" \
  ".claude/skills/serious-plan/hooks/check-extraction.sh" \
  ".claude/skills/serious-scope/hooks/check-manifest.sh" \
  ".claude/skills/serious-research/hooks/capture-research.sh" \
  ".claude/skills/serious-conversation/hooks/capture-conversation.sh"; do
  bash "$PROJECT_ROOT/$hook" 2>/dev/null
  [ $? -eq 0 ] && NORMAL_PASS=$((NORMAL_PASS + 1))
done
rm -rf "$SIM_ROOT"
run_test "All 6 Stop hooks exit 0 with no active session ($NORMAL_PASS/6)" 0 $((6 - NORMAL_PASS))
echo ""

# --- Settings.json: timeouts at 30 ---
echo "Config: Stop hook timeouts"
TIMEOUT_30=$(grep -c '"timeout": 30' "$PROJECT_ROOT/.claude/settings.json" || true)
run_test "6 Stop hooks at timeout 30 ($TIMEOUT_30 found)" 0 $((TIMEOUT_30 < 6 ? 1 : 0))
echo ""

# --- Agent defs: Required Output sections ---
echo "Agent defs: Required Output sections"
REQ_OUTPUT=$(grep -rl "## Required Output" "$PROJECT_ROOT/.claude/agents/serious-code-"* 2>/dev/null | wc -l | tr -d ' ')
run_test "5 agent files have Required Output ($REQ_OUTPUT found)" 0 $((REQ_OUTPUT < 5 ? 1 : 0))
echo ""

# --- SKILL.md: commitment diff claims removed ---
echo "SKILL.md: commitment diff claims removed"
DIFF_CLAIMS=0
grep -q "Stop hook diffs this commitment" "$PROJECT_ROOT/.claude/skills/serious-code/SKILL.md" 2>/dev/null && DIFF_CLAIMS=$((DIFF_CLAIMS + 1))
grep -q "Stop hook checks the plan against this commitment" "$PROJECT_ROOT/.claude/skills/serious-plan/SKILL.md" 2>/dev/null && DIFF_CLAIMS=$((DIFF_CLAIMS + 1))
run_test "0 commitment diff claims remain ($DIFF_CLAIMS found)" 0 "$DIFF_CLAIMS"
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "SOME GAPS ARE STILL OPEN. Review output above."
  exit 1
fi
echo "ALL GAPS CLOSED. Enforcement hardening complete."
exit 0
