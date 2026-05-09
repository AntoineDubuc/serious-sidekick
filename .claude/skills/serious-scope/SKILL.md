---
name: serious-scope
description: "Generate a scope manifest that splits research into discrete implementation plans. Use when the user says 'serious scope', 'scope this', 'how many plans', 'split this', or wants to define plan boundaries before running /serious-plan."
user-invocable: true
---

# Serious Scope

Read research output, propose how to split the work into implementation plans, and write a manifest after user approval. A lens, not an engine — no persona pipeline, no quality validation.

## Phase 0: Intake

### 0-pre. Check for active parent workflow

1. **Scan for breadcrumbs:** Source `.claude/skills/_shared/path-resolve.sh`. Run `breadcrumb_sweep` once to reap orphaned per-session breadcrumbs left behind by terminals that crashed without cleanup, then run `breadcrumb_migrate` once to delete legacy `.active-{skill}` files at the project root under the agreement-or-orphan condition (preserves `.active-conversation` as the in-flight parent carve-out; emits `MIGRATE:` lines to stderr for every action). Then for each known skill name in the writer roster (`conversation`, `research`, `mock-ups`, `scope`, `plan`, `review`, `code`), check the per-session path first by running `bc=$(breadcrumb_path {skill})` and testing `[ -f "$bc" ]` (this resolves to `.claude-active/{claude_pid}-{skill}`); if not found, fall back to the legacy `.active-{skill}` at the project root and emit `WARN: dual-read fallback for {skill}` to stderr (transition-window cleanup will remove these in Task 6). Treat each found breadcrumb as a candidate for the validation steps below.
2. **Validate each:** Verify target folder exists with valid YAML frontmatter. Delete stale breadcrumbs with warning.
2b. **Status-based staleness:** If target frontmatter has `status: done` or `abandoned`, remove the breadcrumb silently.
2c. **Age-based staleness:** If target has `status: active` and `.active-*` file is older than 4 hours, prompt: "Treat as active? (Y/N)". No → remove. Yes → continue to step 4.
3. **If no valid breadcrumbs:** Proceed directly to Phase 0a without any output. Do NOT mention breadcrumbs or scanning.
4. **Deepest active workflow:** Follow `parent:` chains. Longest chain = deepest. If multiple independent top-level breadcrumbs, use most recently modified.
5. **Compare pipeline order:** This skill is `scope` (order 4). Pipeline: youtube-tldr(0.5) → conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7) → debug(8)
   - If 4 > {M}: **advancing** — proceed directly to the next phase without any output about breadcrumbs or pipeline ordering. Both breadcrumbs coexist.
   - If 4 ≤ {M}: **branching** — continue to step 6.
6. **Branching prompt:** Cross-skill: "Link as sub-workflow? (Y/N)" Same-skill (scope→scope): "Start nested /serious-scope? (Y/N)" (overwrites `.active-scope`).
7. **If YES:** Depth guard (≥3 = warn). Set `parent` in frontmatter. Output at `{parent_folder}/sub/{slug}/`.
8. **If NO:** Normal location, no parent field.
9. **Same-skill restoration:** On completion, if `parent:` exists and parent was scope, restore the breadcrumb by **re-running the writer block** with the parent's folder path as `${RELATIVE_OUTPUT_PATH}` and `${SKILL}=scope`. The writer block writes to `.claude-active/$(claude_pid)-scope`, NOT the legacy `.active-scope` at the project root.

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

<!-- GUARDRAILS — DO NOT EDIT WITHOUT REVIEWING FAILURE EVIDENCE -->

> **Before writing the manifest, check this table.**
> If your planned action matches a Rationalization entry, STOP and follow the Correct Action instead.

| # | Rationalization | Correct action | Why it fails |
|---|----------------|----------------|--------------|
| 1 | "These are tightly coupled and belong in one plan" | Coupling requires shared mutable state or circular dependencies. Sequential dependency is not coupling. Split unless you can name the shared state. | False lumping. Fewer plans = less downstream work, which is the real motivation. Coupled plans hide independent decisions. |
| 2 | "This is too small for its own plan" | If it requires decisions the other plans don't, it's a separate plan. Size is not the criteria. | Scope absorption. Small concerns merged into larger plans get deprioritized or dropped entirely. |
| 3 | "The dependency chain means these must be sequential anyway" | Sequential execution does not mean same plan. Each plan has its own boundary, contracts, and verification. | Dependency-as-coupling confusion. Dependencies define order, not grouping. |
| 4 | "A general description captures the intent — the implementer will know what to do" | Name the file, the function, the type, the line range. No hedge words. | Every downstream failure traces to vague language in upstream artifacts. |
| 5 | "This component is too simple for the full process" | The process applies regardless of perceived simplicity. Follow every phase. | The 4 documented failures ALL occurred in "simple" features where shortcuts seemed safe. |
| 6 | "The guardrail table doesn't apply to this situation" | It applies unconditionally. If you're reasoning about why a row doesn't apply, that IS the rationalization the row describes. | Second-order rationalization. The table exists because of situations that "seemed different." |

<!-- END GUARDRAILS -->

## Pre-Scoping Commitment

**Before writing the manifest**, write `_commitment.md` to the output folder:

```markdown
## Commitment — /serious-scope
I will produce: [N plan entries covering all extracted items from research]
I will NOT skip: [items I'm tempted to lump — name them explicitly]
Verification: [handoff verifier will check every research item maps to a plan entry]
```

---

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

**Write `.claude-active/{claude_pid}-scope`** at the project root FIRST. Use a SUBSHELL so `umask` does not leak to the rest of the skill, and CORRECT directory permissions if `.claude-active/` pre-exists with wider perms. Content is the relative path to the manifest folder.

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
  bc=$(breadcrumb_path scope) || exit 1
  printf '%s\n' "${RELATIVE_OUTPUT_PATH}" > "$bc"
)
```

The outer `( ... )` subshell scopes `umask 077` so the caller's umask is unchanged after this block. The pre-existing-perm correction enforces `0700` on `.claude-active/` even if a previous-version skill or attacker created it with wider perms.

## Phase 4: Verification — MANDATORY GATE

Run handoff verifier per `.claude/skills/_shared/handoff-verifier.md`:
- **Upstream:** the `source` path (research.md) | **Downstream:** manifest.md | **Strategy:** `structural`

**On FAIL:** Fix MISSING/SHIRKED items, re-verify. Repeat until PASS or PASS WITH DEFERRALS.
**On PASS:** Set `status: done` in manifest frontmatter. Proceed to Phase 5.

## Phase 5: Cleanup

1. Set `status: done` in manifest frontmatter (if not already set).
2. Remove the breadcrumb. During the dual-read transition window, BOTH the new-path breadcrumb AND any legacy `.active-scope` at project root must be removed:
   ```bash
   new_bc=$(bash -c 'source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh" && breadcrumb_path scope')
   rm -f "$new_bc" "${CLAUDE_PROJECT_DIR}/.active-scope"
   ```
3. **Same-skill restoration:** If `parent:` exists and parent was scope, **re-run the writer block** with the parent's folder path as `${RELATIVE_OUTPUT_PATH}` and `${SKILL}=scope`. The writer block writes to `.claude-active/$(claude_pid)-scope`, do not write the legacy `.active-scope` at the project root.
4. Report: manifest path, number of plans, summary of the split.
