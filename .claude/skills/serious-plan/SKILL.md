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

### 0d. Determine the plan location

- **If input came from `/serious-research`:** Create `implementation_plan.md` in the same folder as the research.
- **If input came from a PRD or description:** Create a folder under `Research/features/{slug}/` (or `bugs/` or `exploratory/` as appropriate), put the plan there, and save the input material alongside it for traceability.

---

## Phase 1: Plan Generation

Read the v6 template file first. Then work through each section in order, filling it in based on the input material.

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

### Plan Review — Adaptive Persona Pipeline
- **Select appropriate personas** based on what the plan touches:
  - Use the persona catalog from the v6 template as your starting point
  - Not every plan needs every persona — a backend-only fix doesn't need an End User review
  - Follow the scaling guidance table in the template
- **Phase A** (Persona Reviews): Select and document which personas will review
- **Phase B** (Mechanical Reviews): Senior Engineer + Integration Architect — always required
- Document persona selection rationale
- **Persona reviews are a rewriting process** — issues found get fixed in the plan, not appended as notes

### Inline QA Protocol v6
- Copy the v6 Inline QA Protocol section verbatim — it is non-negotiable
- The protocol must appear in every plan so the implementing agent has it in context
- v6 integrates TDD: every acceptance criterion gets a failing test FIRST, then implementation, then QA sub-agent verification

### Master Checklist / Progress Dashboard
- Create implementation tasks based on the research recommendations (or PRD requirements, or user description)
- Pair each implementation task with a verification task (N + Nv)
- Assign risk levels (L/M/H) based on complexity and blast radius
- Order tasks by dependency (independent tasks first, dependent tasks later)
- Aim for **3-7 implementation tasks** — decompose large work, combine trivial items

### Evidence Generation Protocol
- Copy from the v6 template — adapt the evidence types table to this project's task categories
- Set up the evidence directory structure
- v6 uses markdown reports (not HTML)

### Task Descriptions
For each task, fill in:
- **Risk level** with justification
- **Intent** — one sentence on what the task accomplishes
- **Context** — why it exists, dependencies, what it enables
- **Expected behavior** — the user-visible outcome
- **Key components** — specific files and functions
- **Acceptance criteria** — concrete, testable `- [ ]` items
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

### Appendix
- Technical decisions (from research or inferred from requirements)
- Dependencies (libraries, APIs, services)
- Out of scope (explicitly list what this plan does NOT cover)
- Changelog (track plan revisions)
- Input source (link to research.md, PRD, or note that it was generated from a description)

---

## Phase 2: Self-Review

Before presenting to the user, verify:

- [ ] Every file path referenced actually exists in the codebase (or is clearly marked as "to be created")
- [ ] Every command in Project Configuration actually works (run them)
- [ ] Task dependencies are consistent (no circular deps, correct ordering)
- [ ] Acceptance criteria are specific enough for a QA sub-agent to verify
- [ ] Acceptance criteria are specific enough to write a test for (TDD requirement)
- [ ] Risk levels make sense (H for shared state/security, M for standard features, L for config/boilerplate)
- [ ] The plan is self-contained — an agent could execute it without asking questions
- [ ] TDD Protocol section is present and unmodified
- [ ] Inline QA Protocol v6 section is present and unmodified
- [ ] Input source is documented in the Appendix

---

## Phase 3: Present to User

Report:
- The plan file path
- The input source used (research, PRD, or description — with disclaimer if applicable)
- Summary of what's planned (task count, estimated complexity)
- The recommended persona review set
- Any questions or decisions that need user input before implementation can begin

---

## Arguments

`$ARGUMENTS` can specify:
- A path to research: `/serious-plan Research/features/notifications/research.md`
- A path to a PRD or spec: `/serious-plan docs/prd-notifications.md`
- Or nothing — the skill will auto-detect or ask

---

## What Comes After

Once the user approves the plan:
1. The plan goes through the **Adaptive Persona Pipeline** review (Phase A + Phase B)
2. Fixes from review are rewritten into the plan
3. Implementation begins following the **Master Checklist** workflow
4. Each acceptance criterion uses the **TDD cycle** (RED→GREEN→VERIFY)
5. Each criterion gets **Inline QA Protocol v6** verification
6. Each task gets **Split-Agent Verification** (Agents A-D)
7. Evidence reports are generated per task (markdown)
8. Summary report is generated at the end
