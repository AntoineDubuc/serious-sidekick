---
task: "05 — Create /serious-abandon skill"
gate: PASSED
verified_by: completion-gate-agent
date: 2026-03-09
artifact: .claude/skills/serious-abandon/SKILL.md
---

# Task 05 Completion Gate: PASSED

All 18 acceptance criteria, 5 negative tests, and 2 evidence requirements verified.

## Acceptance Criteria

| AC  | Description                                                        | Result |
|-----|--------------------------------------------------------------------|--------|
| AC1 | Correct frontmatter (name, user-invocable, no hooks)               | PASS   |
| AC2 | Triggers on all four phrases                                       | PASS   |
| AC3 | Reads .active-* breadcrumbs, validates each, discards stale        | PASS   |
| AC4 | Deepest via parent chains (not path containment)                   | PASS   |
| AC5 | Error: "No active workflow to abandon"                             | PASS   |
| AC6 | Top-level: warns with Y/N prompt                                   | PASS   |
| AC7 | Active children: REFUSE with list and suggestion                   | PASS   |
| AC8 | Sets status: abandoned in YAML frontmatter                         | PASS   |
| AC9 | Removes breadcrumb AFTER setting status (reverse of creation)      | PASS   |
| AC10| Code workflows: checks worktrees, reports, updates log             | PASS   |
| AC11| Notes abandon only after code agents stopped                       | PASS   |
| AC12| Reads parent path and determines skill type                        | PASS   |
| AC13| Same-skill drilling: restores parent breadcrumb                    | PASS   |
| AC14| Cross-skill: no restoration needed                                 | PASS   |
| AC15| Reads parent output and summarizes state                           | PASS   |
| AC16| Reports what abandoned sub-workflow produced                       | PASS   |
| AC17| Final message format: "Abandoned {slug}. Returning to..."         | PASS   |
| AC18| Depth-2 parent edge case documented                                | PASS   |

## Negative Tests

| NT  | Description                                              | Result |
|-----|----------------------------------------------------------|--------|
| NT1 | Does NOT delete worktree directories or branches         | PASS   |
| NT2 | Does NOT merge abandoned worktree branches               | PASS   |
| NT3 | Does NOT skip confirmation for top-level abandon         | PASS   |
| NT4 | Does NOT abandon workflow with active children           | PASS   |
| NT5 | Does NOT cascade-abandon children automatically          | PASS   |

## Evidence

### EV1: Full SKILL.md Verified

File at `.claude/skills/serious-abandon/SKILL.md` — 175 lines read and verified. Frontmatter, 6 steps, arguments section all present and correct.

### EV2: Depth-2 Abandon Chain Walkthrough

Scenario: Three nested same-skill research workflows (depth 0, 1, 2).

**Abandon depth-2 (jwt-parsing):**
- Step 1: deepest found via 2-hop parent chain
- Step 3: status set to abandoned, breadcrumb removed
- Step 5c: same-skill — breadcrumb restored to immediate parent (token-handling)
- Per AC18: "The breadcrumb just needs to point to the IMMEDIATE parent. The parent's own parent relationship is tracked in the parent's frontmatter, not in the breadcrumb."

**Abandon depth-1 (token-handling):**
- Step 1: now deepest (1 hop)
- Step 3: status set to abandoned, breadcrumb removed
- Step 5c: same-skill — breadcrumb restored to top-level (auth)

Chain integrity maintained at each level. Restoration works correctly for depth-2 parents.

## Key Quotes

**AC5:** "No active workflow to abandon." (line 44)
**AC7:** "Cannot abandon {slug} — it has active sub-workflow(s)... Do NOT cascade-abandon children automatically." (lines 68-71)
**AC9:** "AFTER setting `status: abandoned` in the frontmatter (reverse of creation order — frontmatter first, breadcrumb second)" (line 83)
**AC10:** "These have NOT been deleted or merged" (line 98)
**AC18:** "Edge case — depth 2 parent: If the parent itself is a sub-workflow... restoration still works correctly." (line 130)
