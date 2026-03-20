---
skill: serious-plan
slug: pipeline-handoff-verification
status: done
parent: Research/features/pipeline-handoff-verification
created: 2026-03-19
source: Research/features/pipeline-handoff-verification/research.md
---

# Implementation Plan: Pipeline Handoff Verification

---

## Executive Summary

Build an automatic upstream traceability verification system into the serious-* workflow pipeline. An independent sub-agent fires at each skill handoff, extracts enumerable items from the upstream artifact, checks each item's disposition in the downstream output (COVERED / DEFERRED / SHIRKED / MISSING / OVERRIDE), and blocks on gaps. This eliminates the manual `/loop` correction cycles the user currently runs after every handoff.

**Key Outcomes:**
- Every handoff in the pipeline (conversation→research, research→plan, mock-ups→plan, plan→code) gets automatic drift detection
- Scope shirking ("deferred to later") is caught via 11 heuristic patterns
- The verifier lives in one shared file — single source of truth, referenced by all downstream skills
- Retroactive verification catches plans created before the verifier existed
- Multi-plan verification checks item allocation across phase maps
- The user no longer acts as the manual verification layer

---

## Project Configuration

> **Fill this section before starting any tasks.** These values are referenced throughout the plan as `{VARIABLE_NAME}` placeholders.

| Variable | Value | Description |
|----------|-------|-------------|
| `{EVIDENCE_ROOT}` | `./Research/features/pipeline-handoff-verification/evidence` | Root directory for all evidence artifacts |
| `{STATIC_ANALYSIS_CMD}` | N/A — deliverables are markdown/prompt files, not compiled code | Static analysis command(s) |
| `{DEV_SERVER_CMD}` | N/A — no dev server; test by running skills in Claude Code | How to test |
| `{TEST_CMD}` | Manual: run `/serious-plan` or `/serious-research` on a real artifact and inspect verifier output | How to validate |
| `{RUNTIME_LOGS_CMD}` | Inspect verifier output in `_traceability_check.md` and `_extracted_items.md` | Runtime verification |
| `{BUILD_CMD}` | N/A — no build step | Build command |
| `{VERIFICATION_AGENT}` | Manual inspection of verifier sub-agent output | Primary verification tool |
| `{SCREENSHOT_TOOL}` | N/A — text-based deliverables | Screenshot tool |
| `{MAX_RETRIES}` | `3` | Max verification failures before escalating |
| `{STUB_PATTERNS}` | `["{To be written", "TODO", "TBD", "{placeholder}"]` | Patterns indicating incomplete content |
| `{RUNTIME_VERIFY_CMD}` | Run `/serious-plan` against a known research artifact and check for `_traceability_check.md` output | Runtime verification command |

**Note:** This project produces prompt/template files, not compiled software. "Testing" means running the modified skills against real workflow artifacts and verifying the verifier produces correct output. Traditional TDD does not apply — instead, each task uses **manual validation against real artifacts** as the verification method.

---

## Product Manager Review

### Feature Overview

This implementation adds an automatic quality gate at every skill handoff in the serious-* workflow pipeline. Currently, users must manually detect and correct drift between upstream and downstream artifacts. This feature makes that drift visible and blocks on it automatically.

### Features

#### Feature 1: Upstream Traceability Verification

**What it is:** An independent sub-agent that compares upstream and downstream artifacts at each handoff, producing a checklist showing which items were covered, shirked, missing, deferred, or overridden.

**Why it matters:** Users currently spend multiple `/loop` iterations fixing drift after every handoff. This automates the detection, making the pipeline self-correcting.

**User perspective:** After running `/serious-plan`, the user sees a traceability checklist showing "8/8 findings covered" (green) or "1 shirked, 1 missing" (red, with specific gaps and fix instructions). No new commands to learn — it happens automatically.

---

#### Feature 2: Retroactive Verification

**What it is:** When a downstream skill starts, it checks whether its upstream artifact was ever verified. If not (e.g., plans created before the verifier existed), it runs verification before proceeding.

**Why it matters:** Ensures the verification system catches legacy artifacts, not just new ones.

**User perspective:** Running `/serious-code` on an old plan triggers "This plan was never verified against its research. Running verification now..." followed by the traceability checklist.

---

## Pre-Flight Readiness

> **Complete before starting any implementation task.** All items must be checked.

- [ ] **Skills directory accessible** — `.claude/skills/` exists and contains all serious-* skills
- [ ] **Template readable** — `./_implementation_plan_template_v6.md` exists
- [ ] **Research complete** — `Research/features/pipeline-handoff-verification/research.md` status is `done`
- [ ] **Real test artifacts available** — At least 2 completed conversation→research workflows exist in `Research/` to test against (a 3rd synthetic artifact will be created in Task 5)
- [ ] **Evidence directory exists** — `{EVIDENCE_ROOT}/assets/` created
- [ ] **Git branch created** — Working on the correct feature branch

---

## Test-Driven Development Protocol

> **Adapted for prompt engineering:** Traditional TDD (write failing test → implement → verify) does not apply to markdown/prompt file deliverables. Instead, each task uses this cycle:
>
> 1. **DEFINE** — Write the expected verifier output for a known input (the "test case")
> 2. **IMPLEMENT** — Write the prompt/template change
> 3. **VERIFY** — Run the skill with the change, compare actual output to expected output
> 4. **FIX** — If output doesn't match, adjust the prompt and re-verify
>
> The verification sub-agent checks that the delivered files match the spec and produce correct output on real artifacts.

---

## Inline QA Protocol v6

> **Adapted for prompt engineering:** QA sub-agents verify each deliverable by:
> 1. Reading the acceptance criterion from the plan
> 2. Reading the delivered file
> 3. Checking that the file matches the specification (structure, content, conventions)
> 4. For runtime-verifiable criteria: running the skill and inspecting output
>
> **Non-Negotiable Rules:**
> 1. Every acceptance criterion gets verified. No exceptions.
> 2. QA sub-agent is independent — it reads the plan and the deliverable, not the implementer's self-report.
> 3. Failures are fixed immediately. Not logged for later.
> 4. The QA sub-agent cannot approve its own work — use the Agent tool.

---

## Master Checklist

### Progress Dashboard

| Done | # | Task Name | Risk | Start | End | Total (min) | Human Est. (min) | Multiplier | Status | Attempts | Evidence | Blocker |
|:----:|:-:|-----------|:----:|:-----:|:---:|:-----------:|:----------------:|:----------:|:------:|:--------:|:--------:|:-------:|
| ⬜ | 0 | Smoke Test: Observe handoff drift | L | | | | 30 | | pending | — | — | |
| ⬜ | 1 | Implement: Create shared verifier prompt | H | | | | 180 | | pending | — | — | |
| ⬜ | 1v | Verify: Shared verifier prompt | | | | | 60 | | pending | 0 | | |
| ⬜ | 2 | Implement: Standardize upstream output headings | L | | | | 30 | | pending | — | — | |
| ⬜ | 2v | Verify: Standardized headings | | | | | 15 | | pending | 0 | | |
| ⬜ | 3 | Implement: Add source field, verifier blocks, and CLAUDE.md update | M | | | | 90 | | pending | — | — | |
| ⬜ | 3v | Verify: SKILL.md integration | | | | | 30 | | pending | 0 | | |
| ⬜ | 4 | Implement: Wire extract-mode and retroactive checks into Phase 0 | M | | | | 90 | | pending | — | — | |
| ⬜ | 4v | Verify: Extract-mode at startup | | | | | 30 | | pending | 0 | | |
| ⬜ | 5 | Implement: Test verifier on real + synthetic artifacts | H | | | | 180 | | pending | — | — | |
| ⬜ | 5v | Verify: Real-artifact validation | | | | | 60 | | pending | 0 | | |
| ⬜ | 6 | Smoke Test: End-to-end verification | M | | | | 60 | | pending | — | — | |

> **Risk levels:** L = Low (boilerplate, config), M = Medium (feature work, standard logic), H = High (complex logic, prompt engineering precision)

**Summary:**
- Total tasks: 5 (implementation) + 5 (verification) + 2 (smoke tests) = 12 total
- Completed: 0
- Passed verification: 0 / 5
- Failed then passed: 0
- Blocked: 0
- Total time spent: 0 minutes
- Total human estimate: 855 minutes (~14 hours)
- Overall multiplier: TBD

---

## Evidence Generation Protocol

### Evidence Directory

```
{EVIDENCE_ROOT}/
├── assets/
│   ├── task_00_drift_observation.md
│   ├── task_05_verifier_output.md
│   └── task_05_synthetic_artifact.md
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
|---|---|
| **Prompt file creation** | File exists at expected path, contains required sections, matches spec |
| **Template modification** | Diff showing changes, before/after heading comparison |
| **SKILL.md modification** | Diff showing changes, instruction block matches pattern |
| **Verification testing** | Verifier output on real artifact, disposition accuracy assessment |

---

## Task Descriptions

### Task 0: Smoke Test — Observe Handoff Drift

**Risk:** L
**Intent:** Establish the baseline — demonstrate the drift problem on a real artifact before any changes.
**Depends on:** Nothing (first task).

**Scope:** Observation only. "Done" means we have documented evidence of drift between the conversation output and the research output for this very workflow.

**Expected behavior:** Read `Research/conversations/pipeline-handoff-verification/summary.md` (the conversation output) and `Research/features/pipeline-handoff-verification/research.md` (the research output). Manually check: does the research address every Key Insight and Open Question from the conversation? Document any gaps.

**Acceptance criteria:**
- [ ] Read conversation summary.md and extract all Key Insights (numbered) and Open Questions (bulleted)
- [ ] Read research.md and check each item's coverage
- [ ] Document findings in `{EVIDENCE_ROOT}/assets/task_00_drift_observation.md`
- [ ] Document whether each drift type (omission, contradiction, shirking) was found — for each type found, provide a specific example with upstream item and downstream disposition; if no instances of a type are found, state this explicitly with the search methodology used

**Evidence requirements:**
- The drift observation document with specific item-by-item comparison
- Count of items found vs addressed

---

### Task 1: Create Shared Verifier Prompt

**Risk:** H — This is the core deliverable. The verifier prompt's quality determines whether the entire system works.
**Depends on:** Nothing (can be done in parallel with Task 0 and Task 2).

**Intent:** Create `.claude/skills/_shared/handoff-verifier.md` containing the complete verification protocol with both modes (extract and verify), all 11 shirking patterns, worked examples, output format, multi-plan handling, and frontmatter conventions.

**Scope:** "Done" means the verifier file exists, is complete, and follows the non-invocable skill convention. This task does NOT wire it into any SKILL.md — that's Task 3.

**Context:** This file is the single source of truth for all handoff verification. Every downstream skill references it. Changes here propagate everywhere.

**Key components:**
- `.claude/skills/_shared/handoff-verifier.md` (new file, new directory)

**Impact analysis:**
- All downstream SKILL.md files will reference this file (Task 3)
- Extract-mode output (`_extracted_items.md`) will be consumed by verify-mode
- Verify-mode output (`_traceability_check.md`) will be read by users and downstream skills
- Frontmatter stamps (`verified`, `verified_source`, `verified_hash`) will be read by Phase 0 retroactive checks (Task 4)

**Acceptance criteria:**
- [ ] Directory `.claude/skills/_shared/` exists
- [ ] File `.claude/skills/_shared/handoff-verifier.md` exists
- [ ] File has frontmatter with `user-invocable: false` to prevent appearing as a slash command
- [ ] **Extract Mode section** contains: read upstream artifact, extract enumerable items from contract sections, output "Found N items from M sections in [path]. Proceeding.", sanity-check extraction count against section bullet/item counts, write `_extracted_items.md` to downstream folder, warn (don't block) if no structured items found
- [ ] **Verify Mode section** contains: read `_extracted_items.md`, search downstream for each item using the passed `match_strategy`, classify placement and substance, assign disposition, output checklist with per-item confidence (high/medium/low), apply verdict rules, stamp frontmatter on PASS, log to `_traceability_check.md` with versioning (rename previous to `_traceability_check_v{N}.md`)
- [ ] **Verify Mode explicitly mandates sub-agent spawn** via Agent tool — NOT inline execution — stated as a non-negotiable constraint
- [ ] **6 general shirking patterns** listed by name: future work section, out of scope dump, nice-to-have downgrade, parenthetical mention, passive deferral, hollow section — each with example text and explanation
- [ ] **5 LLM-specific shirking patterns** listed by name: abstraction escalation, conditional coverage, complexity acknowledgment, reference pass-through, delegation to future skill — each with example text and explanation
- [ ] **Minimum substance threshold** requires at least 2 of 5 signals: (1) concrete action item (not a restatement), (2) design decision with rationale, (3) acceptance criteria (checkboxes), (4) code reference (path/function/line), (5) data model or schema definition
- [ ] **Substance examples** include at least 2 positive (COVERED) and 2 negative (SHIRKED) examples with signal counts, matching those in research Finding 3
- [ ] **Worked examples for ambiguous cases** include at least 4 examples: 1 semantic match (conversation→research), 1 structural match (research→plan), 1 exact match (plan→code), 1 empty-section case (e.g., "Unresolved tensions: None" → 0 items extracted, no warning)
- [ ] **Output format** contains all mandatory elements: (1) numbered checklist, (2) disposition label per item (5 types with emoji markers), (3) confidence indicator `[high/medium/low]`, (4) location reference (section/line in downstream), (5) verdict line (PASS / PASS WITH DEFERRALS / FAIL with counts), (6) fix instructions on FAIL (path + re-run command), (7) override syntax reminder on FAIL, (8) upstream incompleteness warning footer
- [ ] **Verdict rules**: PASS = all COVERED/OVERRIDE; PASS WITH DEFERRALS = any DEFERRED, no SHIRKED/MISSING; FAIL = any SHIRKED or MISSING
- [ ] **Frontmatter stamp spec** defines `verified` (date), `verified_source` (upstream path), `verified_hash` (8 chars) with hash computation rules specifying all 5 steps: (a) extract only contract sections per transition, (b) strip leading/trailing whitespace per line, (c) normalize line endings to LF, (d) compute SHA-256, (e) store first 8 characters
- [ ] **Match strategy parameter** spec defines 3 modes (semantic / structural / exact) — the calling skill passes this
- [ ] **Context window guard**: chunk into batches of 10 if extracted items exceed 20, aggregate results
- [ ] **Marker conventions**: `[DEFERRED: reason]` for legitimate deferrals, `[VERIFIED: override — reason]` for user overrides (reason required for marker to be recognized)
- [ ] **Multi-plan verification protocol**: when the downstream artifact is a phase_map.md with multiple plans, (a) extract items from upstream, (b) read phase map to determine item-to-plan allocation, (c) verify each plan against its assigned items independently, (d) each plan gets its own `verified` stamp, (e) output shows per-plan verification with item allocation

**Negative tests:**
- [ ] File does NOT have `user-invocable: true` in frontmatter
- [ ] File does NOT claim shirking detection is "pattern matching, not semantic reasoning" — it must frame it as heuristic semantic judgment with a non-zero false-negative rate
- [ ] File does NOT allow inline execution of verification — must mandate Agent tool spawn

**Evidence requirements:**
- File content review showing all sections present
- Section-by-section checklist confirming each AC

**Rollback plan:** Delete `.claude/skills/_shared/` directory.

---

### Task 2: Standardize Upstream Output Headings

**Risk:** L — Template text changes only.
**Depends on:** Nothing (can be done in parallel with Tasks 0 and 1).

**Intent:** Ensure upstream skill output templates use consistent, enumerable heading names that the verifier can reliably extract from.

**Scope:** "Done" means the heading names in output templates are standardized. This does NOT change how skills generate content — only the template headings they use.

**Context:** The verifier extracts items from specific heading names. If headings vary ("Key Insights" vs "Takeaways" vs "Main Points"), extraction is unreliable.

**Key components:**
- `.claude/skills/serious-conversation/SKILL.md` — summary.md template
- `.claude/skills/serious-research/SKILL.md` — research.md template
- `.claude/skills/serious-mock-ups/SKILL.md` — mock-up-summary.md template

**Impact analysis:**
- Future conversation/research/mock-up outputs will use standardized headings
- Existing outputs are unaffected (they keep whatever headings they have)
- The verifier's extraction accuracy improves because heading names are predictable

**Acceptance criteria:**
- [ ] serious-conversation SKILL.md: summary.md template uses `## Key insights`, `## Unresolved tensions`, `## Open questions` as heading names (verify already correct — change only if they differ)
- [ ] serious-research SKILL.md: research.md template's `## Findings` section is updated to specify numbered subsection format (`### Finding 1: [title]`, `### Finding 2: [title]`, etc.) in the placeholder text — not prose paragraphs
- [ ] serious-research SKILL.md: research.md template uses `## Recommendations` as a bulleted list heading
- [ ] serious-mock-ups SKILL.md: mock-up-summary.md template uses `## Component Inventory` and `## Design Decisions` as table headings (verify already correct — change only if they differ)

**Negative tests:**
- [ ] No changes to skill logic, phases, or behavior — heading standardization only
- [ ] No changes to existing artifacts in Research/ folder — only templates

**Evidence requirements:**
- Diff of each SKILL.md showing only heading/template changes (or confirmation no change was needed)

**Rollback plan:** Revert heading text in each SKILL.md.

---

### Task 3: Add Source Field, Verifier Blocks, and CLAUDE.md Update

**Risk:** M — Modifying 4 SKILL.md files and CLAUDE.md with new instruction blocks and fields.
**Depends on:** Task 1 (verifier file must exist for references to be valid at runtime).

**Intent:** Wire the verifier into each downstream skill by (1) adding a `source` field to output frontmatter specs, (2) adding a verifier instruction block at the completion phase of each skill, (3) handling the mock-ups→plan conditional transition, and (4) updating CLAUDE.md's frontmatter standard with new fields.

**Scope:** "Done" means each downstream SKILL.md tells Claude to (a) populate the `source` frontmatter field during output generation and (b) spawn a verification sub-agent before marking the skill complete. CLAUDE.md is updated with the 4 new frontmatter fields.

**Context:** This is the integration point — connecting the shared verifier (Task 1) to the individual skills. The verifier runs automatically because it's instructed in the SKILL.md, not because the user invokes it.

**Key components:**
- `.claude/skills/serious-research/SKILL.md` — Phase 6 (Handoff): add verifier block
- `.claude/skills/serious-plan/SKILL.md` — Phase 3 (Present to User): add verifier block
- `.claude/skills/serious-code/SKILL.md` — completion section: add verifier block
- `.claude/skills/serious-plan/SKILL.md` — conditional mock-ups→plan verifier
- `CLAUDE.md` — Workflow Frontmatter Standard section

**Impact analysis:**
- All future skill runs will invoke the verifier automatically
- The `source` field in output frontmatter enables retroactive verification (Task 4)
- Each skill gains ~15-20 lines of new instruction text
- CLAUDE.md documents the new fields for all future skill development

**Acceptance criteria:**
- [ ] serious-research SKILL.md: output frontmatter template includes `source:` field with instruction: "Set to the path of the conversation summary.md consumed, or leave empty if no conversation upstream"
- [ ] serious-research SKILL.md: **Phase 6 (Handoff)** includes verifier instruction block referencing `.claude/skills/_shared/handoff-verifier.md` with `match_strategy: semantic`
- [ ] serious-plan SKILL.md: output frontmatter template includes `source:` field with instruction: "Set to the path of the research.md consumed, or leave empty if plan was generated from description"
- [ ] serious-plan SKILL.md: **Phase 3 (Present to User)** includes verifier instruction block referencing `.claude/skills/_shared/handoff-verifier.md` with `match_strategy: structural`
- [ ] serious-plan SKILL.md: **Conditional mock-ups verifier** — if mock-ups were consumed (mock-up-summary.md exists alongside research), a second verifier invocation runs against `mock-up-summary.md` with `match_strategy: structural`, checking Component Inventory and Design Decisions table rows
- [ ] serious-code SKILL.md: output frontmatter template includes `source:` field with instruction: "Set to the path of the implementation_plan.md consumed"
- [ ] serious-code SKILL.md: **completion section** includes verifier instruction block referencing `.claude/skills/_shared/handoff-verifier.md` with `match_strategy: exact`
- [ ] Each verifier block uses the established pattern: fenced code block with path, then bold instruction to spawn a sub-agent (Agent tool) — matching serious-plan's template reference pattern
- [ ] Each verifier block specifies: upstream artifact path, downstream artifact path, and match strategy
- [ ] **CLAUDE.md** Workflow Frontmatter Standard table is updated with 4 new optional fields: `source` (string, path to upstream artifact or empty), `verified` (date, set by verifier on PASS), `verified_source` (string, path to upstream verified against), `verified_hash` (string, 8-char hash of upstream contract sections)

**Negative tests:**
- [ ] Verifier blocks do NOT say "read and execute inline" — they must say "spawn a sub-agent using the Agent tool"
- [ ] No changes to existing skill logic, phases, or behavior beyond adding the verifier block and source field
- [ ] CLAUDE.md changes are additive — do not modify existing required fields

**Evidence requirements:**
- Diff of each SKILL.md showing the added blocks and their placement in the correct phase/section
- Diff of CLAUDE.md showing the frontmatter standard update

**Rollback plan:** Remove the verifier instruction blocks, source field, and CLAUDE.md additions.

---

### Task 4: Wire Extract-Mode and Retroactive Checks into Phase 0

**Risk:** M — Adding startup logic to 3 SKILL.md files.
**Depends on:** Task 1 (verifier file exists), Task 3 (source field exists in output templates).

**Intent:** Add the extract-mode pre-check and retroactive verification logic to Phase 0 of each downstream skill, so the verifier validates upstream artifacts before the skill burns time producing output.

**Scope:** "Done" means each downstream skill's Phase 0 (a) runs the verifier in extract-mode on the upstream artifact, (b) checks for the `verified` frontmatter stamp, and (c) triggers retroactive verification if the stamp is missing or stale.

**Context:** Extract-mode at startup catches two problems early: (1) malformed upstream artifacts that will fail verification later, and (2) unverified legacy artifacts that need checking before the skill proceeds.

**Key components:**
- `.claude/skills/serious-research/SKILL.md` — Phase 0, after step 0b (scope determination)
- `.claude/skills/serious-plan/SKILL.md` — Phase 0, after step 0c (input validation)
- `.claude/skills/serious-code/SKILL.md` — Phase 0, after plan auto-detection and validation

**Impact analysis:**
- Each skill's Phase 0 gains ~15-20 lines of new logic
- Startup time increases by 30-90 seconds (one sub-agent spawn for extraction)
- Legacy plans without `verified` stamps will trigger verification before `/serious-code` proceeds

**Acceptance criteria:**
- [ ] Each downstream SKILL.md's Phase 0 includes an extract-mode step **after** the existing auto-detect and validation steps (after 0b in serious-research, after 0c in serious-plan, after plan validation in serious-code) — added as a new numbered step
- [ ] Extract-mode step reads the upstream artifact and outputs "Found N items from M sections in [path]. Proceeding."
- [ ] Extract-mode writes `_extracted_items.md` to the downstream artifact's folder (survives context compaction, inspectable by user)
- [ ] Each downstream SKILL.md's Phase 0 includes a retroactive verification check: if the upstream artifact's frontmatter has no `verified` field, run full verification before proceeding
- [ ] Each downstream SKILL.md's Phase 0 includes a hash staleness check: if `verified_hash` doesn't match current upstream content hash, re-verify
- [ ] If `source` field is empty (no upstream), both extract-mode and retroactive checks are skipped with a note: "No upstream artifact specified — skipping verification."
- [ ] If `source` field points to a path that does not exist, the skill logs a warning ("Upstream artifact at [path] not found — skipping verification") and proceeds without blocking
- [ ] If upstream artifact has malformed frontmatter (unparseable YAML), extract-mode warns and proceeds with extraction based on headings only — it does NOT block the skill
- [ ] Retroactive verification depth limit: verify only the immediate upstream, not the entire chain
- [ ] If retroactive verification discovers that the upstream artifact's own `source` is also unverified (chain gap), log a warning: "Note: [upstream path]'s own upstream at [source path] has not been verified. Consider running verification on the full chain." Do NOT recurse — warn only.

**Negative tests:**
- [ ] Extract-mode does NOT block on unstructured upstream — it warns and proceeds
- [ ] Retroactive verification does NOT recurse through the entire pipeline chain
- [ ] Phase 0 additions do NOT modify existing Phase 0-pre breadcrumb logic
- [ ] Phase 0 does NOT crash or block if `source` points to a missing file

**Evidence requirements:**
- Diff of each SKILL.md showing Phase 0 additions and their exact placement relative to existing steps
- Confirmation that new logic is additive (doesn't replace existing Phase 0 steps)

**Rollback plan:** Remove the extract-mode and retroactive verification sections from each SKILL.md's Phase 0.

---

### Task 5: Test Verifier on Real + Synthetic Artifacts

**Risk:** H — This is where we find out if the verifier actually works.
**Depends on:** Tasks 1, 3, 4 (full verifier system must be wired).

**Intent:** Run the verifier against 2 real workflow artifact pairs + 1 synthetic known-bad artifact, validate dispositions, and tune the verifier prompt based on results.

**Scope:** "Done" means the verifier has been tested on 3 artifact pairs (2 real + 1 synthetic), dispositions are hand-labeled for comparison, accuracy is documented, and prompt adjustments are made if needed.

**Context:** The verifier is a heuristic semantic classifier. Without testing on real artifacts, we don't know its false-positive or false-negative rate. This task establishes the baseline accuracy.

**Key components:**
- Real pair 1: `Research/conversations/pipeline-handoff-verification/summary.md` → `Research/features/pipeline-handoff-verification/research.md`
- Real pair 2: Any other completed workflow in the `Research/` directory
- Synthetic pair: A known-bad artifact created specifically for this test, with intentional omissions, shirking patterns, and deferred items
- The verifier prompt at `.claude/skills/_shared/handoff-verifier.md`

**Acceptance criteria:**
- [ ] Create a synthetic known-bad artifact pair with intentional: 1 omission, 1 shirked item (hollow section), 1 shirked item (LLM-specific pattern), 1 legitimately deferred item with `[DEFERRED: reason]`, 1 override with `[VERIFIED: override — reason]`. Document in `{EVIDENCE_ROOT}/assets/task_05_synthetic_artifact.md`
- [ ] Verifier tested on all 3 upstream→downstream artifact pairs (2 real + 1 synthetic)
- [ ] Each test: hand-label expected dispositions for every extracted item BEFORE running the verifier
- [ ] Each test: run verifier and compare actual vs expected dispositions
- [ ] Document accuracy: agreement rate (verifier vs hand labels) per disposition type (COVERED, SHIRKED, MISSING, DEFERRED, OVERRIDE)
- [ ] If accuracy < 85% on any disposition type, identify the failure pattern and adjust the verifier prompt
- [ ] Test the context window guard: run the verifier against the synthetic artifact with >20 extracted items (pad the synthetic artifact if needed). Verify output shows batched processing.
- [ ] All test results documented in `{EVIDENCE_ROOT}/assets/task_05_verifier_output.md`
- [ ] Any verifier prompt adjustments are documented with before/after and rationale

**Negative tests:**
- [ ] Do NOT skip hand-labeling — automated-only testing hides systematic biases
- [ ] The synthetic artifact MUST include at least 1 instance of each disposition type — clean-pass-only testing is insufficient

**Evidence requirements:**
- Full verifier output for each test pair
- Hand-labeled ground truth alongside verifier output
- Accuracy summary table by disposition type
- Synthetic artifact contents
- Any prompt adjustments with rationale

**Rollback plan:** N/A — testing is non-destructive.

---

### Task 6: Smoke Test — End-to-End Verification

**Risk:** M
**Depends on:** All prior tasks (full system must be integrated).

**Intent:** Run a complete skill invocation with the verifier wired in and confirm the end-to-end flow works: extract at startup, verify at completion, output checklist, stamp frontmatter, version on re-run.

**Scope:** "Done" means we can demonstrate: (1) extract-mode outputs item count at startup, (2) verify-mode produces a correct traceability checklist at completion, (3) frontmatter is stamped on PASS, (4) FAIL produces actionable error message, (5) re-run versions the previous output.

**Expected behavior:** Run `/serious-plan` on the research artifact for this workflow. The verifier should fire automatically, produce a traceability checklist, and either PASS (stamping frontmatter) or FAIL (showing specific gaps).

**Acceptance criteria:**
- [ ] Running a downstream skill (e.g., `/serious-plan`) on a research artifact triggers extract-mode at startup with item count output
- [ ] After the skill produces its output, verify-mode fires automatically via sub-agent spawn (not inline)
- [ ] Verifier produces a traceability checklist containing: numbered item list, disposition labels (emoji + text), confidence indicators `[high/medium/low]`, location references, verdict line, and upstream incompleteness warning
- [ ] On PASS: downstream artifact's frontmatter contains `verified`, `verified_source`, `verified_hash` fields with correct values
- [ ] On FAIL: output includes specific gaps (item number + description), override syntax (`[VERIFIED: override — reason]`), and re-run instruction (path + command)
- [ ] `_extracted_items.md` exists in the downstream artifact's folder
- [ ] `_traceability_check.md` exists in the downstream artifact's folder
- [ ] **Re-run versioning:** Run the verifier a second time on the same artifact. After the second run, `_traceability_check_v1.md` exists (first run's output) and `_traceability_check.md` contains the second run's output.

**Evidence requirements:**
- Full output of the end-to-end run (both runs)
- Copy of the traceability checklist output
- Frontmatter of the downstream artifact showing verification stamps
- Proof of `_traceability_check_v1.md` existence after second run

---

## Appendix

### Technical Decisions

1. **Sharing mechanism:** Direct path + prose instruction (not `@include`, not markdown link references — neither works in SKILL.md files). The conversation output used "markdown link references" imprecisely; the actual mechanism matches serious-plan's template reference pattern.
2. **Sub-agent vs inline:** Verification MUST run as a sub-agent spawn (Agent tool) to avoid sycophantic bias from the session that produced the downstream artifact
3. **Hash scope:** Hash extractable sections only (not full file) to avoid false re-verification from metadata/formatting changes
4. **Substance threshold:** Require 2+ of 5 signals (raised from 1 based on Devil's Advocate review — single-signal threshold was too permissive)
5. **Framing:** Shirking detection is heuristic semantic judgment, not structural pattern matching. PASS verdicts have a non-zero false-negative rate.
6. **Bootstrap:** This plan's own frontmatter uses a `source` field that won't be standardized until Task 3 is executed — this is intentional bootstrapping, not an error.

### Dependencies

| Task | Depends on |
|---|---|
| Task 0 | Nothing |
| Task 1 | Nothing |
| Task 2 | Nothing |
| Task 3 | Task 1 (verifier file exists at runtime) |
| Task 4 | Task 1 (verifier file exists), Task 3 (source field populated) |
| Task 5 | Tasks 1, 3, 4 (full system wired) |
| Task 6 | All prior tasks |

### Out of Scope

- Contradiction detection (detecting when downstream says the opposite of upstream) — deferred to v2
- DEFERRED item limits (capping how many items can be deferred per artifact) — needs usage data first
- Automated feedback loop (prompting users to report misclassifications) — deferred to v2
- `_shared/phase-0-pre.md` extraction (the DRY fix for Phase 0-pre) — separate workflow
- research→mock-ups transition verification — deferred until mock-ups usage patterns are established

### Input Source

Research: `Research/features/pipeline-handoff-verification/research.md`
Conversation: `Research/conversations/pipeline-handoff-verification/summary.md`

### Changelog

| Date | Change |
|---|---|
| 2026-03-19 | Initial plan generated from research |
| 2026-03-19 | v2: Integrated QA Engineer review (16 findings: 3C, 7M, 6m) and Senior Engineer review (7 findings: 1C, 2M, 4m). Added multi-plan verification to Task 1. Added mock-ups→plan conditional verifier to Task 3. Added CLAUDE.md update to Task 3. Added non-existent source path and malformed frontmatter handling to Task 4. Added synthetic known-bad artifact and chunking guard test to Task 5. Added re-run versioning test to Task 6. Specified exact placement for all SKILL.md additions. Added explicit task dependencies. Fixed task count math. Enumerated all acceptance criteria to be self-contained (no cross-referencing needed). |
