---
name: serious-code
description: "Execute implementation plans from /serious-plan with TDD, parallel agents, and verification. Use when the user says 'serious code', 'execute the plan', 'implement the plan', 'start coding', or wants to move from planning to implementation."
user-invocable: true
hooks:
  Stop:
    - matcher: "*"
      handler:
        type: prompt
        prompt: |
          If a serious code session is active (check for .active-code file in project root),
          read the execution folder path from it, then update execution_log.md with the latest
          status: which phase is active, which plans are running/completed/failed, and any
          errors encountered. Include timestamp. Keep it concise.
---

# Serious Code

Execute implementation plans produced by `/serious-plan`. Orchestrates parallel plan execution via git worktrees, manages TDD cycles through Agent Teams, handles verification, and generates evidence.

**Position in the workflow:**
```
/serious-conversation → /serious-research → /serious-plan → /serious-code → done
```

---

## Phase 0: Intake

### 0a. Auto-detect plans

Before asking anything, scan the project:

- Check `Research/features/*/phase_map.md` for multi-plan setups
- Check `Research/features/*/implementation_plan.md` for single plans
- Check `Research/bugs/*/` and `Research/exploratory/*/` similarly
- If `$ARGUMENTS` specifies a path, use that directly

### 0b. Present what you found

**If exactly one plan or phase map found:**
> "I found a plan at `Research/features/auth/implementation_plan.md`. Execute this?"

**If multiple found:**
> List them and ask which one to execute.

**If nothing found:**
> "No plans found. Run `/serious-plan` first to generate one."

### 0c. Validate the plan

Before executing, verify:

- [ ] The plan follows v6 template structure
- [ ] All referenced files exist in the codebase (or are marked "to be created")
- [ ] Project configuration commands work (test command, lint command, etc.)
- [ ] For multi-plan: `phase_map.md` exists and has no circular dependencies

If validation fails, report what's wrong and ask the user to fix the plan or re-run `/serious-plan`.

### 0d. Set up tracking

Create the execution tracking files:

**Single plan:**
```
{plan_folder}/
├── execution_log.md        # Phase/plan status, timestamps, failures
└── evidence/               # Created if not exists
```

**Multiple plans:**
```
{plan_folder}/
├── execution_log.md        # Phase/plan status, timestamps, failures
├── plans/
│   ├── 01_xxx_progress.md  # Per-plan task tracking
│   ├── 02_xxx_progress.md
│   └── ...
└── evidence/
```

**Write `.active-code`** to the project root containing the path to the plan folder. The Stop hook reads this.

### 0e. Initialize execution_log.md

```markdown
# Execution Log

**Started:** {timestamp}
**Plan:** {single plan path or phase map path}
**Status:** In Progress

## Phases

### Phase 1 — {parallel|sequential}
| Plan | Status | Started | Completed | Notes |
|------|--------|---------|-----------|-------|
| 01_xxx | pending | — | — | |
| 02_xxx | pending | — | — | |

### Phase 2 — {parallel|sequential}
| Plan | Status | Started | Completed | Notes |
|------|--------|---------|-----------|-------|
| 03_xxx | pending | — | — | |

## Failures
(none yet)
```

### 0f. Initialize per-plan progress.md files

```markdown
# Progress: {Plan Name}

**Plan:** {plan file path}
**Status:** Pending

## Tasks

| # | Task | Status | Risk | Evidence |
|---|------|--------|------|----------|
| 1 | {task name} | pending | {L/M/H} | — |
| 1v | {verify task name} | pending | — | — |
| 2 | {task name} | pending | {L/M/H} | — |
| 2v | {verify task name} | pending | — | — |

## Failures
(none yet)

## Notes
```

---

## Phase 1: Execution

### Single Plan Execution

If there's only one plan (no phase map):

1. Present the plan summary to the user: task count, risk levels, estimated scope
2. Wait for user approval: "Go"
3. Work through tasks sequentially (see Task Execution Cycle below)
4. After each task completes, update `progress.md` and `execution_log.md`
5. After all tasks complete, proceed to Phase 2 (Completion)

### Multi-Plan Execution

If there's a phase map:

For each phase in order:

#### 1a. Present the phase

Show the user:
- Phase number and type (parallel/sequential)
- Which plans are in this phase
- Task count and risk levels per plan
- What the phase depends on (previous phases)

Wait for user approval: "Go"

#### 1b. Create worktrees (parallel phases)

For each plan in a parallel phase:
- Create a git worktree: `.claude/worktrees/serious-code-{plan_slug}`
- Each worktree gets its own branch based on current HEAD

For sequential phases: work in the main directory, no worktrees needed.

#### 1c. Dispatch plan agents

For each plan in the phase, spawn a plan agent using the Agent tool:

```
You are executing implementation plan: {plan_name}

Read the plan at: {plan_file_path}
Write your progress to: {progress_file_path}
Evidence goes in: {evidence_folder_path}

Your working directory is: {worktree_path or project_root}

For each task in the plan's Master Checklist, in order:

1. Update progress.md: mark task as in_progress
2. Dispatch the serious-code-implementer agent for the task
3. When implementer completes, dispatch verification agents in parallel:
   - serious-code-reviewer
   - serious-code-test-runner
   - serious-code-runtime-checker
   - serious-code-qa
4. Collect verification results
5. If all pass: update progress.md, mark task as completed, move to next task
6. If any fail: update progress.md with failure details, STOP, report back

Do NOT skip tasks. Do NOT continue past a failed task.
Write progress after every task completes or fails.
```

**Parallel plans:** Spawn all plan agents concurrently.
**Sequential plans:** Spawn one at a time, wait for completion.

#### 1d. Monitor and collect results

Wait for all plan agents in the phase to complete.

Update `execution_log.md` with results:
- Which plans completed successfully
- Which plans failed (and which task, and why)
- Timestamp for each

#### 1e. Merge worktrees (parallel phases)

For each completed plan's worktree, merge sequentially:

1. Merge the worktree branch into main
2. If merge conflict: **STOP**, report the conflict to the user, ask how to proceed
3. If clean merge: continue to next worktree
4. Clean up merged worktrees

Failed plans' worktrees are NOT merged. They remain for the user to inspect or resume.

#### 1f. Report phase results

Present to the user:
- Which plans succeeded, which failed
- For failures: which task, what went wrong, options (fix and resume, skip, roll back, abort)
- For successes: brief summary of what was implemented

Wait for user approval before next phase.

#### 1g. Handle failures

If a plan failed:
- The user can: fix the issue and resume (re-run the failed plan from the failed task), skip the plan, roll back the plan's changes, or abort everything
- If the failed plan is a dependency for a later phase, warn the user that skipping will affect downstream phases

---

## Task Execution Cycle

This is what happens inside each plan agent for each task. The plan agent dispatches to Agent Teams agents.

### Step 1: Implement (serious-code-implementer)

Spawn the `serious-code-implementer` agent with:
- The task description from the plan (acceptance criteria, key components, expected behavior)
- The working directory
- Instruction to follow TDD: write failing test FIRST, then implement, then make test pass

The implementer:
1. Reads the task's acceptance criteria
2. For each criterion: writes a failing test (RED), implements the code (GREEN), verifies the test passes (VERIFY)
3. Commits after each criterion passes
4. Returns: list of files changed, tests written, any issues encountered

### Step 2: Verify (4 agents in parallel)

After the implementer completes, spawn all four verification agents in parallel:

**serious-code-reviewer:**
- Reads the diff of all files changed by the implementer
- Checks: code quality, patterns, security, consistency with the plan
- Returns: PASS/FAIL with findings

**serious-code-test-runner:**
- Runs the project's static analysis command (from plan's Project Configuration)
- Runs the full test suite
- Returns: PASS/FAIL with output

**serious-code-runtime-checker:**
- Verifies each acceptance criterion's expected behavior
- May run the app, hit endpoints, check UI, or read state — depends on the project
- Returns: PASS/FAIL per criterion

**serious-code-qa:**
- Picks 3 random acceptance criteria from the task
- Independently re-verifies them (does not trust the implementer's self-report)
- Returns: PASS/FAIL per spot-check

### Step 3: Evaluate

The plan agent reads all verification results:

- **All pass:** Task is complete. Update progress.md. Move to next task.
- **Any fail:** Task failed verification. Record failure details in progress.md. STOP.

### Step 4: Evidence

After a task passes verification, the plan agent compiles evidence:

```
{evidence_folder}/
└── task_{NN}/
    ├── implementation.md    # What was done, files changed, commits
    ├── review.md            # Code reviewer findings
    ├── tests.md             # Test results, coverage
    ├── runtime.md           # Runtime verification results
    └── qa.md                # QA spot-check results
```

---

## Phase 2: Completion

After all phases complete successfully:

### 2a. Generate completion_report.md

```markdown
# Completion Report: {Project Title}

**Started:** {timestamp}
**Completed:** {timestamp}
**Plans executed:** {count}
**Phases:** {count}
**Total tasks:** {count}

## Executive Summary
{One paragraph — what was built and how it went}

## Per-Plan Results

### {Plan 01 Name}
- **Tasks:** {completed}/{total}
- **Tests:** {passing}/{total}
- **Verification:** All agents passed
- **Evidence:** {link to evidence folder}

### {Plan 02 Name}
...

## Verification Summary
| Plan | Code Review | Tests | Runtime | QA |
|------|-------------|-------|---------|-----|
| 01_xxx | PASS | PASS | PASS | PASS |
| 02_xxx | PASS | PASS | PASS | PASS |

## Issues Encountered
{List any failures, how they were resolved, and any user decisions made}

## Stats
- Total tasks implemented: {N}
- Total tests written: {N}
- Total verification agents run: {N}
- Phases: {N}
- Worktree merges: {N} (conflicts: {N})
```

### 2b. Clean up

- Remove `.active-code` breadcrumb from project root
- Clean up any remaining worktrees
- Update `execution_log.md` with final status: Complete

### 2c. Report to user

Present:
- Completion report path
- High-level summary: what was built, all tests passing, evidence collected
- Any follow-up recommendations

---

## Arguments

`$ARGUMENTS` can specify:
- A path to a plan or phase map: `/serious-code Research/features/auth/phase_map.md`
- `--resume` — resume from where a previous run stopped (reads execution_log.md)
- `--plan {name}` — execute only a specific plan from a multi-plan setup
- `--phase {N}` — start from a specific phase (skips earlier phases)

---

## Resume Mode

If `/serious-code --resume` is invoked or the orchestrator detects an existing `execution_log.md` with status "In Progress":

1. Read `execution_log.md` to find the last completed phase/plan/task
2. Read each plan's `progress.md` to find the exact stopping point
3. Present to the user: "Found an in-progress execution. Last completed: Phase {N}, Plan {X}, Task {Y}. Resume from Task {Y+1}?"
4. On approval, continue from where it left off
5. For parallel phases that partially completed: only re-run the incomplete/failed plans, skip already-completed ones

---

## Operating Rules

1. **Never skip verification.** Every task gets all 5 agents. No shortcuts.
2. **Never continue past a failed task.** Stop the plan and report up.
3. **Never merge a failed plan's worktree.** Leave it for inspection.
4. **Always write progress after every task.** The hook backs this up, but the plan agent should write explicitly too.
5. **User approval between phases.** Never start a phase without the user saying "go."
6. **Evidence is mandatory.** Every completed task gets an evidence folder.
7. **Commits should be granular.** One commit per acceptance criterion, not one mega-commit per task.
