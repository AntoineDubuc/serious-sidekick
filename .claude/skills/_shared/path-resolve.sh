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
  # Note: $'\x00' (null byte) is NOT included in the case pattern because
  # bash 3.2 expands it to an empty string, making *$'\x00'* equivalent to
  # ** which matches everything. Bash already truncates strings at null bytes
  # during read, so null injection is handled implicitly.
  # Checked: \x01-\x08, \x0b, \x0c, \x0e, \x0f, \x7f.
  case "$raw" in
    *$'\x01'*|*$'\x02'*|*$'\x03'*|*$'\x04'*|*$'\x05'*|*$'\x06'*|*$'\x07'*|*$'\x08'*|*$'\x0b'*|*$'\x0c'*|*$'\x0e'*|*$'\x0f'*|*$'\x7f'*)
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

# =============================================================================
# Per-session breadcrumb helpers (multi-terminal collision fix)
# =============================================================================
#
# These helpers implement the per-PID breadcrumb scheme:
#
#   $PROJECT_ROOT/.claude-active/{PID}-{skill}
#
# where {PID} is the result of claude_pid (the nearest ancestor process whose
# `comm` is exactly `claude`).
#
# ## Security framing — claude_pid() is NOT authentication
#
# claude_pid() is a best-effort heuristic for "which Claude Code session am I
# in." It is NOT a security control. A user can rename any process to `claude`
# (e.g., `cp /bin/cat ~/claude && exec ~/claude`) and claude_pid will trust it.
#
# The threat model for this plan is a single-user dev tool; we accept that.
# Future maintainers MUST NOT treat claude_pid as authentication of "this is
# the real Claude Code process."
#
# The substring-vs-equality and `comm`-vs-`argv` distinctions reduce
# trivial-mistake misidentification — they do not provide authenticated
# identity.
#
# ## Security boundary — breadcrumb_path() skill-name allow-list IS a control
#
# breadcrumb_path() validates skill names against ^[a-z][a-z0-9-]{0,31}$ before
# constructing any path. This guarantees the constructed path cannot escape
# .claude-active/ via traversal, contain shell metacharacters that downstream
# callers might unquote, or include control characters that corrupt log lines.
#
# ## Sweep contract — sweep is called from skill startups, NEVER from hooks
#
# breadcrumb_sweep() runs `kill -0` per file (~2.4ms each) and a glob walk
# (~1ms). At ~12ms total for 5 files, calling it from every hook would multiply
# 12ms × 30 tools = 360ms wasted per plan run. Sweep MUST run on every skill
# startup. Sweep MUST NOT run from hooks.
#
# ## TOCTOU and PID-reuse — sweep is race-narrowed, NOT race-closed
#
# Sweep has known residual race windows:
#
#   1. PID reuse during sweep: kill -0 99999 returns dead, then rm -f
#      .claude-active/99999-research. Between those two operations, the OS
#      could recycle PID 99999 to a new Claude Code process that creates a new
#      breadcrumb at the same path. Sweep then deletes a LIVE breadcrumb.
#      macOS PID space is 99,999 — recycle is slow but possible under stress.
#
#   2. `> file` open vs concurrent unlink: writer's
#      `printf '%s\n' "$path" > "$bc"` is open(O_WRONLY|O_CREAT|O_TRUNC) +
#      write + close. Sweep's `rm -f "$bc"` is unlink. If sweep's kill -0
#      happens during a transient ESRCH window of the writer's parent (e.g.,
#      during fork/zombie reaping), sweep deletes a directory entry that the
#      writer is about to populate.
#
# These are accepted in v1. They are NOT zero-risk; they are low-probability
# on macOS for a single-user dev tool, with zero observed instances in 21
# days of 5-concurrent-process operation.
#
# Future maintainers MUST NOT read this comment as claiming sweep is
# race-free — it is race-narrowed, not race-closed. A v2 fix would use flock
# on .claude-active/.lock for the sweep critical section + O_EXCL on writer
# create + procStart/lstart= PID-reuse guard.

# claude_pid — Walk $PPID upward until a process whose comm is exactly
# `claude` (case-sensitive, byte-mode comparison under LC_ALL=C) is found.
# Returns that PID on stdout.
#
# If no `claude` ancestor is found within 10 hops or before reaching pid=1,
# fall back to printing $PPID and emit a stderr warning.
#
# Arguments: none
#
# Outputs:
#   stdout — numeric PID
#   stderr — warning on fallback (no claude ancestor found)
#
# Exit codes:
#   0 — always (graceful fallback; never errors out)
#
# Implementation note: the comm match uses
#   case "$comm" in claude) ... ;; esac
# under LC_ALL=C — exact equality, NOT [[ "$comm" == *claude* ]] (substring),
# NOT grep -i (case-insensitive). This prevents `claude-helper` and
# `fakeclaude` from matching as `claude`.
claude_pid() {
  local pid="$PPID"
  local hops=0
  local max_hops=10
  local ppid comm line

  while [ "$hops" -lt "$max_hops" ]; do
    # Bail at pid=1 (init) — no point walking further.
    case "$pid" in
      ''|0|1)
        echo "claude_pid: no claude ancestor found (reached pid=$pid); falling back to PPID=$PPID" >&2
        printf '%s\n' "$PPID"
        return 0
        ;;
    esac

    # Read ppid and comm in one ps call. LC_ALL=C forces byte-mode so multibyte
    # chars in comm don't confuse the comparison.
    line=$(LC_ALL=C ps -p "$pid" -o ppid=,comm= 2>/dev/null)
    case "$line" in
      '')
        # ps failed (PID gone or invalid). Fall back.
        echo "claude_pid: ps lookup failed for pid=$pid; falling back to PPID=$PPID" >&2
        printf '%s\n' "$PPID"
        return 0
        ;;
    esac

    # Strip leading whitespace, then split on first whitespace into ppid + comm.
    # Use a portable trim via parameter expansion (avoid `read` since stdin may
    # be in use by the caller).
    line="${line#"${line%%[![:space:]]*}"}"  # ltrim
    ppid="${line%%[[:space:]]*}"
    comm="${line#*[[:space:]]}"
    # ltrim comm too (multiple spaces between fields).
    comm="${comm#"${comm%%[![:space:]]*}"}"

    # Exact-equality match on comm. Per the security framing: NOT substring.
    case "$comm" in
      claude)
        printf '%s\n' "$pid"
        return 0
        ;;
    esac

    pid="$ppid"
    hops=$((hops + 1))
  done

  # Walk-bound exhausted — fall back to PPID with warning.
  echo "claude_pid: walk-bound (${max_hops}) exhausted without finding claude ancestor; falling back to PPID=$PPID" >&2
  printf '%s\n' "$PPID"
  return 0
}

# breadcrumb_path — Compute the per-session breadcrumb path for a skill.
# Outputs $PROJECT_ROOT/.claude-active/{PID}-{skill_name} on stdout when
# skill_name passes the allow-list ^[a-z][a-z0-9-]{0,31}$.
#
# Arguments:
#   $1 — skill name (kebab-case, must match the allow-list)
#
# Outputs:
#   stdout — absolute path on success; nothing on rejection
#   stderr — warning on rejection
#
# Exit codes:
#   0 — success
#   1 — rejected (skill_name failed allow-list, or PROJECT_ROOT unset)
#
# Allow-list: first char must be [a-z]; subsequent chars must be [a-z0-9-];
# total length must be 1..32. Rejects: empty, leading dash/digit, uppercase,
# slashes, dotdot, shell metacharacters, whitespace, control chars, NUL,
# Unicode lookalikes, names >32 chars.
breadcrumb_path() {
  local skill="$1"

  # Reject empty.
  if [ -z "$skill" ]; then
    echo "breadcrumb_path: skill name is empty" >&2
    return 1
  fi

  # Length check first (cheap; defends against very long inputs reaching the
  # case patterns).
  if [ "${#skill}" -gt 32 ]; then
    echo "breadcrumb_path: skill name too long (${#skill} > 32 chars): $skill" >&2
    return 1
  fi

  # Allow-list via case (bash 3.2 compatible — no [[ ]] regex).
  # Step 1: first char must be [a-z].
  case "$skill" in
    [a-z]*) ;;
    *)
      echo "breadcrumb_path: skill name must start with lowercase letter: $skill" >&2
      return 1
      ;;
  esac

  # Step 2: every char must be in [a-z0-9-].
  # Inverse match: reject if any char is NOT in [a-z0-9-].
  case "$skill" in
    *[!a-z0-9-]*)
      echo "breadcrumb_path: skill name contains disallowed char (allow-list: [a-z][a-z0-9-]{0,31}): $skill" >&2
      return 1
      ;;
  esac

  # PROJECT_ROOT must be set. Fall back to CLAUDE_PROJECT_DIR — that is the env
  # var Claude Code itself sets in every session, and it is the only project-
  # root signal that SKILL.md prose-driven writers have access to. Without this
  # fallback the deployed writer block fails at runtime with "PROJECT_ROOT is
  # not set" because no SKILL.md exports PROJECT_ROOT before invoking us.
  local root="$PROJECT_ROOT"
  if [ -z "$root" ]; then
    root="$CLAUDE_PROJECT_DIR"
  fi
  if [ -z "$root" ]; then
    echo "breadcrumb_path: neither PROJECT_ROOT nor CLAUDE_PROJECT_DIR is set" >&2
    return 1
  fi

  local pid
  pid=$(claude_pid)
  printf '%s/.claude-active/%s-%s\n' "$root" "$pid" "$skill"
  return 0
}

# breadcrumb_sweep — Reap orphaned per-session breadcrumb files.
#
# Iterates $PROJECT_ROOT/.claude-active/*-* and removes files whose leading
# {pid} segment refers to a process that no longer exists.
#
# File-name parsing rules (a file is candidate-for-sweep ONLY if all hold):
#   - Filename matches *-* (contains at least one dash).
#   - Leading segment up to first dash is purely digits (PID candidate).
#   - Trailing segment after first dash is non-empty.
#   - Trailing segment matches ^[a-z][a-z0-9-]{0,31}$ (skill allow-list).
#
# Files that do not match are LEFT UNTOUCHED (never deleted) — sweep is
# defensive: anything we don't recognize, we don't touch.
#
# Arguments: none
#
# Outputs:
#   stderr — optional debug messages
#
# Exit codes:
#   0 — always (idempotent)
#
# Contract: this function MUST NOT be called from hooks (see file-level
# comment for cost rationale). It MUST run on every skill startup.
#
# Implementation note: this function uses bare shell (ls + kill -0 + rm -f)
# and does NOT call resolve_breadcrumb_path. Per research Finding 2, the
# sweep operates on filenames that we own (we wrote them at skill startup),
# not on opaque target paths.
breadcrumb_sweep() {
  # Same fallback as breadcrumb_path: real Claude Code sessions only set
  # CLAUDE_PROJECT_DIR. Sweep is idempotent — exit 0 if neither is set.
  local root="$PROJECT_ROOT"
  if [ -z "$root" ]; then
    root="$CLAUDE_PROJECT_DIR"
  fi
  if [ -z "$root" ]; then
    return 0
  fi

  local dir="$root/.claude-active"
  if [ ! -d "$dir" ]; then
    return 0
  fi

  local file name pid rest first_char
  # Use a glob; if no match, the literal pattern is returned (nullglob is not
  # set in source-safe code), so guard with -e.
  for file in "$dir"/*-*; do
    [ -e "$file" ] || continue
    [ -f "$file" ] || continue

    name="${file##*/}"

    # Skip hidden files (we don't own them).
    case "$name" in
      .*) continue ;;
    esac

    # Parse: leading digits up to first dash, then rest.
    pid="${name%%-*}"
    rest="${name#*-}"

    # Validate pid is purely digits and non-empty.
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac

    # Validate rest is non-empty.
    [ -n "$rest" ] || continue

    # Validate rest matches skill allow-list ^[a-z][a-z0-9-]{0,31}$.
    if [ "${#rest}" -gt 32 ]; then
      continue
    fi
    first_char="${rest:0:1}"
    case "$first_char" in
      [a-z]) ;;
      *) continue ;;
    esac
    case "$rest" in
      *[!a-z0-9-]*) continue ;;
    esac

    # All checks passed — pid is a valid candidate. Probe liveness.
    # kill -0 returns 0 if process exists; non-zero otherwise.
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$file"
    fi
  done

  return 0
}

# breadcrumb_list_all — Enumerate breadcrumb files for a given skill across
# all live sessions.
#
# Outputs each matching filename in $PROJECT_ROOT/.claude-active/*-{skill}
# on stdout, one per line. Used by /serious-status and parent
# auto-detection.
#
# Arguments:
#   $1 — skill name (must pass the allow-list; otherwise no-op)
#
# Outputs:
#   stdout — one filename per matching breadcrumb (or empty if no match)
#
# Exit codes:
#   0 — always
#
# Note: this function does NOT validate liveness of the PIDs (use
# breadcrumb_sweep first if a stale-free view is required).
breadcrumb_list_all() {
  local skill="$1"

  # Validate skill name via the same allow-list as breadcrumb_path. We open-
  # code it here rather than calling breadcrumb_path (which would also call
  # claude_pid and emit unrelated output).
  if [ -z "$skill" ]; then
    return 0
  fi
  if [ "${#skill}" -gt 32 ]; then
    return 0
  fi
  case "$skill" in
    [a-z]*) ;;
    *) return 0 ;;
  esac
  case "$skill" in
    *[!a-z0-9-]*) return 0 ;;
  esac

  # Same fallback as breadcrumb_path: real Claude Code sessions only set
  # CLAUDE_PROJECT_DIR. List is idempotent — return 0 with no output if
  # neither is set.
  local root="$PROJECT_ROOT"
  if [ -z "$root" ]; then
    root="$CLAUDE_PROJECT_DIR"
  fi
  if [ -z "$root" ]; then
    return 0
  fi

  local dir="$root/.claude-active"
  if [ ! -d "$dir" ]; then
    return 0
  fi

  local file
  for file in "$dir"/*-"$skill"; do
    [ -e "$file" ] || continue
    [ -f "$file" ] || continue
    printf '%s\n' "$file"
  done

  return 0
}

# _breadcrumb_migrate_canonicalize — Internal helper for breadcrumb_migrate.
#
# Resolves $1 to its canonical absolute path. Tries /bin/realpath first; if
# unavailable or it fails, falls back to a pure-shell `cd && pwd -P`. Returns
# non-zero (and prints nothing) if BOTH fail.
#
# Extracted as a separate function so tests can override it with a stub that
# unconditionally fails — letting us actually exercise the
# `MIGRATE: skip realpath-unavailable` code path in breadcrumb_migrate.
#
# Arguments:
#   $1 — path to canonicalize
#
# Outputs:
#   stdout — canonical path on success (no trailing newline beyond what the
#            underlying tool emits; callers strip via $(...) anyway).
#   stderr — silent (errors from realpath/cd are swallowed by 2>/dev/null).
#
# Exit codes:
#   0 — success, canonical path printed to stdout
#   1 — both methods failed (caller decides whether this is fail-safe-skip
#       or orphan-branch based on target existence)
_breadcrumb_migrate_canonicalize() {
  local _path="$1"
  local _canon=""
  if command -v /bin/realpath >/dev/null 2>&1; then
    _canon=$(/bin/realpath "$_path" 2>/dev/null)
  fi
  if [ -z "$_canon" ]; then
    _canon=$(cd "$_path" 2>/dev/null && pwd -P)
  fi
  if [ -z "$_canon" ]; then
    return 1
  fi
  printf '%s\n' "$_canon"
  return 0
}

# breadcrumb_migrate — Agreement-gated deletion of legacy `.active-{skill}`
# files at the project root.
#
# Iterates ${PROJECT_ROOT}/.active-* and conditionally deletes legacy entries
# according to FIVE gates (in order). EVERY entry runs every applicable gate;
# any failure SKIPS deletion of that entry and emits a `MIGRATE: skip ...`
# stderr line with the reason.
#
#   Gate 0 — Type check
#     Reject symlinks (never follow). Reject directories (rm -f, never -rf).
#     Reject non-regular files. Use -L before -d to detect symlinks first.
#
#   Gate 1 — Carve-out (in-flight parent preservation)
#     If basename equals `.active-conversation` (after trailing-newline strip),
#     log preserve and continue. Filename-only — content is never resolved,
#     never realpathed. The match is a literal-byte `case` pattern that is
#     locale-insensitive by construction (no metacharacters or character
#     classes), so no $LC_ALL wrapping is needed.
#
#   Gate 2 — Content validation
#     Reject empty (after whitespace strip), control chars, shell metacharacters,
#     `..`, leading `/`, and any content whose realpath escapes the project
#     root. Fail-safe: if BOTH /bin/realpath and the cd-fallback fail, treat
#     as escape and log `MIGRATE: skip realpath-unavailable`.
#
#   Gate 3a — Orphan branch
#     Validated content resolves to a non-existent folder AND basename
#     matches ^\.active-[a-z][a-z0-9-]{0,31}$ → `rm -f --`. Log
#     `MIGRATE: removed orphan`.
#
#   Gate 3b — Agreement branch
#     Validated content resolves to an existing folder AND
#     `.claude-active/{claude_pid}-{skill}` exists with byte-identical
#     (whitespace-stripped) content → `rm -f --`. Log
#     `MIGRATE: removed legacy ... (agreement check passed)`.
#     Else log `MIGRATE: skip no-agreement`.
#
# Style:
#   - Zero arguments. Carve-out is hard-coded.
#   - No set -e/u/o pipefail. Stderr-only warnings. Always returns 0.
#   - Log lines NEVER include the legacy file's content (security control
#     against log injection from malicious legacy contents).
#   - case patterns, not [[ ]] regex (bash 3.2 compatibility).
#   - rm -f -- (with --), never rm -rf.
#
# Arguments: none
#
# Outputs:
#   stderr — MIGRATE: ... lines for every action (delete OR skip)
#
# Exit codes:
#   0 — always (idempotent, safe to call repeatedly)
breadcrumb_migrate() {
  # Same fallback as breadcrumb_path: real Claude Code sessions only set
  # CLAUDE_PROJECT_DIR. Migrate is idempotent — exit 0 if neither is set.
  local root="$PROJECT_ROOT"
  if [ -z "$root" ]; then
    root="$CLAUDE_PROJECT_DIR"
  fi
  if [ -z "$root" ]; then
    return 0
  fi

  if [ ! -d "$root" ]; then
    return 0
  fi

  # Canonicalize the project root once. Used by Gate 2 escape check.
  # Delegates to _breadcrumb_migrate_canonicalize (extracted helper) so tests
  # can stub the canonicalizer to simulate /bin/realpath failure end-to-end.
  local canon_root
  canon_root=$(_breadcrumb_migrate_canonicalize "$root") || canon_root=""
  if [ -z "$canon_root" ]; then
    # Cannot canonicalize root — fail-safe, do nothing.
    return 0
  fi

  local entry name name_norm legacy_content target canon_target skill new_path new_content
  for entry in "$root"/.active-*; do
    # Glob may not match — guard.
    [ -e "$entry" ] || continue

    # === Gate 0 — Type check ===
    # Symlink first (-L), so that a directory-symlink isn't classified as -d.
    if [ -L "$entry" ]; then
      name="${entry##*/}"
      printf '%s\n' "MIGRATE: skip symlink $entry" >&2
      continue
    fi
    if [ -d "$entry" ]; then
      printf '%s\n' "MIGRATE: skip directory $entry" >&2
      continue
    fi
    if [ ! -f "$entry" ]; then
      printf '%s\n' "MIGRATE: skip non-regular $entry" >&2
      continue
    fi

    # === Gate 1 — Carve-out ===
    name="${entry##*/}"
    # Strip trailing newline injected via filesystem (defense against shells
    # that allow newline in filenames).
    name_norm="${name%$'\n'}"
    # The pattern `.active-conversation` is a literal byte sequence — no
    # metacharacters, no character classes, no locale-sensitive collation —
    # so bash's `case` matches byte-for-byte regardless of $LC_COLLATE /
    # $LC_ALL. No locale wrapping needed for correctness.
    case "$name_norm" in
      .active-conversation)
        printf '%s\n' "MIGRATE: preserve carve-out $entry" >&2
        continue
        ;;
    esac

    # === Gate 2 — Content validation ===
    # Read content with whitespace stripped. LC_ALL=C forces byte-mode.
    legacy_content=$(LC_ALL=C tr -d '[:space:]' < "$entry" 2>/dev/null)

    # Empty after strip → skip.
    if [ -z "$legacy_content" ]; then
      printf '%s\n' "MIGRATE: skip invalid content $entry (empty)" >&2
      continue
    fi

    # Control chars — same case pattern as resolve_breadcrumb_path:138-143.
    case "$legacy_content" in
      *$'\x01'*|*$'\x02'*|*$'\x03'*|*$'\x04'*|*$'\x05'*|*$'\x06'*|*$'\x07'*|*$'\x08'*|*$'\x0b'*|*$'\x0c'*|*$'\x0e'*|*$'\x0f'*|*$'\x7f'*)
        printf '%s\n' "MIGRATE: skip invalid content $entry (control-char)" >&2
        continue
        ;;
    esac

    # Shell metacharacters. Explicit case enumeration (NOT [[ ]] regex).
    # Each class is its own branch so the structure is auditable.
    case "$legacy_content" in
      *";"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"|"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *'`'*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"\$"*) printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"&"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"("*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *")"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"<"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *">"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"*"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"?"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"["*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
      *"]"*)  printf '%s\n' "MIGRATE: skip invalid content $entry (shell-meta)" >&2; continue ;;
    esac
    # Newline and tab are stripped by tr -d '[:space:]' above, so they cannot
    # reach this point. The strip is the canonical defense; we re-test for
    # belt-and-braces only on chars that survive whitespace-strip.

    # Traversal: '..' or leading '/'.
    case "$legacy_content" in
      /*)
        printf '%s\n' "MIGRATE: skip invalid content $entry (absolute-path)" >&2
        continue
        ;;
      *..*)
        printf '%s\n' "MIGRATE: skip invalid content $entry (traversal)" >&2
        continue
        ;;
    esac

    # Project-root prefix check (escape detection). Same logic as
    # resolve_breadcrumb_path:189-203 (prefix-with-trailing-slash).
    # Delegates to _breadcrumb_migrate_canonicalize so tests can stub it.
    target="${canon_root}/${legacy_content}"
    canon_target=$(_breadcrumb_migrate_canonicalize "$target") || canon_target=""

    if [ -z "$canon_target" ]; then
      # BOTH realpath and cd-fallback failed. Two reasons:
      #   (a) /bin/realpath unavailable AND target doesn't exist (BSD/GNU portability).
      #   (b) Target legitimately does not exist (orphan candidate path).
      # We cannot distinguish (a) from (b) reliably without a stub. Per the
      # research M4 review, fail-safe is to LEAVE the file in place and log
      # `MIGRATE: skip realpath-unavailable`. This is more conservative than
      # the orphan branch but defends against environments where realpath is
      # broken — a v2 fix could split (a) and (b) explicitly.
      #
      # However, a true orphan (folder doesn't exist) IS a legitimate Gate 3a
      # candidate. We must distinguish: if /bin/realpath ran and returned
      # nothing AND the target path itself is not present as any filesystem
      # entry, it's an orphan. Use [ ! -e "$target" ] as the orphan signal.
      if [ ! -e "$target" ]; then
        # Orphan branch — fall through to Gate 3a.
        canon_target=""
      else
        printf '%s\n' "MIGRATE: skip realpath-unavailable $entry" >&2
        continue
      fi
    fi

    # If we have a canon_target, verify it stays inside the project root.
    if [ -n "$canon_target" ]; then
      case "${canon_target}/" in
        "${canon_root}/"*) : ;;
        *)
          printf '%s\n' "MIGRATE: skip invalid content $entry (escapes-root)" >&2
          continue
          ;;
      esac
    fi

    # === Gate 3 — Orphan or Agreement ===
    if [ -z "$canon_target" ] || [ ! -d "$canon_target" ]; then
      # --- Gate 3a — Orphan branch ---
      # Strict basename shape check: ^\.active-[a-z][a-z0-9-]{0,31}$.
      # name_norm is the trailing-newline-stripped basename from Gate 1.
      case "$name_norm" in
        .active-*) : ;;
        *)
          printf '%s\n' "MIGRATE: skip invalid filename $entry (no .active- prefix)" >&2
          continue
          ;;
      esac
      local suffix="${name_norm#.active-}"
      if [ -z "$suffix" ]; then
        printf '%s\n' "MIGRATE: skip invalid filename $entry (empty suffix)" >&2
        continue
      fi
      if [ "${#suffix}" -gt 32 ]; then
        printf '%s\n' "MIGRATE: skip invalid filename $entry (suffix too long)" >&2
        continue
      fi
      # First char [a-z].
      case "$suffix" in
        [a-z]*) : ;;
        *)
          printf '%s\n' "MIGRATE: skip invalid filename $entry (suffix bad first char)" >&2
          continue
          ;;
      esac
      # All chars [a-z0-9-].
      case "$suffix" in
        *[!a-z0-9-]*)
          printf '%s\n' "MIGRATE: skip invalid filename $entry (suffix bad char)" >&2
          continue
          ;;
      esac
      # Filename shape passed. Delete via rm -f -- (end-of-options marker).
      rm -f -- "$entry"
      printf '%s\n' "MIGRATE: removed orphan $entry" >&2
      continue
    fi

    # --- Gate 3b — Agreement branch ---
    # canon_target exists AND is a directory. Derive skill from filename.
    case "$name_norm" in
      .active-*) : ;;
      *)
        printf '%s\n' "MIGRATE: skip invalid filename $entry (no .active- prefix)" >&2
        continue
        ;;
    esac
    skill="${name_norm#.active-}"
    if [ -z "$skill" ]; then
      printf '%s\n' "MIGRATE: skip invalid filename $entry (empty suffix)" >&2
      continue
    fi
    new_path="${canon_root}/.claude-active/$(claude_pid)-${skill}"
    if [ ! -f "$new_path" ]; then
      printf '%s\n' "MIGRATE: skip no-agreement $entry" >&2
      continue
    fi
    # Read new-path content with the same whitespace strip + content validation.
    new_content=$(LC_ALL=C tr -d '[:space:]' < "$new_path" 2>/dev/null)
    if [ -z "$new_content" ] || [ "$new_content" != "$legacy_content" ]; then
      printf '%s\n' "MIGRATE: skip no-agreement $entry" >&2
      continue
    fi
    # Agreement! Delete via rm -f -- (end-of-options marker).
    rm -f -- "$entry"
    printf '%s\n' "MIGRATE: removed legacy $entry (agreement check passed)" >&2
  done

  return 0
}
