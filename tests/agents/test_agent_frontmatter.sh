#!/bin/bash
# test_agent_frontmatter.sh — Verify agent frontmatter fields
# Tests: frontmatter presence, disallowedTools, effort values per agent
set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"

run_test() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

check_field() {
  local file="$1" field="$2" expected="$3" agent="$(basename "$1" .md)"
  local val=$(head -20 "$file" | grep "^${field}:" | sed "s/${field}: *//" | tr -d '[:space:]')
  if [ "$val" = "$expected" ]; then
    run_test "$agent has $field: $expected" 0 0
  else
    run_test "$agent has $field: $expected (got '$val')" 0 1
  fi
}

check_no_field() {
  local file="$1" field="$2" agent="$(basename "$1" .md)"
  local count=$(head -20 "$file" | grep -c "^${field}:" || true)
  if [ "$count" -eq 0 ]; then
    run_test "$agent has NO $field field" 0 0
  else
    run_test "$agent has NO $field field (found $count)" 0 1
  fi
}

check_frontmatter() {
  local file="$1" agent="$(basename "$1" .md)"
  local line1=$(head -1 "$file")
  if [ "$line1" = "---" ]; then
    run_test "$agent has YAML frontmatter" 0 0
  else
    run_test "$agent has YAML frontmatter (line 1: '$line1')" 0 1
  fi
}

check_body_preserved() {
  local file="$1" expected_heading="$2" agent="$(basename "$1" .md)"
  if grep -q "^# $expected_heading" "$file"; then
    run_test "$agent body preserved (# $expected_heading found)" 0 0
  else
    run_test "$agent body preserved (# $expected_heading NOT found)" 0 1
  fi
}

echo "=== Agent Frontmatter Tests ==="
echo ""

# --- Frontmatter presence ---
echo "Frontmatter presence:"
for f in "$AGENTS_DIR"/serious-*.md; do
  check_frontmatter "$f"
done
echo ""

# --- disallowedTools ---
echo "disallowedTools field:"
check_no_field "$AGENTS_DIR/serious-code-implementer.md" "disallowedTools"
for agent in serious-code-reviewer serious-code-test-runner serious-code-runtime-checker serious-code-qa \
             serious-review-anti-slop serious-review-structural serious-review-security \
             serious-review-restraint serious-review-correctness; do
  check_field "$AGENTS_DIR/${agent}.md" "disallowedTools" "Edit,Write,NotebookEdit"
done
echo ""

# --- effort ---
echo "effort field:"
check_field "$AGENTS_DIR/serious-code-implementer.md" "effort" "high"
check_field "$AGENTS_DIR/serious-code-reviewer.md" "effort" "high"
check_field "$AGENTS_DIR/serious-code-test-runner.md" "effort" "low"
check_field "$AGENTS_DIR/serious-code-runtime-checker.md" "effort" "medium"
check_field "$AGENTS_DIR/serious-code-qa.md" "effort" "high"
check_field "$AGENTS_DIR/serious-review-anti-slop.md" "effort" "high"
check_field "$AGENTS_DIR/serious-review-structural.md" "effort" "high"
check_field "$AGENTS_DIR/serious-review-security.md" "effort" "high"
check_field "$AGENTS_DIR/serious-review-restraint.md" "effort" "high"
check_field "$AGENTS_DIR/serious-review-correctness.md" "effort" "high"
echo ""

# --- Body preservation ---
echo "Body preservation:"
check_body_preserved "$AGENTS_DIR/serious-code-implementer.md" "serious-code-implementer"
check_body_preserved "$AGENTS_DIR/serious-code-reviewer.md" "serious-code-reviewer"
check_body_preserved "$AGENTS_DIR/serious-code-test-runner.md" "serious-code-test-runner"
check_body_preserved "$AGENTS_DIR/serious-code-runtime-checker.md" "serious-code-runtime-checker"
check_body_preserved "$AGENTS_DIR/serious-code-qa.md" "serious-code-qa"
check_body_preserved "$AGENTS_DIR/serious-review-anti-slop.md" "serious-review-anti-slop"
check_body_preserved "$AGENTS_DIR/serious-review-structural.md" "serious-review-structural"
check_body_preserved "$AGENTS_DIR/serious-review-security.md" "serious-review-security"
echo ""

# --- Required Output (5 code agents only) ---
echo "Required Output sections (code agents only):"
for agent in serious-code-implementer serious-code-reviewer serious-code-test-runner serious-code-runtime-checker serious-code-qa; do
  count=$(grep -c '## Required Output' "$AGENTS_DIR/${agent}.md" || true)
  run_test "$agent has Required Output ($count)" 0 $((count < 1 ? 1 : 0))
done
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
