---
name: serious-code
description: "Execute implementation plans from /serious-plan with TDD, parallel agents, and verification. Use when the user says 'serious code', 'execute the plan', 'implement the plan', 'start coding', or wants to move from planning to implementation."
user-invocable: true
---

# Serious Code

Execute implementation plans produced by `/serious-plan`. Orchestrates parallel plan execution via git worktrees, manages TDD cycles through Agent Teams, handles verification, and generates evidence.

**Position in the workflow:**
```
/serious-conversation → /serious-research → /serious-scope → /serious-plan → /serious-review → /serious-code → done
```

---

## Phase 0: Intake

### 0-pre. Check for active parent workflow

Before anything else, check for active workflow breadcrumbs in the project root:

1. **Scan for breadcrumbs:** Source `.claude/skills/_shared/path-resolve.sh`. Run `breadcrumb_sweep` once to reap orphaned per-session breadcrumbs left behind by terminals that crashed without cleanup. Then for each known skill name in the writer roster (`conversation`, `research`, `mock-ups`, `scope`, `plan`, `review`, `code`), check the per-session path first by running `bc=$(breadcrumb_path {skill})` and testing `[ -f "$bc" ]` (this resolves to `.claude-active/{claude_pid}-{skill}`); if not found, fall back to the legacy `.active-{skill}` at the project root and emit `WARN: dual-read fallback for {skill}` to stderr (transition-window cleanup will remove these in Task 6). Treat each found breadcrumb as a candidate for the validation steps below.
2. **Validate each:** For each breadcrumb found, verify the target folder exists and contains a valid output file with parseable YAML frontmatter. If not, delete the stale breadcrumb with a warning: "Removed stale .active-{skill} breadcrumb (target folder missing)."
2b. **Status-based staleness check:** For each validated breadcrumb, read the first 10 lines of the target file and grep for `^status:` to extract the value. If the value is `done` or `abandoned`, the breadcrumb is stale (skill completed but cleanup was interrupted). Remove the `.active-*` file silently — do not prompt the user.
2c. **Age-based staleness check:** If the breadcrumb's target file has `status: active`, check the `.active-*` file's modification time using Bash (`stat -f %m` on macOS or `stat -c %Y` on Linux, or `ls -l` as a portable fallback). If the file is older than 4 hours, warn: "Found .active-{skill} for {slug}, but it hasn't been modified in {N} hours. This may be from an interrupted session. Treat as active? (Y/N)". If the user says No, remove the breadcrumb and proceed. If Yes, treat as a valid active breadcrumb and continue to step 4.
3. **If no valid breadcrumbs exist:** Proceed directly to Phase 0a without any output. Do NOT mention breadcrumbs, scanning, or the absence of active workflows. This is the normal state — the previous skill completed and cleaned up its breadcrumb.
4. **Determine the deepest active workflow:** If multiple valid breadcrumbs exist, follow `parent:` chains in each breadcrumb's target frontmatter. The workflow with the longest parent chain is the deepest. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.
5. **Compare pipeline order:** This skill is `code` (order 7). The deepest active skill is order {M}.
   - **Pipeline order:** youtube-tldr(0.5) → conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7) → debug(8)
   - If 7 > {M}: this is **advancing**. Proceed directly to the next phase without any output about breadcrumbs or pipeline ordering. Both breadcrumbs coexist. Advancing means normal behavior — no new logic needed. The skill uses its existing folder rules. No parent field is set. No prompt is shown. No sub/ folder is created. Both the new skill's breadcrumb AND the existing skill's breadcrumb coexist.
   - If 7 ≤ {M}: this is **branching**. Continue to step 6.
6. **Branching prompt:**
   - **Cross-skill:** "I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"
   - **Same-skill (code → code):** "I see you're already in /serious-code for {slug}. Start a nested /serious-code within it? (Y/N)" Note: the existing `.active-code` breadcrumb will be overwritten with the new sub-workflow's path.
7. **If YES (sub-workflow):**
   - Compute proposed depth: follow `parent:` chain from the proposed parent's frontmatter, count hops until no `parent:` field, add 1.
   - **Depth guard:** If proposed depth ≥ 3, warn: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If No: do not create the sub-workflow, return without starting the new skill.
   - Set `parent` in this workflow's frontmatter to the parent's output folder path
   - Create output at `{parent_folder}/sub/{slug}/` instead of the normal location
8. **If NO:** Create output in normal location, no parent field set.
9. **Same-skill restoration:** On wrap-up/completion of this skill, if frontmatter has a `parent:` field and the parent was the same skill type (code), restore the breadcrumb by **re-running the writer block** with the parent's folder path as `${RELATIVE_OUTPUT_PATH}` and `${SKILL}=code`. The writer block writes to `.claude-active/$(claude_pid)-code`, NOT the legacy `.active-code` at the project root. This works even if the parent was itself a sub-workflow (depth 2), because the parent's frontmatter has its own parent reference, and the breadcrumb just needs to point to the immediate parent.

### 0a. Auto-detect plans

Before asking anything, scan the project:

- Check `Research/features/*/phase_map.md` for multi-plan setups — verify `status: done` in YAML frontmatter (primary), fall back to `**Status: Complete**` bold headers for legacy files
- Check `Research/features/*/implementation_plan.md` for single plans — same dual-check (YAML primary, bold header fallback)
- Check `Research/bugs/*/` and `Research/exploratory/*/` similarly
- Check sub-workflow paths: `Research/**/sub/*/implementation_plan.md` and `Research/**/sub/*/phase_map.md` (same dual-check)
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

### 0d. Upstream extract-mode pre-check

Once the upstream plan artifact is identified and validated (from 0a/0b/0c):

1. **If no upstream artifact is specified** (no `source` field or it is empty in the plan's frontmatter): output "No upstream artifact specified — skipping verification." Skip the rest of 0d.
2. **If the upstream path does not exist on disk**: warn "Upstream artifact at [path] not found — skipping verification." Proceed without blocking.
3. **Read the upstream artifact's YAML frontmatter.** If frontmatter is malformed or unparseable, warn and proceed with heading-based extraction only — do NOT block.
4. **Run extract-mode** per the protocol in `.claude/skills/_shared/handoff-verifier.md`: read the upstream artifact (the plan's `source` research.md), extract enumerable items from contract sections (Findings, Recommendations), output "Found N items from M sections in [path]. Proceeding." Write `_extracted_items.md` to this skill's output folder (the plan folder).
5. **Retroactive verification check** (immediate upstream only — do NOT recurse):
   - If the upstream artifact's frontmatter has no `verified` field, run full verification on it before proceeding.
   - If `verified_hash` exists but does not match the current upstream content hash, re-verify.
   - If the upstream artifact's own `source` field points to an unverified artifact (chain gap), warn: "Note: [upstream path]'s own upstream at [source path] has not been verified. Consider running verification on the full chain." Do NOT recurse — warn only.

### 0d-review. Review verdict check

After the plan is validated, check its YAML frontmatter for `review_status`:

- **If `review_status` is missing:** Display warning: "No review verdict found for this plan. Run `/serious-review` first? (Y/n)." If Y: stop and tell the user to run `/serious-review`. If N: proceed, log "Proceeding without review verdict."
- **If `review_status: failed`:** Display warning: "This plan FAILED review. Proceeding without fixes is not recommended. Continue anyway? (Y/n)." If Y: proceed with warning logged. If N: stop.
- **If `review_status: passed`, `passed-with-conditions`, or `override`:** Proceed silently.

This check is advisory — it never hard-blocks execution.

### 0e. Set up tracking

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

**Write `.claude-active/{claude_pid}-code`** at the project root FIRST (before creating execution_log.md). Use a SUBSHELL so `umask` does not leak to the rest of the skill, and CORRECT directory permissions if `.claude-active/` pre-exists with wider perms. Content is the relative path from project root to the plan folder. The Stop hook reads this.

```bash
(
  umask 077
  source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh"
  cad="${CLAUDE_PROJECT_DIR}/.claude-active"
  if [ -L "$cad" ]; then
    echo "FATAL: $cad is a symlink — refusing to write breadcrumbs" >&2
    exit 1
  elif [ -e "$cad" ]; then
    [ -d "$cad" ] || { echo "FATAL: $cad exists and is not a directory" >&2; exit 1; }
    chmod 700 "$cad" 2>/dev/null || { echo "FATAL: cannot enforce 0700 on $cad" >&2; exit 1; }
  else
    mkdir -p "$cad"
  fi
  bc=$(breadcrumb_path code) || exit 1
  printf '%s\n' "${RELATIVE_OUTPUT_PATH}" > "$bc"
)
```

The outer `( ... )` subshell scopes `umask 077` so the caller's umask is unchanged after this block. The pre-existing-perm correction enforces `0700` on `.claude-active/` even if a previous-version skill or attacker created it with wider perms.

### 0f. Initialize execution_log.md

```markdown
---
skill: serious-code
slug: {slug}
status: active
parent:
created: {date}
source: # Set to the path of the implementation_plan.md consumed
---

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

### 0g. Initialize per-plan progress.md files

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

<!-- GUARDRAILS — DO NOT EDIT WITHOUT REVIEWING FAILURE EVIDENCE -->

> **Before executing any task, check this table. If your planned action matches a Rationalization entry, STOP.**

| # | Rationalization | Correct action | Why it fails |
|---|----------------|----------------|--------------|
| 1 | "I'll add tests after implementation" | Write the failing test FIRST. Red-green-refactor order is mandatory. | Post-hoc tests are written to pass, not to catch. They verify what was built, not what was needed. |
| 2 | "This is a small change, tests aren't needed" | Every acceptance criterion gets a test. Size is not the criteria. | Small changes have root causes and edge cases too. Untested small changes compound into untested large systems. |
| 3 | "This component is too simple for the full process" | The process applies regardless of perceived simplicity. Follow every phase. | The 4 documented /serious-plan failures ALL occurred in "simple" features where shortcuts seemed safe. Complexity is not the threshold. |
| 4 | "I'm confident this works, no need to verify" | Run the actual command. Read the actual output. Confidence is not evidence. | Agents report "verified" without running commands. The QA sub-agent exists to catch this. |
| 5 | "The guardrail table doesn't apply to this situation" | It applies unconditionally. If you're reasoning about why a row doesn't apply, that IS the rationalization the row describes. | Second-order rationalization. The table exists because of situations that "seemed different." |
| 6 | "The plan says X but that's not actually needed" | The plan is the contract. If it's wrong, flag it as BLOCKED. Do not silently skip. | Silent scope reduction is the #1 cause of downstream plan failures. Every skipped item cascades. |
| 7 | "A general description captures the intent — the implementer will know what to do" | Name the file, the function, the type, the line range. No hedge words. | Every downstream failure in the evidence log traces to vague language ("consider", "as needed") in upstream artifacts. Vague inputs produce vague outputs. |

<!-- END GUARDRAILS -->

## Pre-Execution Commitment

**Before starting any task**, write `_commitment.md` to the plan's output folder:

```markdown
## Commitment — /serious-code
I will produce: [list every deliverable from the plan's acceptance criteria]
I will NOT skip: [list the top 3 rationalizations from the guardrail table above]
Verification: [how to check — test commands, grep patterns, file existence checks]
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
5. MANDATORY: Dispatch the Completion Gate sub-agent (Step 2.5)
   - It independently reads ALL acceptance criteria from the plan
   - It greps the codebase for implementing code per AC
   - It returns PASS/FAIL per AC
   - It writes gate_passed.md to evidence/task_{NN}/
   - A stop hook ENFORCES this — session cannot exit without it
6. If all pass + gate passed: update progress.md, mark task as completed, move to next task
7. If any fail: update progress.md with failure details, STOP, report back

Do NOT skip tasks. Do NOT continue past a failed task.
Do NOT skip the Completion Gate. The stop hook will block exit if you do.
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

#### 1f. Inter-Plan Regression Check (multi-plan only)

After all plans in a phase complete and worktrees are merged, but **before** reporting results to the user:

1. **Skip if:** This is Phase 1 (no previous phase to regress against), or `{RUNTIME_VERIFY_CMD}` is not set in any plan's Project Configuration.
2. **Collect previous phases' visible-to-user ACs:** Read the progress files and plans for all completed phases. Extract every acceptance criterion tagged "visible to user."
3. **Run regression:** For each previous-phase visible-to-user AC, use `{RUNTIME_VERIFY_CMD}` (or the equivalent check from the AC) to verify the behavior still works after the current phase's merge.
4. **If any regression found:**
   - Record the regression in `execution_log.md` under a new `## Regressions` section: which AC, which plan broke it, what the expected vs actual behavior is.
   - **STOP.** Report the regression to the user before proceeding. The user decides: fix it now (re-open the offending plan), roll back the current phase, or accept the regression.
5. **If all pass:** Note in `execution_log.md`: "Phase {N} regression check: all previous ACs verified."

This catches cases where Plan B's merge breaks something Plan A built — the exact failure mode that single-plan verification cannot detect.

#### 1g. Report phase results

Present to the user:
- Which plans succeeded, which failed
- Regression check results (if applicable)
- For failures: which task, what went wrong, options (fix and resume, skip, roll back, abort)
- For successes: brief summary of what was implemented

Wait for user approval before next phase.

#### 1h. Handle failures

If a plan failed:
- The user can: fix the issue and resume (re-run the failed plan from the failed task), skip the plan, roll back the plan's changes, or abort everything
- If the failed plan is a dependency for a later phase, warn the user that skipping will affect downstream phases

---

## Task Execution Cycle

This is what happens inside each plan agent for each task. The plan agent dispatches to Agent Teams agents.

The full cycle is: **SMOKE → STUB CHECK → RED → GREEN → VERIFY → SMOKE**

"Tests pass" is a necessary condition. "User can see/use it" is the sufficient condition.

### Step 0: Smoke Test (before implementation)

If this is Task 0 (the smoke test task from the plan), or if the task has "visible to user" acceptance criteria:

1. Ensure the application is running (launch dev server, start CLI, etc.)
2. Perform the user action described in the task
3. Capture the result: error messages, HTTP responses, screenshots, console output
4. Write the baseline to evidence: `evidence/task_{NN}/smoke_before.md`

This takes 2-5 minutes and establishes what needs to change.

### Step 1: Implement (serious-code-implementer)

Spawn the `serious-code-implementer` agent with:
- The task description from the plan (acceptance criteria, key components, expected behavior)
- The working directory
- Instruction to follow TDD: write failing test FIRST, then implement, then make test pass
- Include `TASK_ID: task_{NN}` on its own line near the top of every Agent dispatch prompt (where `{NN}` is the zero-padded task number from the plan's Master Checklist). This tag is consumed by the dispatch audit hook for traceability.

The implementer:
1. Reads the task's acceptance criteria
2. For each criterion: writes a failing test (RED), implements the code (GREEN), verifies the test passes (VERIFY)
3. Commits after each criterion passes
4. Returns: list of files changed, tests written, any issues encountered

**Monorepo awareness:** If the implementer modifies a dependency package (library, shared module), it must:
- Rebuild the modified package before testing dependents
- Restart any running dev servers that consume the modified package
- Track which packages were modified and which dependents need rebuilding

### Step 1.25: Stub Detection

After the implementer completes, scan all files changed in this task for stub patterns defined in the plan's `{STUB_PATTERNS}` configuration:

1. Get the list of files changed by the implementer
2. For each file, grep for every pattern in `{STUB_PATTERNS}`
3. If any match is found:
   - Report the file, line number, and matching pattern
   - Feed the list back to the implementer: "These patterns indicate hollow/stub code. Replace with real implementations."
   - The implementer fixes all matches
   - Re-scan until clean
4. If `{STUB_PATTERNS}` is empty or not set, skip this step

This catches empty method bodies, placeholder returns, TODO markers, and framework-specific stubs before they reach verification.

### Step 1.5: Post-Implementation Smoke Test

After the implementer completes and all unit tests pass, but **before** running the 4 verification agents:

1. If the task has "visible to user" acceptance criteria, perform a smoke test in the running app
2. If the smoke test fails despite unit tests passing, **investigate the gap**:
   - The gap is always in a layer that unit tests don't cover
   - Common culprits: caching/indexing layers, visibility culling, event propagation, z-ordering, async timing, build caches (stale code)
   - Add a test for the missing layer, fix the layer, then re-run
   - Document the missing layer in evidence so future plans include it
3. Do not proceed to Step 2 until the smoke test passes

### Step 2: Verify (4 agents in parallel)

After the implementer completes AND the smoke test passes, spawn all four verification agents in parallel.

Include `TASK_ID: task_{NN}` on its own line near the top of every Agent dispatch prompt for each verification agent (where `{NN}` is the zero-padded task number). This tag is consumed by the dispatch audit hook for traceability.

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

### Step 2.5: Completion Gate (MANDATORY — CANNOT BE SKIPPED)

> **Why this exists:** Implementing agents will build the easy parts, skip the hard parts, and self-report "done." This gate catches that. A stop hook enforces it — the session physically cannot exit without gate_passed.md for every task.

After the 4 verification agents return (Step 2), but BEFORE marking the task complete, dispatch an independent **Completion Gate sub-agent**.

Include `TASK_ID: task_{NN}` on its own line near the top of the Completion Gate Agent dispatch prompt (where `{NN}` is the zero-padded task number). This tag is consumed by the dispatch audit hook for traceability.

```
TASK_ID: task_{NN}
COMPLETION GATE — Task {task_id}: {task_name}

You are an independent verifier. You did NOT implement this code.
Your job is to verify that every acceptance criterion has implementing code
AND that the code is reachable (not dead code).

PLAN FILE: {plan_file_path}
TASK NUMBER: {task_id}

INSTRUCTIONS:
1. Read the task's acceptance criteria from the plan file
   (NOT from any implementer report or completion manifest)
2. For EACH acceptance criterion:
   a. Search the codebase for implementing code (grep, read files)
   b. Determine: does code exist that implements this criterion?
   c. Report: PASS (with file:line evidence) or FAIL (not found)
3. For EACH "visible to user" acceptance criterion, run the
   REACHABILITY CHECK (see below)
4. Output a structured report with every AC, its verdict, and evidence

REACHABILITY CHECK (for "visible to user" ACs):
Code existing in a file is NOT enough. The code must be WIRED IN.
For each new component/widget/view/endpoint:
   a. Find the new component (class, function, widget, route handler)
   b. Find its PARENT CONTAINER — the file that should render/call/mount it
   c. Verify the parent container IMPORTS the new component
   d. Verify the parent container INSTANTIATES or CALLS the new component
   e. If the new component REPLACES an old one, verify the old one is
      REMOVED from the parent container
   f. Report: WIRED (with parent file:line showing import + usage)
      or DEAD CODE (component exists but no parent references it)

DEAD CODE = FAIL. A component that exists but is never rendered,
called, or mounted is not implemented — it is dead code.

Common dead-code patterns to catch:
- Widget file created but never added to a parent widget tree
- API route handler created but never registered in the router
- Service class created but never injected/instantiated
- React component created but never imported in a page/layout
- Database migration created but never run
- CSS/style file created but never imported

RULES:
- Do NOT trust any implementer self-report
- Do NOT accept "INFRASTRUCTURE READY", "DEFERRED", "PARTIAL",
  or any status other than PASS or FAIL
- Either implementing code exists AND is reachable, or it doesn't
- If you cannot find implementing code, it is a FAIL
- If code exists but is not wired into its parent, it is a FAIL
- Tests passing is NOT evidence of implementation — the agent may
  have only written tests for the parts it built
- A unit test for a dead-code component will pass. That proves
  nothing about whether the user can see/use the component.
```

**If ANY AC is FAIL:**
- Task stays `in_progress`
- Feed the failure list back to the implementer agent
- Implementer fixes all failures
- Re-run Step 2 (verification agents) AND Step 2.5 (gate)
- Max 2 retries, then escalate to the user

**If ALL ACs PASS:**
- Write `gate_passed.md` to `evidence/task_{NN}/` with:
  - Timestamp
  - Full AC-by-AC verification log (criterion text, PASS/FAIL, file:line evidence)
  - For visible-to-user ACs: parent file:line showing import + instantiation
  - Count: {N}/{N} passed
- Only THEN may the task be marked `completed` in progress.md

> **A stop hook enforces this.** The hook is registered in `.claude/settings.json` (installed by `/serious-init`) and runs `verify-completion-gate.sh`. If any task evidence directory exists without `gate_passed.md`, the session cannot exit (hook returns exit code 2). The agent is forced to run the gate.

### Step 3: Evaluate

The plan agent reads all verification results AND the Completion Gate result:

- **All pass + gate passed:** Task is complete. Update progress.md. Move to next task.
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

## Dispatch Audit
{Read `dispatch_log.md` from the plan's evidence directory. Summarize per-task dispatch counts
and list distinct agent types dispatched for each task. If any task has fewer than 5 distinct
agent types, emit a warning. This section is advisory — warnings do not block completion.}

| Task | Dispatch Count | Distinct Agent Types | Warning |
|------|---------------|---------------------|---------|
| task_01 | {N} | {list} | {if < 5 distinct types: "WARN: fewer than 5 distinct agent types"} |
| task_02 | {N} | {list} | |
| ... | | | |
```

### 2b. Upstream Traceability Verification

Before cleanup, verify that the code execution covered everything from the upstream plan.

If the `source` field in `execution_log.md` frontmatter is empty, skip this step.

If the `source` field points to an `implementation_plan.md` (or `phase_map.md`), run the verifier:

```
.claude/skills/_shared/handoff-verifier.md
```
**Spawn a verification sub-agent using the Agent tool with the protocol described in this file. Pass these parameters:**
- **Upstream artifact:** the path in the `source` frontmatter field (`implementation_plan.md` or `phase_map.md`)
- **Downstream artifact:** the path to this skill's `completion_report.md` output (or `execution_log.md` if no completion report yet)
- **Match strategy:** `exact`

### 2c. Clean up

- Set `status: done` in the YAML frontmatter of `execution_log.md`. Then remove the breadcrumb. During the dual-read transition window, BOTH the new-path breadcrumb AND any legacy `.active-code` at project root must be removed:
  ```bash
  new_bc=$(bash -c 'source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh" && breadcrumb_path code')
  rm -f "$new_bc" "${CLAUDE_PROJECT_DIR}/.active-code"
  ```
- Clean up any remaining worktrees
- Update `execution_log.md` with final status: Complete

### 2d. Report to user

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
8. **"Tests pass" is necessary, not sufficient.** After unit tests pass, always perform a smoke test in the running app for tasks with user-visible outcomes. Do not mark a task complete until the user can see/use the result.
9. **When tests pass but the feature doesn't work, investigate the gap.** The gap is always in a layer tests don't cover — caches, indexes, visibility culling, event propagation, async timing, build caches. Add a test for the missing layer, fix it, document it.
10. **Rebuild dependencies in monorepos.** After modifying a dependency package, rebuild it before testing dependents. Restart dev servers that consume the modified package. Stale builds are a silent failure source.
11. **The completion report is not optional.** Generate `completion_report.md` with full evidence summary. If the session is interrupted, resume must generate it.
12. **The Completion Gate is enforced by a stop hook.** The hook (registered in `.claude/settings.json` by `/serious-init`) checks that every task evidence directory contains `gate_passed.md`. If any are missing, the session cannot exit (exit code 2). You MUST run Step 2.5 for every task. There is no way around this — the hook runs outside your control.
13. **"INFRASTRUCTURE READY" is not a valid status.** Every acceptance criterion is either PASS or FAIL. There is no partial credit. If code doesn't exist for an AC, it's a FAIL, even if related infrastructure was built.
14. **Dead code is not implementation.** A widget/component/handler that exists in its own file but is never imported, instantiated, or mounted by a parent container is dead code. The Completion Gate must verify reachability for all "visible to user" ACs: find the parent container, confirm it imports the new component, confirm it instantiates/renders it, confirm any replaced component is removed. Dead code = FAIL.
15. **Stub code must be caught before verification.** Step 1.25 scans for `{STUB_PATTERNS}` after implementation. If stubs are found, the implementer must replace them with real code before proceeding. An empty method body or TODO placeholder that reaches verification is a process failure.
16. **Inter-plan regression is mandatory for multi-plan phases.** After merging a phase's worktrees (Step 1f), re-verify all previous phases' visible-to-user ACs using `{RUNTIME_VERIFY_CMD}`. If any regress, stop and report before starting the next phase. A green phase that silently breaks a previous phase is worse than a red phase.

---

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| `execution_log.md` | `{plan_folder}/` | Phase/plan status, timestamps, failures |
| `completion_report.md` | `{plan_folder}/` | Final summary with evidence |
| `progress.md` | `{plan_folder}/plans/` | Per-plan task tracking (multi-plan only) |
| `evidence/` | `{plan_folder}/` | Per-task evidence artifacts |
| `status.json` | `$PLAN_DIR/` | Live status for the status line (see below) |

---

## Status JSON Output

Write `$PLAN_DIR/status.json` on every state transition: phase change, task start, task complete, agent start, agent complete. This file is the data contract consumed by the status line (Plan 4b).

**Schema reference:** See `.claude/skills/_shared/status-schema.md` for the full field inventory and type constraints.

This is single-plan status only. Cross-worktree aggregation is future work.

### Write Triggers

Update `status.json` whenever any of these events occur:

- Phase changes (start, complete)
- Task starts or completes
- Agent starts, completes, or errors (implementer, reviewer, test_runner, runtime_checker, qa)

### Sanitization Pipeline (4-step, mandatory)

Before writing any string field (`plan_name`, `worktree_name`) to `status.json`, apply this 4-step pipeline in order:

1. **Strip ALL C0 control characters** including TAB, LF, CR:
   ```bash
   sanitized=$(printf '%s' "$raw_value" | LC_ALL=C tr -d '\000-\037\177')
   ```
2. **Strip UTF-8 bidi codepoints** (U+202A-U+202E, U+2066-U+2069, U+200B-U+200F):
   ```bash
   sanitized=$(printf '%s' "$sanitized" | sed 's/[\xe2\x80\x8b-\xe2\x80\x8f]//g; s/[\xe2\x80\xaa-\xe2\x80\xae]//g; s/[\xe2\x81\xa6-\xe2\x81\xa9]//g')
   ```
3. **Truncate** to 200 bytes:
   ```bash
   sanitized=$(printf '%s' "$sanitized" | head -c 200)
   ```
4. **Serialize via JSON library** — use `python3 json.dumps()` or `jq --arg`. NEVER string-interpolate values into a JSON template, because unescaped `"` or `\` in agent strings would break JSON structure:
   ```bash
   python3 -c "
   import json
   d = {
       'version': 1,
       'plan_name': '''$sanitized_plan_name''',
       ...
   }
   print(json.dumps(d))
   "
   ```
   Or equivalently with jq:
   ```bash
   jq -n --arg plan_name "$sanitized_plan_name" ... '{version: 1, plan_name: $plan_name, ...}'
   ```

### File Permissions

Write `status.json.tmp` with mode 0600. The `mv` preserves mode.

```bash
umask 077
# ... write to status.json.tmp ...
```

### Atomic Write Pattern

Write to `$PLAN_DIR/status.json.tmp`, then `mv` to `$PLAN_DIR/status.json`. This ensures the reader never sees partial JSON.

```bash
# Write to temp file
python3 -c "import json; ..." > "$PLAN_DIR/status.json.tmp"
chmod 0600 "$PLAN_DIR/status.json.tmp"
mv "$PLAN_DIR/status.json.tmp" "$PLAN_DIR/status.json"
```

### Error Behavior

If the write or `mv` fails (disk full, permissions, missing `$PLAN_DIR`), log a warning to stderr and continue the `/serious-code` session. Do NOT abort the session — status.json is advisory, not load-bearing. The reader (Plan 4b) handles missing files gracefully.

### status.json template

```json
{
  "version": 1,
  "plan_name": "<sanitized plan name>",
  "phase": {"current": 0, "total": 0},
  "task": {"current": 0, "total": 0},
  "agents": {
    "implementer": "idle",
    "reviewer": "idle",
    "test_runner": "idle",
    "runtime_checker": "idle",
    "qa": "idle"
  },
  "worktree_name": "",
  "timestamp": "2026-04-12T00:00:00Z"
}
```
