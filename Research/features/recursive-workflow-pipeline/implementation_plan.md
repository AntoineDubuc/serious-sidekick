# Implementation Plan: Recursive Workflow Pipeline — Phase 1

---

## Executive Summary

Add recursive/nested workflow support to the Serious Sidekick skill system. This means any `/serious-*` skill can spawn sub-workflows that nest inside their parent, creating a tree of related work instead of a flat sequence. The user gets two new commands (`/serious-status` to see everything, `/serious-abandon` to bail on a sub-workflow) and all six existing skills learn to detect active parents, link to them, and nest their output folders accordingly.

**Key Outcomes:**
- All 6 workflow skills support YAML frontmatter with `parent:`, `status:`, `skill:`, `slug:`, `created:` fields
- All 6 skills have breadcrumb files (`.active-*`) for parent detection
- All 6 skills distinguish "advancing" (research → plan) from "branching" (plan → sub-research) and only prompt for sub-workflow linking on branches
- `/serious-status` displays a flat table of all workflows with tree indentation
- `/serious-abandon` marks sub-workflows as abandoned and returns to parent context

---

## Project Configuration

> **Fill this section before starting any tasks.** These values are referenced throughout the plan as `{VARIABLE_NAME}` placeholders.

| Variable | Value | Description |
|----------|-------|-------------|
| `{EVIDENCE_ROOT}` | `./Research/features/recursive-workflow-pipeline/evidence` | Root directory for all evidence artifacts |
| `{STATIC_ANALYSIS_CMD}` | `N/A — prompt files, not executable code` | No static analysis for SKILL.md files |
| `{DEV_SERVER_CMD}` | `N/A` | No dev server |
| `{TEST_CMD}` | `N/A — manual verification by reading files` | No automated test suite |
| `{RUNTIME_LOGS_CMD}` | `N/A` | No runtime logs |
| `{BUILD_CMD}` | `N/A` | No build step |
| `{VERIFICATION_AGENT}` | `File reading + diff comparison` | Verify by reading modified SKILL.md files |
| `{SCREENSHOT_TOOL}` | `N/A` | No visual output |
| `{MAX_RETRIES}` | `2` | Max verification attempts |

**Project type:** Prompt engineering — all deliverables are SKILL.md markdown instruction files. Verification is done by reading the files and checking for required sections/patterns, not by running tests.

---

## Product Manager Review

### Feature Overview

Users of Serious Sidekick currently work through a linear pipeline: conversation → research → mock-ups → plan → code → review. But real work isn't linear — during planning you discover sub-problems that need their own research, during code you find gaps that need their own conversation. This feature lets users "open a new tab" for any sub-problem without losing their place in the main workflow.

### Features

#### Feature 1: Parent Linking

**What it is:** When you invoke a skill while another workflow is active, the system detects this and offers to link the new work as a sub-workflow of the active one.

**Why it matters:** Without this, sub-problems get created as disconnected top-level workflows. The user loses the relationship between "I was working on auth and discovered I need to research token expiry separately."

**User perspective:** "I'm mid-planning for auth. I type `/serious-research token expiry`. The system says: 'You're in /serious-plan for auth. This looks like a sub-problem. Link as sub-workflow?' I say yes. My research nests inside the auth folder."

#### Feature 2: Workflow Status Dashboard

**What it is:** `/serious-status` — a single command that shows all active, done, and abandoned workflows in a flat table with tree indentation for parent-child relationships.

**Why it matters:** As workflows accumulate and nest, the user needs a way to see the big picture. "What am I working on? What's done? What did I abandon?"

**User perspective:** "I type `/serious-status` and see a clean table showing my auth workflow at the top, with its two sub-researches indented below — one done, one active."

#### Feature 3: Sub-Workflow Abandonment

**What it is:** `/serious-abandon` — marks the current sub-workflow as abandoned, preserves its files, and returns to the parent workflow with a summary of where things stand.

**Why it matters:** Not every sub-investigation pans out. The user needs a clean way to say "this isn't going anywhere" and return to the parent without losing work.

**User perspective:** "I type `/serious-abandon`. The system marks my token-expiry research as abandoned, tells me 'Returning to auth planning. The plan was at task 3.' I'm back where I was."

---

## Pre-Flight Readiness

> **Complete before starting any implementation task.** All items must be checked.

- [ ] **Repository is clean** — no uncommitted changes that could conflict with SKILL.md edits
- [ ] **All 6 skill files exist** — verify paths in `.claude/skills/serious-{conversation,research,mock-ups,plan,code,review}/SKILL.md`
- [ ] **Research is available** — `Research/features/recursive-workflow-pipeline/research.md` exists with Status: Complete
- [ ] **Global profiles identified** — `~/.claude/skills/`, `~/.claude-work/skills/`, `~/.claude-alex/skills/` exist
- [ ] **Evidence directory exists** — `Research/features/recursive-workflow-pipeline/evidence/` created
- [ ] **Git branch created** — working on a feature branch (or main, per user preference)

---

## Test-Driven Development Protocol

> **Tests are written BEFORE or ALONGSIDE implementation, never after.** This section defines the TDD workflow that applies to every implementation task.

### Adaptation for Prompt Engineering

This project modifies SKILL.md instruction files, not executable code. The TDD cycle is adapted:

- **RED:** Define what the SKILL.md file MUST contain (specific sections, patterns, field names) as acceptance criteria
- **GREEN:** Edit the SKILL.md to include the required content
- **VERIFY:** Read the modified file and check that every acceptance criterion is met (grep for required patterns, verify section structure)
- **REFACTOR:** Ensure consistency across all 6 skill files

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

1. **Tests must be behavioral, not structural.** Test what the code does, not how it does it.
2. **Each test should test one thing.** If a test name contains "and", split it.
3. **Tests must be independent.** No test should depend on another test running first.
4. **Tests must be deterministic.** No flaky tests.
5. **Edge cases are mandatory.** Empty inputs, null values, boundary conditions, error paths.

### TDD in the Task Workflow

Each task description includes acceptance criteria. For every acceptance criterion:

1. **Write the test first** — the test encodes the acceptance criterion as executable code
2. **Run the test** — confirm it fails (RED phase)
3. **Implement** — write the code to make it pass
4. **Run all relevant tests** — confirm everything passes (no regressions)
5. **Move to next criterion**

> **The implementing agent must not skip the RED phase.** A test that was never seen failing provides no confidence.

---

## Plan Review — Adaptive Persona Pipeline with Convergence

### Severity Classification

| Severity | Definition | Examples |
|----------|-----------|---------|
| **Critical** | Architectural flaw, security vulnerability, incorrect requirements, broken dependency chain | Wrong pipeline order, missing breadcrumb causing infinite loop, parent check that fires on advancing |
| **Major** | Significant gap, missing acceptance criteria, wrong component, incomplete rollback plan | Missing status update on completion, incomplete scan paths, forgot a skill |
| **Minor** | Formatting, wording, minor optimization, style preference | Inconsistent field names, verbose prompt wording, reorder sections |

### Convergence Rules

- **Any critical found** → fix and re-review (mandatory)
- **3+ majors found** → fix and re-review
- **Majors < 3, no criticals** → fix and done
- **Minors only** → fix and done
- **Max 3 rounds** regardless

### Recommended Persona Review Set

| Persona | Rationale |
|---------|-----------|
| **QA Engineer** | Verify acceptance criteria are specific and testable for prompt files |
| **Senior Engineer** | Verify file paths exist, section structure is correct, no gaps |
| **DX Advocate** (custom) | Verify the parent-link prompt UX is not annoying, status output is scannable |

---

## Inline QA Protocol v6

> **THIS IS THE SINGLE MOST IMPORTANT SECTION IN THIS DOCUMENT.**

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
│  │ FILES CHANGED:                                             │ │
│  │ [List the files that were created/modified]                │ │
│  │                                                            │ │
│  │ INSTRUCTIONS:                                              │ │
│  │ 1. Read the plan requirement for this item                 │ │
│  │ 2. Read the modified file                                  │ │
│  │ 3. Answer: Does the file match the plan requirement?       │ │
│  │    - YES: State what you verified and why it passes        │ │
│  │    - NO: State exactly what's wrong and how to fix it      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  STEP 4: FIX (if QA sub-agent says NO)                          │
│  Fix the file, then re-run STEP 3 on the same item.            │
│  Do NOT move to the next item until this one passes.            │
├─────────────────────────────────────────────────────────────────┤
│  STEP 5: LOG                                                    │
│  Record in the completion manifest:                             │
│  - Item number                                                  │
│  - QA verdict (PASS / FAIL→FIX)                                │
│  - What was verified                                            │
│  - If fixed: what was wrong and what changed                    │
└─────────────────────────────────────────────────────────────────┘
```

### Non-Negotiable Rules

1. **Every acceptance criterion gets verified.** No exceptions.
2. **QA sub-agent is independent.** It reads the plan and the file. It does not trust the implementing agent.
3. **Failures are fixed immediately.** Not logged for later.
4. **Completion manifests without an inline QA log are rejected.**

---

## Master Checklist

### Progress Dashboard

| Done | # | Task Name | Risk | Start | End | Total (min) | Human Est. (min) | Multiplier | Status | Attempts | Evidence | Blocker |
|:----:|:-:|-----------|:----:|:-----:|:---:|:-----------:|:----------------:|:----------:|:------:|:--------:|:--------:|:-------:|
| ⬜ | 0 | Smoke Test: Verify current state | L | | | | 15 | | pending | — | — | |
| ⬜ | 1 | Implement: YAML frontmatter standard + .gitignore | L | | | | 30 | | pending | — | — | |
| ⬜ | 1v | Verify: YAML frontmatter standard + .gitignore | | | | | | | pending | 0 | | |
| ⬜ | 2 | Implement: Add breadcrumbs + frontmatter + status update to all 6 skills | H | | | | 120 | | pending | — | — | |
| ⬜ | 2v | Verify: All 6 skills have breadcrumbs + frontmatter + status update | | | | | | | pending | 0 | | |
| ⬜ | 3 | Implement: Add parent check (0-pre) to all 6 skills | H | | | | 90 | | pending | — | — | |
| ⬜ | 3v | Verify: Parent check logic in all 6 skills | | | | | | | pending | 0 | | |
| ⬜ | 4 | Implement: Create /serious-status skill | M | | | | 60 | | pending | — | — | |
| ⬜ | 4v | Verify: /serious-status skill | | | | | | | pending | 0 | | |
| ⬜ | 5 | Implement: Create /serious-abandon skill | M | | | | 60 | | pending | — | — | |
| ⬜ | 5v | Verify: /serious-abandon skill | | | | | | | pending | 0 | | |
| ⬜ | 6 | Implement: Update auto-detection scan paths + copy to global profiles | L | | | | 30 | | pending | — | — | |
| ⬜ | 6v | Verify: Scan paths + profiles updated | | | | | | | pending | 0 | | |
| ⬜ | 7 | Final verification: Invoke /serious-status against existing Research/ | L | | | | 15 | | pending | — | — | |

> **Risk levels:** L = Low (boilerplate, config), M = Medium (feature work, standard logic), H = High (complex logic, many files, cross-cutting concerns)

**Summary:**
- Total tasks: 7 (implementation) + 6 (verification) + 1 (smoke test) = 14 total
- Completed: 0
- Passed verification: 0 / 6
- Total human estimate: 420 minutes (~7 hours)

---

## Evidence Generation Protocol

### Overview

Every implementation task is paired with a verification task that produces an **evidence report**. Since this is a prompt-engineering project, evidence consists of file diffs and pattern checks rather than test output.

### Evidence Directory

```
Research/features/recursive-workflow-pipeline/evidence/
├── task_00_smoke_test.md
├── task_01_report.md
├── task_02_report.md
├── task_03_report.md
├── task_04_report.md
├── task_05_report.md
├── task_06_report.md
└── summary.md
```

### Evidence Types

| Task Category | Required Evidence |
|---------------|-------------------|
| **SKILL.md modification** | Before/after diff of modified sections, grep confirmation of required patterns |
| **New SKILL.md** | Full file review, section checklist, consistency check with standard |
| **.gitignore update** | Diff showing added patterns |
| **Profile copy** | md5 checksum comparison across profiles |

---

## Task Descriptions

---

### Task 0: Smoke Test — Verify Current State

**Risk:** L

**Intent:** Baseline the current state of all skill files to confirm what needs changing.

**Scope:** Read-only. No modifications.

**Expected behavior:** Produce a report showing:
- Which skills have breadcrumbs (should be: conversation, research, code)
- Which skills lack breadcrumbs (should be: mock-ups, plan, review)
- Which skills use YAML frontmatter (should be: none)
- What format research.md uses for metadata (should be: markdown bold headers)
- What `.active-*` files currently exist in the project root

**Key components:**
- `.claude/skills/serious-conversation/SKILL.md`
- `.claude/skills/serious-research/SKILL.md`
- `.claude/skills/serious-mock-ups/SKILL.md`
- `.claude/skills/serious-plan/SKILL.md`
- `.claude/skills/serious-code/SKILL.md`
- `.claude/skills/serious-review/SKILL.md`

**Acceptance criteria:**
- [ ] Report documents breadcrumb status for all 6 skills
- [ ] Report documents frontmatter status for all 6 skills
- [ ] Report lists current `.active-*` files in project root
- [ ] Report confirms research.md uses `**Status:**` format (not YAML)

**Evidence requirements:**
- [ ] `evidence/task_00_smoke_test.md` with full audit

**Rollback plan:** N/A — read-only task

---

### Task 1: YAML Frontmatter Standard + .gitignore

**Risk:** L

**Intent:** Establish the frontmatter standard that all other tasks depend on, and add breadcrumb files to .gitignore.

**Scope:** "Done" means the standard is documented in CLAUDE.md and .gitignore is updated.

**Context:** Every subsequent task references this standard. Must be done first.

**Expected behavior:** A clear, documented standard for YAML frontmatter across all skills.

**Key components:**
- `CLAUDE.md` — add frontmatter standard section
- `.gitignore` — add `.active-*` pattern

**Acceptance criteria:**
- [ ] CLAUDE.md contains a new section titled "## Workflow Frontmatter Standard" (or similar) under the Workflow Skills section
- [ ] The standard defines these required fields: `skill`, `slug`, `status`, `parent`, `created`
- [ ] The standard defines valid values for `status`: `active`, `done`, `abandoned`
- [ ] The standard defines `parent` as a relative path from project root (or absent for top-level)
- [ ] The standard defines the pipeline order: `conversation(1) → research(2) → mock-ups(3) → plan(4) → code(5) → review(6)`
- [ ] The standard defines advancing vs branching: new skill order > active skill order = advancing (no prompt), otherwise = branching (prompt)
- [ ] `.gitignore` contains `.active-*` pattern
- [ ] `.gitignore` contains `.active-conversation`, `.active-research`, `.active-code`, `.active-mock-ups`, `.active-plan`, `.active-review` (or the wildcard pattern covers all)

**Negative tests:**
- [ ] The frontmatter standard does NOT include `spawned_from` or `depth` fields (deferred to Phase 2)
- [ ] The `.gitignore` change does NOT affect any other existing patterns

**Evidence requirements:**
- [ ] Diff of CLAUDE.md showing added section
- [ ] Diff of .gitignore showing added pattern
- [ ] Grep of CLAUDE.md confirming all 5 required field names appear

> **TDD (v6):** Every acceptance criterion above requires verification. Read the modified files and confirm each pattern exists.

**Rollback plan:** `git checkout CLAUDE.md .gitignore`

**Notes:** The pipeline order constant is critical — it determines the advancing-vs-branching logic in Task 3.

---

### Task 2: Add Breadcrumbs + Frontmatter + Status Update to All 6 Skills

**Risk:** H — touches all 6 skill files, each with multiple changes

**Intent:** Every skill gets: (1) a breadcrumb file, (2) YAML frontmatter in its primary output file template, (3) status update to `done` on completion.

**Scope:** "Done" means all 6 SKILL.md files have the three changes. This task does NOT add the parent check (that's Task 3).

**Context:** Depends on Task 1 (frontmatter standard). Enables Tasks 3-5.

**Expected behavior:** After this task, every skill's output file will have YAML frontmatter from creation, every skill will write/remove a breadcrumb, and every skill will mark `status: done` on completion.

**Key components:**
- `.claude/skills/serious-conversation/SKILL.md` — add frontmatter to conversation.md template, update Phase 3c
- `.claude/skills/serious-research/SKILL.md` — convert research.md template from bold headers to YAML, update Phase 6
- `.claude/skills/serious-mock-ups/SKILL.md` — create mock-up-summary.md stub in Phase 0e, add `.active-mock-ups` breadcrumb, update Phase 4
- `.claude/skills/serious-plan/SKILL.md` — add frontmatter to implementation_plan.md/phase_map.md, add `.active-plan` breadcrumb, update Phase 3
- `.claude/skills/serious-code/SKILL.md` — add frontmatter to execution_log.md, update Phase 2b
- `.claude/skills/serious-review/SKILL.md` — add frontmatter to findings.md, add `.active-review` breadcrumb, update Phase 5b

**Impact analysis:**
- Skills that auto-detect outputs (plan, code, review) currently check for specific file patterns. Adding frontmatter doesn't break auto-detection — it adds information, doesn't change file names or locations.
- The research.md format change (bold headers → YAML) means any code/skill that parses `**Status: Complete**` needs updating. Currently only `/serious-plan` and `/serious-mock-ups` do this in their auto-detect phases.

**Acceptance criteria:**

For **ALL 6 skills:**
- [ ] The SKILL.md contains a YAML frontmatter block in the primary output file template, with all 5 fields: `skill`, `slug`, `status`, `parent`, `created`
- [ ] The SKILL.md specifies writing a `.active-{skill-name}` breadcrumb file at startup. Breadcrumb content is the relative path from project root to the workflow's output folder (e.g., `Research/features/auth`)
- [ ] The SKILL.md specifies the breadcrumb write order: write breadcrumb FIRST, then create the output file with frontmatter. This ensures interrupted operations leave a breadcrumb that can be cleaned up, rather than an orphan output file with no breadcrumb
- [ ] The SKILL.md specifies removing the `.active-{skill-name}` breadcrumb at completion/wrap-up (AFTER setting status: done in frontmatter)
- [ ] The SKILL.md specifies setting `status: done` in the output file's frontmatter at completion/wrap-up

For **specific skills:**
- [ ] `/serious-research` SKILL.md: the research.md template uses `---` YAML frontmatter instead of `**Date:**`, `**Status:**` bold headers
- [ ] `/serious-research` SKILL.md: research-specific fields (`classification`, `scope`, `mode`) are inside the YAML block
- [ ] `/serious-mock-ups` SKILL.md: Phase 0e creates `mock-up-summary.md` early with YAML frontmatter + placeholder content (not Phase 4)
- [ ] `/serious-mock-ups` SKILL.md: Phase 4 updates the existing stub with real content and sets `status: done`
- [ ] `/serious-plan` SKILL.md: auto-detect in Phase 0a checks for `status: done` in YAML frontmatter as the PRIMARY check
- [ ] `/serious-plan` SKILL.md: auto-detect includes LEGACY FALLBACK — if no YAML frontmatter found, falls back to checking `**Status: Complete**` bold markdown headers (for pre-frontmatter research files)
- [ ] `/serious-plan` SKILL.md: for multi-plan, `phase_map.md` gets the canonical frontmatter (not individual plan files)
- [ ] `/serious-mock-ups` SKILL.md: auto-detect in Phase 0a checks for `status: done` in YAML frontmatter as PRIMARY, falls back to `**Status: Complete**` bold headers for legacy files
- [ ] `/serious-code` SKILL.md: auto-detect includes the same dual-check (YAML primary, bold header fallback) for finding completed plans

**Negative tests:**
- [ ] `notebook.md` (research scratchpad) does NOT get YAML frontmatter
- [ ] Skills that already had breadcrumbs (conversation, research, code): REPLACE their existing breadcrumb logic with the new standardized version (same format, same write order). Do NOT leave both old and new breadcrumb logic in the file.

**Evidence requirements:**
- [ ] Grep all 6 SKILL.md files for `^---` (YAML frontmatter delimiters in templates)
- [ ] Grep all 6 SKILL.md files for `.active-` (breadcrumb references)
- [ ] Grep all 6 SKILL.md files for `status: done` (completion update)
- [ ] Diff of each modified SKILL.md

> **TDD (v6):** For each skill, verify the three changes independently before moving to the next skill.

**Rollback plan:** `git checkout .claude/skills/`

**Notes:**
- Process one skill at a time. Read → modify → verify → next.
- The research.md format change is the most impactful since it changes an existing format. The others are additive.

---

### Task 3: Add Parent Check (0-pre) to All 6 Skills

**Risk:** H — the advancing-vs-branching logic is the most important design decision

**Intent:** Every skill checks for active breadcrumbs at startup and either prompts for sub-workflow linking (branching) or silently co-locates (advancing).

**Scope:** "Done" means all 6 SKILL.md files contain the parent check step. This includes the advancing-vs-branching logic, the depth guard, stale breadcrumb handling, and the sub-workflow folder convention.

**Context:** Depends on Task 2 (breadcrumbs exist). This is the core of the recursive workflow feature.

**Expected behavior:** When a user invokes `/serious-research` while `/serious-plan` is active, the system detects this as branching (research is earlier than plan in the pipeline) and prompts for sub-workflow linking. When a user invokes `/serious-plan` while `/serious-research` is active, the system detects this as advancing and does NOT prompt.

**Key components:**
- All 6 SKILL.md files — add "### 0-pre. Check for active parent workflow" section

**Impact analysis:**
- This changes the Phase 0 flow of every skill. All downstream phases are unaffected.
- Sub-workflow folder creation (`{parent}/sub/{slug}/`) replaces the normal folder creation path when the user accepts a sub-workflow link. All subsequent file writes in the skill use this new base folder.
- The `parent:` field in frontmatter connects the child to the parent for `/serious-status` tree reconstruction.

**Acceptance criteria:**

For **ALL 6 skills:**
- [ ] Contains a "### 0-pre. Check for active parent workflow" section before any other Phase 0 steps
- [ ] Lists all 6 breadcrumb filenames to check: `.active-conversation`, `.active-research`, `.active-mock-ups`, `.active-plan`, `.active-code`, `.active-review`
- [ ] Includes stale breadcrumb validation: check that the target folder exists and contains a valid output file. If not, delete the stale breadcrumb with a warning.
- [ ] References the pipeline order from CLAUDE.md: `conversation(1) → research(2) → mock-ups(3) → plan(4) → code(5) → review(6)`
- [ ] Implements the advancing-vs-branching distinction: new skill order > active skill order = advancing, new skill order ≤ active skill order = branching
- [ ] **Advancing behavior is explicitly documented as "normal behavior — no new logic needed."** The new skill uses its existing folder rules (e.g., /serious-plan already co-locates in the research folder, /serious-code already co-locates in the plan folder). No parent field is set. No prompt is shown. No sub/ folder is created. Both the new skill's breadcrumb AND the existing skill's breadcrumb coexist. The parent check section explicitly states: "If advancing: skip the rest of 0-pre, proceed to Phase 0a as normal."
- [ ] **When multiple breadcrumbs exist:** resolve to the deepest active workflow by following `parent:` chains in frontmatter. Compare the new skill's pipeline order against the DEEPEST active skill's order. If new > deepest = advancing. If new ≤ deepest = branching. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.
- [ ] **Branching behavior:** when branching, the deepest active workflow becomes the proposed parent
- [ ] When branching: prompts with "I see you're in /serious-{skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"
- [ ] If YES: sets `parent` in frontmatter to the parent's output folder path, creates output at `{parent_folder}/sub/{slug}/`
- [ ] If NO: creates output in normal location, no parent field set
- [ ] Includes depth guard: computes the PROPOSED depth of the NEW workflow by counting parent chain hops from the proposed parent (parent at depth 0 → new workflow would be depth 1; parent at depth 1 → new workflow would be depth 2; etc.)
- [ ] Depth guard fires when proposed depth ≥ 3, warns: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If user says No: do not create the sub-workflow, return without starting the new skill.
- [ ] Documents that depth is computed by following the `parent:` chain in frontmatter of the proposed parent, counting hops until a workflow with no `parent:` field is reached, then adding 1

For **same-skill drilling** (e.g., research → sub-research):
- [ ] Explicitly documents: "When branching into the SAME skill type, the existing `.active-{skill}` breadcrumb will be overwritten with the new sub-workflow's path"
- [ ] Documents the user-facing prompt difference: "I see you're already in /serious-{skill} for {slug}. Start a nested /serious-{skill} within it? (Y/N)" — distinct wording from cross-skill branching
- [ ] Documents restoration on wrap-up: when the sub-workflow completes or is abandoned, read its frontmatter `parent:` field, then restore the breadcrumb to point to the parent's folder path
- [ ] Documents the edge case: if the parent was also a sub-workflow (depth 2), restoration still works because the parent's frontmatter has ITS parent, and the breadcrumb just needs to point to the immediate parent

**Negative tests:**
- [ ] Parent check does NOT fire when no breadcrumbs exist (top-level workflow)
- [ ] Parent check does NOT prompt when advancing (e.g., research active, plan invoked). Advancing = new skill order > active skill order.
- [ ] Advancing case uses the skill's NORMAL folder logic, does NOT create a sub/ folder, does NOT set a parent field
- [ ] Advancing case does NOT overwrite or remove the active skill's breadcrumb — both breadcrumbs coexist

**Evidence requirements:**
- [ ] Grep all 6 SKILL.md files for "0-pre"
- [ ] Grep all 6 SKILL.md files for "advancing" and "branching"
- [ ] Grep all 6 SKILL.md files for "depth"
- [ ] Diff of each modified SKILL.md showing the added section

> **TDD (v6):** Verify each criterion by reading the modified file. The advancing-vs-branching logic is the highest-risk item — verify it first.

**Rollback plan:** `git checkout .claude/skills/`

**Notes:**
- The parent check section should be written ONCE as a template, then adapted per skill (only the breadcrumb filename and folder location differ).
- The advancing-vs-branching distinction is the #1 DX issue identified in the research. Get it right. If it fires on normal forward flow, users will hate it.

---

### Task 4: Create /serious-status Skill

**Risk:** M

**Intent:** A new user-invocable skill that scans all workflow folders, reads frontmatter, reconstructs the tree, and displays a flat table.

**Scope:** "Done" means the SKILL.md exists and contains complete instructions for scanning, parsing, tree building, and rendering.

**Context:** Depends on Tasks 1-3 (frontmatter exists, breadcrumbs exist, parent field exists). This is a read-only command.

**Expected behavior:** User types `/serious-status`. The system scans all Research/ and QA/ folders, reads frontmatter from output files, builds a parent-child tree, and displays a flat table with indentation.

**Key components:**
- `.claude/skills/serious-status/SKILL.md` (NEW)

**Acceptance criteria:**
- [ ] SKILL.md has correct frontmatter header: `name: serious-status`, `user-invocable: true`, no hooks
- [ ] Description triggers on: 'serious status', 'what am I working on', 'show workflows', 'where am I'
- [ ] Scan algorithm covers: `Research/conversations/*/`, `Research/{bugs,features,exploratory}/*/`, `Research/**/sub/*/`, `QA/*/`
- [ ] Also checks `.active-*` breadcrumbs to find active workflows not in standard locations
- [ ] Reads YAML frontmatter from primary output files (skill, slug, status, parent, created)
- [ ] Falls back to markdown bold headers for legacy files (pre-frontmatter)
- [ ] Uses frontmatter `skill:` field as primary source for stage. Falls back to file existence priority only when no frontmatter exists.
- [ ] Builds tree from `parent:` references, identifies roots (no parent)
- [ ] Sorts roots by `created:` date (newest first)
- [ ] Status precedence: breadcrumb file = live "active" signal. Frontmatter "done"/"abandoned" are authoritative terminal states.
- [ ] Output format: flat table with columns Status, Workflow, Stage, Path
- [ ] Status glyphs: `✓` done, `●` active, `○` pending, `✗` abandoned, `?` legacy (no frontmatter)
- [ ] Indentation: 2 spaces per depth level, `└` connector for children
- [ ] Validates frontmatter: skips files with malformed YAML, shows `⚠ {path}` warning
- [ ] Validates `parent:` paths: shows orphaned workflows at top level with warning if parent path doesn't resolve

**Negative tests:**
- [ ] Does NOT modify any files (read-only)
- [ ] Does NOT crash on empty Research/ folder (shows "No workflows found")
- [ ] Does NOT crash on files without frontmatter (falls back gracefully)

**Evidence requirements:**
- [ ] Full SKILL.md file content
- [ ] Example output format matching the spec

> **TDD (v6):** Verify each section of the SKILL.md against the acceptance criteria.

**Rollback plan:** `rm .claude/skills/serious-status/SKILL.md`

---

### Task 5: Create /serious-abandon Skill

**Risk:** M

**Intent:** A new user-invocable skill that marks the current sub-workflow as abandoned, removes its breadcrumb, restores parent context, and reports status.

**Scope:** "Done" means the SKILL.md exists and contains complete instructions for finding the active workflow, marking it abandoned, handling worktrees, restoring parent breadcrumb, and providing a user-facing summary of the return.

**Context:** Depends on Tasks 1-3 (frontmatter, breadcrumbs, parent field). This modifies frontmatter status and breadcrumb files.

**Expected behavior:** User types `/serious-abandon`. The system finds the deepest active workflow, marks it as abandoned, removes its breadcrumb, restores the parent's breadcrumb (if same-skill drilling), reads the parent's state, and reports back with a summary.

**Key components:**
- `.claude/skills/serious-abandon/SKILL.md` (NEW)

**Acceptance criteria:**
- [ ] SKILL.md has correct frontmatter header: `name: serious-abandon`, `user-invocable: true`, no hooks
- [ ] Description triggers on: 'serious abandon', 'abandon this', 'bail out', 'go back to parent'
- [ ] Step 1: Reads all `.active-*` breadcrumbs, validates each (folder exists, frontmatter parseable), discards stale
- [ ] Step 1: Determines deepest by following parent chains in frontmatter (not path containment)
- [ ] Step 1: Error state: "No active workflow to abandon" when no valid breadcrumbs exist
- [ ] Step 2: If no parent field: warns "This is a top-level workflow. Abandon it? (Y/N)"
- [ ] Step 2: If the workflow being abandoned HAS active children (other breadcrumbs whose frontmatter `parent:` points into this workflow's folder): REFUSE to abandon. Display: "Cannot abandon {slug} — it has active sub-workflow(s): {list of child slugs}. Abandon or complete the children first, or use /serious-abandon on them."
- [ ] Step 3: Sets `status: abandoned` in the output file's YAML frontmatter
- [ ] Step 3: Removes the breadcrumb file for the abandoned workflow (AFTER setting status in frontmatter — reverse of creation order)
- [ ] Step 4: If `/serious-code` workflow: checks for worktrees at `.claude/worktrees/serious-code-*`, does NOT delete/merge them, updates execution_log.md status to "Abandoned", reports which worktrees exist
- [ ] Step 4: Notes that `/serious-abandon` should only be invoked after code agents have stopped
- [ ] Step 5: Reads parent path from frontmatter, determines parent's skill type from parent's frontmatter
- [ ] Step 5: If same-skill drilling: restores parent's breadcrumb by writing `.active-{skill}` with the parent's folder path as content (e.g., write `Research/features/auth` to `.active-research`)
- [ ] Step 5: If cross-skill: parent's breadcrumb already exists (no restoration needed — cross-skill breadcrumbs coexist)
- [ ] Step 6: Reads parent's primary output file and summarizes current state
- [ ] Step 6: Reports what the abandoned sub-workflow produced (if anything)
- [ ] Step 6: Suggests next step with format: "Abandoned {slug}. Returning to {parent_slug} (/serious-{skill}). Parent status: {summary}."

**Negative tests:**
- [ ] Does NOT delete worktree directories or branches
- [ ] Does NOT merge abandoned worktree branches into main
- [ ] Does NOT skip the confirmation prompt for top-level abandon
- [ ] Does NOT abandon a workflow that has active children — refuses with an actionable message
- [ ] Does NOT cascade-abandon children automatically (user must abandon children explicitly)

**Evidence requirements:**
- [ ] Full SKILL.md file content
- [ ] Walkthrough of the depth-2 abandon chain proving restoration works (grandparent → parent → child)

> **TDD (v6):** The depth-2 chain walkthrough is the highest-risk item. Verify it explicitly.

**Rollback plan:** `rm .claude/skills/serious-abandon/SKILL.md`

---

### Task 6: Update Auto-Detection Scan Paths + Copy to Global Profiles

**Risk:** L

**Intent:** Skills that auto-detect outputs need expanded glob patterns to find sub-workflow outputs. All modified skills need copying to global profiles.

**Scope:** "Done" means scan paths are updated AND all skills (6 modified + 2 new) are copied to all 3 global profiles.

**Context:** Depends on Tasks 2-5. Final task before verification.

**Expected behavior:** `/serious-plan` can find research.md files inside `**/sub/*/` folders. `/serious-code` can find implementation plans inside `**/sub/*/`. All three global profiles have identical skill files.

**Key components:**
- `.claude/skills/serious-plan/SKILL.md` — expand auto-detect scan paths
- `.claude/skills/serious-code/SKILL.md` — expand auto-detect scan paths
- `.claude/skills/serious-review/SKILL.md` — expand auto-detect scan paths
- `~/.claude/skills/`, `~/.claude-work/skills/`, `~/.claude-alex/skills/` — copy destinations

**Impact analysis:**
- Plan auto-detect currently scans `Research/{bugs,features,exploratory}/*/research.md`. Must add `Research/**/sub/*/research.md`.
- Code auto-detect currently scans `Research/features/*/implementation_plan.md`. Must add `Research/**/sub/*/implementation_plan.md`.
- Review auto-detect needs similar expansion for recent work scanning.
- Auto-detect must filter by `status: done` in frontmatter (not `**Status: Complete**`).

**Acceptance criteria:**
- [ ] `/serious-plan` SKILL.md: Phase 0a scan paths include `Research/**/sub/*/research.md` and `**/sub/*/mock-ups/mock-up-summary.md`
- [ ] `/serious-plan` SKILL.md: auto-detect uses dual-check: YAML `status: done` primary, `**Status: Complete**` bold header fallback for legacy files (consistent with Task 2 changes)
- [ ] `/serious-code` SKILL.md: Phase 0a scan paths include `Research/**/sub/*/implementation_plan.md` and `**/sub/*/phase_map.md`
- [ ] `/serious-code` SKILL.md: auto-detect uses dual-check for completed plans (same logic as plan skill)
- [ ] `/serious-review` SKILL.md: scan includes `**/sub/*/` paths for recent work detection
- [ ] All 8 skill folders (6 modified + serious-status + serious-abandon) exist in `~/.claude/skills/`
- [ ] All 8 skill folders exist in `~/.claude-work/skills/`
- [ ] All 8 skill folders exist in `~/.claude-alex/skills/`
- [ ] md5 checksums match across all profiles for each skill

**Negative tests:**
- [ ] Auto-detect does NOT offer `status: active` stub files as completed research/plans
- [ ] Profile copies do NOT overwrite any profile-specific customizations in other skill files

**Evidence requirements:**
- [ ] Grep of scan path changes in plan, code, review SKILL.md files
- [ ] md5 checksum comparison across profiles

> **TDD (v6):** Verify scan paths by grep, then verify profile copies by checksum.

**Rollback plan:** `git checkout .claude/skills/serious-plan/ .claude/skills/serious-code/ .claude/skills/serious-review/`

---

### Task 7: Final Verification — Invoke /serious-status Against Existing Data

**Risk:** L

**Intent:** Prove the system works end-to-end by mentally walking through what `/serious-status` would produce for the existing Research/ folder.

**Scope:** Read-only verification. No modifications.

**Expected behavior:** Describe what `/serious-status` output would look like given the current project's Research/ contents.

**Key components:**
- `Research/conversations/recursive-workflow-pipeline/` — existing conversation (done)
- `Research/features/recursive-workflow-pipeline/` — existing research (done)

**Acceptance criteria:**
- [ ] Walkthrough shows both existing workflows detected (conversation and research, both for recursive-workflow-pipeline)
- [ ] Walkthrough correctly identifies both as "done" (no active breadcrumbs point to them)
- [ ] Walkthrough shows they are NOT linked as parent-child (they were created before the parent linking feature)
- [ ] Walkthrough shows correct glyphs: either `✓` (if frontmatter exists) or `?` (legacy, no frontmatter)

**Evidence requirements:**
- [ ] Written walkthrough in `evidence/task_07_verification.md`

**Rollback plan:** N/A — read-only

---

## Appendix

### Technical Decisions

1. **Advancing vs branching determined by pipeline order, not by user prompt.** The system compares the new skill's position in the pipeline against the active skill's position. Later = advancing, earlier/same = branching.

2. **Breadcrumbs use relative paths, not absolute.** Ensures portability between machines and avoids path-specific issues.

3. **Frontmatter `skill:` field is authoritative for stage detection.** File existence is a fallback for legacy files only. This prevents incorrect stage detection when a folder has outputs from multiple skills.

4. **No breadcrumb stack.** Same-skill drilling overwrites the breadcrumb. The frontmatter `parent:` field serves as the backup pointer. Each completion/abandon pops one level.

5. **Sub-workflows don't follow normal location rules.** They always go to `{parent}/sub/{slug}/`. This breaks folder-path-based skill detection but keeps the hierarchy visible.

6. **Phase 1 only — no registry, no auto-pause, no router.** These were discussed in the conversation and explicitly deferred to Phase 2/3.

### Dependencies

- No external dependencies. All changes are to SKILL.md markdown files.

### Out of Scope

- `/serious-cleanup` command (Phase 2)
- Triage prompt at stage exits (Phase 2)
- Work item registry and stage boundary router (Phase 3)
- `status: paused` for parent workflows when children are active (Phase 3)
- `spawned_from` field in frontmatter (Phase 2)
- `/serious-status --active` filter (Phase 2)
- `/serious-status --tree` visualization (Phase 2)

### Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1 | 2026-03-08 | Initial plan from `/serious-research` output |
| v2 | 2026-03-08 | Round 1 fixes: 7 critical + 14 major (QA Engineer + DX Advocate). Round 2: converged (0 critical, 3 major, 7 minor fixed). Key changes: breadcrumb write order, advancing = normal behavior, depth guard uses proposed depth, parent-with-active-children refuses abandon, legacy fallback, same-skill drilling ACs, multi-breadcrumb resolution, depth guard "No" path, prompt wording, breadcrumb restoration specificity |

### Input Source

Research: `Research/features/recursive-workflow-pipeline/research.md` (Status: Complete)
Conversation: `Research/conversations/recursive-workflow-pipeline/summary.md`
