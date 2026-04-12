#!/bin/bash
# lint-no-glob-path-rejection.sh — Lint check for the old glob-pattern path rejection
#
# Usage:
#   bash bin/lint-no-glob-path-rejection.sh            # scan all hook files
#   bash bin/lint-no-glob-path-rejection.sh <file>...   # scan specific files
#
# Detects the insecure pattern:
#   case "$BREADCRUMB_CONTENT" in /* | *..* )
#
# This pattern was the original path-traversal check that was replaced by
# resolve_breadcrumb_path in path-resolve.sh. Any reintroduction of this
# pattern in a hook is a regression.
#
# Exit codes:
#   0 — no violations found
#   1 — violations found (printed to stdout)
#
# This script is read-only — it never modifies files.

VIOLATIONS=0

# The old insecure pattern spans two lines:
#   case "$BREADCRUMB_CONTENT" in     (line 1)
#     /* | *..* )                      (line 2)
#
# We detect EITHER indicator in non-comment lines:
#   PATTERN_A: the glob-rejection line itself: /* | *..* )
#   PATTERN_B: the single-line variant: case...BREADCRUMB.../\*...*\.\.\*
#
# Both patterns skip lines that are bash comments (start with #).
PATTERN_A='/\*[[:space:]]*\|[[:space:]]*\*\.\.\*'
PATTERN_B='case.*BREADCRUMB.*/\*.*\*\.\.\*'

scan_file() {
  local file="$1"
  # Skip the helper and this lint script (they reference the pattern
  # in documentation/comments)
  local basename_f
  basename_f=$(basename "$file")
  if [ "$basename_f" = "path-resolve.sh" ] || [ "$basename_f" = "lint-no-glob-path-rejection.sh" ]; then
    return 0
  fi

  local matches
  # Check for both patterns, exclude comment lines
  matches=$(grep -nE "$PATTERN_A|$PATTERN_B" "$file" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#')
  if [ -n "$matches" ]; then
    while IFS= read -r line; do
      echo "VIOLATION: $file:$line"
      VIOLATIONS=$((VIOLATIONS + 1))
    done <<< "$matches"
  fi
}

if [ $# -gt 0 ]; then
  # Scan specific files
  for f in "$@"; do
    if [ -f "$f" ]; then
      scan_file "$f"
    fi
  done
else
  # Scan all hook files under .claude/skills/
  while IFS= read -r f; do
    scan_file "$f"
  done < <(find .claude/skills -name '*.sh' -path '*/hooks/*' 2>/dev/null)
fi

if [ "$VIOLATIONS" -gt 0 ]; then
  echo ""
  echo "Found $VIOLATIONS violation(s). Replace the glob-pattern path check"
  echo "with resolve_breadcrumb_path from .claude/skills/_shared/path-resolve.sh"
  exit 1
fi

exit 0
