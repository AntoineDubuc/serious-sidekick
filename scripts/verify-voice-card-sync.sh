#!/bin/bash
# verify-voice-card-sync.sh — Lint that the canonical voice block is byte-identical
# across all 24 surfaces.
#
# 24 surfaces:
#   1 canonical card:     .claude/skills/_shared/voice-card.md
#   1 Output Style:       .claude/output-styles/PM-voice.md
#   14 SKILL.md:          .claude/skills/serious-{14 names}/SKILL.md
#   8 agent files:        .claude/agents/{8 names}.md
#
# The canonical block is the text between the markers:
#   <!-- BEGIN CANONICAL VOICE BLOCK -->
#   <!-- END CANONICAL VOICE BLOCK -->
# Every surface must contain that exact byte sequence.
#
# Exit codes:
#   0 — all 24 surfaces match
#   1 — drift detected on one or more surfaces
#   2 — file list corrupted (e.g., symlink escape, missing file)
#
# Source: implementation_plan.md Task 1 AC3, AC11, AC13.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Hardcoded allowlist — 25 entries. NOT a glob.
# Task 3 added the 25th surface (voice-translator agent).
SURFACES=(
  ".claude/skills/_shared/voice-card.md"
  ".claude/output-styles/PM-voice.md"
  ".claude/skills/serious-abandon/SKILL.md"
  ".claude/skills/serious-bananas/SKILL.md"
  ".claude/skills/serious-code/SKILL.md"
  ".claude/skills/serious-conversation/SKILL.md"
  ".claude/skills/serious-debug/SKILL.md"
  ".claude/skills/serious-init/SKILL.md"
  ".claude/skills/serious-mock-ups/SKILL.md"
  ".claude/skills/serious-plan/SKILL.md"
  ".claude/skills/serious-prospect-research/SKILL.md"
  ".claude/skills/serious-research/SKILL.md"
  ".claude/skills/serious-review/SKILL.md"
  ".claude/skills/serious-scope/SKILL.md"
  ".claude/skills/serious-status/SKILL.md"
  ".claude/skills/serious-youtube-tldr/SKILL.md"
  ".claude/agents/serious-code-implementer.md"
  ".claude/agents/serious-code-qa.md"
  ".claude/agents/serious-code-reviewer.md"
  ".claude/agents/serious-code-runtime-checker.md"
  ".claude/agents/serious-code-test-runner.md"
  ".claude/agents/serious-review-anti-slop.md"
  ".claude/agents/serious-review-security.md"
  ".claude/agents/serious-review-structural.md"
  ".claude/agents/voice-translator.md"
)

EXPECTED_COUNT=25
if [ "${#SURFACES[@]}" != "$EXPECTED_COUNT" ]; then
  echo "ERROR: hardcoded surface list count is ${#SURFACES[@]}, expected $EXPECTED_COUNT" >&2
  exit 2
fi

BEGIN_MARKER='<!-- BEGIN CANONICAL VOICE BLOCK'
END_MARKER='<!-- END CANONICAL VOICE BLOCK -->'

# Extract the canonical block from the source-of-truth file (voice-card.md).
CANONICAL_FILE="$PROJECT_ROOT/.claude/skills/_shared/voice-card.md"
if [ ! -f "$CANONICAL_FILE" ]; then
  echo "ERROR: canonical card missing at $CANONICAL_FILE" >&2
  exit 2
fi

extract_block() {
  local file="$1"
  # Print lines strictly between BEGIN_MARKER and END_MARKER (exclusive of markers).
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    index($0, end) { p=0 }
    p { print }
    index($0, begin) { p=1 }
  ' "$file"
}

CANONICAL_BLOCK="$(extract_block "$CANONICAL_FILE")"
if [ -z "$CANONICAL_BLOCK" ]; then
  echo "ERROR: could not extract canonical block from $CANONICAL_FILE" >&2
  exit 2
fi

# Resolve project_root canonically once
CANON_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"
ALLOWED_ROOT="$CANON_ROOT/.claude"

DRIFT=0
CHECKED=0
DRIFT_FILES=()
MISSING_FILES=()
OUTSIDE_FILES=()

for rel in "${SURFACES[@]}"; do
  abs="$PROJECT_ROOT/$rel"
  if [ ! -f "$abs" ]; then
    MISSING_FILES+=("$rel")
    continue
  fi

  # Canonicalize and verify it resolves inside .claude/
  canon="$(cd "$(dirname "$abs")" 2>/dev/null && pwd -P)/$(basename "$abs")"
  case "$canon" in
    "$ALLOWED_ROOT"/*) : ;;
    *)
      OUTSIDE_FILES+=("$rel -> $canon")
      continue
      ;;
  esac

  # Reject symlinks outright (defense-in-depth — even if symlink target resolves
  # inside .claude/, a symlinked surface is a signal of tampering).
  if [ -L "$abs" ]; then
    OUTSIDE_FILES+=("$rel (symlink)")
    continue
  fi

  block="$(extract_block "$canon")"
  if [ "$block" = "$CANONICAL_BLOCK" ]; then
    echo "Checked: $rel — OK"
    CHECKED=$((CHECKED+1))
  else
    echo "Checked: $rel — DRIFT"
    DRIFT_FILES+=("$rel")
    DRIFT=$((DRIFT+1))
  fi
done

echo ""
echo "Surfaces: $EXPECTED_COUNT"
echo "OK:       $CHECKED"
echo "Drift:    $DRIFT"
echo "Missing:  ${#MISSING_FILES[@]}"
echo "Outside:  ${#OUTSIDE_FILES[@]}"

if [ "${#MISSING_FILES[@]}" -gt 0 ]; then
  echo "" >&2
  echo "ERROR: missing surface files:" >&2
  for f in "${MISSING_FILES[@]}"; do echo "  - $f" >&2; done
fi

if [ "${#OUTSIDE_FILES[@]}" -gt 0 ]; then
  echo "" >&2
  echo "ERROR: surface files outside .claude/ or symlink escape:" >&2
  for f in "${OUTSIDE_FILES[@]}"; do echo "  - $f" >&2; done
  exit 2
fi

if [ "${#MISSING_FILES[@]}" -gt 0 ]; then
  exit 2
fi

if [ "$DRIFT" -gt 0 ]; then
  echo "" >&2
  echo "Drift detected on the following surfaces (block does not match canonical):" >&2
  for f in "${DRIFT_FILES[@]}"; do echo "  - $f" >&2; done
  exit 1
fi

exit 0
