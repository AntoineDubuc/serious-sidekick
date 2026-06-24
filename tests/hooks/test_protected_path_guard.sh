#!/bin/bash
# test_protected_path_guard.sh — Behavioral tests for the PreToolUse protected-path guard.
#
# Guard under test: .claude/skills/serious-code/hooks/protected-path-guard.sh
#
# The guard activates ONLY when the active plan (resolved via `breadcrumb_path code`)
# carries a verified `protected-paths.txt`. It then canonicalizes the Edit/Write target
# and, if the target falls inside a protected glob, emits a block/ask decision.
#
# Decision convention (matches Claude Code PreToolUse protocol, see 03_Hooks/research.md):
#   - ALLOW / NO-OP : exit 0, NO permissionDecision emitted on stdout.
#   - BLOCK / ASK   : stdout JSON with hookSpecificOutput.permissionDecision = "ask" (or "deny").
#                     This is the "pause and confirm; declining blocks the write" behavior.
#
# SAFETY INVARIANT (the most important assertion in this file):
#   With NO protected-paths.txt for the active plan, OR no `code` breadcrumb, the guard
#   is a COMPLETE no-op (exit 0, no decision). Anything else would block normal edits in
#   every future /serious-code session.
#
# Cross-platform: sources tests/lib/portable.sh; uses winpath for any path handed to
# native exes; uses mktemp -d (TMPDIR normalized by portable.sh). assert() style mirrors
# tests/test_skillmd_taskid.sh.
#
# Usage: bash tests/hooks/test_protected_path_guard.sh
# Exit:  0 if all assertions pass, 1 otherwise.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$TESTS_DIR/lib/portable.sh"

GUARD="$PROJECT_ROOT/.claude/skills/serious-code/hooks/protected-path-guard.sh"

PASS=0
FAIL=0
TOTAL=0
SKIP=0

assert() {
  local description="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $description"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $description"
  fi
}

skip() {
  SKIP=$((SKIP + 1))
  echo "  SKIP  $1"
}

# --- Helpers --------------------------------------------------------------

# sha256 of a file, hex digest only, portable across coreutils/macOS.
sha_of() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    echo "NO_SHA_TOOL"
  fi
}

# Build a scratch repo with a `code` breadcrumb pointing at a plan folder.
# Echoes the scratch root on stdout. Sets globals SCRATCH / PLAN_DIR_REL / PLAN_DIR_ABS.
make_scratch() {
  SCRATCH=$(mktemp -d)
  # Plan folder relative to root (the breadcrumb stores a root-relative path).
  PLAN_DIR_REL="Research/features/sample"
  PLAN_DIR_ABS="$SCRATCH/$PLAN_DIR_REL"
  mkdir -p "$PLAN_DIR_ABS"
  mkdir -p "$SCRATCH/src/payments" "$SCRATCH/src/util" "$SCRATCH/src/payments-report"
  # The guard resolves the plan via `breadcrumb_path code`, which yields
  # $ROOT/.claude-active/{claude_pid}-code. We cannot know the PID the guard's
  # claude_pid() will compute, so write BOTH the legacy breadcrumb (.active-code)
  # and let the guard's dual-read fall back to it. The guard must support the
  # same dual-read topology the other serious-code hooks use.
  printf '%s\n' "$PLAN_DIR_REL" > "$SCRATCH/.active-code"
}

# Write a verified sidecar (protected-paths.txt + matching .sha256) into the plan dir.
write_sidecar() {
  local content="$1"
  printf '%s' "$content" > "$PLAN_DIR_ABS/protected-paths.txt"
  sha_of "$PLAN_DIR_ABS/protected-paths.txt" > "$PLAN_DIR_ABS/protected-paths.sha256"
}

# Invoke the guard with a Write to TARGET (a path relative to or absolute in SCRATCH).
# Captures stdout to GUARD_OUT and exit code to GUARD_EXIT.
run_guard() {
  local target="$1"
  local input
  # The hook reads tool input from stdin JSON (.tool_input.file_path) — the modern
  # PreToolUse protocol used by log-dispatch.sh.
  input=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$target")
  GUARD_OUT=$(CLAUDE_PROJECT_DIR="$SCRATCH" printf '%s' "$input" | CLAUDE_PROJECT_DIR="$SCRATCH" bash "$GUARD" 2>/dev/null)
  GUARD_EXIT=$?
}

# Predicate: did the guard emit a block/ask decision?
is_blocked() {
  printf '%s' "$GUARD_OUT" | grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"(ask|deny)"'
}

cleanup_scratch() {
  [ -n "${SCRATCH:-}" ] && rm -rf "$SCRATCH"
  SCRATCH=""
}

echo "=== protected-path-guard.sh — behavioral tests ==="
echo ""

# =========================================================================
# AC1: verified sidecar with src/payments/** → Write to src/payments/charge.js BLOCKS
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
run_guard "$SCRATCH/src/payments/charge.js"
if is_blocked; then assert "AC1: protected write (src/payments/charge.js) is blocked/asked" 0
else assert "AC1: protected write (src/payments/charge.js) is blocked/asked" 1; fi
cleanup_scratch

# =========================================================================
# AC2: write to a NON-protected path (src/util/date.js) → ALLOWED
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
run_guard "$SCRATCH/src/util/date.js"
if is_blocked; then assert "AC2: non-protected write (src/util/date.js) is allowed" 1
else assert "AC2: non-protected write (src/util/date.js) is allowed" 0; fi
# allowed must also be exit 0
assert "AC2b: allowed write exits 0" "$([ "$GUARD_EXIT" -eq 0 ] && echo 0 || echo 1)"
cleanup_scratch

# =========================================================================
# AC3: canonicalization — ../ and ./ and symlinked parent all resolve & BLOCK
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
# Need the real file to exist for realpath to resolve it; create it.
: > "$SCRATCH/src/payments/charge.js"

# 3a: src/util/../payments/charge.js
run_guard "$SCRATCH/src/util/../payments/charge.js"
if is_blocked; then assert "AC3a: ../ traversal resolves into payments and blocks" 0
else assert "AC3a: ../ traversal resolves into payments and blocks" 1; fi

# 3b: ./src/payments/charge.js
run_guard "$SCRATCH/./src/payments/charge.js"
if is_blocked; then assert "AC3b: ./ prefix resolves into payments and blocks" 0
else assert "AC3b: ./ prefix resolves into payments and blocks" 1; fi

# 3c: symlinked parent. Create alias -> src, then alias/payments/charge.js.
if ln -s "$SCRATCH/src" "$SCRATCH/alias" 2>/dev/null && [ -L "$SCRATCH/alias" ]; then
  run_guard "$SCRATCH/alias/payments/charge.js"
  if is_blocked; then assert "AC3c: symlinked-parent path resolves into payments and blocks" 0
  else assert "AC3c: symlinked-parent path resolves into payments and blocks" 1; fi
else
  skip "AC3c: symlink could not be created on this OS — sub-case skipped"
fi
cleanup_scratch

# =========================================================================
# AC4: Windows-style backslash path normalized to / and BLOCKED
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
run_guard 'src\payments\charge.js'
if is_blocked; then assert "AC4: backslash path src\\payments\\charge.js normalized and blocked" 0
else assert "AC4: backslash path src\\payments\\charge.js normalized and blocked" 1; fi
cleanup_scratch

# =========================================================================
# AC5: pinned matcher is documented in a comment block inside the guard
# =========================================================================
# dir/** semantics, single-* not crossing /, bare/single-* globs defined.
matcher_doc=$(sed -n '/MATCHER/,/^[^#]/p' "$GUARD" 2>/dev/null)
# Be liberal: just require the guard source to document the three semantics.
doc_ok=0
grep -q 'dir/\*\*' "$GUARD" || doc_ok=1
grep -qiE 'does not cross|not cross|within a single (path )?segment|single segment' "$GUARD" || doc_ok=1
grep -qiE 'single-\*|bare|\*\.env|single .?\*.? ' "$GUARD" || doc_ok=1
assert "AC5: pinned matcher algorithm documented in a comment block" "$doc_ok"

# =========================================================================
# AC6: active-plan via breadcrumb; NO `code` breadcrumb → NO-OP (exit 0, no decision)
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
# Remove the breadcrumb so there is no active plan.
rm -f "$SCRATCH/.active-code"
run_guard "$SCRATCH/src/payments/charge.js"
noop_ok=0
[ "$GUARD_EXIT" -eq 0 ] || noop_ok=1
if is_blocked; then noop_ok=1; fi
assert "AC6: no 'code' breadcrumb → no-op (exit 0, no decision)" "$noop_ok"
cleanup_scratch

# =========================================================================
# AC7: integrity — sha256 mismatch → FAIL-SECURE (block/ask), file not trusted
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
# Corrupt the .sha256 so it no longer matches.
printf '%s\n' "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" > "$PLAN_DIR_ABS/protected-paths.sha256"
run_guard "$SCRATCH/src/util/date.js"
# Even a normally-allowed path must be blocked when the sidecar cannot be verified.
if is_blocked; then assert "AC7: hash mismatch → fail-secure block (even for non-protected target)" 0
else assert "AC7: hash mismatch → fail-secure block (even for non-protected target)" 1; fi
cleanup_scratch

# =========================================================================
# NEG8: blank/#-only sidecar WITH matching hash → protects nothing (allowed)
# =========================================================================
make_scratch
write_sidecar '# nothing protected here

# another comment
'
run_guard "$SCRATCH/src/payments/charge.js"
if is_blocked; then assert "NEG8: empty-but-verified sidecar protects nothing (write allowed)" 1
else assert "NEG8: empty-but-verified sidecar protects nothing (write allowed)" 0; fi
cleanup_scratch

# =========================================================================
# NEG9: fail-secure for present-but-unverifiable sidecars (NOT fail-open)
# =========================================================================

# 9a: missing .sha256 entirely
make_scratch
printf '%s' 'src/payments/**
' > "$PLAN_DIR_ABS/protected-paths.txt"
# (no .sha256 written)
run_guard "$SCRATCH/src/util/date.js"
if is_blocked; then assert "NEG9a: present sidecar with MISSING .sha256 → fail-secure block" 0
else assert "NEG9a: present sidecar with MISSING .sha256 → fail-secure block" 1; fi
cleanup_scratch

# 9b: unreadable protected-paths.txt (chmod 000). Skip if chmod can't restrict (Windows).
make_scratch
write_sidecar 'src/payments/**
'
chmod 000 "$PLAN_DIR_ABS/protected-paths.txt" 2>/dev/null || true
if [ -r "$PLAN_DIR_ABS/protected-paths.txt" ]; then
  skip "NEG9b: filesystem ignores chmod 000 (Windows/MSYS) — unreadable sub-case skipped"
else
  run_guard "$SCRATCH/src/util/date.js"
  if is_blocked; then assert "NEG9b: UNREADABLE sidecar → fail-secure block" 0
  else assert "NEG9b: UNREADABLE sidecar → fail-secure block" 1; fi
fi
chmod 644 "$PLAN_DIR_ABS/protected-paths.txt" 2>/dev/null || true
cleanup_scratch

# =========================================================================
# NEG10: no prefix-bleed — src/payments-report/x.js NOT matched by src/payments/**
# =========================================================================
make_scratch
write_sidecar 'src/payments/**
'
run_guard "$SCRATCH/src/payments-report/x.js"
if is_blocked; then assert "NEG10: prefix-bleed avoided (payments-report not matched)" 1
else assert "NEG10: prefix-bleed avoided (payments-report not matched)" 0; fi
cleanup_scratch

# =========================================================================
# NEG11: no line injection — a malicious glob line executes nothing
# =========================================================================
make_scratch
# Two injection attempts as literal glob lines. The marker file must NOT appear.
MARKER="$SCRATCH/pwned_marker"
write_sidecar "\$(touch $MARKER)
*; rm -rf $SCRATCH/src
src/payments/**
"
run_guard "$SCRATCH/src/payments/charge.js"
inj_ok=0
# The injection commands must not have run.
[ -e "$MARKER" ] && inj_ok=1
[ -d "$SCRATCH/src" ] || inj_ok=1
assert "NEG11: malicious sidecar lines execute no command (no marker, src intact)" "$inj_ok"
# And the legitimate glob on the 3rd line still protects.
if is_blocked; then assert "NEG11b: legitimate glob still enforced alongside injection lines" 0
else assert "NEG11b: legitimate glob still enforced alongside injection lines" 1; fi
cleanup_scratch

# =========================================================================
# NEG12: a sidecar glob line containing `..` is rejected/ignored
# =========================================================================
make_scratch
# Only protected line is a traversal glob; it must be ignored, so the
# corresponding write is NOT blocked by it.
write_sidecar '../etc/**
'
run_guard "$SCRATCH/src/payments/charge.js"
if is_blocked; then assert "NEG12: '..' glob line ignored (not used to block)" 1
else assert "NEG12: '..' glob line ignored (not used to block)" 0; fi
cleanup_scratch

# =========================================================================
echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped, $TOTAL total"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
