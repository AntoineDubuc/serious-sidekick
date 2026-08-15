#!/bin/bash
# verify-completion-gate.sh
# Stop hook for /serious-code: blocks session exit (exit 2) if any task
# has evidence but no gate_passed.md from the Completion Gate sub-agent,
# is missing required agent evidence files, or has a gate verdict without PASS.
#
# How it works:
# 1. Dual-read breadcrumb gate: prefer .claude-active/{PID}-code, fall back
#    to legacy .active-code with WARN, exit 0 if neither exists
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

# Dual-read breadcrumb gate (Task 4 of multi-terminal-breadcrumb-collision-verify).
# Prefer the per-session path; fall back to legacy with a stderr WARN.
SKILL=code

# ---------------------------------------------------------------------------
# ROOT SELF-CORRECTION (2026-08-12) — search the breadcrumb, not a marker file.
#
# Found by audit: this gate had fired 1,336 times in one installation and
# SKIPped every one. Claude Code sets CLAUDE_PROJECT_DIR to the directory the
# session was OPENED in. When that sits a level ABOVE the actual project — e.g.
# opened at "Workspace/" while the project is "Workspace/app/" — the breadcrumb
# is written under the real project root and this hook looked under the wrong
# one, found nothing, logged SKIP and exited 0. It reported success by doing
# nothing, for months.
#
# ⛔ TWO WRONG FIXES, both tried and rejected on 2026-08-12 — do not reintroduce:
#   1. Scan sibling directories for a .claude/settings.json. Ambiguous: it
#      cheerfully selected an unrelated project that sorted first.
#   2. Treat "no .claude/settings.json under CLAUDE_PROJECT_DIR" as proof the
#      root is wrong, and swap in the script's own root. That HIJACKS any
#      legitimately-rooted session whose project has no settings.json — which is
#      exactly what a mktemp test fixture is. It silently retargeted the hook at
#      the real repo and turned three blocking tests green (exit 0 where 2 was
#      required), i.e. it broke the gate in the very way this audit was about.
#
# The breadcrumb IS the signal. Try the given root first — always winning when
# it has one, so fixtures and normal sessions are untouched — and only then the
# script's own root, which is unambiguous because this file always lives at
#   <PROJECT_ROOT>/.claude/skills/serious-code/hooks/verify-completion-gate.sh
# No breadcrumb under either root means no active /serious-code session, which
# is a legitimate exit 0 — the pre-existing behaviour, unchanged.
# ---------------------------------------------------------------------------
_self_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." 2>/dev/null && pwd)"
bc=""
for _root in "$PROJECT_ROOT" "$_self_root"; do
  [ -n "$_root" ] && [ -d "$_root" ] || continue
  _pid_bc="${_root}/.claude-active/$(claude_pid)-${SKILL}"
  _legacy_bc="${_root}/.active-${SKILL}"
  if [ -f "$_pid_bc" ]; then
    bc="$_pid_bc"
  elif [ -f "$_legacy_bc" ]; then
    bc="$_legacy_bc"
    echo "WARN: dual-read fallback for ${SKILL} from legacy path" >&2
  else
    continue
  fi
  if [ "$_root" != "$PROJECT_ROOT" ]; then
    echo "NOTE: no ${SKILL} breadcrumb under CLAUDE_PROJECT_DIR ($PROJECT_ROOT); using $_root" >&2
  fi
  PROJECT_ROOT="$_root"
  break
done
if [ -z "$bc" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "no-active-code"
  exit 0
fi

if ! PLAN_DIR=$(resolve_breadcrumb_path "$bc" "$PROJECT_ROOT"); then
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

  # --- Evidence completeness check ---
  # TWO ACCEPTED SHAPES (widened 2026-08-12). The teeth of this gate are
  # gate_passed.md above and its verdict validation below — those are NOT
  # relaxed. This check only asks "is there a written task record beside it".
  #
  #   LEGACY  — the 5-agent-per-task shape: implementation/review/tests/runtime/qa.md
  #   CURRENT — the v6 plan shape: a single task report at the plan's evidence
  #             root, e.g. evidence/task_01_report.md, carrying the Inline QA Log.
  #
  # Why both: the v6 template deliberately REMOVED the separate `Nv` verification
  # task for code tasks, replacing it with a per-criterion independent QA
  # sub-agent plus this gate. Demanding five files named after five agents that a
  # v6 plan never spawns blocks every conforming plan — so the hook has to be
  # disabled to get work done, which is how gates die.
  # ⛔ Accepting two shapes is NOT accepting no evidence. Neither shape still blocks.
  _num="${task_name#task_}"
  if [ -f "${PLAN_DIR}/evidence/task_${_num}_report.md" ]; then
    :   # CURRENT shape satisfied
  else
    REQUIRED_FILES="implementation.md review.md tests.md runtime.md qa.md"
    _legacy_missing=""
    for req_file in $REQUIRED_FILES; do
      [ -f "${task_dir}/${req_file}" ] || _legacy_missing="${_legacy_missing}  - ${task_name}/${req_file}\n"
    done
    if [ -n "$_legacy_missing" ]; then
      MISSING_EVIDENCE="${MISSING_EVIDENCE}${_legacy_missing}  - ...or a v6 task report at evidence/task_${_num}_report.md\n"
    fi
  fi

  # --- gate_passed.md verdict validation ---
  # ⛔ REWRITTEN 2026-08-12. The previous version grepped the WHOLE file for the
  # bare words "pass" / "fail" and blocked on any "fail". That is unusable: a
  # thorough gate report necessarily discusses failure — "no criterion failed",
  # "PASS or FAIL", "this mutation would FAIL". Three genuinely passing gates
  # (17/17, 11/11, 12/12) were all rejected as "contains FAIL verdict". A gate
  # that cannot distinguish a verdict from a sentence about verdicts gets
  # switched off by the first person who meets it.
  #
  # The verdict is now a MACHINE-READABLE LINE the gate sub-agent must emit:
  #     GATE: PASS      (or)      GATE: FAIL
  # Everything else in the file is free prose and is ignored.
  # ⛔ A missing marker BLOCKS. Absence is not consent.
  if [ -f "${task_dir}/gate_passed.md" ]; then
    # ⛔ THIRD VERDICT ADDED 2026-08-13: BLOCKED.
    # A structural review found the hole: this hook understood only PASS and FAIL, so a task
    # that genuinely CANNOT be verified — because it waits on something outside its control —
    # had to lie in one direction or the other. Five plans in that review depend on uncommitted
    # code; in a worktree cut from HEAD their headline symbols do not exist. "FAIL" reads as
    # "the work is wrong" and invites an implementer to weaken criteria until they compile.
    # BLOCKED is the honest answer, so the hook must be able to hear it.
    #
    # ⛔ BLOCKED IS NOT A BYPASS. It is only accepted with a BLOCKED-ON: line naming the external
    # dependency. Without one it is treated as a missing verdict and BLOCKS, because "just write
    # BLOCKED" must never be cheaper than doing the work.
    # Markdown emphasis is STRIPPED before matching. The previous regex tried to spell out
    # optional `**` at each position and missed the commonest bold form of all — `**GATE:** **PASS**`
    # — because the colon sits INSIDE the emphasis. A gate agent that bolded its verdict was read as
    # having written no verdict at all. Safe direction (it blocked), but it blocked PASSING tasks
    # on formatting. Normalising once is both simpler and complete.
    # ⛔ ACCEPTED KEYS: GATE | VERDICT | STATUS. Measured against all 367 gate files in this repo:
    # `**Verdict:** PASS` is the established convention (166 files) and `GATE:` the newer one (10).
    # Accepting only GATE: would have blocked every resumed legacy plan for a naming difference.
    # ⛔ NOT ACCEPTED: a markdown heading such as `# Task 03 — Gate Passed` (109 files). A title is
    # not an assertion — accepting it would pass any file merely NAMED "gate passed", which is the
    # exact rubber stamp this hook exists to prevent. Those files must add one explicit line.
    #
    # ⛔ ALL verdict lines are read, not just the first, and ANY FAIL blocks. Reading only head -1
    # would let a file whose first hit is a per-criterion PASS mask an overall FAIL further down.
    # (0 of the 367 currently carry a FAIL line, so this strictness costs nothing today.)
    GATE_LINES=$(sed 's/[*_`]//g' "${task_dir}/gate_passed.md" \
                  | grep -iE '^[[:space:]]*(GATE|VERDICT|STATUS)[[:space:]]*:[[:space:]]*(PASS|FAIL|BLOCKED)' || true)
    GATE_LINE=$(printf '%s' "$GATE_LINES" | head -1)
    if printf '%s' "$GATE_LINES" | grep -qiE ':[[:space:]]*FAIL'; then GATE_LINE="FAIL"; fi
    if [ -z "$GATE_LINE" ]; then
      INVALID_GATE="${INVALID_GATE}  - ${task_name}/gate_passed.md (no verdict line: needs 'GATE:' or 'Verdict:' followed by PASS, FAIL or BLOCKED)\n"
    elif echo "$GATE_LINE" | grep -qiE 'BLOCKED'; then
      BLOCKED_ON=$(sed 's/[*_`]//g' "${task_dir}/gate_passed.md" \
                     | grep -iE '^[[:space:]]*BLOCKED-ON[[:space:]]*:[[:space:]]*\S' | head -1 || true)
      if [ -z "$BLOCKED_ON" ]; then
        INVALID_GATE="${INVALID_GATE}  - ${task_name}/gate_passed.md (GATE: BLOCKED with no 'BLOCKED-ON:' line naming the dependency)\n"
      else
        echo "NOTE: ${task_name} is BLOCKED — ${BLOCKED_ON}" >&2
      fi
    elif echo "$GATE_LINE" | grep -qiE 'FAIL'; then
      INVALID_GATE="${INVALID_GATE}  - ${task_name}/gate_passed.md (verdict line says FAIL)\n"
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
