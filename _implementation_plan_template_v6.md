# Implementation Plan: [PROJECT NAME]

---

## Executive Summary

[One paragraph explaining what we're building at the highest level. What is the product? What problem does it solve? Who is it for? Why does it matter?]

**Key Outcomes:**
- [Outcome 1]
- [Outcome 2]
- [Outcome 3]

---

## Project Configuration

> **Fill this section before starting any tasks.** These values are referenced throughout the plan as `{VARIABLE_NAME}` placeholders.

| Variable | Value | Description |
|----------|-------|-------------|
| `{EVIDENCE_ROOT}` | `./evidence` | Root directory for all evidence artifacts |
| `{STATIC_ANALYSIS_CMD}` | e.g. `npm run lint && npm run typecheck` | Static analysis command(s) for changed files |
| `{DEV_SERVER_CMD}` | e.g. `npm run dev` | Command to start the development server |
| `{TEST_CMD}` | e.g. `npm test` | Command to run unit/integration tests |
| `{RUNTIME_LOGS_CMD}` | e.g. `browser console` or `tail -f app.log` | How to capture runtime errors |
| `{BUILD_CMD}` | e.g. `npm run build` | Production build command |
| `{VERIFICATION_AGENT}` | e.g. `Playwright MCP`, `Puppeteer`, `curl` | Primary tool for runtime verification |
| `{SCREENSHOT_TOOL}` | e.g. `Playwright screenshot`, `browser_take_screenshot` | Tool used to capture visual evidence |
| `{MAX_RETRIES}` | `3` | Max verification failures before escalating to user |

---

## Product Manager Review

### Feature Overview

[Brief introduction to the features being developed in this implementation phase.]

### Features

#### Feature 1: [Feature Name]

**What it is:** [One sentence description]

**Why it matters:** [Business value and user benefit]

**User perspective:** [How will users interact with this? What problem does it solve for them?]

---

#### Feature 2: [Feature Name]

**What it is:** [One sentence description]

**Why it matters:** [Business value and user benefit]

**User perspective:** [How will users interact with this? What problem does it solve for them?]

---

## Pre-Flight Readiness

> **Complete before starting any implementation task.** All items must be checked.

- [ ] **Dependencies installed** — `{BUILD_CMD}` or equivalent succeeds without errors
- [ ] **Environment configured** — `.env` (or equivalent) has all required variables
- [ ] **Dev server starts** — `{DEV_SERVER_CMD}` launches without errors
- [ ] **Static analysis baseline** — `{STATIC_ANALYSIS_CMD}` passes (or known issues documented)
- [ ] **Test suite baseline** — `{TEST_CMD}` passes (or known failures documented)
- [ ] **Evidence directory exists** — `{EVIDENCE_ROOT}/assets/` created
- [ ] **Mock/seed data ready** — Any required test data is in place
- [ ] **Git branch created** — Working on the correct feature branch

---

## Test-Driven Development Protocol

> **Tests are written BEFORE or ALONGSIDE implementation, never after.** This section defines the TDD workflow that applies to every implementation task.

### The TDD Cycle

Every implementation task follows this cycle for each unit of work:

```
1. RED    — Write a failing test that defines the expected behavior
2. GREEN  — Write the minimum code to make the test pass
3. REFACTOR — Clean up the code while keeping tests green
4. VERIFY — Run the full relevant test suite to check for regressions
```

### When to Write Tests

| Situation | Test Approach |
|-----------|--------------|
| **New function/module** | Write tests first — define the contract before the implementation |
| **New user-facing behavior** | Write behavioral tests first — "when user does X, Y happens" |
| **Bug fix** | Write a failing test that reproduces the bug, then fix it |
| **Refactor** | Ensure tests exist and pass before refactoring, then verify they still pass after |
| **Schema/data model change** | Write validation tests first — edge cases, required fields, type coercion |
| **Integration point** | Write integration tests that verify the contract between components |

### Test Quality Rules

1. **Tests must be behavioral, not structural.** Test what the code does, not how it does it. A test that breaks when you rename a private method is a bad test.
2. **Each test should test one thing.** If a test name contains "and", split it.
3. **Tests must be independent.** No test should depend on another test running first.
4. **Tests must be deterministic.** No flaky tests. If it fails intermittently, fix it or delete it.
5. **Edge cases are mandatory.** Empty inputs, null values, boundary conditions, error paths — these are where bugs live.

### TDD in the Task Workflow

Each task description includes acceptance criteria. For every acceptance criterion:

1. **Write the test first** — the test encodes the acceptance criterion as executable code
2. **Run the test** — confirm it fails (RED phase). If it passes without new code, the criterion was already met or the test is wrong.
3. **Implement** — write the code to make it pass
4. **Run all relevant tests** — confirm everything passes (no regressions)
5. **Move to next criterion**

> **The implementing agent must not skip the RED phase.** A test that was never seen failing provides no confidence. The RED phase proves the test is actually checking something.

---

## Plan Review — Adaptive Persona Pipeline

> **MANDATORY before implementation begins.** Every plan must pass through persona reviews and mechanical verification. The reviewing agent decides which personas, how many, and in what order — based on what this specific plan actually touches.

### How It Works

The review process has two phases:

1. **Phase A — Persona Reviews** (variable count, agent's choice)
2. **Phase B — Mechanical Reviews** (always required, fixed)

The reviewing agent reads the plan, assesses what it touches (UI? backend? API? data model? multi-component?), and selects the appropriate personas from the catalog below. The agent MAY also create new personas not in the catalog if the plan demands expertise the defaults don't cover.

### Phase A — Persona Reviews

#### Instructions for the Reviewing Agent

```
You are reviewing an implementation plan before it gets built. Your job is to
select which persona reviews are needed, then execute them.

READ THE PLAN FIRST. Then decide:

1. WHICH personas from the catalog below are relevant to this plan?
   - A backend-only data model change does NOT need an End User review.
   - A one-line boolean fix does NOT need 5 personas.
   - A new user-facing feature DOES need the End User persona.
   - A concurrent/async change DOES need the Concurrency Engineer persona.
   - A cross-component change needs the Integration Architect in Phase B.

2. HOW MANY personas to run?
   - Minimum: 1 (for trivial single-scope changes)
   - Typical: 2-3 (for most feature work)
   - Maximum: as many as the plan warrants (for complex, multi-component features)

3. Should you CREATE a new persona?
   - If the plan touches a domain none of the defaults cover well
     (e.g., accessibility auditor, performance engineer, database specialist,
     DevOps engineer, security researcher), create one.
   - Define it with the same structure: Focus, Reviewer Checks, Verdict criteria.

4. EXECUTE the selected reviews in the order that makes sense.
   - User-facing personas first (they catch UX issues that inform technical fixes).
   - Apply corrections from each review before running the next.
   - Each reviewer sees the UPDATED plan, not the original.

5. DOCUMENT your selection rationale at the top of the review output:
   "Selected N personas: [list]. Rationale: [why these, why not others]."

6. REWRITE THE PLAN after each review.
   - Persona reviews are a REWRITING PROCESS, not a deliverable.
   - For every issue found, go back into the implementation plan and rewrite
     the affected task descriptions, expected behaviors, and notes.
   - If a finding requires new work, add new tasks to the Progress Dashboard.
   - The persona review file exists as an audit trail; the plan is the
     single source of truth.
```

#### Persona Catalog (Defaults)

These are starting points. The reviewing agent is free to use all, some, or none — and to create new ones as needed.

---

##### Persona: End User

**When to use:** Plan includes UI visible to users, interaction flows, or features where usability matters.

**Focus:** Is the user-facing experience intuitive, responsive, and predictable?

**Reviewer checks:**
1. Every user action has clear, immediate visual feedback.
2. Primary flows are discoverable without documentation.
3. Error states are handled gracefully with clear messaging.
4. Undo/cancel paths exist for destructive or significant actions.
5. Edge cases in user input are handled (empty, too long, special characters, rapid repeated actions).
6. The feature behaves consistently with existing patterns in the product.

**Verdict:**
- **PASS:** Flow is intuitive with no critical usability gaps.
- **FAIL:** List every usability issue and required fix.

---

##### Persona: API Consumer / Agent Developer

**When to use:** Plan includes API endpoints, data model changes, SDK interfaces, or features that external consumers (human developers or AI agents) interact with programmatically.

**Focus:** Can a developer or agent use this feature correctly with minimal friction?

**Reviewer checks:**
1. API contracts are explicit — input types, output types, error types are all defined.
2. Naming is consistent with existing conventions (no mixed camelCase/snake_case, no ambiguous field names).
3. Error responses are informative (not just "400 Bad Request" — include what was wrong and how to fix it).
4. Minimal tool call sequence to accomplish common goals.
5. Round-trip integrity: data written via API reads back correctly via API and renders correctly in UI.
6. Edge cases: what happens with missing optional fields, extra unknown fields, empty arrays, null values?

**Verdict:**
- **PASS:** API is consistent, well-typed, and usable without guesswork.
- **FAIL:** List every ambiguity, inconsistency, or missing contract.

---

##### Persona: Concurrency / Systems Engineer

**When to use:** Plan involves shared mutable state, async operations, file I/O, race conditions, event ordering, caching, or multi-process coordination.

**Focus:** Are there race conditions, lost updates, deadlocks, or ordering bugs?

**Reviewer checks:**
1. Shared mutable state is protected (mutexes, atomic operations, or immutable patterns).
2. Async operations have defined ordering guarantees (or explicitly document that ordering is not guaranteed).
3. Error recovery releases locks and cleans up resources (no deadlocks on failure).
4. Fire-and-forget operations can't corrupt state if they resolve out of order.
5. File I/O uses atomic writes or write-ahead patterns to prevent partial writes.
6. Optimistic updates have rollback paths if the server rejects the mutation.

**Verdict:**
- **PASS:** No race conditions, deadlocks, or ordering bugs found.
- **FAIL:** List every concurrency issue with specific fix.

---

##### Persona: QA Engineer

**When to use:** Plan includes testable behavior — which is nearly always. Skip only for pure documentation or configuration changes.

**Focus:** Are the acceptance criteria testable? Are edge cases covered? Are there gaps in the test plan?

**Reviewer checks:**
1. Every acceptance criterion is specific enough to write a test for (no "works correctly" without defining what correct means).
2. Negative tests are defined — what should happen on invalid input, missing data, timeout, permission denied?
3. Boundary conditions are identified — empty lists, max-length strings, zero values, off-by-one scenarios.
4. State transitions are fully specified — what happens if the user interrupts mid-operation?
5. Test data requirements are defined — what fixtures or seed data do tests need?
6. Regression risks are identified — what existing behavior could this change break?

**Verdict:**
- **PASS:** Acceptance criteria are testable, edge cases covered, no gaps.
- **FAIL:** List every untestable criterion, missing edge case, or gap.

---

##### Persona: Security Reviewer

**When to use:** Plan involves authentication, authorization, API endpoints, data storage, user input handling, or credential management.

**Focus:** Are there security vulnerabilities in the proposed implementation?

**Reviewer checks:**
1. No credentials, tokens, or secrets in source code.
2. Input validation at system boundaries (user input, API requests, file uploads).
3. Authorization checks on protected routes/endpoints.
4. No injection vectors (SQL, NoSQL, command injection, XSS).
5. Sensitive data encrypted at rest and in transit.
6. CORS, CSP, and other security headers configured appropriately.

**Verdict:**
- **PASS:** No security vulnerabilities found.
- **FAIL:** List every vulnerability with severity and fix.

---

#### Creating Custom Personas

The reviewing agent may create personas not in the catalog. Use this structure:

```markdown
##### Persona: [Name]

**When to use:** [Conditions that make this persona relevant]

**Focus:** [One-sentence summary of what this persona evaluates]

**Reviewer checks:**
1. [Check 1]
2. [Check 2]
3. [Check 3]
4. [Check 4]

**Verdict:**
- **PASS:** [What passing looks like]
- **FAIL:** [What failing looks like and what must be listed]
```

**Examples of custom personas you might create:**
- **Performance Engineer** — for plans with animation, real-time updates, large datasets, or latency-sensitive operations
- **Accessibility Auditor** — for plans with new UI components or interaction patterns
- **Data Architect** — for plans involving schema migrations, data model evolution, or storage changes
- **DevOps Engineer** — for plans involving CI/CD, deployment, infrastructure, or monitoring
- **Domain Expert** — for plans requiring specialized knowledge (e.g., medical, financial, legal)

---

### Phase B — Mechanical Reviews (Always Required)

These two passes run on EVERY plan regardless of scope. They catch factual errors that persona reviews can't.

---

#### Senior Engineer Review

**Focus:** Are the mechanical details correct? Can an agent execute this plan without guessing?

**Reviewer checks:**

##### File Path Verification
| # | Plan Reference | Actual (exists? line count?) | Verdict |
|---|---------------|------------------------------|---------|
| 1 | `path/to/file.ext` | Exists, N lines | CONFIRMED / WRONG |

##### Line Number Verification
For every BEFORE block in the plan:
1. Read the actual file at the specified line range
2. Compare the plan's BEFORE code with the actual code
3. Verdict: MATCH / MISMATCH (with correct code if mismatched)

##### API Signature Verification
For every function call, endpoint, or constructor the plan references:
1. Verify the function/endpoint exists with the expected signature
2. Verify parameter names, types, and order match
3. Verdict: CONFIRMED / WRONG (with correct signature)

##### Import Path Verification
For every import statement in AFTER blocks:
1. Verify the import path resolves to an actual file
2. Verify project conventions are followed (e.g., relative vs package imports)
3. Verdict: CONFIRMED / WRONG (with correct path)

##### Verdict
- **PASS:** All file paths, line numbers, BEFORE blocks, API signatures, and imports are correct.
- **FAIL:** List every discrepancy. Plan must be fixed and re-reviewed.

---

#### Integration Architect Review

**Focus:** Do plans conflict with each other? Are shared files handled safely? Is merge order specified?

**Scope:** Review ALL plans in the current phase together (not individually).

##### Shared File Conflicts
For every file modified by more than one plan:

| File | Plans That Touch It | Lines/Sections Modified | Compatible? |
|------|--------------------|-----------------------|-------------|
| `path/to/file.ext` | Plan A (Task 2), Plan B (Task 1) | A: lines 40-50, B: lines 120-130 | YES — different sections |

##### Cross-Plan Dependencies
| Dependency | Reason | Build Order Implication |
|-----------|--------|----------------------|
| Plan X before Plan Y | Y reads a field that X creates | X must be implemented first |

##### Shared Data Contracts
For fields, models, or API payloads used by multiple plans:
1. Verify all plans agree on field name, type, and format.
2. Verify producer and consumer are consistent.

##### Import Collision Check
When multiple plans add imports to the same file, verify no duplicates or conflicts.

##### Verdict
- **PASS:** No conflicts, dependencies documented, merge order specified.
- **FAIL:** List every conflict. Specify which plan must be modified and how.

---

### Review Execution Rules

1. **Phase A persona reviews must complete before Phase B mechanical reviews.** Persona feedback may change the plan, which invalidates mechanical verification.
2. **Corrections cascade forward.** Each review assumes prior fixes are applied.
3. **A FAIL at any review blocks the next.** Fix first, then advance.
4. **Phase A reviews are per-plan. Integration Architect review is cross-plan.** Follow this scope strictly.
5. **The reviewer persona cannot be the same agent that wrote the plan.** Use the Agent tool to spawn separate review agents.
6. **Document persona selection.** The first line of the review output must state which personas were selected and why.
7. **Parallel execution encouraged.** Independent persona reviews (those that don't inform each other) can run in parallel. Phase B reviews can also run in parallel with each other.

### Review Output Files

```
{PLAN_DIR}/review_personas.md       — All Phase A persona reviews (with selection rationale)
{PLAN_DIR}/review_engineer.md       — Senior Engineer (per-plan, Phase B)
{PLAN_DIR}/review_integration.md    — Integration Architect (cross-plan, Phase B)
```

### Scaling Guidance

| Plan Scope | Recommended Persona Count | Example Selection |
|------------|--------------------------|-------------------|
| One-line config/boolean fix | 1 | Senior Engineer only (skip Phase A entirely) |
| Single-file bug fix | 1-2 | QA Engineer + Senior Engineer |
| Single-component feature | 2-3 | End User + QA Engineer + Senior Engineer |
| Multi-component feature | 3-4 | End User + API Consumer + QA Engineer + Senior Engineer |
| Feature with async/concurrency | 3-4 | Concurrency Engineer + QA Engineer + Senior Engineer + Integration Architect |
| New user-facing interaction pattern | 3-5 | End User + QA Engineer + (Accessibility Auditor) + Senior Engineer |
| Security-sensitive change | +1 | Add Security Reviewer to whatever else is selected |
| Backend-only (no UI) | 1-2 | Senior Engineer + (Security Reviewer if auth-related) |

---

## Inline QA Protocol v6

> **THIS IS THE SINGLE MOST IMPORTANT SECTION IN THIS DOCUMENT.**
>
> Experience proves that agents read implementation plans, then deviate during coding. The plan is correct; the execution drifts. End-of-task QA catches problems too late — hours of wrong work must be redone. The fix is **per-item verification**: code one item, verify it, fix it, then move to the next.

### The Protocol — For EVERY Acceptance Criterion

```
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: TEST (TDD Red Phase)                                   │
│  Write a failing test that encodes the acceptance criterion.    │
│  Run it. Confirm it fails.                                      │
├─────────────────────────────────────────────────────────────────┤
│  STEP 2: CODE (TDD Green Phase)                                 │
│  Implement the minimum code to make the test pass.              │
├─────────────────────────────────────────────────────────────────┤
│  STEP 3: VERIFY (Mandatory — DO NOT SKIP)                       │
│                                                                 │
│  Spawn a QA sub-agent (Agent tool) with this prompt:            │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ QA VERIFICATION — Task [ID], Item [N]                      │ │
│  │                                                            │ │
│  │ PLAN REQUIREMENT:                                          │ │
│  │ [Paste the exact acceptance criterion from the plan]       │ │
│  │                                                            │ │
│  │ TEST FILE:                                                 │ │
│  │ [Path to the test that was written for this criterion]     │ │
│  │                                                            │ │
│  │ FILES CHANGED:                                             │ │
│  │ [List the files that were created/modified]                │ │
│  │                                                            │ │
│  │ INSTRUCTIONS:                                              │ │
│  │ 1. Read the plan requirement for this item                 │ │
│  │ 2. Read the test — does it actually test the requirement?  │ │
│  │ 3. Read the implementation code                            │ │
│  │ 4. Run the test: {TEST_CMD} [test file]                    │ │
│  │ 5. Answer: Does the code match the plan requirement?       │ │
│  │    - YES: State what you verified and why it passes        │ │
│  │    - NO: State exactly what's wrong and how to fix it      │ │
│  │ 6. If the item is a UI element, verify via                 │ │
│  │    {VERIFICATION_AGENT} (screenshot or DOM inspection)     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  STEP 4: FIX (if QA sub-agent says NO)                          │
│  Fix the code, then re-run STEP 3 on the same item.            │
│  Do NOT move to the next item until this one passes.            │
├─────────────────────────────────────────────────────────────────┤
│  STEP 5: LOG                                                    │
│  Record in the completion manifest:                             │
│  - Item number                                                  │
│  - QA verdict (PASS / FAIL→FIX)                                │
│  - What was verified (test name + runtime check if applicable)  │
│  - If fixed: what was wrong and what changed                    │
└─────────────────────────────────────────────────────────────────┘
```

### QA Sub-Agent Prompt Template

Copy-paste this for each item:

```
You are a QA verification agent. Your ONLY job is to check if code matches a plan
requirement. Be strict. Be literal. If the plan says "use mutex" and the code uses
a bare promise chain without lock semantics, that is a FAIL.

TASK: [Task ID] — [Task Name]
ITEM: [N] — [Paste exact text of acceptance criterion]
PLAN FILE: [Path to this implementation plan file]
PLAN SECTION: [Task heading in the plan]
TEST FILE: [Path to the test file for this item]
CODE FILES: [List of files to read]

Read the plan requirement. Read the test. Read the code. Answer:
1. VERDICT: PASS or FAIL
2. TEST QUALITY: Does the test actually verify the requirement? (YES/NO — if NO, the test must be rewritten)
3. EVIDENCE: Quote the specific code that proves pass/fail
4. If FAIL: Exact fix required (what to change, in which file, at which location)
5. If UI item: Verify via {VERIFICATION_AGENT} and describe what you see
```

### Checklist Item Categories

| Category | Example | Verification Rule |
|----------|---------|-------------------|
| **A: Data/Schema** | "node has a `label` field of type string" | Unit test required. Verify individually. |
| **B: API Contract** | "create-node returns the new node with its ID" | Integration test required. Verify individually. |
| **C: Behavior/State** | "clicking Delete removes the node from canvas" | Behavioral test + runtime check. Verify individually. |
| **D: Architecture Rules** | "no direct DOM manipulation outside render layer" | Code review. May batch up to 3 in same file. |
| **E: Edge Cases** | "empty text field defaults to placeholder" | Unit test required. May batch up to 3 in same file. |

### Inline QA Log Format (Required in Completion Manifest)

```markdown
## Inline QA Log

| # | Acceptance Criterion (abbreviated) | Test File | QA Verdict | Evidence | Fix Applied |
|---|-------------------------------------|-----------|:----------:|----------|-------------|
| 1 | Node created with correct type | node.test.ts:42 | PASS | Test passes, node.type === "sticky" | — |
| 2 | Delete removes connected edges | delete.test.ts:88 | FAIL→FIX | Was not removing edges | Added cascade delete at line 120 |
| 3 | ... | ... | ... | ... | ... |

**Items verified:** 14/14
**Items that needed fixes:** 2
**All items passing:** YES
```

### Non-Negotiable Rules

1. **Every acceptance criterion gets a test and gets verified.** No exceptions. No "I'm confident this is right."
2. **QA sub-agent is independent.** It reads the plan, the test, and the code. It does not trust the implementing agent's self-report.
3. **Failures are fixed immediately.** Not logged for later. Fixed now, re-verified now.
4. **The QA sub-agent cannot approve its own work.** Use the Agent tool to spawn a separate agent.
5. **Completion manifests without an inline QA log are rejected.**
6. **UI items require runtime verification.** The QA sub-agent must verify via {VERIFICATION_AGENT}, not just read the code.

---

## Master Checklist

### Instructions for the Implementing Agent

> **CRITICAL: You must follow these rules exactly.**
>
> 1. **Save at checkpoints.** Update this file at four checkpoints per task: **start time**, **end time/totals**, **verdict**, and **blocker/change** (if any). Do not batch — save immediately at each checkpoint.
>
> 2. **Check the checkbox** when you begin a task. This serves as a visual indicator of which task is currently in progress.
>
> 3. **Workflow for each IMPLEMENTATION task (numbered N):**
>    - Check the checkbox → Save (start checkpoint)
>    - Write start time → Save
>    - **For EACH acceptance criterion in the task description:**
>      1. Write a failing test (RED)
>      2. Implement the code (GREEN)
>      3. Spawn a QA sub-agent to verify it matches the plan (see Inline QA Protocol)
>      4. If FAIL: fix the code and/or test, re-verify until PASS
>      5. Log the result in the Inline QA Log
>      6. **Do NOT proceed to the next criterion until this one passes**
>    - After all items pass: Run `{STATIC_ANALYSIS_CMD}` on changed files (capture output)
>    - Run `{TEST_CMD}` — full relevant suite (capture output)
>    - Write end time, total time, human estimate, multiplier → Save (end checkpoint)
>    - **Immediately proceed to the paired verification task (Nv)**
>
> 4. **Workflow for each VERIFICATION task (numbered Nv):**
>    - Check the checkbox → Save (start checkpoint)
>    - Write start time → Save
>    - **First: Audit the Inline QA Log** — verify it exists, all items are logged, no gaps
>    - **Then: Launch verification sub-agents in parallel** (see "Split-Agent Verification" below):
>      - **Agent A (Code Review)** — reads changed files, checks for defects and code smells
>      - **Agent B (Static + Tests)** — runs `{STATIC_ANALYSIS_CMD}` and `{TEST_CMD}`, captures output
>      - **Agent C (Runtime)** — UI/API tasks only: navigates app, tests interactions, checks logs
>      - **Agent D (Inline QA Spot-Check)** — picks 3 random items from the Inline QA Log and independently re-verifies them
>    - Wait for all agents to complete. Collect their output.
>    - **Merge results** into the evidence report.
>    - **Apply verdict:** ALL agents must report PASS for an overall PASS. ANY agent FAIL = overall FAIL.
>    - Update the Evidence column → Save (verdict checkpoint)
>    - Write end time → Save
>    - **If FAIL:** Increment the Attempts column. Fix the issue, then launch NEW sub-agents for re-verification.
>    - **If FAIL and Attempts = `{MAX_RETRIES}`:** STOP. Update Status to `BLOCKED`. Write the blocker → Save. Ask the user for guidance.
>    - **If PASS:** Move to next implementation task.
>
> 5. **Time format:** Use `HH:MM` (24-hour format) for start/end times. Use minutes for total time and estimates.
>
> 6. **Multiplier calculation:** `Multiplier = Human Estimate ÷ Total Time`. Express as `Nx` (e.g., `10x` means 10 times faster than human estimate).
>
> 7. **If blocked:** Note the blocker in the task description section below, set Status to `BLOCKED`, and move to the next unblocked task.

### Progress Dashboard

| Done | # | Task Name | Risk | Start | End | Total (min) | Human Est. (min) | Multiplier | Status | Attempts | Evidence | Blocker |
|:----:|:-:|-----------|:----:|:-----:|:---:|:-----------:|:----------------:|:----------:|:------:|:--------:|:--------:|:-------:|
| ⬜ | 1 | Implement: [Task name] | M | | | | | | pending | — | — | |
| ⬜ | 1v | Verify: [Task name] | | | | | | | pending | 0 | | |
| ⬜ | 2 | Implement: [Task name] | M | | | | | | pending | — | — | |
| ⬜ | 2v | Verify: [Task name] | | | | | | | pending | 0 | | |
| ⬜ | 3 | Implement: [Task name] | M | | | | | | pending | — | — | |
| ⬜ | 3v | Verify: [Task name] | | | | | | | pending | 0 | | |

> **Risk levels:** L = Low (boilerplate, config), M = Medium (feature work, standard logic), H = High (complex logic, shared state, concurrency)

> **Status values:** `pending` | `in_progress` | `passed` | `failed` | `blocked`

**Summary:**
- Total tasks: [X] (implementation) + [X] (verification) = [X] total
- Completed: [X]
- Passed verification: [X] / [X]
- Failed then passed: [X]
- Blocked: [X]
- Total time spent: [X] minutes
- Total human estimate: [X] minutes
- Overall multiplier: [X]x

---

## Evidence Generation Protocol

### Overview

Every implementation task is paired with a verification task that produces an **evidence report**. This report proves the feature works correctly and can be reviewed by any team member.

### Evidence Directory

```
{EVIDENCE_ROOT}/
├── assets/                  ← screenshots and large artifacts
│   ├── task_01_screen.png
│   ├── task_01_after.png
│   └── ...
├── task_01_report.md        ← individual task reports (markdown)
├── task_02_report.md
├── ...
└── summary.md               ← rollup of all task verdicts
```

> **Screenshots and large artifacts go in `assets/` and are linked from reports.**

### Evidence Types by Task Category

| Task Category | Required Evidence |
|---------------|-------------------|
| **Backend (API/Service)** | API response verification, server logs, data store query showing created/modified records |
| **UI (new component)** | `{STATIC_ANALYSIS_CMD}` output, screenshot(s), `{RUNTIME_LOGS_CMD}` output, interaction test |
| **UI (modified component)** | `{STATIC_ANALYSIS_CMD}` output, before/after screenshots, interaction test |
| **Data model/Schema** | `{TEST_CMD}` output, validation tests for edge cases |
| **Integration (end-to-end)** | Full flow screenshots, server logs, client logs |
| **Refactoring** | Test suite output (before and after, same results) |

### Report Template (Markdown)

Each `task_NN_report.md` follows this structure:

```markdown
# Evidence Report — Task [N]: [Task Name]

**Verdict:** PASS / FAIL
**Generated:** [YYYY-MM-DD HH:MM]
**Duration:** [X] min
**Attempt:** [N] of {MAX_RETRIES}

## 0. Inline QA Log

[Paste the full Inline QA Log table]

**Items verified:** [X]/[X] | **Items needing fixes:** [X] | **All passing:** YES/NO

## 1. Static Analysis

**Command:** `{STATIC_ANALYSIS_CMD}`
**Result:** [0 errors, N warnings] — PASS/FAIL

## 2. Test Results

**Command:** `{TEST_CMD} [relevant test files]`
**Result:** [X passed, Y failed, Z skipped] — PASS/FAIL

**Regression check:** `{TEST_CMD}` (full suite)
**New failures:** [none / list]

## 3. Visual Evidence (UI tasks only)

**Screenshots:** [link to assets/task_NN_screen.png]
**Observations:** [what the screenshot confirms]

## 4. Runtime Verification (UI/API tasks only)

**Actions performed:**
1. [Action → Result]
2. [Action → Result]

**Runtime errors:** [none / details]

## 5. Inline QA Spot-Check

**3 random items re-verified by Agent D:**

| Item # | Original Verdict | Spot-Check Verdict | Match | Notes |
|--------|------------------|--------------------|-------|-------|
| [N] | PASS | PASS | YES | [what was checked] |

**Spot-check result:** ALL MATCH / MISMATCH FOUND — PASS/FAIL

## 6. Overall Verdict

**Result:** PASS / FAIL
**Notes:** [observations, warnings, follow-up items]
```

### Summary Report

After all tasks complete, generate `{EVIDENCE_ROOT}/summary.md`:

| Task | Name | Risk | Verdict | Attempts | QA Items | QA Fixes | Duration |
|------|------|------|---------|----------|:--------:|:--------:|----------|
| 1 | [name] | M | PASS | 1 | 14/14 | 2 | X min |
| 2 | [name] | H | FAIL → PASS | 2 | 18/18 | 5 | X min |

---

### Split-Agent Verification

> **CRITICAL: Verification must be performed by SEPARATE sub-agents, NOT by the agent that wrote the code.**
>
> The implementing agent must NOT verify its own work. Instead, it launches **up to four focused sub-agents in parallel**, each with a narrow scope.

#### Why split verification?

| Concern | Single agent | Split agents |
|---------|-------------|-------------|
| **Depth** | Broad but shallow — context-switches between reading code and running tests | Each agent goes deep on its scope |
| **Speed** | Sequential: code review → static analysis → runtime → report | Parallel: all four run simultaneously |
| **Failure isolation** | "FAIL" — but which part failed? | Clear signal: "Code Review PASS, Tests PASS, Runtime FAIL" |
| **Bias** | One agent forming one opinion | Four independent assessments |

#### Agent Overview

| Agent | Scope | When to Launch | Output |
|-------|-------|----------------|--------|
| **A — Code Review** | Read changed files, check for defects, code smells, security issues | Always | `{EVIDENCE_ROOT}/assets/task_NN_code_review.json` |
| **B — Static + Tests** | Run `{STATIC_ANALYSIS_CMD}` and `{TEST_CMD}`, capture output | Always | `{EVIDENCE_ROOT}/assets/task_NN_test_results.json` |
| **C — Runtime** | Navigate app, take screenshots, test interactions, check logs | UI and API tasks only | `{EVIDENCE_ROOT}/assets/task_NN_runtime.json` |
| **D — Inline QA Spot-Check** | Pick 3 random items from Inline QA Log, independently re-verify | Always | `{EVIDENCE_ROOT}/assets/task_NN_qa_spotcheck.json` |

> **Launch agents A, B, and D always.** Launch agent C only when the task involves UI or API behavior.

---

#### Agent A — Code Review

```
You are an IMPARTIAL CODE REVIEWER. Your only job is to read the changed files
and find defects. You do NOT run any commands, tests, or tools. You only READ.

## Your Mindset
- Be skeptical. Assume the implementation has bugs until proven otherwise.
- A FAIL verdict is a GOOD outcome if it catches a real issue.
- If something looks "probably fine," flag it anyway — another agent will test it.

## Files Changed
[list the files that were created or modified]

## Task Requirements
[paste the task description and acceptance criteria]

## What to Check

### Code Correctness
- Logic errors, off-by-one, missing null/undefined checks
- Incorrect conditional logic or missing branches
- Race conditions or async issues (missing await, unhandled promises)
- Edge cases the implementer may have missed

### Code Hygiene
- Hardcoded values that should use constants/config
- Unused imports or variables
- Missing or incorrect types
- Inconsistent naming conventions

### Code Smells
- TODO/FIXME comments left behind
- Commented-out code that should have been deleted
- Console.log / debug statements left in production code
- Copy-pasted code that wasn't adapted to context

### Security
- Exposed secrets, API keys, or credentials
- Missing input validation at system boundaries
- Injection vectors (SQL, command, XSS)

### Acceptance Criteria Check
- For each criterion, verify the code logically implements it
- For each negative test, verify the code handles the failure case

## Output
Write a JSON file to: {EVIDENCE_ROOT}/assets/task_[NN]_code_review.json

{
  "agent": "code_review",
  "task": [N],
  "verdict": "PASS" | "FAIL",
  "findings": [
    {
      "severity": "error" | "warning" | "info",
      "file": "path/to/file.ts",
      "line": 42,
      "category": "logic" | "hygiene" | "smell" | "security" | "acceptance",
      "description": "Description of the finding"
    }
  ],
  "summary": "One-paragraph summary"
}

## Verdict Rules
- ANY finding with severity "error" = FAIL
- Warnings and info items are noted but don't cause FAIL
```

---

#### Agent B — Static Analysis + Tests

```
You are a TEST RUNNER. Your only job is to run static analysis and tests,
then report the results.

## Commands to Run

### Step 1 — Static Analysis
Run: {STATIC_ANALYSIS_CMD}
Capture the FULL output.

### Step 2 — Relevant Tests
Run: {TEST_CMD} [relevant test files or directories]
Capture the FULL output.

### Step 3 — Full Test Suite (regression check)
Run: {TEST_CMD}
Capture the FULL output. Flag any tests that were passing before but now fail.

## Files Changed
[list the files — use to identify relevant test files]

## Output
Write a JSON file to: {EVIDENCE_ROOT}/assets/task_[NN]_test_results.json

{
  "agent": "static_and_tests",
  "task": [N],
  "verdict": "PASS" | "FAIL",
  "static_analysis": { "command": "...", "errors": 0, "warnings": 0, "output": "..." },
  "relevant_tests": { "command": "...", "passed": 0, "failed": 0, "skipped": 0, "output": "..." },
  "regression_check": { "command": "...", "new_failures": [], "output": "..." }
}

## Verdict Rules
- Static analysis errors > 0 = FAIL
- Any relevant test failure = FAIL
- Any regression = FAIL
- Warnings alone do NOT cause FAIL
```

---

#### Agent C — Runtime Verification

> **Launch only for UI or API tasks.** Skip for pure refactoring, config, or internal logic tasks.

```
You are a RUNTIME TESTER. Your only job is to interact with the running
application and verify it behaves correctly.

## Prerequisites
- Dev server must be running at {DEV_SERVER_CMD}
- If it's not running, start it and wait for it to be ready

## Task Requirements
[paste the task description, acceptance criteria, and negative tests]

## Verification Steps

### Step 1 — Navigate and Verify
1. Open the relevant page/endpoint using {VERIFICATION_AGENT}
2. Verify the page renders correctly (no layout issues, expected content visible)
3. Take a screenshot: save to {EVIDENCE_ROOT}/assets/task_[NN]_screen.png

### Step 2 — Interaction Test
1. Perform the primary user action
2. Verify the expected result
3. Take an after-interaction screenshot: {EVIDENCE_ROOT}/assets/task_[NN]_after.png

### Step 3 — Negative Tests
For each negative test in the acceptance criteria:
1. Perform the invalid/edge-case action
2. Verify graceful handling (no crash, clear feedback)

### Step 4 — Runtime Errors
1. Check {RUNTIME_LOGS_CMD} for errors
2. Capture any errors or confirm "No errors"

## Output
Write a JSON file to: {EVIDENCE_ROOT}/assets/task_[NN]_runtime.json

{
  "agent": "runtime",
  "task": [N],
  "verdict": "PASS" | "FAIL",
  "screenshots": [ { "path": "...", "description": "..." } ],
  "interactions": [ { "action": "...", "result": "PASS|FAIL", "detail": "..." } ],
  "negative_tests": [ { "case": "...", "result": "PASS|FAIL", "detail": "..." } ],
  "runtime_errors": "No errors" | "Error details",
  "summary": "One-paragraph summary"
}

## Verdict Rules
- Page fails to render = FAIL
- Primary interaction doesn't work = FAIL
- Any negative test causes a crash = FAIL
- Runtime errors in logs = FAIL
```

---

#### Agent D — Inline QA Spot-Check

> **Launch always.** This agent validates that the inline QA process was honest.

```
You are an INLINE QA AUDITOR. Your only job is to verify that the implementing
agent's Inline QA Log is honest and accurate.

## Inline QA Log
[paste the full Inline QA Log table]

## Plan Requirements
[paste the full task description with all acceptance criteria]

## Files Changed
[list all files that were created or modified]

## Your Job

### Step 1 — Completeness Check
1. Count the total acceptance criteria + negative tests in the plan
2. Count the items in the Inline QA Log
3. If there's a gap = FAIL

### Step 2 — Random Spot-Check (3 items)
Pick 3 items at random (different categories if possible). For each:
1. Read the plan requirement
2. Read the test file for that item
3. Read the actual code
4. Does the code match the plan requirement?
5. Compare your verdict with the Inline QA Log
6. If the log says PASS but the code doesn't match = MISMATCH (critical)

## Output
Write a JSON file to: {EVIDENCE_ROOT}/assets/task_[NN]_qa_spotcheck.json

{
  "agent": "qa_spotcheck",
  "task": [N],
  "verdict": "PASS" | "FAIL",
  "completeness": { "plan_items": N, "log_items": N, "complete": true/false },
  "spot_checks": [
    {
      "item_number": N,
      "plan_says": "...",
      "log_says": "PASS",
      "reviewer_says": "PASS",
      "match": true,
      "evidence": "..."
    }
  ],
  "summary": "One-paragraph summary"
}

## Verdict Rules
- Inline QA Log incomplete = FAIL
- ANY spot-check mismatch = FAIL → triggers FULL re-verification
- All checks match and log complete = PASS
```

---

#### Report Merge (Implementing Agent)

After all sub-agents complete, the implementing agent assembles the report. This is **mechanical** — no judgment, just assembly.

1. Read all JSON output files
2. **Verdict rule:** ALL agents PASS = overall PASS. ANY agent FAIL = overall FAIL.
3. Build the markdown report from the template above
4. Save to `{EVIDENCE_ROOT}/task_NN_report.md`
5. Update the Progress Dashboard

#### On FAIL

- Read the failing agent's output to understand what failed
- Fix the issue(s)
- Launch NEW sub-agents for re-verification (fresh eyes)
- Repeat until PASS or `{MAX_RETRIES}` reached

#### On Escalation (max retries reached)

- Set Status to `BLOCKED` in the Progress Dashboard
- Document clearly: which agent(s) failed, what they reported, what was tried
- Ask the user for guidance

---

## Task Descriptions

This section provides context for each task. Read the relevant description before starting implementation.

---

### Task 1: [Task Name]

**Risk:** [L / M / H]

**Intent:** [What is this task trying to accomplish?]

**Context:** [Why does this task exist? What depends on it? What does it depend on?]

**Expected behavior:** [How should this feature work when complete?]

**Key components:**
- [Component/file 1]
- [Component/file 2]
- [Component/file 3]

**Acceptance criteria:**
- [ ] [Positive criterion 1 — specific, testable, behavioral]
- [ ] [Positive criterion 2]
- [ ] [Positive criterion 3]

**Negative tests:**
- [ ] [Negative test 1 — e.g., "Invalid input returns error, not crash"]
- [ ] [Negative test 2 — e.g., "Missing required field returns 400 with field name"]

**Evidence requirements:**
- [ ] [Specific evidence item 1 — e.g., "Test suite output showing all tests pass"]
- [ ] [Specific evidence item 2 — e.g., "Screenshot of created node on canvas"]
- [ ] [Specific evidence item 3 — e.g., "API response showing correct JSON structure"]

> **TDD (v6):** Every acceptance criterion above requires a failing test FIRST, then implementation, then independent QA sub-agent verification. The Inline QA Log must include test file references for each item.

**Rollback plan:** [How to undo this task if it breaks something]

**Notes:** [Special considerations, edge cases, gotchas]

---

### Task 2: [Task Name]

**Risk:** [L / M / H]

**Intent:** [What is this task trying to accomplish?]

**Context:** [Why does this task exist? What depends on it? What does it depend on?]

**Expected behavior:** [How should this feature work when complete?]

**Key components:**
- [Component/file 1]
- [Component/file 2]

**Acceptance criteria:**
- [ ] [Positive criterion 1]
- [ ] [Positive criterion 2]

**Negative tests:**
- [ ] [Negative test 1]

**Evidence requirements:**
- [ ] [Evidence 1]
- [ ] [Evidence 2]

> **TDD (v6):** Every acceptance criterion above requires a failing test FIRST, then implementation, then independent QA sub-agent verification. The Inline QA Log must include test file references for each item.

**Rollback plan:** [How to undo this task]

**Notes:** [Special considerations]

---

[Add more task descriptions as needed]

---

## Appendix

### Technical Decisions

[Document any significant technical decisions made during planning]

### Dependencies

[List external dependencies, APIs, or libraries required]

### Out of Scope

[Explicitly list what is NOT being built in this implementation phase]

### Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1-v4 | — | Prior iterations (healthcare-specific) |
| v5 | 2026-03-01 | Adaptive Persona Pipeline, split-agent verification, inline QA protocol |
| **v6** | **2026-03-04** | **Generalized for any project. TDD protocol integrated as first-class workflow (RED→GREEN→VERIFY per criterion). Healthcare-specific personas removed; replaced with general-purpose catalog (End User, API Consumer, Concurrency Engineer, QA Engineer, Security Reviewer). Agent-driven persona selection emphasized with explicit rewriting process. Evidence reports simplified to markdown. Inline QA Log now includes test file references.** |
