#!/bin/bash
# verify-completion-gate.sh
# Stop hook for /serious-code: blocks session exit (exit 2) if any task
# has evidence but no gate_passed.md from the Completion Gate sub-agent,
# is missing required agent evidence files, or has a gate verdict without PASS.
#
# How it works:
# 1. Check if .active-code breadcrumb exists (active /serious-code session)
# 2. Find all task evidence directories (evidence/task_*/)
# 3. For each, check that gate_passed.md exists
# 4. For each, check that all 5 agent evidence files exist
# 5. For each, validate gate_passed.md contains PASS verdict
# 6. If any checks fail: exit 2 → Claude cannot stop, must fix
#
# Exit codes:
#   0 = allow exit (no active session, or all tasks verified)
#   2 = block exit (unverified tasks exist)

# Source shared guard utility (stdin is consumed and cached in _STOP_HOOK_GUARD_INPUT)
source "$(dirname "$0")/../../_shared/stop-hook-guard.sh" || exit 0
# Source the canonical path helper (shared by all Stop hooks that read breadcrumb contents)
source "$(dirname "$0")/../../_shared/path-resolve.sh" || exit 0
# Source observability helper (diagnostic only — not a security control).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/log-outcome.sh" 2>/dev/null || true
guard_stop_hook_active

# Breadcrumb files are written by SKILL.md prompt instructions from the main
# session (project root CWD). If skills are ever invoked from worktree agents,
# the write side will need the same PROJECT_ROOT fix.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active code session? Allow exit.
if [ ! -f "${PROJECT_ROOT}/.active-code" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "no-active-code"
  exit 0
fi

if ! PLAN_DIR=$(resolve_breadcrumb_path "${PROJECT_ROOT}/.active-code" "$PROJECT_ROOT"); then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "breadcrumb-unresolvable"
  exit 0
fi
if [ -L "$PLAN_DIR" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "plan-dir-is-symlink"
  exit 0
fi

# No plan directory? Allow exit.
if [ ! -d "$PLAN_DIR" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "plan-dir-missing"
  exit 0
fi

# No evidence directory? Allow exit (session just starting).
if [ ! -d "${PLAN_DIR}/evidence" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "evidence-dir-missing"
  exit 0
fi

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check each task evidence directory for gate_passed.md, evidence files, and gate content
MISSING=""
MISSING_EVIDENCE=""
INVALID_GATE=""
for task_dir in "${PLAN_DIR}/evidence"/task_*/; do
  # Skip if glob didn't match anything
  [ ! -d "$task_dir" ] && continue

  task_name=$(basename "$task_dir")

  if [ ! -f "${task_dir}/gate_passed.md" ]; then
    MISSING="${MISSING}  - ${task_name}\n"
  fi

  # --- Evidence file completeness check ---
  # All 5 agents must produce evidence files (shared contract with agent definitions)
  REQUIRED_FILES="implementation.md review.md tests.md runtime.md qa.md"
  for req_file in $REQUIRED_FILES; do
    if [ ! -f "${task_dir}/${req_file}" ]; then
      MISSING_EVIDENCE="${MISSING_EVIDENCE}  - ${task_name}/${req_file}\n"
    fi
  done

  # --- gate_passed.md content validation ---
  # The gate verdict file must contain PASS and must NOT contain FAIL.
  # Both checks are needed: an empty file has neither (should block).
  if [ -f "${task_dir}/gate_passed.md" ]; then
    GATE_CONTENT=$(cat "${task_dir}/gate_passed.md")
    HAS_PASS=$(echo "$GATE_CONTENT" | grep -ciE '\bpass\b' || true)
    HAS_FAIL=$(echo "$GATE_CONTENT" | grep -ciE '\bfail\b' || true)
    if [ "$HAS_FAIL" -gt 0 ]; then
      INVALID_GATE="${INVALID_GATE}  - ${task_name}/gate_passed.md (contains FAIL verdict)\n"
    elif [ "$HAS_PASS" -eq 0 ]; then
      INVALID_GATE="${INVALID_GATE}  - ${task_name}/gate_passed.md (does not contain PASS verdict)\n"
    fi
  fi
done

if [ -n "$MISSING" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "missing-gate-passed-md"
  emit_block_then_exit_2 "COMPLETION GATE BLOCK

These tasks have evidence directories but no gate_passed.md:
$(echo -e "$MISSING")
The Completion Gate sub-agent (Step 2.5 in the plan) must independently
verify ALL acceptance criteria before a task can be marked complete."
fi

if [ -n "$MISSING_EVIDENCE" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "missing-evidence-files"
  emit_block_then_exit_2 "EVIDENCE FILE BLOCK

These agent evidence files are missing:
$(echo -e "$MISSING_EVIDENCE")
All 5 agents (implementer, reviewer, test-runner, runtime-checker, qa)
must produce their evidence files before the session can end.

Required files per task: implementation.md, review.md, tests.md, runtime.md, qa.md"
fi

if [ -n "$INVALID_GATE" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "gate-verdict-invalid"
  emit_block_then_exit_2 "GATE VERDICT BLOCK

These gate files do not contain a PASS verdict:
$(echo -e "$INVALID_GATE")
The gate_passed.md file must contain 'PASS' to prove the Completion Gate
sub-agent approved the task. A file without PASS is not a valid gate."
fi

# --- Anti-rationalization strengthening (Layer 2) ---

# Check for TODO/FIXME placeholders in changed files
WARNINGS=""
for task_dir in "${PLAN_DIR}/evidence"/task_*/; do
  [ ! -d "$task_dir" ] && continue
  # Read the code review JSON for file list if available
  CODE_REVIEW=$(find "$task_dir" -name "*code_review*" 2>/dev/null | head -1)
  [ -z "$CODE_REVIEW" ] && continue
  # Extract file paths from the review (grep for common source extensions)
  FILES=$(grep -oE '"file"[[:space:]]*:[[:space:]]*"[^"]*"' "$CODE_REVIEW" 2>/dev/null | sed 's/.*"file"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
  for f in $FILES; do
    [ ! -f "$f" ] && continue
    TODOS=$(grep -n 'TODO\|FIXME\|HACK\|XXX' "$f" 2>/dev/null | head -3)
    if [ -n "$TODOS" ]; then
      WARNINGS="${WARNINGS}  ${f}:\n$(echo "$TODOS" | sed 's/^/    /')\n"
    fi
  done
done

if [ -n "$WARNINGS" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "todo-fixme-markers"
  emit_block_then_exit_2 "TODO/FIXME WARNING

Placeholder comments found in implementation files:
$(echo -e "$WARNINGS")
TODO/FIXME/HACK/XXX markers remain in implementation files."
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome ERROR "checks-not-reached"
  emit_block_then_exit_2 "ENFORCEMENT ERROR: verify-completion-gate.sh did not complete all checks"
fi

type _log_outcome >/dev/null 2>&1 && _log_outcome PASS "all-tasks-verified"
exit 0
