#!/bin/bash
# tdd-gate.sh
# PreToolUse hook for /serious-code: blocks Write of implementation files
# when no corresponding test file exists yet.
#
# Only active during /serious-code sessions (checks .active-code breadcrumb).
# Checks if the file being written is an implementation file and whether
# a test file for it already exists on disk.
#
# Exit codes:
#   0 = allow (no active session, is a test file, or test exists)
#   2 = block (implementation file written without test)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active code session? Allow (not logged — PreToolUse fires too often to log inactive sessions).
[ ! -f "${PROJECT_ROOT}/.active-code" ] && exit 0

# Source observability helper (diagnostic only — not a security control).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/log-outcome.sh" 2>/dev/null || true

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Parse file path from tool input
FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

if [ -z "$FILE_PATH" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "no-file-path"
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Allow test files through unconditionally
if echo "$BASENAME" | grep -qiE '\.(test|spec)\.'; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ALLOW "test-file-ext"
  exit 0
fi
if echo "$BASENAME" | grep -qiE '^test_|_test\.'; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ALLOW "test-file-prefix"
  exit 0
fi
if echo "$FILE_PATH" | grep -qiE '__tests__/|/tests?/'; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ALLOW "tests-dir"
  exit 0
fi

# Allow non-code files (markdown, json, yaml, config, etc.)
if echo "$BASENAME" | grep -qiE '\.(md|json|yaml|yml|toml|txt|sh|css|html|svg|png|jpg)$'; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ALLOW "non-code-file"
  exit 0
fi

# Allow files in evidence/hooks/scripts directories
if echo "$FILE_PATH" | grep -qiE 'evidence/|/hooks/|/scripts/'; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ALLOW "infra-dir"
  exit 0
fi

# This is an implementation file — check for corresponding test
DIR=$(dirname "$FILE_PATH")
NAME_NO_EXT="${BASENAME%.*}"
EXT="${BASENAME##*.}"

# Search for test files matching common patterns
FOUND_TEST=0
for pattern in "${DIR}/${NAME_NO_EXT}.test.${EXT}" \
               "${DIR}/${NAME_NO_EXT}.spec.${EXT}" \
               "${DIR}/__tests__/${NAME_NO_EXT}.test.${EXT}" \
               "${DIR}/__tests__/${NAME_NO_EXT}.spec.${EXT}" \
               "${DIR}/test_${BASENAME}" \
               "${DIR}/tests/${BASENAME}"; do
  [ -f "$pattern" ] && FOUND_TEST=1 && break
done

if [ "$FOUND_TEST" = "0" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "no-test-for-impl"
  echo "TDD GATE: Write the test first." >&2
  echo "" >&2
  echo "You are writing: ${FILE_PATH}" >&2
  echo "No test file found matching: ${NAME_NO_EXT}.test.${EXT} or ${NAME_NO_EXT}.spec.${EXT}" >&2
  echo "" >&2
  echo "Red-green-refactor order is mandatory. Write the failing test FIRST," >&2
  echo "then write the implementation to make it pass." >&2
  exit 2
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ERROR "checks-not-reached"
  echo "ENFORCEMENT ERROR: tdd-gate.sh did not complete all checks" >&2
  exit 2
fi

type _log_outcome >/dev/null 2>&1 && _log_outcome PASS "test-exists"
exit 0
