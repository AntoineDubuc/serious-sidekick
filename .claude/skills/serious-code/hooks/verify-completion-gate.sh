#!/bin/bash
# verify-completion-gate.sh
# Stop hook for /serious-code: blocks session exit (exit 2) if any task
# has evidence but no gate_passed.md from the Completion Gate sub-agent.
#
# How it works:
# 1. Check if .active-code breadcrumb exists (active /serious-code session)
# 2. Find all task evidence directories (evidence/task_*/)
# 3. For each, check that gate_passed.md exists
# 4. If any are missing: exit 2 → Claude cannot stop, must run the gate
#
# Exit codes:
#   0 = allow exit (no active session, or all tasks verified)
#   2 = block exit (unverified tasks exist)

# No active code session? Allow exit.
[ ! -f ".active-code" ] && exit 0

PLAN_DIR=$(cat .active-code | tr -d '[:space:]')

# No plan directory? Allow exit.
[ ! -d "$PLAN_DIR" ] && exit 0

# No evidence directory? Allow exit (session just starting).
[ ! -d "${PLAN_DIR}/evidence" ] && exit 0

# Check each task evidence directory for gate_passed.md
MISSING=""
for task_dir in "${PLAN_DIR}/evidence"/task_*/; do
  # Skip if glob didn't match anything
  [ ! -d "$task_dir" ] && continue

  task_name=$(basename "$task_dir")

  if [ ! -f "${task_dir}/gate_passed.md" ]; then
    MISSING="${MISSING}  - ${task_name}\n"
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

exit 0
