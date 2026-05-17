#!/bin/bash
# test_skill_slop_coverage.sh — Task 2 RED test for inline-rewrite coverage.
#
# Procedural metric: every change to address a thread-1 entry leaves an inline
# marker. The test counts markers per skill and asserts ≥50% of baseline.
#
# Allowed markers (matched case-sensitive):
#   <!-- voice-retrofit: rewritten; thread-1 line: N -->
#   <!-- voice-retrofit: deferred — reason: <R>; thread-1 line: N -->
#       where <R> is one of: phase-4-polish | out-of-scope-for-MVP | covered-by-translator | not-user-facing
#
# The em-dash in "reason: <R>" can be either `—` (U+2014) or `--`.
#
# Baseline counts come from fixtures/slop_baseline.tsv (one row per skill).
#
# Usage:
#   bash tests/voice/test_skill_slop_coverage.sh             # all skills
#   bash tests/voice/test_skill_slop_coverage.sh serious-X   # one skill

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASELINE_TSV="$SCRIPT_DIR/fixtures/slop_baseline.tsv"

ALLOWED_REASONS_REGEX='phase-4-polish|out-of-scope-for-MVP|covered-by-translator|not-user-facing'

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

count_matches() {
  local file="$1"; local pattern="$2"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    grep -cE "$pattern" "$file" 2>/dev/null
  else
    echo 0
  fi
}

check_skill() {
  local skill="$1"
  local skill_file="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    assert "$skill: SKILL.md exists" "fail" "missing $skill_file"
    return
  fi

  local baseline
  baseline=$(awk -F'\t' -v s="$skill" '$1==s {print $2}' "$BASELINE_TSV")
  if [ -z "$baseline" ]; then
    assert "$skill: has baseline entry in slop_baseline.tsv" "fail"
    return
  fi
  local min_count=$(( (baseline + 1) / 2 ))   # ceil(baseline / 2)

  local rewritten
  rewritten=$(count_matches "$skill_file" 'voice-retrofit: rewritten; thread-1 line: [0-9]+')
  rewritten=$((rewritten + 0))

  local deferred
  deferred=$(count_matches "$skill_file" "voice-retrofit: deferred [—-]+ reason: ($ALLOWED_REASONS_REGEX); thread-1 line: [0-9]+")
  deferred=$((deferred + 0))

  local all_deferred
  all_deferred=$(count_matches "$skill_file" 'voice-retrofit: deferred')
  all_deferred=$((all_deferred + 0))
  local bad_deferred=$((all_deferred - deferred))
  if [ "$bad_deferred" -gt 0 ]; then
    assert "$skill: all deferred markers use allowed reasons + thread-1 line" "fail" "$bad_deferred malformed"
  fi

  # AC1 strict reading: ≥50% REWRITTEN (not just deferred).
  # Deferrals are allowed for the rest, but they DO NOT count toward the 50% threshold.
  echo "  $skill: baseline=$baseline rewritten=$rewritten deferred=$deferred (min rewrites: $min_count)"

  if [ "$rewritten" -ge "$min_count" ]; then
    assert "$skill: ≥50% REWRITTEN (${rewritten}/${baseline})" "pass"
  else
    assert "$skill: ≥50% REWRITTEN" "fail" "rewritten=${rewritten}/${baseline} < ${min_count} (deferred=${deferred} does not count)"
  fi

  # Separate budget check: rewritten + deferred should cover the full baseline (every item has a disposition).
  local total_addressed=$((rewritten + deferred))
  if [ "$total_addressed" -lt "$baseline" ]; then
    assert "$skill: every thread-1 item has a disposition" "fail" "rewritten+deferred=${total_addressed} < baseline ${baseline}"
  fi
}

echo "=== Task 2 slop-coverage per-skill check ==="
if [ "$#" -gt 0 ]; then
  for skill in "$@"; do
    check_skill "$skill"
  done
else
  while IFS=$'\t' read -r s _ _; do
    [ -z "$s" ] && continue
    case "$s" in '#'*) continue ;; esac
    check_skill "$s"
  done < "$BASELINE_TSV"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
