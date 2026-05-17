#!/bin/bash
# falsification_gate.sh — Task 6 kill-switch.
#
# Replays the 5 historical slop examples from evidence/falsification-baseline.md
# against the retrofitted system (the voice-gate.sh validator hook).
#
# Per-example verdict (assigned via voice-gate response + AC1 enumeration):
#   PASS                            — voice-gate fires on the verbatim slop (safety net caught it)
#   STILL_FAIL_regex_miss           — voice-gate misses; example expected this (validator regex
#                                     can't catch paraphrased plan-position references per F7)
#   STILL_FAIL_translator_unavailable — touchpoint relies on translator; translator unavailable
#                                       from a shell test (out-of-band live invocation needed)
#   STILL_FAIL_unacceptable          — voice-gate misses AND the example wasn't expected to miss
#                                      (retrofit has a real gap; cannot be overridden)
#
# Threshold: ≥4 of 5 must be PASS or one of the enumerated STILL_FAIL_acceptable variants.
# STILL_FAIL_unacceptable does NOT count toward the threshold.
#
# Source: implementation_plan.md Task 6 AC1-3.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/_shared/voice-gate.sh"
BASELINE="$PROJECT_ROOT/Research/features/skill-voice-retrofit/evidence/falsification-baseline.md"
EVIDENCE_DIR="$PROJECT_ROOT/Research/features/skill-voice-retrofit/evidence"
FINAL="$EVIDENCE_DIR/falsification-final.md"

ACCEPTABLE_REGEX='^(PASS|STILL_FAIL_regex_miss|STILL_FAIL_translator_unavailable)$'

if [ ! -f "$BASELINE" ]; then
  echo "ERROR: baseline file missing at $BASELINE" >&2
  exit 2
fi
if [ ! -x "$HOOK" ]; then
  echo "ERROR: voice-gate.sh missing or not executable at $HOOK" >&2
  exit 2
fi

# Extract each example's verbatim text + expected verdict.
# Python parser — more robust than awk for this structured markdown.
python3 - <<'PYEOF' > /tmp/falsification-examples.tsv
import re, sys

with open('Research/features/skill-voice-retrofit/evidence/falsification-baseline.md') as f:
    text = f.read()

# Each example starts with "## Example N:" and contains:
#   **Skill:** ... | **Touchpoint:** ... | **Verbatim text:** \n> "..." [multi-line] | **Voice-rule violation:** ... | **Expected verdict after retrofit:** ...
examples = re.split(r'^## Example (\d+):', text, flags=re.MULTILINE)
# Split yields: [preamble, 'N', body, 'N', body, ...]
for i in range(1, len(examples), 2):
    n = examples[i]
    body = examples[i+1]
    # Extract MULTI-LINE verbatim text: all `> ` lines after **Verbatim text:** until the
    # next bold marker (e.g. **Voice-rule violation:**).
    m_section = re.search(r'\*\*Verbatim text:\*\*\s*\n((?:>\s*[^\n]*\n)+)', body)
    if m_section:
        # Collapse the > lines into a single string with newlines preserved
        quoted_block = m_section.group(1)
        # Strip the leading `> ` from each line; preserve internal newlines
        lines = [re.sub(r'^>\s?', '', line) for line in quoted_block.split('\n') if line.strip().startswith('>')]
        verbatim = '\n'.join(lines).strip()
    else:
        verbatim = ''
    # Strip wrapping quotes from the first line if present (some examples are single-line)
    if verbatim.startswith('"') and verbatim.endswith('"') and '\n' not in verbatim:
        verbatim = verbatim[1:-1]
    m_verdict = re.search(r'\*\*Expected verdict after retrofit:\*\*\s*(PASS|STILL_FAIL_acceptable|STILL_FAIL_regex_miss|STILL_FAIL_translator_unavailable)', body)
    expected = m_verdict.group(1) if m_verdict else 'PASS'
    # Map STILL_FAIL_acceptable (legacy) to STILL_FAIL_regex_miss (current enumerated reason)
    if expected == 'STILL_FAIL_acceptable':
        expected = 'STILL_FAIL_regex_miss'
    # TSV: example_num \t expected_verdict \t verbatim
    # Replace tabs and newlines with literal markers so the bash while-read works
    verbatim_safe = verbatim.replace('\t', ' ').replace('\n', '\\n')
    print(f"{n}\t{expected}\t{verbatim_safe}")
PYEOF

mkdir -p "$EVIDENCE_DIR/replays"

PASS_COUNT=0
ACCEPTABLE_COUNT=0
UNACCEPTABLE_COUNT=0

# Initialize the final report
{
  echo "# Falsification Gate — Final Report"
  echo ""
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Threshold:** ≥4 of 5 must be PASS or one of the enumerated STILL_FAIL_* acceptable variants."
  echo ""
  echo "## Per-example verdicts"
  echo ""
} > "$FINAL"

while IFS=$'\t' read -r n expected verbatim; do
  [ -z "$n" ] && continue

  # Restore embedded newlines (the TSV uses \n as a literal marker for multi-line content)
  verbatim_real=$(printf '%b' "${verbatim//\\n/\\n}")

  # Pipe the verbatim slop through voice-gate.sh
  input_json=$(jq -n --arg t "$verbatim_real" '{hook_event_name:"Stop",message:{content:[{type:"text",text:$t}]}}')
  hook_stderr_file=$(mktemp)
  set +e
  echo "$input_json" | "$HOOK" >/dev/null 2>"$hook_stderr_file"
  hook_exit=$?
  set -e
  hook_stderr=$(cat "$hook_stderr_file")
  rm -f "$hook_stderr_file"

  # Decide verdict
  if [ "$hook_exit" = "2" ]; then
    verdict="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    # Hook didn't fire. Use the example's expected verdict if it's STILL_FAIL_*
    if [ "$expected" = "STILL_FAIL_regex_miss" ] || [ "$expected" = "STILL_FAIL_translator_unavailable" ]; then
      verdict="$expected"
      ACCEPTABLE_COUNT=$((ACCEPTABLE_COUNT + 1))
    else
      verdict="STILL_FAIL_unacceptable"
      UNACCEPTABLE_COUNT=$((UNACCEPTABLE_COUNT + 1))
    fi
  fi

  # Capture replay output
  replay_file="$EVIDENCE_DIR/replays/example-${n}.txt"
  {
    echo "Example $n"
    echo "Expected verdict: $expected"
    echo "Hook exit code: $hook_exit"
    echo "Final verdict: $verdict"
    echo "Verbatim input:"
    echo "  $verbatim"
    echo "Hook stderr:"
    echo "$hook_stderr" | sed 's/^/  /'
  } > "$replay_file"

  # Append to final report
  {
    echo "### Example $n"
    echo ""
    echo "- **Expected:** \`$expected\`"
    echo "- **Hook exit code:** $hook_exit"
    echo "- **Final verdict:** \`$verdict\`"
    echo "- **Verbatim input (first 200 chars):** \`${verbatim:0:200}\`"
    echo ""
  } >> "$FINAL"
done < /tmp/falsification-examples.tsv

ACCEPTABLE_TOTAL=$((PASS_COUNT + ACCEPTABLE_COUNT))
TOTAL=$((PASS_COUNT + ACCEPTABLE_COUNT + UNACCEPTABLE_COUNT))

{
  echo "## Summary"
  echo ""
  echo "- **Total examples:** $TOTAL"
  echo "- **PASS:** $PASS_COUNT"
  echo "- **STILL_FAIL_* acceptable:** $ACCEPTABLE_COUNT"
  echo "- **STILL_FAIL_unacceptable:** $UNACCEPTABLE_COUNT"
  echo "- **Acceptable threshold:** ≥4 of 5 ($ACCEPTABLE_TOTAL of $TOTAL achieved)"
  echo ""
  if [ "$ACCEPTABLE_TOTAL" -ge 4 ]; then
    echo "## Gate verdict: **PASS**"
    echo ""
    echo "Retrofit succeeded the falsification gate."
  else
    echo "## Gate verdict: **FAIL (BLOCKED)**"
    echo ""
    echo "Retrofit failed the falsification gate. <4 of 5 examples acceptable. Cannot proceed."
  fi
} >> "$FINAL"

echo "=== Falsification gate ==="
cat "$FINAL" | tail -15

# Replay-only mode: produce files, don't enforce threshold
if [ "${1:-}" = "--replay-only" ]; then
  exit 0
fi

# Enforcement
if [ "$ACCEPTABLE_TOTAL" -ge 4 ]; then
  exit 0
fi
exit 1
