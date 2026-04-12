#!/bin/bash
# path-resolve.sh — Shared path-resolution helper for Claude Code Stop hooks
#
# Usage: source this file to get the resolve_breadcrumb_path function.
#   source "$(dirname "$0")/../../_shared/path-resolve.sh"
#   PLAN_DIR=$(resolve_breadcrumb_path "${PROJECT_ROOT}/.active-code" "$PROJECT_ROOT") || exit 0
#   [ -L "$PLAN_DIR" ] && exit 0   # TOCTOU re-check (see below)
#   cat "$PLAN_DIR/some-file"
#
# This file is source-safe: sourcing it defines the function but does NOT
# execute anything. No top-level commands, no side effects, no env exports.
#
# IMPORTANT: This file does NOT use set -e, set -u, or set -o pipefail.
# As a shared utility sourced by multiple hooks, it must not alter the
# caller's shell options. Each caller manages its own error handling.
#
# ## Sync-Pair Documentation
#
# The following 6 Stop hooks consume resolve_breadcrumb_path (all updated
# in a single sync-pair commit — update all or none):
#
#   1. .claude/skills/serious-code/hooks/verify-completion-gate.sh
#   2. .claude/skills/serious-plan/hooks/check-extraction.sh
#   3. .claude/skills/serious-review/hooks/check-verdict.sh
#   4. .claude/skills/serious-research/hooks/capture-research.sh
#   5. .claude/skills/serious-conversation/hooks/capture-conversation.sh
#   6. .claude/skills/serious-scope/hooks/check-manifest.sh
#
# The following 3 PreToolUse hooks share the breadcrumb-read topology but
# DO NOT currently read breadcrumb contents (they only check existence).
# If you ever add content-reading logic to these, you MUST use
# resolve_breadcrumb_path:
#
#   - .claude/skills/serious-code/hooks/tdd-gate.sh
#   - .claude/skills/serious-plan/hooks/hedge-language-gate.sh
#   - .claude/skills/serious-review/hooks/review-theater-gate.sh
#
# The following 6 serious-debug stub hooks will need this helper when
# Plan 2 of /serious-debug fills in their real logic:
#
#   - stop-plan-escalation.sh
#   - stop-require-report.sh
#   - block-edit-during-investigate.sh
#   - session-start.sh
#   - reproducer-gate.sh
#   - stop-corpus-append.sh
#
# ## TOCTOU — Residual Risk & Caller Contract
#
# This function canonicalizes at call time, but the filesystem can change
# between the resolve and the caller's subsequent open/read. This is the
# classic time-of-check/time-of-use (TOCTOU) race.
#
# Callers MUST re-validate that the resolved path is not a symlink at use
# time before reading the target:
#
#   canon=$(resolve_breadcrumb_path "$bc_file" "$root") || exit 0
#   [ -L "$canon" ] && exit 0   # re-validate: reject if now a symlink
#   cat "$canon"
#
# The residual race window is narrowed (canonical resolve + re-check) but
# NOT closed in pure bash 3.2. Closing the race completely would require
# FD-based operations (open + fstat) or a compiled helper, both of which
# are out of scope for this project.
#
# The re-check catches the common case where an attacker replaces a
# legitimate directory with a symlink between the resolve and the open.
# It does NOT catch an attacker who swaps a directory's contents without
# changing its type (still a directory, but now points elsewhere via
# bind mount or similar). That attack requires root and is outside this
# threat model.

# resolve_breadcrumb_path — Read a breadcrumb file and return a canonical,
# project-root-contained path.
#
# Arguments:
#   $1 — absolute path to the breadcrumb file (e.g., "$PROJECT_ROOT/.active-code")
#   $2 — absolute canonical project root (e.g., the result of realpath "$CLAUDE_PROJECT_DIR")
#
# Outputs:
#   stdout — the canonical absolute path of the breadcrumb target (no trailing slash)
#            ONLY when all checks pass.
#   stderr — a warning when rejection occurs (non-fatal to the caller).
#
# Exit codes:
#   0 — success; canonical path printed to stdout
#   1 — rejected; nothing printed to stdout, warning on stderr
#
# Security guarantees:
#   1. Inside project root — returned path is always inside $project_root
#      (prefix-checked with trailing slash to defeat sibling-prefix attacks)
#   2. Absolute rejection — absolute paths in the breadcrumb are rejected
#   3. Symlink rejection — symlinks are resolved; escapes are rejected
#   4. Empty rejection — empty breadcrumbs are rejected
#   5. Dotdot rejection — paths with '..' that resolve outside root are rejected
#   6. Control-char rejection — breadcrumbs with control characters are rejected
#   7. Unicode-slash rejection — Unicode slash lookalikes are rejected by
#      realpath (which only understands ASCII '/'); they become part of a
#      single component name and the lookup fails
resolve_breadcrumb_path() {
  local breadcrumb_file="$1"
  local project_root="$2"

  # --- 1. Validate arguments ---
  if [ -z "$breadcrumb_file" ] || [ -z "$project_root" ]; then
    echo "resolve_breadcrumb_path: missing arguments" >&2
    return 1
  fi

  if [ ! -f "$breadcrumb_file" ]; then
    # Not an error — caller already checked; return silently
    return 1
  fi

  if [ ! -d "$project_root" ]; then
    echo "resolve_breadcrumb_path: project_root is not a directory: $project_root" >&2
    return 1
  fi

  # --- 2. Read breadcrumb, strip ALL whitespace including Unicode via LC_ALL=C ---
  # LC_ALL=C forces byte-mode tr so no multibyte whitespace (U+00A0, etc.)
  # gets preserved. The [:space:] class in C locale = ASCII whitespace only.
  local raw
  raw=$(LC_ALL=C tr -d '[:space:]' < "$breadcrumb_file")

  # --- 3. Reject empty ---
  if [ -z "$raw" ]; then
    echo "resolve_breadcrumb_path: breadcrumb is empty: $breadcrumb_file" >&2
    return 1
  fi

  # --- 4. Reject control characters that tr didn't strip (belt & braces) ---
  # Specifically: null byte (\x00) though bash strings truncate on \x00 anyway,
  # plus \x01-\x08, \x0b, \x0c, \x0e, \x0f, \x7f.
  case "$raw" in
    *$'\x00'*|*$'\x01'*|*$'\x02'*|*$'\x03'*|*$'\x04'*|*$'\x05'*|*$'\x06'*|*$'\x07'*|*$'\x08'*|*$'\x0b'*|*$'\x0c'*|*$'\x0e'*|*$'\x0f'*|*$'\x7f'*)
      echo "resolve_breadcrumb_path: breadcrumb contains control character: $breadcrumb_file" >&2
      return 1
      ;;
  esac

  # --- 5. Reject absolute-path input ---
  # A breadcrumb is always a RELATIVE path from project root. An absolute
  # path in the breadcrumb is always an attack (or a bug).
  case "$raw" in
    /*)
      echo "resolve_breadcrumb_path: breadcrumb is absolute, rejected: $raw" >&2
      return 1
      ;;
  esac

  # --- 6. Canonicalize the project root itself ---
  # Caller may pass a non-canonical path (e.g., containing symlinks). We
  # canonicalize both sides so the prefix check is an apples-to-apples
  # comparison.
  local canon_root
  if command -v /bin/realpath >/dev/null 2>&1; then
    canon_root=$(/bin/realpath "$project_root" 2>/dev/null) || {
      echo "resolve_breadcrumb_path: cannot canonicalize project_root: $project_root" >&2
      return 1
    }
  else
    canon_root=$(cd "$project_root" 2>/dev/null && pwd -P) || {
      echo "resolve_breadcrumb_path: cannot canonicalize project_root: $project_root" >&2
      return 1
    }
  fi

  # --- 7. Canonicalize the target path ---
  # Join root + raw, resolve, check prefix.
  local target="${canon_root}/${raw}"
  local canon_target
  if command -v /bin/realpath >/dev/null 2>&1; then
    canon_target=$(/bin/realpath "$target" 2>/dev/null) || {
      echo "resolve_breadcrumb_path: target does not exist or cannot be resolved: $raw" >&2
      return 1
    }
  else
    # Pure-shell fallback. cd into target and use pwd -P.
    canon_target=$(cd "$target" 2>/dev/null && pwd -P) || {
      echo "resolve_breadcrumb_path: target does not exist or cannot be resolved: $raw" >&2
      return 1
    }
  fi

  # --- 8. Prefix check (WITH trailing slash) ---
  # The trailing slash is CRITICAL. Without it, /foo-evil would match
  # the prefix /foo. With it, we compare /foo-evil/ against /foo/
  # and the match correctly fails.
  case "${canon_target}/" in
    "${canon_root}/"*)
      # Inside the project root — safe.
      printf '%s\n' "$canon_target"
      return 0
      ;;
    *)
      echo "resolve_breadcrumb_path: target escapes project root: $canon_target (root=$canon_root)" >&2
      return 1
      ;;
  esac
}
