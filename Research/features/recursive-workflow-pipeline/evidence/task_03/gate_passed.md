# Completion Gate Report — Task 3: Add Parent Check (0-pre) to All 6 Skills

**Timestamp:** 2026-03-09
**Verifier:** Independent Completion Gate sub-agent (re-verification)
**Verdict:** ALL PASS (21/21 criteria)

---

## Verification Method

Each criterion was independently verified by reading all 6 SKILL.md files and grepping for the required content. No implementer reports were trusted. All evidence comes from direct file inspection.

**Files verified:**
- `.claude/skills/serious-conversation/SKILL.md`
- `.claude/skills/serious-research/SKILL.md`
- `.claude/skills/serious-mock-ups/SKILL.md`
- `.claude/skills/serious-plan/SKILL.md`
- `.claude/skills/serious-code/SKILL.md`
- `.claude/skills/serious-review/SKILL.md`

---

## AC1: Contains "### 0-pre. Check for active parent workflow" before other Phase 0 steps

**PASS** -- All 6 files.

| Skill | 0-pre Line | First 0a/1a Line | Confirmed Before |
|-------|-----------|-------------------|------------------|
| conversation | 32 | 56 (0a) | Yes |
| research | 132 | 155 (1a) | Yes |
| mock-ups | 20 | 43 (0a) | Yes |
| plan | 26 | 49 (0a) | Yes |
| code | 33 | 56 (0a) | Yes |
| review | 29 | 53 (0a) | Yes |

Note: research places 0-pre under "Phase 1: Setup" heading, but it still appears before any setup steps (1a). The 0-pre numbering makes the execution order clear.

---

## AC2: Lists all 6 breadcrumb filenames

**PASS** -- All 6 files.

All files contain step 1: `Check for .active-conversation, .active-research, .active-mock-ups, .active-plan, .active-code, .active-review`

Grep confirmed 6/6 matches.

---

## AC3: Stale breadcrumb validation (check target folder exists, delete stale with warning)

**PASS** -- All 6 files.

All files contain step 2: `For each breadcrumb found, verify the target folder exists and contains a valid output file with parseable YAML frontmatter. If not, delete the stale breadcrumb with a warning: "Removed stale .active-{skill} breadcrumb (target folder missing)."`

Grep confirmed 6/6 matches.

---

## AC4: References pipeline order conversation(1) -> research(2) -> mock-ups(3) -> plan(4) -> code(5) -> review(6)

**PASS** -- All 6 files.

All files contain: `**Pipeline order:** conversation(1) -> research(2) -> mock-ups(3) -> plan(4) -> code(5) -> review(6)`

Grep confirmed 6/6 matches.

---

## AC5: Implements advancing-vs-branching (new > active = advancing, new <= active = branching)

**PASS** -- All 6 files with correct skill-specific order numbers.

| Skill | Order | Advancing Condition | Branching Condition |
|-------|-------|--------------------|--------------------|
| conversation | 1 | `If 1 > {M}` | `If 1 <= {M}` |
| research | 2 | `If 2 > {M}` | `If 2 <= {M}` |
| mock-ups | 3 | `If 3 > {M}` | `If 3 <= {M}` |
| plan | 4 | `If 4 > {M}` | `If 4 <= {M}` |
| code | 5 | `If 5 > {M}` | `If 5 <= {M}` |
| review | 6 | `If 6 > {M}` | `If 6 <= {M}` |

---

## AC6: Advancing = skip 0-pre, proceed normally, no sub/ folder, no parent field, no prompt, breadcrumbs coexist

**PASS** -- All 6 files.

5 of 6 files contain the full elaboration: `Skip the rest of 0-pre, proceed to Phase 0a as normal. Both breadcrumbs will coexist. Advancing means normal behavior -- no new logic needed. The skill uses its existing folder rules. No parent field is set. No prompt is shown. No sub/ folder is created. Both the new skill's breadcrumb AND the existing skill's breadcrumb coexist.`

Conversation has abbreviated text (`Skip the rest of 0-pre, proceed to Phase 0a as normal. Both breadcrumbs will coexist.`) plus a note: `Since conversation is order 1 (the lowest), it can never be greater than any active skill's order. Advancing never applies to conversation.` This is correct -- the advancing path is unreachable for order 1, and the note documents this.

---

## AC7: Multi-breadcrumb resolution (deepest via parent chain, most recently modified for independent top-level)

**PASS** -- All 6 files.

All contain step 4: `If multiple valid breadcrumbs exist, follow parent: chains in each breadcrumb's target frontmatter. The workflow with the longest parent chain is the deepest. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.`

Grep confirmed 6/6 matches.

---

## AC8: Branching -- deepest active becomes proposed parent

**PASS** -- All 6 files.

Flow: step 4 determines deepest active -> step 5 compares pipeline order against deepest -> step 6 branching prompt references the deepest's {slug} -> step 7 sets parent to the deepest's output folder path.

---

## AC9: Branching prompt "I see you're in /serious-{skill} for {slug}..."

**PASS** -- All 6 files.

All contain step 6 cross-skill prompt: `"I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"`

Grep confirmed 6/6 matches.

---

## AC10: YES = parent field set + output at {parent}/sub/{slug}/

**PASS** -- All 6 files.

All contain step 7:
- `Set parent in this workflow's frontmatter to the parent's output folder path`
- `Create output at {parent_folder}/sub/{slug}/ instead of the normal location`

Grep confirmed 6/6 matches for both lines.

---

## AC11: NO = normal location, no parent

**PASS** -- All 6 files.

All contain step 8: `Create output in normal location, no parent field set.`

Grep confirmed 6/6 matches.

---

## AC12: Depth guard -- count parent chain hops + 1, fire at >= 3

**PASS** -- All 6 files.

All contain in step 7: `Depth guard: If proposed depth >= 3, warn: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If No: do not create the sub-workflow, return without starting the new skill.`

Grep confirmed 6/6 matches.

---

## AC13: Depth computation documented (follow parent chain, count hops, add 1)

**PASS** -- All 6 files.

All contain in step 7: `Compute proposed depth: follow parent: chain from the proposed parent's frontmatter, count hops until no parent: field, add 1.`

Grep confirmed 6/6 matches.

---

## AC14: Documents breadcrumb overwrite for same-skill

**PASS** -- All 6 files.

All contain in step 6 same-skill prompt: `the existing .active-{skill} breadcrumb will be overwritten with the new sub-workflow's path`

| Skill | Evidence |
|-------|----------|
| conversation | `the existing .active-conversation breadcrumb will be overwritten` |
| research | `the existing .active-research breadcrumb will be overwritten` |
| mock-ups | `the existing .active-mock-ups breadcrumb will be overwritten` |
| plan | `the existing .active-plan breadcrumb will be overwritten` |
| code | `the existing .active-code breadcrumb will be overwritten` |
| review | `the existing .active-review breadcrumb will be overwritten` |

---

## AC15: Different prompt wording for same-skill vs cross-skill

**PASS** -- All 6 files.

Cross-skill: `"I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"`

Same-skill: `"I see you're already in /serious-{skill} for {slug}. Start a nested /serious-{skill} within it? (Y/N)"`

Key differences: "you're in" vs "you're already in"; "looks like it needs its own workflow. Link as a sub-workflow?" vs "Start a nested /serious-{skill} within it?"

---

## AC16: Restoration on wrap-up (read parent field, restore breadcrumb)

**PASS** -- All 6 files.

All contain step 9: `On wrap-up/completion of this skill, if frontmatter has a parent: field and the parent was the same skill type ({skill}), restore the breadcrumb: write .active-{skill} with the parent's folder path as content.`

Grep confirmed 6/6 matches for "Same-skill restoration".

---

## AC17: Edge case -- depth 2 parent still works for restoration

**PASS** -- All 6 files.

All contain in step 9: `This works even if the parent was itself a sub-workflow (depth 2), because the parent's frontmatter has its own parent reference, and the breadcrumb just needs to point to the immediate parent.`

---

## NT1: No fire when no breadcrumbs exist

**PASS** -- All 6 files.

All contain step 3: `If no valid breadcrumbs exist: Skip the rest of 0-pre. Proceed to Phase 0a as normal (top-level workflow).` (research says "Phase 1a" which matches its structure)

Grep confirmed 6/6 matches.

---

## NT2: No prompt on advancing

**PASS** -- All 6 files.

5 of 6 explicitly state `No prompt is shown.` in the advancing description. Conversation's advancing path is documented as unreachable, so no prompt can occur.

---

## NT3: Advancing uses normal folder, no sub/, no parent

**PASS** -- All 6 files.

5 of 6 explicitly state: `The skill uses its existing folder rules. No parent field is set. No sub/ folder is created.` Conversation's advancing path is unreachable (order 1 can never be > any M).

---

## NT4: Advancing doesn't remove existing breadcrumb

**PASS** -- All 6 files.

All 6 state: `Both breadcrumbs will coexist.` 5 of 6 additionally elaborate: `Both the new skill's breadcrumb AND the existing skill's breadcrumb coexist.`

---

## Summary

| Category | Criteria | Passed | Failed |
|----------|----------|--------|--------|
| Core ACs (AC1-AC13) | 13 | 13 | 0 |
| Same-skill drilling (AC14-AC17) | 4 | 4 | 0 |
| Negative tests (NT1-NT4) | 4 | 4 | 0 |
| **Total** | **21** | **21** | **0** |

**GATE: PASSED**
