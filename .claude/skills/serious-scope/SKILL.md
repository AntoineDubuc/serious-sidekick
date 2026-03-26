---
name: serious-scope
description: "Generate a scope manifest that splits research into discrete implementation plans. Use when the user says 'serious scope', 'scope this', 'how many plans', 'split this', or wants to define plan boundaries before running /serious-plan."
user-invocable: true
---

# Serious Scope

Read research output, propose how to split the work into implementation plans, and write a manifest after user approval. A lens, not an engine — no persona pipeline, no quality validation.

## Phase 0: Intake

### 0-pre. Check for active parent workflow

1. **Scan for breadcrumbs:** Check for `.active-conversation`, `.active-research`, `.active-mock-ups`, `.active-scope`, `.active-plan`, `.active-code`, `.active-review`
2. **Validate each:** Verify target folder exists with valid YAML frontmatter. Delete stale breadcrumbs with warning.
3. **If no valid breadcrumbs:** Skip to Phase 0a (top-level workflow).
4. **Deepest active workflow:** Follow `parent:` chains. Longest chain = deepest. If multiple independent top-level breadcrumbs, use most recently modified.
5. **Compare pipeline order:** This skill is `scope` (order 4). Pipeline: conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7)
   - If 4 > {M}: **advancing** — skip to Phase 0a.
   - If 4 ≤ {M}: **branching** — continue to step 6.
6. **Branching prompt:** Cross-skill: "Link as sub-workflow? (Y/N)" Same-skill (scope→scope): "Start nested /serious-scope? (Y/N)" (overwrites `.active-scope`).
7. **If YES:** Depth guard (≥3 = warn). Set `parent` in frontmatter. Output at `{parent_folder}/sub/{slug}/`.
8. **If NO:** Normal location, no parent field.
9. **Same-skill restoration:** On completion, if `parent:` exists and parent was scope, restore `.active-scope` with parent's folder path.

### 0a. Auto-detect research

- Check `Research/features/*/research.md`, `Research/bugs/*/research.md`, `Research/exploratory/*/research.md` for `status: done` in YAML frontmatter
- Check sub-workflow paths: `Research/**/sub/*/research.md`
- If `$ARGUMENTS` specifies a path, use that directly and skip to Phase 0b
- **One found:** "Use this as the basis for scoping?" **Multiple:** list and ask. **None:** "Run `/serious-research` first, or provide a path."

### 0b. Upstream extract-mode pre-check — MANDATORY GATE

**DO NOT proceed to Phase 1 until `_extracted_items.md` exists in the output folder.**

1. Read the research artifact identified in 0a.
2. **Run extract-mode** per `.claude/skills/_shared/handoff-verifier.md`: extract items from contract sections (Findings, Recommendations), write `_extracted_items.md`. If 0 items from non-empty artifact, STOP.
3. **Gate check:** `_extracted_items.md` exists with ≥1 item. Only then may Phase 1 begin.

## Phase 1: Scope

Read extracted items and research findings/recommendations. Identify natural plan boundaries:

- **Group by concern:** clusters sharing a theme, component, or dependency chain
- **Check coupling:** tightly coupled items → same plan; independent items → separate plans
- **Propose a split.** Each plan entry must have:
  - **Title** — descriptive name
  - **Boundary** — what's IN, what's explicitly OUT
  - **Rationale** — why this is separate (MANDATORY — prevents planner from recombining)
  - **Dependencies** — which plan slugs must complete first
  - **Shared contracts** — interfaces this plan must honor
  - **Tags** — freeform (e.g., auth, user-data, infra, external-api) — flag, do not interpret

## Phase 2: Present

Show the proposed manifest to the user. Interactive — the user may adjust boundaries, add/remove/merge/split plans, edit rationale or tags. **Wait for explicit approval before proceeding.**

## Phase 3: Write

After approval, write `manifest.md` to the same folder as `research.md`:

```yaml
---
skill: serious-scope
slug: {slug}
status: active
source: {path to research.md}
created: {date}
---
# Scope Manifest: {Title}
## Overview
{One paragraph — what the research says we need to build}
## Plans
### Plan 1: {title}
- **Boundary:** {what's in, what's explicitly out}
- **Rationale:** {why this is a separate plan}
- **Dependencies:** {which other plan slugs must complete first}
- **Shared contracts:** {interfaces this plan must honor}
- **Tags:** {freeform labels}
```

Write `.active-scope` breadcrumb to project root (content = relative path to manifest folder).

## Phase 4: Verification — MANDATORY GATE

Run handoff verifier per `.claude/skills/_shared/handoff-verifier.md`:
- **Upstream:** the `source` path (research.md) | **Downstream:** manifest.md | **Strategy:** `structural`

**On FAIL:** Fix MISSING/SHIRKED items, re-verify. Repeat until PASS or PASS WITH DEFERRALS.
**On PASS:** Set `status: done` in manifest frontmatter. Proceed to Phase 5.

## Phase 5: Cleanup

1. Set `status: done` in manifest frontmatter (if not already set).
2. Remove `.active-scope` breadcrumb from project root.
3. **Same-skill restoration:** If `parent:` exists and parent was scope, restore `.active-scope` with parent's folder path.
4. Report: manifest path, number of plans, summary of the split.
