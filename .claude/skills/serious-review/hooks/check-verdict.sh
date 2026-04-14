#!/bin/bash
# check-verdict.sh
# Stop hook for /serious-review: warns if an active review session
# has no review_verdict.md (review started but never reached a verdict).
#
# Exit codes:
#   0 = allow exit (no active session, or verdict exists)
#   2 = block exit (active session without verdict)

# Source shared guard utility (stdin is consumed and cached in _STOP_HOOK_GUARD_INPUT)
source "$(dirname "$0")/../../_shared/stop-hook-guard.sh" || exit 0
# Source the canonical path helper (shared by all Stop hooks that read breadcrumb contents)
source "$(dirname "$0")/../../_shared/path-resolve.sh" || exit 0
# Source observability helper (diagnostic only — not a security control).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/log-outcome.sh" 2>/dev/null || true
guard_stop_hook_active

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active review session? Allow exit.
if [ ! -f "${PROJECT_ROOT}/.active-review" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "no-active-review"
  exit 0
fi

if ! REVIEW_DIR=$(resolve_breadcrumb_path "${PROJECT_ROOT}/.active-review" "$PROJECT_ROOT"); then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "breadcrumb-unresolvable"
  exit 0
fi
if [ -L "$REVIEW_DIR" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "review-dir-is-symlink"
  exit 0
fi

# No review directory? Allow exit.
if [ ! -d "$REVIEW_DIR" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "review-dir-missing"
  exit 0
fi

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check for review_verdict.md
if [ ! -f "${REVIEW_DIR}/review_verdict.md" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "verdict-md-missing"
  emit_block_then_exit_2 "REVIEW VERDICT WARNING

Active review session at ${REVIEW_DIR} has no review_verdict.md.
The plan review started but never reached a verdict."
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
    type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "pass-without-refs"
    emit_block_then_exit_2 "REVIEW QUALITY WARNING

Review verdict at ${REVIEW_DIR}/review_verdict.md passed but contains
zero file:line references. A substantive review must cite specific
locations in the plan, not just generic approval."
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
    type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "missing-agent-sections"
    emit_block_then_exit_2 "AGENT DISPATCH WARNING

Review verdict at ${REVIEW_DIR}/review_verdict.md is missing reports from:
$(echo -e "$MISSING_AGENTS")
All 3 mandatory agents must produce reports before a verdict is accepted."
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ERROR "checks-not-reached"
  emit_block_then_exit_2 "ENFORCEMENT ERROR: check-verdict.sh did not complete all checks"
fi

type _log_outcome >/dev/null 2>&1 && _log_outcome PASS "verdict-substantive"
exit 0
