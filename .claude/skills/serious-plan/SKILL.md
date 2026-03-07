---
name: serious-plan
description: "Generate a structured implementation plan from research, a PRD, or a brief description, using the v6 template. Use when the user says 'serious plan', 'create implementation plan', 'plan the implementation', 'write the plan', or wants to move from research to execution."
user-invocable: true
---

# Serious Plan

Generate a complete implementation plan using the v6 template methodology. Adapts to whatever input material the user has — from a full `/serious-research` deliverable down to a verbal description.

## Template Reference

The full v6 implementation plan template lives at:
```
./_implementation_plan_template_v6.md
```

**Read this file before generating any plan.** It contains the complete structure, TDD protocol, QA protocols, verification procedures, and evidence generation standards that every plan must follow.

---

## Phase 0: Intake

**Goal:** Figure out what input material exists and meet the user where they are.

### 0a. Auto-detect existing research

Before asking anything, scan the project:

- Check `Research/bugs/*/research.md`, `Research/features/*/research.md`, `Research/exploratory/*/research.md` for files with `Status: Complete`
- Check legacy paths: `Bugs/*/research.md`, `New Features/*/research.md`
- Check for `synthesis.md` files (produced by deep-mode `/serious-research`)
- Check for `mock-ups/mock-up-summary.md` alongside research files (produced by `/serious-mock-ups`)
- If `$ARGUMENTS` specifies a path, use that directly and skip to Phase 1

### 0b. Present what you found

**If exactly one completed research found:**
> "I found completed research at `Research/features/notifications/research.md`. Use this as the basis for the plan?"

**If multiple found:**
> List them and ask which one to use.

**If nothing found**, present the options:

1. **"Point me to your `/serious-research` output"** — if they ran it but the folder is somewhere unexpected, they give you the path.
2. **"I have a PRD, spec, or requirements doc"** — they provide a file path or paste content. This could be a formal PRD, a Jira ticket, a design doc, meeting notes — anything with requirements.
3. **"Run `/serious-research` first"** — if they realize they need deeper investigation before planning. Hand off to `/serious-research` and stop.
4. **"I'll describe what I want"** — lightest path. They describe the feature/fix in conversation and you work from that.

### 0c. Validate the input

Whatever the source, assess whether there's enough to generate a quality plan:

**Sufficient for planning:**
- Clear description of what to build or fix
- Enough context to identify affected files/components
- Enough detail to write testable acceptance criteria

**Insufficient — ask clarifying questions (2-4 max):**
- What's the expected user-facing behavior?
- What components/systems does this touch?
- Are there constraints (performance, compatibility, security)?
- What does "done" look like?

**If input is a brief description (option 4), add a disclaimer to the plan:**
> "This plan was generated from a brief description, not structured research. Consider running `/serious-research` if you need higher confidence before implementation."

### 0d. Assess scope — single plan or multiple plans?

Before creating any files, assess whether the work should be one plan or many:

**Single plan** when:
- The work is focused on one concern (e.g., "fix the auth token expiry bug")
- Tasks are tightly coupled — most depend on each other
- 3-7 tasks total

**Multiple plans** when:
- The work spans multiple independent concerns (e.g., "add user auth" touches backend, frontend, and integration)
- Groups of tasks can be worked on in parallel by separate agents
- More than 7 tasks, or tasks that naturally cluster by component/layer/concern

If multiple plans: identify the clusters and propose them to the user. Each cluster becomes its own focused plan. The user approves the split before you generate.

### 0e. Determine the plan location

**Single plan:**
- **If input came from `/serious-research`:** Create `implementation_plan.md` in the same folder as the research.
- **If input came from a PRD or description:** Create a folder under `Research/features/{slug}/` (or `bugs/` or `exploratory/` as appropriate), put the plan there, and save the input material alongside it for traceability.

**Multiple plans:**
- Create the folder under `Research/features/{slug}/` (or `bugs/` / `exploratory/`)
- Create a `plans/` subdirectory for the individual plans
- Create `phase_map.md` at the root of the folder

```
Research/features/{slug}/
├── phase_map.md                         # Execution order — which plans run when
├── plans/
│   ├── 01_{concern_a}.md                # Focused plan (follows v6 template)
│   ├── 02_{concern_b}.md                # Focused plan
│   ├── 03_{concern_c}.md                # Focused plan
│   └── 04_{integration}.md              # Often depends on earlier plans
├── research.md                          # If from /serious-research
└── evidence/                            # Shared evidence root
```

---

## Phase 1: Plan Generation

Read the v6 template file first. If a `mock-ups/mock-up-summary.md` exists alongside the research, read it too — use the component inventory for task breakdown, design decisions for acceptance criteria, screen flow for navigation tasks, and responsive notes for breakpoint tasks.

Then work through each section in order, filling it in based on the input material.

**If generating multiple plans:** Generate each plan independently using the full v6 template structure below. Each plan must be self-contained — an agent should be able to execute it without reading the other plans. Then generate the phase map (see Phase 1b).

### Executive Summary
- One paragraph: what, why, who, why it matters
- Key outcomes (3-5 bullet points)
- Derive from the research findings, PRD, or user description

### Project Configuration
- Fill the variable table (`{EVIDENCE_ROOT}`, `{STATIC_ANALYSIS_CMD}`, etc.)
- Detect project tooling from the codebase: package.json, Makefile, pyproject.toml, etc.
- If unsure about a command, check the codebase or ask the user
- Set `{EVIDENCE_ROOT}` to `./evidence` inside the plan folder

### Product Manager Review
- Translate findings into feature descriptions
- Each feature gets: What it is, Why it matters, User perspective
- Keep it non-technical — a PM should understand this section

### Pre-Flight Readiness
- Adapt the checklist to this specific project
- Verify each item is actually checkable (commands exist, paths are real)

### Test-Driven Development Protocol
- Copy the v6 TDD Protocol section verbatim — it is non-negotiable
- This section defines the RED→GREEN→REFACTOR→VERIFY cycle that applies to every task

### Plan Review — Adaptive Persona Pipeline with Convergence

Persona reviews are iterative — they run in rounds until the plan converges.

#### Severity Classification

Every issue found by a persona must be tagged with a severity:

| Severity | Definition | Examples |
|----------|-----------|---------|
| **Critical** | Architectural flaw, security vulnerability, incorrect requirements, broken dependency chain | Wrong auth model, missing data validation, circular task dependency |
| **Major** | Significant gap, missing acceptance criteria, wrong component, incomplete rollback plan | Missing error handling for a key flow, task missing a dependency |
| **Minor** | Formatting, wording, minor optimization, style preference | Rename a variable, reword a criterion, add a note |

#### Convergence Rules

After each review round, the orchestrator tallies severities and decides:

- **Any critical found** → fix and re-review (mandatory)
- **3+ majors found** → fix and re-review
- **Majors < 3, no criticals** → fix and done
- **Minors only** → fix and done
- **Max 3 rounds** regardless (safety cap — escalate to user if still not clean)

#### Individual Plan Review (per plan)

1. **Select appropriate personas** based on what the plan touches:
   - Use the persona catalog from the v6 template as your starting point
   - Not every plan needs every persona — a backend-only fix doesn't need an End User review
   - Follow the scaling guidance table in the template
2. **Phase A** (Persona Reviews): Run selected personas. Each tags findings with severity.
3. **Phase B** (Mechanical Reviews): Senior Engineer + Integration Architect — always required.
4. **Rewrite** — issues get fixed in the plan, not appended as notes.
5. **Convergence check** — apply the rules above. If another round is needed, re-run with the same personas reviewing the updated plan.
6. Document: which personas reviewed, how many rounds, what was found and fixed per round.

#### Cross-Plan Integration Review (multiple plans only)

Runs AFTER all individual plan reviews have converged.

**Integration personas (always selected for multi-plan):**

| Persona | Focus |
|---------|-------|
| **Integration Architect** | Do plans compose correctly? Shared interfaces, data contracts, API boundaries, schema consistency |
| **Merge Strategist** | Will branches merge cleanly? File conflicts, migration ordering, shared config changes |

**Optional (selected based on what plans touch):**

| Persona | When to include |
|---------|----------------|
| **Concurrency Engineer** | Plans touch shared state, caches, async operations, or event ordering |

**Integration review flow:**
1. Integration personas read ALL plans + the phase map
2. Issues are tagged with severity and routed to the specific plan(s) they affect
3. Affected plans are fixed
4. **Convergence check** — same severity rules. If another integration round is needed, re-run.
5. If fixes significantly changed a plan → that plan gets one more individual review round to verify internal consistency
6. Max 3 integration rounds (safety cap)

**The full review sequence:**
1. Individual plan reviews converge (up to 3 rounds each)
2. Integration review converges (up to 3 rounds)
3. If integration fixes changed plans → one more individual round for affected plans
4. All plans are now reviewed and stable

### Inline QA Protocol v6
- Copy the v6 Inline QA Protocol section verbatim — it is non-negotiable
- The protocol must appear in every plan so the implementing agent has it in context
- v6 integrates TDD: every acceptance criterion gets a failing test FIRST, then implementation, then QA sub-agent verification

### Master Checklist / Progress Dashboard

**Task 0 is always a smoke test.** Before any implementation tasks, the checklist must start with:

```
Task 0: Smoke Test — Reproduce the problem (or baseline the current behavior) in the running application.
```

This is not a unit test. It's launching the app, performing the user action, and capturing what happens. The output becomes the baseline that implementation must improve.

After Task 0, create implementation tasks:
- Pair each implementation task with a verification task (N + Nv)
- Assign risk levels (L/M/H) based on complexity and blast radius
- Order tasks by dependency (independent tasks first, dependent tasks later)
- Aim for **3-7 implementation tasks** — decompose large work, combine trivial items
- **Interleave browser/app verification gates** — don't save all user-visible testing for the end. After each cluster of related changes, include a verification step that checks behavior in the running app.

**The final task must always be a user-visible verification:** the same smoke test from Task 0, which should now pass.

### Evidence Generation Protocol
- Copy from the v6 template — adapt the evidence types table to this project's task categories
- Set up the evidence directory structure
- v6 uses markdown reports (not HTML)

### Task Descriptions
For each task, fill in:
- **Risk level** with justification
- **Intent** — one sentence on what the task accomplishes
- **Scope clarity** — explicitly state what "done" means for this task:
  - Does "done" mean the data model is correct? (schema/API layer)
  - Does "done" mean the user can see/interact with the result? (rendering/UI layer)
  - Does "done" mean the full round-trip works? (create → persist → reload → still there)
  - If a task only covers the data layer, say so, and ensure a later task covers the user-visible layer.
- **Context** — why it exists, dependencies, what it enables
- **Expected behavior** — the user-visible outcome
- **Key components** — specific files and functions
- **Impact analysis** — what other components consume the output of the changed code? Follow the chain:
  - What calls the changed function?
  - What renders data from the changed data source?
  - What caches/indexes recompute when this data changes?
  - List each downstream consumer and whether it handles the new behavior correctly.
- **Acceptance criteria** — concrete, testable `- [ ]` items (see quality bar below)
- **Negative tests** — what should NOT happen
- **Evidence requirements** — specific proof items
- **TDD note** — the v6 reminder that every criterion requires a failing test first
- **Rollback plan** — how to undo safely
- **Notes** — edge cases, gotchas

**Quality bar for acceptance criteria:**
- Every criterion must be verifiable by a QA sub-agent reading code or interacting with the app
- No vague criteria ("works correctly") — specify what "correct" means
- Include the specific component, property, or behavior to check
- Every criterion must be encodable as a test (TDD requirement)
- **Every task with a user-facing outcome must include at least one "visible to user" criterion** — phrased as: "A user performing [action] sees [result]." These criteria cannot be verified by unit tests alone — they require a running application check.
- Structural criteria (function accepts X, API returns Y) are necessary but **insufficient** for UI/UX tasks. Always pair them with a user-visible criterion.

### Appendix
- Technical decisions (from research or inferred from requirements)
- Dependencies (libraries, APIs, services)
- Out of scope (explicitly list what this plan does NOT cover)
- Changelog (track plan revisions)
- Input source (link to research.md, PRD, or note that it was generated from a description)

### Phase 1b: Phase Map (multiple plans only)

After all plans are generated, create `phase_map.md`:

```markdown
# Phase Map: {Project Title}

## Overview
{One paragraph — what's being built and how it's been decomposed}

## Plans
| # | Plan | Concern | Tasks | Risk |
|---|------|---------|-------|------|
| 01 | 01_backend_auth.md | Backend auth service | 4 | M |
| 02 | 02_frontend_login.md | Login UI + form validation | 3 | L |
| 03 | 03_api_endpoints.md | REST API endpoints | 5 | M |
| 04 | 04_integration_tests.md | End-to-end integration | 3 | H |

## Execution Phases

### Phase 1 — parallel
Plans: 01, 02, 03
Rationale: These three plans are independent — backend, frontend, and API can be built concurrently with no shared state.

### Phase 2 — sequential
Plans: 04
Rationale: Integration tests depend on all three components being complete.
Depends on: Phase 1

## Dependency Graph
01 ──┐
02 ──┤──→ 04
03 ──┘
```

**Rules for phase assignment:**
- Plans with NO dependencies on other plans go in the earliest phase
- Plans that depend on others go in the phase after their dependencies complete
- Within a phase, all plans run in parallel (separate agents)
- If two plans modify the same files, they CANNOT be in the same phase — flag this to the user
- Each phase must complete fully before the next phase starts

---

## Phase 2: Self-Review

Before presenting to the user, verify each plan:

- [ ] Every file path referenced actually exists in the codebase (or is clearly marked as "to be created")
- [ ] Every command in Project Configuration actually works (run them)
- [ ] Task dependencies are consistent (no circular deps, correct ordering)
- [ ] Acceptance criteria are specific enough for a QA sub-agent to verify
- [ ] Acceptance criteria are specific enough to write a test for (TDD requirement)
- [ ] Risk levels make sense (H for shared state/security, M for standard features, L for config/boilerplate)
- [ ] The plan is self-contained — an agent could execute it without asking questions
- [ ] Task 0 is a smoke test that reproduces the problem in the running app
- [ ] The final task is a user-visible verification (same smoke test, now passing)
- [ ] Every task with a user-facing outcome has at least one "visible to user" acceptance criterion
- [ ] Every task has an impact analysis listing downstream consumers of changed code
- [ ] Each task's scope is explicit about what "done" means (data layer, UI layer, or full round-trip)
- [ ] TDD Protocol section is present and unmodified
- [ ] Inline QA Protocol v6 section is present and unmodified
- [ ] Input source is documented in the Appendix

**Additional checks for multiple plans:**
- [ ] No two plans in the same phase modify the same files
- [ ] Each plan is truly self-contained — no implicit dependencies on another plan's work
- [ ] The phase map's dependency graph has no circular dependencies
- [ ] Phase ordering is correct — no plan runs before its dependencies complete
- [ ] Shared evidence root is consistent across all plans

---

## Phase 3: Present to User

**Single plan — report:**
- The plan file path
- The input source used (research, PRD, or description — with disclaimer if applicable)
- Summary of what's planned (task count, estimated complexity)
- The recommended persona review set
- Any questions or decisions that need user input before implementation can begin

**Multiple plans — report:**
- The phase map file path
- How many plans were generated and why the work was split this way
- The phase structure: which plans run in parallel, which are sequential
- Per-plan summary (concern, task count, risk level)
- Total task count across all plans
- The recommended persona review set (may differ per plan)
- Any cross-plan dependencies or shared-file risks to flag

---

## Arguments

`$ARGUMENTS` can specify:
- A path to research: `/serious-plan Research/features/notifications/research.md`
- A path to a PRD or spec: `/serious-plan docs/prd-notifications.md`
- Or nothing — the skill will auto-detect or ask

---

## What Comes After

Once the user approves the plan(s):

**Single plan:**
1. The plan goes through the **Adaptive Persona Pipeline** review (Phase A + Phase B)
2. Fixes from review are rewritten into the plan
3. Run `/serious-code` to begin implementation
4. `/serious-code` follows the Master Checklist with TDD, QA, and verification

**Multiple plans:**
1. Each plan goes through persona review independently
2. Fixes are rewritten into each plan
3. Run `/serious-code` — it reads `phase_map.md` and orchestrates execution
4. Phase 1 plans are dispatched to parallel agents (one agent per plan)
5. When Phase 1 completes, Phase 2 begins, and so on
6. Each plan's agent follows TDD, QA, and verification independently
7. Evidence reports are generated per task, per plan
8. Summary report is generated across all plans at the end
