# SKILL.md Baseline Capture

**File:** .claude/skills/serious-code/SKILL.md
**Line count:**      649
**Captured:** 2026-04-12T14:56:09Z

## First 10 lines
```
---
name: serious-code
description: "Execute implementation plans from /serious-plan with TDD, parallel agents, and verification. Use when the user says 'serious code', 'execute the plan', 'implement the plan', 'start coding', or wants to move from planning to implementation."
user-invocable: true
---

# Serious Code

Execute implementation plans produced by `/serious-plan`. Orchestrates parallel plan execution via git worktrees, manages TDD cycles through Agent Teams, handles verification, and generates evidence.
```

## Last 10 lines
```
7. **Commits should be granular.** One commit per acceptance criterion, not one mega-commit per task.
8. **"Tests pass" is necessary, not sufficient.** After unit tests pass, always perform a smoke test in the running app for tasks with user-visible outcomes. Do not mark a task complete until the user can see/use the result.
9. **When tests pass but the feature doesn't work, investigate the gap.** The gap is always in a layer tests don't cover — caches, indexes, visibility culling, event propagation, async timing, build caches. Add a test for the missing layer, fix it, document it.
10. **Rebuild dependencies in monorepos.** After modifying a dependency package, rebuild it before testing dependents. Restart dev servers that consume the modified package. Stale builds are a silent failure source.
11. **The completion report is not optional.** Generate `completion_report.md` with full evidence summary. If the session is interrupted, resume must generate it.
12. **The Completion Gate is enforced by a stop hook.** The hook (registered in `.claude/settings.json` by `/serious-init`) checks that every task evidence directory contains `gate_passed.md`. If any are missing, the session cannot exit (exit code 2). You MUST run Step 2.5 for every task. There is no way around this — the hook runs outside your control.
13. **"INFRASTRUCTURE READY" is not a valid status.** Every acceptance criterion is either PASS or FAIL. There is no partial credit. If code doesn't exist for an AC, it's a FAIL, even if related infrastructure was built.
14. **Dead code is not implementation.** A widget/component/handler that exists in its own file but is never imported, instantiated, or mounted by a parent container is dead code. The Completion Gate must verify reachability for all "visible to user" ACs: find the parent container, confirm it imports the new component, confirm it instantiates/renders it, confirm any replaced component is removed. Dead code = FAIL.
15. **Stub code must be caught before verification.** Step 1.25 scans for `{STUB_PATTERNS}` after implementation. If stubs are found, the implementer must replace them with real code before proceeding. An empty method body or TODO placeholder that reaches verification is a process failure.
16. **Inter-plan regression is mandatory for multi-plan phases.** After merging a phase's worktrees (Step 1f), re-verify all previous phases' visible-to-user ACs using `{RUNTIME_VERIFY_CMD}`. If any regress, stop and report before starting the next phase. A green phase that silently breaks a previous phase is worse than a red phase.
```
