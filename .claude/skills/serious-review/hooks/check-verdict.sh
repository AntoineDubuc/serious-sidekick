#!/bin/bash
# check-verdict.sh
# Stop hook for /serious-review: warns if an active review session
# has no review_verdict.md (review started but never reached a verdict).
#
# Exit codes:
#   0 = allow exit (no active session, or verdict exists)
#   2 = block exit (active session without verdict)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active review session? Allow exit.
[ ! -f "${PROJECT_ROOT}/.active-review" ] && exit 0

BREADCRUMB_CONTENT=$(cat "${PROJECT_ROOT}/.active-review" | tr -d '[:space:]')
case "$BREADCRUMB_CONTENT" in
  /* | *..* )
    echo "WARNING: breadcrumb content rejected (path traversal or absolute path)" >&2
    exit 0 ;;
esac
REVIEW_DIR="${PROJECT_ROOT}/${BREADCRUMB_CONTENT}"

# No review directory? Allow exit.
[ ! -d "$REVIEW_DIR" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check for review_verdict.md
if [ ! -f "${REVIEW_DIR}/review_verdict.md" ]; then
  echo "REVIEW VERDICT WARNING" >&2
  echo "" >&2
  echo "Active review session at ${REVIEW_DIR} has no review_verdict.md." >&2
  echo "The plan review started but never reached a verdict." >&2
  echo "" >&2
  echo "To fix: complete /serious-review to produce a verdict, or" >&2
  echo "run /serious-abandon to abandon this review." >&2
  exit 2
fi

# --- Anti-rationalization strengthening (Layer 2) ---
# Check that the verdict contains specific references, not just generic approval
if [ -f "${REVIEW_DIR}/review_verdict.md" ]; then
  VERDICT_CONTENT=$(cat "${REVIEW_DIR}/review_verdict.md")
  # Check for review theater: verdict exists but has no file:line references
  HAS_REFS=$(echo "$VERDICT_CONTENT" | grep -cE '[a-zA-Z_/]+\.(ts|tsx|js|jsx|py|rb|go|rs|java|kt|c|cpp|cs|swift|md|sh|bash|yaml|yml|json|toml|css|scss|html|vue|svelte):[0-9]+|line [0-9]+|lines [0-9]+' || true)
  VERDICT_LINE=$(echo "$VERDICT_CONTENT" | grep -i 'verdict:' | head -1)
  # Only flag if verdict says PASS but has zero specific references
  if echo "$VERDICT_LINE" | grep -qiE '\bpass\b' && [ "$HAS_REFS" -eq 0 ]; then
    echo "REVIEW QUALITY WARNING" >&2
    echo "" >&2
    echo "Review verdict at ${REVIEW_DIR}/review_verdict.md passed but contains" >&2
    echo "zero file:line references. A substantive review must cite specific" >&2
    echo "locations in the plan, not just generic approval." >&2
    echo "" >&2
    echo "See Guardrail Block entry #1: 'Name at least one specific concern" >&2
    echo "with file path and line number.'" >&2
    exit 2
  fi
fi

# --- Agent dispatch validation (Layer 3) ---
# Verify all 3 mandatory review agents contributed to the verdict
# Section headers are a shared contract with the review agent definitions
if [ -f "${REVIEW_DIR}/review_verdict.md" ]; then
  MISSING_AGENTS=""
  ANTI_SLOP=$(grep -c '## Anti-Slop Audit Report' "${REVIEW_DIR}/review_verdict.md" || true)
  STRUCTURAL=$(grep -c '## Structural Review Report' "${REVIEW_DIR}/review_verdict.md" || true)
  SECURITY=$(grep -c '## Security Review Report' "${REVIEW_DIR}/review_verdict.md" || true)

  [ "$ANTI_SLOP" -eq 0 ] && MISSING_AGENTS="${MISSING_AGENTS}  - Anti-Slop Auditor\n"
  [ "$STRUCTURAL" -eq 0 ] && MISSING_AGENTS="${MISSING_AGENTS}  - Structural Reviewer\n"
  [ "$SECURITY" -eq 0 ] && MISSING_AGENTS="${MISSING_AGENTS}  - Security Mind\n"

  if [ -n "$MISSING_AGENTS" ]; then
    echo "AGENT DISPATCH WARNING" >&2
    echo "" >&2
    echo "Review verdict at ${REVIEW_DIR}/review_verdict.md is missing reports from:" >&2
    echo -e "$MISSING_AGENTS" >&2
    echo "All 3 mandatory agents must produce reports before a verdict is accepted." >&2
    exit 2
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: check-verdict.sh did not complete all checks" >&2
  exit 2
fi
exit 0
