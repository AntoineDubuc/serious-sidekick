#!/bin/bash
# test_agent_voice_rule.sh — Task 1 RED test for sub-agent inline voice rule.
#
# Verifies AC1 of implementation_plan.md Task 1: all 8 .claude/agents/*.md files
# contain a `## Voice` section after frontmatter, before the first behavioral
# instruction. Content must include the four PM-voice structure rules.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"

EXPECTED_AGENTS=(
  serious-code-implementer.md
  serious-code-qa.md
  serious-code-reviewer.md
  serious-code-runtime-checker.md
  serious-code-test-runner.md
  serious-review-anti-slop.md
  serious-review-security.md
  serious-review-structural.md
)

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

echo "=== Task 1 sub-agent voice rule ==="

# AC1: every agent file has a ## Voice section
for f in "${EXPECTED_AGENTS[@]}"; do
  path="$AGENTS_DIR/$f"
  if [ ! -f "$path" ]; then
    assert "$f exists" "fail" "missing"
    continue
  fi
  if grep -q '^## Voice' "$path"; then
    assert "$f has ## Voice section" "pass"
  else
    assert "$f has ## Voice section" "fail"
    continue
  fi

  # Voice section must include the 4 structure rules
  for rule in "What this does" "What I need from you" "What you need to set up first" "Question"; do
    if grep -qF "$rule" "$path"; then
      assert "  $f references rule: $rule" "pass"
    else
      assert "  $f references rule: $rule" "fail"
    fi
  done

  # Voice section must appear AFTER frontmatter (after the second `---`)
  voice_line=$(grep -n '^## Voice' "$path" | head -1 | cut -d: -f1)
  fm_end_line=$(awk '/^---$/{c++; if(c==2){print NR; exit}}' "$path")
  if [ -n "$voice_line" ] && [ -n "$fm_end_line" ] && [ "$voice_line" -gt "$fm_end_line" ]; then
    assert "  $f: ## Voice appears after frontmatter" "pass"
  else
    assert "  $f: ## Voice appears after frontmatter" "fail" "voice=$voice_line fm_end=$fm_end_line"
  fi
done

# Negative test: grep -L returns 0 files missing the section
MISSING=$(grep -L '^## Voice' "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$MISSING" = "0" ]; then
  assert "no agent file is missing ## Voice section" "pass"
else
  assert "no agent file is missing ## Voice section" "fail" "$MISSING missing"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
