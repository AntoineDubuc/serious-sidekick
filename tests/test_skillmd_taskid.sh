#!/bin/bash
# test_skillmd_taskid.sh — Verify SKILL.md contains TASK_ID tagging instructions
# and Dispatch Audit completion report section.
#
# These are grep-based content tests per the implementation plan Task 2.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
SKILLMD="$PROJECT_ROOT/.claude/skills/serious-code/SKILL.md"

PASS=0
FAIL=0
TOTAL=0

assert() {
  local description="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $description"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $description"
  fi
}

# --- AC1: Step 1 (implementer dispatch) contains TASK_ID instruction ---
# Step 1 is between "### Step 1: Implement" and "### Step 1.25"
step1_content=$(sed -n '/^### Step 1: Implement/,/^### Step 1\.25/p' "$SKILLMD")
if echo "$step1_content" | grep -q 'TASK_ID: task_{NN}'; then
  assert "AC1: Step 1 (implementer) contains TASK_ID: task_{NN} instruction" 0
else
  assert "AC1: Step 1 (implementer) contains TASK_ID: task_{NN} instruction" 1
fi

# --- AC2: Step 2 (verification agents) contains TASK_ID instruction ---
# Step 2 is between "### Step 2: Verify" and "### Step 2.5"
step2_content=$(sed -n '/^### Step 2: Verify/,/^### Step 2\.5/p' "$SKILLMD")
if echo "$step2_content" | grep -q 'TASK_ID: task_{NN}'; then
  assert "AC2: Step 2 (verification agents) contains TASK_ID: task_{NN} instruction" 0
else
  assert "AC2: Step 2 (verification agents) contains TASK_ID: task_{NN} instruction" 1
fi

# --- AC3: Step 2.5 (completion gate) contains TASK_ID instruction ---
# Step 2.5 is between "### Step 2.5" and "### Step 3"
step25_content=$(sed -n '/^### Step 2\.5/,/^### Step 3/p' "$SKILLMD")
if echo "$step25_content" | grep -q 'TASK_ID: task_{NN}'; then
  assert "AC3: Step 2.5 (completion gate) contains TASK_ID: task_{NN} instruction" 0
else
  assert "AC3: Step 2.5 (completion gate) contains TASK_ID: task_{NN} instruction" 1
fi

# --- AC4: Phase 2 completion report contains Dispatch Audit section ---
phase2_content=$(sed -n '/^## Phase 2: Completion/,/^## [A-Z]/p' "$SKILLMD")
if echo "$phase2_content" | grep -q 'Dispatch Audit'; then
  assert "AC4: Phase 2 completion report contains Dispatch Audit section" 0
else
  assert "AC4: Phase 2 completion report contains Dispatch Audit section" 1
fi

# --- AC5: Dispatch Audit section mentions dispatch_log.md ---
if echo "$phase2_content" | grep -q 'dispatch_log.md'; then
  assert "AC5: Dispatch Audit section references dispatch_log.md" 0
else
  assert "AC5: Dispatch Audit section references dispatch_log.md" 1
fi

# --- AC5b: Dispatch Audit section mentions per-task dispatch counts ---
if echo "$phase2_content" | grep -q 'dispatch count'; then
  assert "AC5b: Dispatch Audit section mentions per-task dispatch counts" 0
else
  assert "AC5b: Dispatch Audit section mentions per-task dispatch counts" 1
fi

# --- AC5c: Dispatch Audit warns on fewer than 5 distinct agent types ---
if echo "$phase2_content" | grep -q '5 distinct'; then
  assert "AC5c: Dispatch Audit warns on fewer than 5 distinct agent types" 0
else
  assert "AC5c: Dispatch Audit warns on fewer than 5 distinct agent types" 1
fi

# --- AC5d: Dispatch Audit section is advisory (warning, not blocking) ---
if echo "$phase2_content" | grep -qi 'advisory\|warning.*not.*block'; then
  assert "AC5d: Dispatch Audit section is advisory (not blocking)" 0
else
  assert "AC5d: Dispatch Audit section is advisory (not blocking)" 1
fi

# --- Negative: No new Stop hook logic or exit 2 paths added ---
dispatch_audit_section=$(sed -n '/### .*Dispatch Audit/,/^###\|^## /p' "$SKILLMD" 2>/dev/null || true)
if [ -n "$dispatch_audit_section" ]; then
  if echo "$dispatch_audit_section" | grep -q 'exit 2'; then
    assert "NEG1: Dispatch Audit section does NOT contain exit 2" 1
  else
    assert "NEG1: Dispatch Audit section does NOT contain exit 2" 0
  fi
  if echo "$dispatch_audit_section" | grep -qi 'stop hook'; then
    assert "NEG2: Dispatch Audit section does NOT reference Stop hook logic" 1
  else
    assert "NEG2: Dispatch Audit section does NOT reference Stop hook logic" 0
  fi
else
  # Section doesn't exist yet -- negative tests pass vacuously (nothing bad can be in nothing)
  assert "NEG1: Dispatch Audit section does NOT contain exit 2 (section absent)" 0
  assert "NEG2: Dispatch Audit section does NOT reference Stop hook logic (section absent)" 0
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
