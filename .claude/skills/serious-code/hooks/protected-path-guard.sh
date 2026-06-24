#!/bin/bash
# protected-path-guard.sh — PreToolUse(Edit|Write) guard for /serious-code.
#
# PURPOSE
#   When (and ONLY when) the active plan carries a verified `protected-paths.txt`,
#   this guard canonicalizes the Edit/Write target and, if it falls inside a
#   protected glob, pauses for user confirmation before the write proceeds.
#   This is the code-time enforcement of /serious-simple-plan's `--avoid` boundary.
#
# DECISION CONVENTION (Claude Code PreToolUse protocol — 03_Hooks/research.md)
#   ALLOW / NO-OP : exit 0, NOTHING on stdout.
#   BLOCK / ASK   : exit 0 with stdout JSON:
#                     {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#                      "permissionDecision":"ask","permissionDecisionReason":"..."}}
#                   "ask" pauses and asks the user to confirm; declining blocks the
#                   write. We use "ask" (recoverable) rather than "deny" so the user
#                   can consciously cross the fence or fix the sidecar.
#
# ============================ FAIL POSTURE ===============================
#   - GENUINELY ABSENT sidecar  → NO-OP (exit 0). The plan never opted in.
#   - NO `code` breadcrumb      → NO-OP (exit 0). No active plan.
#   - PRESENT but UNVERIFIABLE  → FAIL-SECURE (ask) with a loud stderr error.
#         "unverifiable" = unreadable, hash mismatch, or missing `.sha256`.
#   This is deliberate: an actor who corrupts the fence must not thereby open it.
#   Blocking is recoverable (confirm or fix the sidecar); silently opening is not.
#
#   The no-op path is the SAFETY-CRITICAL invariant: this hook is wired on every
#   Edit|Write in the LIVE settings.json. If it blocked when there is simply no
#   sidecar, it would break normal editing in every future session.
# =========================================================================
#
# ============================ MATCHER (pinned) ===========================
#   Matching is CANONICAL, not lexical. Before matching, the target is:
#     1. backslash `\` normalized to `/`  (Windows-path normalization)
#     2. resolved (realpath / readlink -f, with a pure-bash `cd && pwd -P`
#        fallback) so `.`/`..`/symlinks collapse to a real path
#     3. made repo-root-relative (forward-slash), so it is comparable to the
#        repo-root-relative globs in the sidecar.
#
#   Supported glob shapes (one repo-root-relative, forward-slash glob per line):
#
#     dir/**        Recursive directory fence. Matches `dir` and EVERYTHING
#                   beneath it at any depth (dir/a.js, dir/sub/b.js, ...).
#                   Implemented as a containment test: target == dir OR target
#                   begins with `dir/` (the trailing slash defeats prefix-bleed,
#                   so `payments-report/x` is NOT matched by `payments/**`).
#
#     dir/*         Single-segment wildcard. Matches files/dirs DIRECTLY inside
#                   `dir` only — `*` does NOT cross `/`. (dir/a.js matches;
#                   dir/sub/b.js does NOT.)
#
#     dir/*.env     Bare/single-`*` suffix glob. Matches names like `*.env`
#                   DIRECTLY inside `dir` (not recursively). The `*` matches
#                   within a single path segment and does not cross `/`.
#
#     file.js       Bare file glob (no slash). Matches that exact repo-root file,
#                   or `*`-containing single-segment patterns at repo root.
#
#   `*` ALWAYS matches within a single path segment and never crosses `/`.
#   `**` is ONLY meaningful as the trailing `/**` recursive form above.
#
#   Glob lines that the matcher does not support, or that contain a `..`
#   segment, or that are absolute (leading `/`), are IGNORED (Task 1 sanitizes
#   `--avoid` at write time so unsupported shapes fail loud there).
#
#   INTEGRITY SCOPE: the `.sha256` companion detects accidental corruption and
#   writer/reader drift. It is NOT anti-tamper against an actor with write
#   access to the plan folder (they could rewrite both files). That is
#   acceptable for the threat model (a user fencing themselves from accidental
#   sprawl, not defending against a malicious co-author).
# =========================================================================
#
# SAFETY: parses the sidecar with `while IFS= read -r line` — NO eval, NO command
# substitution, NO glob/word expansion of the line content. A line like
# `$(touch x)` or `*; rm -rf y` is treated as a literal candidate glob and runs
# nothing.

# Source-time note: we DO NOT use `set -e`/`set -u` aggressively because we must
# never abort mid-flight in a way that leaves the tool call in an undefined state.
set -uo pipefail

# ---- Resolve project root -------------------------------------------------
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ -d "$PROJECT_ROOT" ] || exit 0

# ---- Read tool input (stdin JSON; fallback to CLAUDE_TOOL_INPUT) ----------
INPUT=""
INPUT=$(cat 2>/dev/null) || INPUT=""
[ -z "$INPUT" ] && INPUT="${CLAUDE_TOOL_INPUT:-}"

# Extract the target file_path. Prefer jq; fall back to a tolerant grep/sed.
TARGET=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TARGET=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null) || TARGET=""
  fi
  if [ -z "$TARGET" ]; then
    TARGET=$(printf '%s' "$INPUT" \
      | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | head -1 \
      | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
  fi
fi

# No target → nothing to guard.
[ -z "$TARGET" ] && exit 0

# ---- Resolve the active plan folder via the `code` breadcrumb -------------
# Use the shared per-session breadcrumb helper (breadcrumb_path code) with a
# dual-read fallback to the legacy .active-code, matching the other serious-code
# hooks (tdd-gate.sh, log-dispatch.sh).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/path-resolve.sh" || exit 0

SKILL=code
PID_BC=""
PID_BC=$(breadcrumb_path "$SKILL" 2>/dev/null) || PID_BC=""
LEGACY_BC="${PROJECT_ROOT}/.active-${SKILL}"

bc=""
if [ -n "$PID_BC" ] && [ -f "$PID_BC" ]; then
  bc="$PID_BC"
elif [ -f "$LEGACY_BC" ]; then
  bc="$LEGACY_BC"
else
  # No `code` breadcrumb → no active plan → NO-OP.
  exit 0
fi

PLAN_DIR_REL=""
PLAN_DIR_REL=$(LC_ALL=C tr -d '\r\n' < "$bc" 2>/dev/null) || exit 0
[ -z "$PLAN_DIR_REL" ] && exit 0

PLAN_DIR="${PROJECT_ROOT}/${PLAN_DIR_REL}"
[ -d "$PLAN_DIR" ] || exit 0

SIDECAR="${PLAN_DIR}/protected-paths.txt"
SIDECAR_SHA="${PLAN_DIR}/protected-paths.sha256"

# ---- ABSENT sidecar → NO-OP (the plan never opted in) ---------------------
if [ ! -e "$SIDECAR" ]; then
  exit 0
fi

# ============================================================================
# From here on a sidecar is PRESENT. Any inability to verify it = FAIL-SECURE.
# ============================================================================

# emit_ask — print the PreToolUse "ask" decision JSON and exit 0.
emit_ask() {
  local reason="$1"
  # Loud stderr for the fail-secure / block cases (visible to the operator).
  printf 'PROTECTED-PATH GUARD: %s\n' "$reason" >&2
  # Escape backslashes and double quotes for JSON safety.
  local esc
  esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$esc"
  exit 0
}

# sha256 of a file (hex digest only), portable.
sha_of() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" 2>/dev/null | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" 2>/dev/null | awk '{print $1}'
  else
    echo ""
  fi
}

# ---- Integrity: the sidecar must be readable AND its hash must verify ------
if [ ! -r "$SIDECAR" ]; then
  emit_ask "protected-paths.txt is present but UNREADABLE — cannot verify the avoid-list, failing secure. Fix or remove the sidecar in ${PLAN_DIR_REL}."
fi

if [ ! -r "$SIDECAR_SHA" ]; then
  emit_ask "protected-paths.txt is present but its integrity companion protected-paths.sha256 is missing/unreadable — failing secure. Regenerate the sidecar in ${PLAN_DIR_REL}."
fi

EXPECTED_SHA=""
EXPECTED_SHA=$(LC_ALL=C tr -d '[:space:]' < "$SIDECAR_SHA" 2>/dev/null)
# Some sha files store "hash  filename"; the tr above already collapsed that to a
# single token only if there were no other chars, so re-extract the leading hex.
EXPECTED_SHA="${EXPECTED_SHA%%[!0-9a-fA-F]*}"

ACTUAL_SHA=""
ACTUAL_SHA=$(sha_of "$SIDECAR")

if [ -z "$ACTUAL_SHA" ]; then
  emit_ask "cannot compute SHA-256 of protected-paths.txt (no sha tool / read failure) — failing secure."
fi

# Case-insensitive hex compare.
if [ "$(printf '%s' "$EXPECTED_SHA" | tr 'A-F' 'a-f')" != "$(printf '%s' "$ACTUAL_SHA" | tr 'A-F' 'a-f')" ]; then
  emit_ask "protected-paths.txt FAILED its SHA-256 integrity check — the avoid-list cannot be trusted, failing secure. Regenerate protected-paths.sha256 in ${PLAN_DIR_REL}."
fi

# ============================================================================
# The sidecar is PRESENT and VERIFIED. Parse it safely and match the target.
# ============================================================================

# ---- Canonicalize the target ----------------------------------------------
# 1) Normalize backslashes to forward slashes (Windows paths).
#    Use tr (not ${//}) because the `${var//\\//}` form is mis-parsed by some
#    bash builds (the `//` replacement delimiter collides), silently dropping
#    forward slashes. tr is unambiguous.
NORM_TARGET=$(printf '%s' "$TARGET" | tr '\\' '/')

# 2) Make absolute relative to PROJECT_ROOT if it is not already absolute.
#    "Absolute" includes both POSIX (/foo) and Windows/MSYS drive-letter
#    (C:/foo) forms — otherwise a drive-letter path gets the root prepended.
case "$NORM_TARGET" in
  /*)              ABS_TARGET="$NORM_TARGET" ;;
  [A-Za-z]:/*)     ABS_TARGET="$NORM_TARGET" ;;
  *)               ABS_TARGET="${PROJECT_ROOT}/${NORM_TARGET}" ;;
esac

# canonicalize_path — resolve .,..,symlinks. For a not-yet-existing target file,
# resolve the deepest existing ancestor and re-append the unresolved tail.
canonicalize_path() {
  local p="$1"
  local resolved=""
  # Fast path: realpath/readlink on the whole path if it exists.
  if command -v realpath >/dev/null 2>&1; then
    resolved=$(realpath "$p" 2>/dev/null) || resolved=""
  fi
  if [ -z "$resolved" ] && command -v readlink >/dev/null 2>&1; then
    resolved=$(readlink -f "$p" 2>/dev/null) || resolved=""
  fi
  if [ -n "$resolved" ]; then
    printf '%s' "$resolved"
    return 0
  fi
  # Pure-shell fallback: resolve the deepest existing ancestor, keep the tail.
  local dir base tail=""
  dir="$p"
  while [ -n "$dir" ] && [ "$dir" != "/" ] && [ ! -d "$dir" ]; do
    base="${dir##*/}"
    if [ -n "$tail" ]; then tail="$base/$tail"; else tail="$base"; fi
    dir="${dir%/*}"
    [ -z "$dir" ] && dir="/"
  done
  local cdir=""
  if [ -d "$dir" ]; then
    # Resolve the ancestor with realpath FIRST so the result shares the same
    # path namespace as CANON_ROOT (also realpath). Falling straight to
    # `cd && pwd -P` can yield a different namespace (e.g. MSYS /tmp vs the
    # Windows C:/ form), which would break the repo-root prefix strip.
    if command -v realpath >/dev/null 2>&1; then
      cdir=$(realpath "$dir" 2>/dev/null) || cdir=""
    fi
    [ -z "$cdir" ] && cdir=$(cd "$dir" 2>/dev/null && pwd -P)
  fi
  if [ -z "$cdir" ]; then
    # Last resort: lexical normalization (collapse ./ and ../ textually).
    printf '%s' "$p"
    return 0
  fi
  if [ -n "$tail" ]; then
    printf '%s/%s' "$cdir" "$tail"
  else
    printf '%s' "$cdir"
  fi
}

CANON_TARGET=$(canonicalize_path "$ABS_TARGET")

# Canonical project root for an apples-to-apples relative comparison.
CANON_ROOT=""
if command -v realpath >/dev/null 2>&1; then
  CANON_ROOT=$(realpath "$PROJECT_ROOT" 2>/dev/null) || CANON_ROOT=""
fi
[ -z "$CANON_ROOT" ] && CANON_ROOT=$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P)
[ -z "$CANON_ROOT" ] && CANON_ROOT="$PROJECT_ROOT"

# Make the canonical target repo-root-relative (strip the root prefix + slash).
REL_TARGET="$CANON_TARGET"
case "$CANON_TARGET/" in
  "$CANON_ROOT/"*)
    REL_TARGET="${CANON_TARGET#"$CANON_ROOT"/}"
    ;;
esac
# Normalize any residual backslashes (defensive) and strip a leading ./.
REL_TARGET=$(printf '%s' "$REL_TARGET" | tr '\\' '/')
REL_TARGET="${REL_TARGET#./}"

# ---- Matcher --------------------------------------------------------------
# glob_matches REL GLOB → return 0 if the canonical relative target REL is
# inside/at the protected GLOB, per the pinned semantics documented above.
glob_matches() {
  local rel="$1"
  local glob="$2"

  case "$glob" in
    */\*\*)
      # dir/** — recursive containment.
      local dir="${glob%/\*\*}"
      [ -z "$dir" ] && return 1
      if [ "$rel" = "$dir" ] || [ "${rel#"$dir"/}" != "$rel" ]; then
        return 0
      fi
      return 1
      ;;
    \*\*)
      # bare ** — match everything (treated as repo-root recursive).
      return 0
      ;;
    */\*)
      # dir/* — single segment directly under dir, * does not cross '/'.
      local dir="${glob%/\*}"
      local tail="${rel#"$dir"/}"
      # Must actually be under dir, and the remainder must be a single segment.
      [ "$tail" = "$rel" ] && return 1            # not under dir
      case "$tail" in */*) return 1 ;; esac        # crosses '/', reject
      [ -n "$tail" ] && return 0
      return 1
      ;;
    */*)
      # dir/<pattern> where <pattern> may contain a single-segment '*'
      # (e.g. dir/*.env). The directory part must match exactly and the
      # filename part must glob-match a single segment under it.
      local dir="${glob%/*}"
      local fpat="${glob##*/}"
      local tail="${rel#"$dir"/}"
      [ "$tail" = "$rel" ] && return 1            # not under dir
      case "$tail" in */*) return 1 ;; esac        # must be a single segment
      # shellcheck disable=SC2254 # intentional glob match of a single segment
      case "$tail" in
        $fpat) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      # Bare single-segment pattern at repo root (exact file or *-glob).
      case "$rel" in */*) return 1 ;; esac         # target is not at repo root
      # shellcheck disable=SC2254
      case "$rel" in
        $glob) return 0 ;;
        *) return 1 ;;
      esac
      ;;
  esac
}

# ---- Parse the sidecar SAFELY and test each glob --------------------------
# No eval, no expansion. `IFS=` + `-r` preserves the literal line; we never
# execute or expand it. Lines are only ever used as the right-hand operand of a
# `case` pattern inside glob_matches, which performs pattern-matching, not
# execution.
DECISION_BLOCK=0
PROTECTED_GLOB=""

while IFS= read -r line || [ -n "$line" ]; do
  # Strip a trailing CR (Windows line endings).
  line="${line%$'\r'}"
  # Skip blank lines and comments.
  case "$line" in
    ''|\#*) continue ;;
  esac
  # Trim leading/trailing ASCII whitespace.
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  # SANITIZE: ignore traversal globs (`..` segment) and absolute globs.
  case "$line" in
    /*) continue ;;
    ..|../*|*/..|*/../*) continue ;;
  esac
  case "$line" in *..*)
    # Only reject when `..` is a path SEGMENT (defensive: also catches `a/..b`?
    # no — `a/..b` is a legit name; require the `..` to be a whole segment).
    case "/$line/" in
      */../*) continue ;;
    esac
    ;;
  esac

  if glob_matches "$REL_TARGET" "$line"; then
    DECISION_BLOCK=1
    PROTECTED_GLOB="$line"
    break
  fi
done < "$SIDECAR"

if [ "$DECISION_BLOCK" -eq 1 ]; then
  emit_ask "write target '${REL_TARGET}' is inside the protected avoid-list glob '${PROTECTED_GLOB}'. Confirm to cross the fence, or decline to block the write."
fi

# Target is not protected → allow.
exit 0
