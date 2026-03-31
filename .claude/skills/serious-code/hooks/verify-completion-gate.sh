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

# Breadcrumb files are written by SKILL.md prompt instructions from the main
# session (project root CWD). If skills are ever invoked from worktree agents,
# the write side will need the same PROJECT_ROOT fix.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0

# No active code session? Allow exit.
[ ! -f "${PROJECT_ROOT}/.active-code" ] && exit 0

BREADCRUMB_CONTENT=$(cat "${PROJECT_ROOT}/.active-code" | tr -d '[:space:]')
# Reject path traversal and absolute paths
case "$BREADCRUMB_CONTENT" in
  /* | *..* )
    echo "WARNING: breadcrumb content rejected (path traversal or absolute path)" >&2
    exit 0 ;;
esac
PLAN_DIR="${PROJECT_ROOT}/${BREADCRUMB_CONTENT}"

# No plan directory? Allow exit.
[ ! -d "$PLAN_DIR" ] && exit 0

# No evidence directory? Allow exit (session just starting).
[ ! -d "${PLAN_DIR}/evidence" ] && exit 0

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
  echo "COMPLETION GATE BLOCK" >&2
  echo "" >&2
  echo "These tasks have evidence directories but no gate_passed.md:" >&2
  echo -e "$MISSING" >&2
  echo "The Completion Gate sub-agent (Step 2.5 in the plan) must independently" >&2
  echo "verify ALL acceptance criteria before a task can be marked complete." >&2
  echo "" >&2
  echo "For each unverified task:" >&2
  echo "  1. Dispatch the Completion Gate sub-agent (see Step 2.5)" >&2
  echo "  2. If all ACs pass, the gate writes gate_passed.md" >&2
  echo "  3. Then you may exit" >&2
  exit 2
fi

if [ -n "$MISSING_EVIDENCE" ]; then
  echo "EVIDENCE FILE BLOCK" >&2
  echo "" >&2
  echo "These agent evidence files are missing:" >&2
  echo -e "$MISSING_EVIDENCE" >&2
  echo "All 5 agents (implementer, reviewer, test-runner, runtime-checker, qa)" >&2
  echo "must produce their evidence files before the session can end." >&2
  echo "" >&2
  echo "Required files per task: implementation.md, review.md, tests.md, runtime.md, qa.md" >&2
  exit 2
fi

if [ -n "$INVALID_GATE" ]; then
  echo "GATE VERDICT BLOCK" >&2
  echo "" >&2
  echo "These gate files do not contain a PASS verdict:" >&2
  echo -e "$INVALID_GATE" >&2
  echo "The gate_passed.md file must contain 'PASS' to prove the Completion Gate" >&2
  echo "sub-agent approved the task. A file without PASS is not a valid gate." >&2
  exit 2
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
  echo "TODO/FIXME WARNING" >&2
  echo "" >&2
  echo "Placeholder comments found in implementation files:" >&2
  echo -e "$WARNINGS" >&2
  echo "Remove all TODO/FIXME/HACK/XXX before completing the session." >&2
  echo "See Guardrail Block entry #6: 'The plan is the contract. Do not silently skip.'" >&2
  exit 2
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: verify-completion-gate.sh did not complete all checks" >&2
  exit 2
fi
exit 0
