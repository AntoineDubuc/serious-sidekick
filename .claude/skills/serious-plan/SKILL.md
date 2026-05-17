---
name: serious-plan
description: "Generate a structured implementation plan from research, a PRD, or a brief description, using the v6 template. Use when the user says 'serious plan', 'create implementation plan', 'plan the implementation', 'write the plan', or wants to move from research to execution."
user-invocable: true
---

# Serious Plan

Generate a complete implementation plan using the v6 template methodology. Adapts to whatever input material the user has — from a full `/serious-research` deliverable down to a verbal description.

<!-- BEGIN CANONICAL VOICE BLOCK — do not edit; lint compares byte-for-byte across 24 surfaces -->
## Voice (MANDATORY — applies to all chat replies)

Talk to the user like a busy PM, not an engineer. Every chat reply uses this structure:

1. **What this does** — one sentence. Plain English. What the user experiences.
2. **What I need from you** — one ask, sometimes a short numbered list.
3. **What you need to set up first** — only if there's prep on the user's side.
4. **Question** — one line. Just the question, no preamble.

Style:
- ~10 lines max.
- No internal task labels ("Task 5", "Phase 2", "Plan 7B", "1v", "T0").
- No bare ordinal options ("Option 1", "Option 2"). Label alternatives by what they are.
- No file paths, library names, or framework names in chat.

Canonical card: `.claude/skills/_shared/voice-card.md`.
<!-- END CANONICAL VOICE BLOCK -->

## Template Reference

The full v6 implementation plan template lives at:
```
./_implementation_plan_template_v6.md
```

**Read this file before generating any plan.** It contains the complete structure, TDD protocol, QA protocols, verification procedures, and evidence generation standards that every plan must follow.

---

## Phase 0: Intake

**Goal:** Figure out what input material exists and meet the user where they are.

### 0-pre. Check for active parent workflow

Before anything else, check for active workflow breadcrumbs in the project root:

1. **Scan for breadcrumbs:** Source `.claude/skills/_shared/path-resolve.sh`. Run `breadcrumb_sweep` once to reap orphaned per-session breadcrumbs left behind by terminals that crashed without cleanup, then run `breadcrumb_migrate` once to delete legacy `.active-{skill}` files at the project root under the agreement-or-orphan condition (preserves `.active-conversation` as the in-flight parent carve-out; emits `MIGRATE:` lines to stderr for every action). Then for each known skill name in the writer roster (`conversation`, `research`, `mock-ups`, `scope`, `plan`, `review`, `code`), check the per-session path first by running `bc=$(breadcrumb_path {skill})` and testing `[ -f "$bc" ]` (this resolves to `.claude-active/{claude_pid}-{skill}`); if not found, fall back to the legacy `.active-{skill}` at the project root and emit `WARN: dual-read fallback for {skill}` to stderr (transition-window cleanup will remove these in Task 6). Treat each found breadcrumb as a candidate for the validation steps below.
2. **Validate each:** For each breadcrumb found, verify the target folder exists and contains a valid output file with parseable YAML frontmatter. If not, delete the stale breadcrumb with a warning: "Removed stale .active-{skill} breadcrumb (target folder missing)."
2b. **Status-based staleness check:** For each validated breadcrumb, read the first 10 lines of the target file and grep for `^status:` to extract the value. If the value is `done` or `abandoned`, the breadcrumb is stale (skill completed but cleanup was interrupted). Remove the `.active-*` file silently — do not prompt the user.
2c. **Age-based staleness check:** If the breadcrumb's target file has `status: active`, check the `.active-*` file's modification time using Bash (`stat -f %m` on macOS or `stat -c %Y` on Linux, or `ls -l` as a portable fallback). If the file is older than 4 hours, warn: "Found .active-{skill} for {slug}, but it hasn't been modified in {N} hours. This may be from an interrupted session. Treat as active? (Y/N)". If the user says No, remove the breadcrumb and proceed. If Yes, treat as a valid active breadcrumb and continue to step 4.
3. **If no valid breadcrumbs exist:** Proceed directly to Phase 0a without any output. Do NOT mention breadcrumbs, scanning, or the absence of active workflows. This is the normal state — the previous skill completed and cleaned up its breadcrumb.
4. **Determine the deepest active workflow:** If multiple valid breadcrumbs exist, follow `parent:` chains in each breadcrumb's target frontmatter. The workflow with the longest parent chain is the deepest. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.
5. **Compare pipeline order:** This skill is `plan` (order 5). The deepest active skill is order {M}.
   - **Pipeline order:** youtube-tldr(0.5) → conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7) → debug(8)
   - If 5 > {M}: this is **advancing**. Proceed directly to the next phase without any output about breadcrumbs or pipeline ordering. Both breadcrumbs coexist. Advancing means normal behavior — no new logic needed. The skill uses its existing folder rules. No parent field is set. No prompt is shown. No sub/ folder is created. Both the new skill's breadcrumb AND the existing skill's breadcrumb coexist.
   - If 5 ≤ {M}: this is **branching**. Continue to step 6.
6. **Branching prompt:**
   - **Cross-skill:** "I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"
   - **Same-skill (plan → plan):** "I see you're already in /serious-plan for {slug}. Start a nested /serious-plan within it? (Y/N)" Note: the existing `.active-plan` breadcrumb will be overwritten with the new sub-workflow's path.
7. **If YES (sub-workflow):**
   - Compute proposed depth: follow `parent:` chain from the proposed parent's frontmatter, count hops until no `parent:` field, add 1.
   - **Depth guard:** If proposed depth ≥ 3, warn: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If No: do not create the sub-workflow, return without starting the new skill.
   - Set `parent` in this workflow's frontmatter to the parent's output folder path
   - Create output at `{parent_folder}/sub/{slug}/` instead of the normal location
8. **If NO:** Create output in normal location, no parent field set.
9. **Same-skill restoration:** On wrap-up/completion of this skill, if frontmatter has a `parent:` field and the parent was the same skill type (plan), restore the breadcrumb by **re-running the writer block** with the parent's folder path as `${RELATIVE_OUTPUT_PATH}` and `${SKILL}=plan`. The writer block writes to `.claude-active/$(claude_pid)-plan`, NOT the legacy `.active-plan` at the project root. This works even if the parent was itself a sub-workflow (depth 2), because the parent's frontmatter has its own parent reference, and the breadcrumb just needs to point to the immediate parent.

### 0a. Auto-detect existing research

Before asking anything, scan the project:

- Check if `$ARGUMENTS` specifies a manifest entry path (e.g., `Research/features/{slug}/manifest.md#Plan-1`). If so, read the manifest, extract the specified plan entry, and skip to Phase 0c for validation. The manifest entry provides: title, boundary, rationale, dependencies, shared contracts, and tags.
- Check `Research/bugs/*/research.md`, `Research/features/*/research.md`, `Research/exploratory/*/research.md` for files with `status: done` in YAML frontmatter (primary), with fallback to `**Status: Complete**` bold headers for legacy files
- Check sub-workflow paths: `Research/**/sub/*/research.md` (same dual-check)
- Check legacy paths: `Bugs/*/research.md`, `New Features/*/research.md`
- Check for `synthesis.md` files (produced by deep-mode `/serious-research`)
- Check for `mock-ups/mock-up-summary.md` alongside research files (produced by `/serious-mock-ups`)
- Check sub-workflow mock-ups: `Research/**/sub/*/mock-ups/mock-up-summary.md`
- If `$ARGUMENTS` specifies a path, use that directly and skip to Phase 1

### 0b. Present what you found

<!-- voice-retrofit: rewritten; thread-1 line: 67 -->
<!-- voice-retrofit: rewritten; thread-1 line: 70 -->

Use the PM voice. Translate file content to plain English ("the deep research we did on X"). Never paste paths or {placeholder} tokens into chat.

**If a manifest entry was specified:**

> What this does: I'm using the scope manifest entry you pointed me at — building the plan for the feature it describes.
>
> Question: ready to start?

**If exactly one completed research found:**

> What this does: I found the deep research we did on this. I'll use it as the basis for the plan.
>
> Question: use it?

**If multiple found:**

> What this does: a few research write-ups match. I'll describe each in one sentence and you pick.
>
> Question: which?

**If nothing found**, ask in PM voice — recommend ONE path, don't present a 5-option menu.

<!-- voice-retrofit: rewritten; thread-1 line: 75 -->

> What this does: there's no research write-up or scope manifest on disk yet. The fastest path is for you to describe the feature in a sentence and I'll work from that. We can always upgrade to a full investigation later.
>
> Question: describe what you want, or run the deep research step first?

If the user mentions they have a PRD or Jira ticket, just take it. The 5-input-type menu is for the agent's own awareness (manifest, research output, PRD/spec, run-research, brief description) — internal options, NOT a chat menu.

### 0c. Validate the input

Whatever the source, assess whether there's enough to generate a quality plan:

**Sufficient for planning:**
- Manifest entry with boundary, rationale, and at least one tag
- Clear description of what to build or fix
- Enough context to identify affected files/components
- Enough detail to write testable acceptance criteria

**Insufficient — ask clarifying questions ONE AT A TIME:**

<!-- voice-retrofit: rewritten; thread-1 line: 93 -->

Per CLAUDE.md rule 9 (one question per message), ask each question separately and wait for the answer before asking the next. Recommended sequence — start with what the user experiences, then the touchpoints, then constraints. PM voice format ("What this does / Question") for each:
- What's the expected user-facing behavior?
- What components/systems does this touch?
- Are there constraints (performance, compatibility, security)?
- What does "done" look like?

**If input is a brief description (option 4), add a disclaimer to the plan:**

<!-- voice-retrofit: rewritten; thread-1 line: 100 -->

> What this does: I wrote the plan from your short description, not a full investigation. It'll work, but it's a thinner foundation than starting with structured research.
>
> Question: want to run the research step before we build this, or proceed?

### 0d. Upstream extract-mode pre-check — MANDATORY GATE

**This step is MANDATORY when an upstream artifact exists. Skip it and the plan WILL have gaps. DO NOT proceed to Phase 1 until `_extracted_items.md` exists in the output folder.**

Once the upstream research artifact is identified (from 0a/0b/0c):

1. **If no upstream artifact is specified** (plan generated from description, `source` will be empty): output "No upstream artifact specified — skipping extraction." Skip the rest of 0d. Phase 1 may proceed without `_extracted_items.md`.
2. **If the upstream path does not exist on disk**: STOP. Output "ERROR: Upstream artifact at [path] not found. Cannot proceed without extraction. Please provide the correct path." Do NOT proceed to Phase 1.
3. **Read the upstream artifact's YAML frontmatter.** If frontmatter is malformed or unparseable, warn and proceed with heading-based extraction only — extraction must still complete.
<!-- voice-retrofit: rewritten; thread-1 line: 111 -->
4. **Run extract-mode** per the protocol in `.claude/skills/_shared/handoff-verifier.md`: read the upstream artifact, extract enumerable items from contract sections (Findings, Recommendations), and write `_extracted_items.md` to this plan's output folder. **For the user-facing message, use PM voice — don't dump "Found N items from M sections in [path]" verbatim.** Example: "What this does: pulled the key items from the research write-up — there are about N things to plan for. Question: ready for me to draft the plan?" **If extraction produces 0 items from a non-empty artifact, STOP and report the extraction failure (in PM voice) — do not proceed with an empty inventory.**
5. **Retroactive verification check** (immediate upstream only — do NOT recurse):
   - If the upstream artifact's frontmatter has no `verified` field, run full verification on it before proceeding.
   - If `verified_hash` exists but does not match the current upstream content hash, re-verify.
   - If the upstream artifact's own `source` field points to an unverified artifact (chain gap), warn: "Note: [upstream path]'s own upstream at [source path] has not been verified. Consider running verification on the full chain." Do NOT recurse — warn only.
<!-- voice-retrofit: rewritten; thread-1 line: 116 -->
6. **Gate check:** Confirm `_extracted_items.md` exists and contains at least 1 item. For the user, no "Extraction complete: N items from [path]" status banner — that's process narration. Silently proceed to drafting the plan. Only then may Phase 1 begin.

### 0f. Determine the plan location

**Write `.claude-active/{claude_pid}-plan`** at the project root FIRST (before creating the plan file). Use a SUBSHELL so `umask` does not leak to the rest of the skill, and CORRECT directory permissions if `.claude-active/` pre-exists with wider perms. Content is the relative path from project root to the plan folder.

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
  bc=$(breadcrumb_path plan) || exit 1
  printf '%s\n' "${RELATIVE_OUTPUT_PATH}" > "$bc"
)
```

The outer `( ... )` subshell scopes `umask 077` so the caller's umask is unchanged after this block. The pre-existing-perm correction enforces `0700` on `.claude-active/` even if a previous-version skill or attacker created it with wider perms.

**If a manifest entry was provided (from `/serious-scope`):** The manifest specifies the plan's output path. Use it directly.

**If input came from `/serious-research` (no manifest):** Create `implementation_plan.md` in the same folder as the research.

**If input came from a PRD or description (no manifest):** Create a folder under `Research/features/{slug}/` (or `bugs/` or `exploratory/` as appropriate), put the plan there, and save the input material alongside it for traceability.

---

<!-- GUARDRAILS — DO NOT EDIT WITHOUT REVIEWING FAILURE EVIDENCE -->

> **Before acting on any phase below, check this table.**
> If your planned action matches a Rationalization entry, STOP and follow the Correct Action instead.

| # | Rationalization | Correct action | Why it fails |
|---|----------------|----------------|--------------|
| 1 | "This feature is straightforward — tests aren't needed for every task" | Write a failing test for every acceptance criterion. Zero exceptions. | 4/4 plan bugs traced to missing test specifications. Implementer skips what the plan doesn't require. |
| 2 | "I'll specify tests in a later pass / cleanup phase" | Each task description includes its test file and assertion. Now, not later. | Post-hoc test specs verify the plan, not the feature. They get written to match what was built, not what was needed. |
| 3 | "A general description captures the intent — the implementer will know what to do" | Name the file, the function, the type, the line range. No hedge words. | Every downstream failure in the evidence log traces to vague language ("consider", "as needed") in upstream artifacts. Vague inputs produce vague outputs. |
| 4 | "Seed data setup is obvious — no need to spell out commands" | Write the exact SQL, fixture script, or API call. Copy-paste-runnable. | Generic "data is in place" checkboxes cause Task 0 smoke tests to fail, blocking all downstream tasks. |
| 5 | "This component is too simple for the full process" | The process applies regardless of perceived simplicity. Follow every phase. | The 4 documented /serious-plan failures ALL occurred in "simple" features where shortcuts seemed safe. Complexity is not the threshold. |
| 6 | "The guardrail table doesn't apply to this situation" | It applies unconditionally. If you're reasoning about why a row doesn't apply, that IS the rationalization the row describes. | This is second-order rationalization. The table exists because of situations that "seemed different." |
| 7 | "I'll resolve this ambiguity during implementation — no need to decide now" | Resolve it now. If you lack information, ask the user. Do not ship an unresolved decision to the implementer. | Deferred decisions become deferred failures. The implementer guesses wrong, builds the wrong thing, rework follows. |

<!-- END GUARDRAILS -->

## Pre-Generation Commitment

**Before generating the plan**, write `_commitment.md` to the plan's output folder:

```markdown
## Commitment — /serious-plan
I will produce: [list deliverables: task count, test specs per task, seed data commands, specific file references]
I will NOT skip: [list top 3 from guardrail table: test specs, specific names, seed data commands]
Verification: [grep for hedge language, count test file references, verify seed data commands are copy-pasteable]
```


---

## Phase 1: Plan Generation

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 184 -->
<!-- WHY: this is an agent-self-instruction guardrail (a STOP banner addressed to the agent's
     own reasoning, not chat output). The tone is intentionally emphatic to prevent the agent
     from skipping the extraction gate. Never surfaces in chat. -->

**STOP. If an upstream artifact was specified in Phase 0, does `_extracted_items.md` exist in the output folder? If not, go back to Phase 0d. DO NOT generate a plan without the extraction inventory — this is the #1 cause of drift.**

Read the v6 template file first. If a `mock-ups/mock-up-summary.md` exists alongside the research, read it too — use the component inventory for task breakdown, design decisions for acceptance criteria, screen flow for navigation tasks, and responsive notes for breakpoint tasks.

**While generating the plan, cross-reference `_extracted_items.md` continuously.** Every extracted item must appear as a task, acceptance criterion, or explicit `[DEFERRED: reason]` in the plan. Do not rely on memory of the upstream artifact — use the extracted inventory as a checklist.

The implementation_plan.md MUST start with YAML frontmatter containing all 5 standard fields:

```yaml
---
skill: serious-plan
slug: {slug}
status: active
parent:
created: {date}
source: # Set to the path of the research.md consumed, or leave empty if plan was generated from description
---
```

Then work through each section in order, filling it in based on the input material.

### Executive Summary
- One paragraph: what, why, who, why it matters
- Key outcomes (3-5 bullet points)
- Derive from the research findings, PRD, or user description

### Project Configuration
- Fill the variable table (`{EVIDENCE_ROOT}`, `{STATIC_ANALYSIS_CMD}`, etc.)
- Detect project tooling from the codebase: package.json, Makefile, pyproject.toml, etc.
- If unsure about a command, check the codebase or ask the user
- Set `{EVIDENCE_ROOT}` to `./evidence` inside the plan folder
- Set `{STUB_PATTERNS}` — project-specific patterns that indicate hollow/stub code (e.g., `throw UnimplementedException`, `// TODO`, `return null`, `Scaffold()`, `placeholder`). These are checked after each file write during implementation.
- Set `{RUNTIME_VERIFY_CMD}` — command to verify the app works at runtime, used for inter-plan regression checks (e.g., `flutter test integration_test/`, `npx playwright test`). Leave empty if unavailable.

### Product Manager Review
- Translate findings into feature descriptions
- Each feature gets: What it is, Why it matters, User perspective
- Keep it non-technical — a PM should understand this section

### Pre-Flight Readiness
- Adapt the checklist to this specific project
- Verify each item is actually checkable (commands exist, paths are real)
- For the "Mock/seed data ready" item, write the **specific commands** needed to set up test data — SQL statements, API calls, fixture scripts, or seed commands. Never leave this as a generic "data is in place" checkbox. The implementing agent must be able to copy-paste and run the setup.

### Test-Driven Development Protocol
- Copy the v6 TDD Protocol section verbatim — it is non-negotiable
- This section defines the RED→GREEN→REFACTOR→VERIFY cycle that applies to every task

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
- **Key components** — specific files and functions. **Include test files** that reference or assert against modified code. Grep for imports/assertions on changed files to discover affected test files. Every source file in the list should have its corresponding test file(s) listed too.
- **Impact analysis** — what other components consume the output of the changed code? Follow the chain:
  - What calls the changed function?
  - What renders data from the changed data source?
  - What caches/indexes recompute when this data changes?
  - List each downstream consumer and whether it handles the new behavior correctly.
- **Reference implementation** *(when applicable)* — if the research identified sync pairs (functions that must produce equivalent output), specify the counterpart function that this task's code must match. Format: `Match [function name] at [file:line] — case-for-case, field-for-field.` This tells the implementer exactly what to stay in sync with, preventing drift between parallel code paths.
- **Source traceability** — for each acceptance criterion, cite the upstream source: `[Source: research.md#Finding-3]` or `[Source: manifest.md#Plan-1]`. Criteria without a source citation are either invented (remove them) or represent a research gap (flag for user review with `[NO SOURCE: reason]`).
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
- **Every criterion must cite its upstream source** using `[Source: path#section]`. Criteria that can't cite a source are not derived from research — they're invented. Either trace them to a finding or annotate with `[NO SOURCE: reason]` so the reviewer knows it's a deliberate addition, not drift.
- **Irreversible actions require a safety pattern.** Any task involving a destructive or irreversible operation (merge, delete, finalize, publish, drop, archive) must include an acceptance criterion specifying the confirmation UX: type-to-confirm (user types the entity name), two-step confirm, undo window, or equivalent. The criterion must name the specific pattern — e.g., "Dialog includes a text input requiring the user to type the change name before the confirm button enables."

### Appendix
- Technical decisions (from research or inferred from requirements)
- Dependencies (libraries, APIs, services)
- Out of scope (explicitly list what this plan does NOT cover)
- Changelog (track plan revisions)
- Input source (link to research.md, PRD, or note that it was generated from a description)

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
- [ ] If research identified sync pairs, every task that modifies one side of a pair has a Reference Implementation field pointing to the other side
- [ ] **No hedge language in task descriptions.** No "consider whether", "you might want to", "think about", "it may be worth". Every Note must state a decision with a file:line reference, not present options for the implementing agent to choose from. If a decision hasn't been made, it's a planning gap — resolve it now, don't defer it to the implementer.
- [ ] **Every acceptance criterion has a `[Source: ...]` citation** or an explicit `[NO SOURCE: reason]` annotation. Criteria without either are unsigned — they may be invented by the agent rather than derived from research.

---

## Phase 3: Present to User — VERIFICATION GATE

**DO NOT present the plan to the user until the handoff-verifier has run and PASSED.** This is a hard gate — not advisory.

### Upstream Traceability Verification

If the `source` field in the plan's frontmatter is empty (plan was generated from a description), skip verification and proceed to presentation.

If the `source` field points to a `research.md`, run the verifier:

```
.claude/skills/_shared/handoff-verifier.md
```
**Spawn a verification sub-agent using the Agent tool with the protocol described in this file. Pass these parameters:**
- **Upstream artifact:** the path in the `source` frontmatter field (`research.md`)
- **Downstream artifact:** the path to this skill's `implementation_plan.md` output
- **Match strategy:** `structural`

<!-- voice-retrofit: deferred — reason: covered-by-translator; thread-1 line: 349 -->
<!-- WHY: SHIRKED/MISSING/CONTRADICTED/PASS WITH DEFERRALS is internal verifier vocabulary
     for the agent's own loop. Task 3's voice-translator wires into the plan-reveal
     touchpoint and rewrites any verdict that leaks into chat to PM voice. The internal
     loop here can keep its precise vocabulary. -->

**On FAIL:** DO NOT present the plan. Fix every SHIRKED, MISSING, and CONTRADICTED item in the plan. Then re-run the verifier. Repeat until PASS or PASS WITH DEFERRALS. Only then proceed to presentation.

**On PASS or PASS WITH DEFERRALS:** Proceed to presentation. The verifier will have stamped the plan's frontmatter with `verified`, `verified_source`, and `verified_hash`.

### Conditional Mock-Ups Verification

If a `mock-up-summary.md` exists alongside the research (in a `mock-ups/` subdirectory of the research folder), run a second verification to ensure the plan covers the mock-up deliverables:

```
.claude/skills/_shared/handoff-verifier.md
```
**Spawn a verification sub-agent using the Agent tool with the protocol described in this file. Pass these parameters:**
- **Upstream artifact:** the path to the `mock-up-summary.md` (Component Inventory + Design Decisions table rows)
- **Downstream artifact:** the path to this skill's `implementation_plan.md` output
- **Match strategy:** `structural`

If no `mock-up-summary.md` exists, skip this second verification.

**Same gate applies:** On FAIL, fix and re-verify before presenting.

### Presentation

Only after all verification passes (or is skipped due to empty `source`), present the plan and set `status: done` in the YAML frontmatter. Then remove the breadcrumb. During the dual-read transition window, BOTH the new-path breadcrumb AND any legacy `.active-plan` at project root must be removed:

```bash
new_bc=$(bash -c 'source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh" && breadcrumb_path plan')
rm -f "$new_bc" "${CLAUDE_PROJECT_DIR}/.active-plan"
```

<!-- voice-retrofit: rewritten; thread-1 line: 378 -->

**Report via the voice-translator sub-agent.**

This is one of the four highest-value PM-voice touchpoints. Spawn the `voice-translator` sub-agent via the Agent tool. Pass a structured payload (NOT a temp file). Translator returns the chat reply in PM voice; emit it verbatim.

Dispatch protocol:
1. **Build the payload** as a structured prompt-string argument to the Agent tool. Include:
   - Trusted fields (unwrapped, semantic): `event: plan-presentation`, `mode: {single-plan|multi-plan}`, `recommended_next: review`.
   - Untrusted fields (each wrapped in `<payload>...</payload>` tags): `findings` (task count, time estimate, biggest pieces in plain English), `file_paths` (the plan file location for the operator log), `upstream_decisions_needed` (any open questions).
2. **Spawn `voice-translator`** with a 10-second timeout. NO retry on transient errors.
3. **Emit the translator's output verbatim** — no prefix, no suffix, no editing.
4. **If the translator returns `TRANSLATOR_ERROR: <reason>`** or times out (10s wall clock) or the Agent tool errors (5xx, 429, network), emit the hard-coded fallback:

   > What this does: the plan is drafted and saved locally.
   >
   > Question: ready to review it before we build?

   Do NOT retry the translator. One attempt per touchpoint.

The technical details (file path, task count, source disclaimer) are written to disk in the plan file. The user sees the translated summary.

Reference example of a clean translator output (for the operator to compare against in case of weird translator behavior):

> What this does: drafted the plan — about {N} steps to build the feature, biggest piece is {one-sentence summary}. I recommend we have it reviewed before we start building.
>
> What I need from you: any concerns to address up front, otherwise approve the review pass.
>
> Question: run the review now, or skim the plan first?

---

## Recommended Stop Hook (Safety Net)

Add the following to your project's `.claude/settings.json` to catch plans that bypass the in-skill verification gates. This hook fires when the session ends and checks that any active plan directory contains `_extracted_items.md`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "source \"$CLAUDE_PROJECT_DIR/.claude/skills/_shared/path-resolve.sh\"; bc=$(breadcrumb_path plan); if [ -f \"$bc\" ]; then plan_dir=$(cat \"$bc\"); elif [ -f .active-plan ]; then plan_dir=$(cat .active-plan); echo 'WARN: dual-read fallback for plan from legacy path' >&2; else exit 0; fi; if [ ! -f \"$plan_dir/_extracted_items.md\" ]; then echo 'WARNING: Plan at '$plan_dir' has no _extracted_items.md — upstream verification was skipped. Run Phase 0d before using this plan.' >&2; fi",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

This is a safety net, not the primary enforcement mechanism. The in-skill gates (Phase 0d and Phase 3) are the first line of defense. The hook catches cases where a sub-agent or interrupted session bypassed them.

---

## Arguments

`$ARGUMENTS` can specify:
- A path to research: `/serious-plan Research/features/notifications/research.md`
- A path to a PRD or spec: `/serious-plan docs/prd-notifications.md`
- Or nothing — the skill will auto-detect or ask

---

## What Comes After

Once the user approves the plan:

1. Run `/serious-review` to review the plan before `/serious-code`
2. Fixes from review are rewritten into the plan
3. Run `/serious-code` to begin implementation
4. `/serious-code` follows the Master Checklist with TDD, QA, and verification

