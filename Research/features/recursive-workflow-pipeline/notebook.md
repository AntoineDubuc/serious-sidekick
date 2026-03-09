# Research Notebook: Recursive Workflow Pipeline — Phase 1 Technical Implementation
**Started:** 2026-03-08
**Status:** In Progress
**Classification:** Feature
**Scope:** Codebase only
**Mode:** Quick

## Research Question
How do we technically implement the four Phase 1 features decided in the `/serious-conversation`:
1. Parent field auto-detection across all skills
2. `/serious-status` tree reconstruction from YAML frontmatter + folder structure
3. `/serious-abandon` interaction with `/serious-code` worktrees and agent model
4. Per-skill changes needed to support parent linking and nested folders

## Log

### Entry 1 — 2026-03-08 Initial Setup
Beginning codebase investigation. Need to read every existing skill SKILL.md to understand:
- What output files each skill creates
- What YAML frontmatter they already use
- How they detect/read previous skill outputs
- How `/serious-code` manages worktrees
- Where the "active workflow" breadcrumbs are written

### Entry 2 — 2026-03-08 Skill Audit Complete
Read all 6 workflow skills. Key findings:

**Output files per skill (created at startup vs end):**

| Skill | Primary File | Created At | Breadcrumb | Has YAML Frontmatter? |
|-------|-------------|-----------|------------|----------------------|
| conversation | conversation.md | Phase 0d (start) | .active-conversation ✓ | NO |
| research | research.md | Phase 1b (start) | .active-research ✓ | NO (uses markdown bold headers) |
| mock-ups | mock-up-summary.md | Phase 4 (END) | NONE | NO |
| plan | implementation_plan.md | Phase 1 (middle) | NONE | NO |
| code | execution_log.md | Phase 0e (start) | .active-code ✓ | NO |
| review | findings.md | Phase 1b (start) | NONE | NO |

**Critical finding: NONE of the skills use YAML frontmatter.** The conversation decision requires adding `parent:` and `status:` in YAML frontmatter. This means ALL 6 skills need modification.

**Breadcrumb pattern:** 3 of 6 skills have breadcrumb files (.active-conversation, .active-research, .active-code). These are the detection mechanism for parent auto-detection. The other 3 skills (mock-ups, plan, review) need breadcrumbs added.

**Cross-skill breadcrumbs DON'T conflict:** Each skill uses a DIFFERENT breadcrumb filename. So if research is active (.active-research) and you spawn a conversation (.active-conversation), BOTH files exist simultaneously. This is perfect for parent detection!

**Same-skill drilling is the edge case:** If research spawns sub-research, .active-research gets overwritten. Solution: the sub-workflow's frontmatter has the parent path, so on completion/abandon, it restores the parent's breadcrumb.

**Mock-ups timing problem:** mock-up-summary.md is created at the END (Phase 4). For /serious-status to track an active mock-up workflow, the file must exist from the START. Fix: create mock-up-summary.md in Phase 0e with frontmatter + placeholders.

### Entry 3 — 2026-03-08 Parent Auto-Detection Mechanism
**How it works:**

When ANY /serious-* skill starts (Phase 0), it checks for ALL breadcrumb files:
- .active-conversation → potential parent
- .active-research → potential parent
- .active-code → potential parent
- .active-mock-ups → potential parent (NEW)
- .active-plan → potential parent (NEW)
- .active-review → potential parent (NEW)

If a breadcrumb from a DIFFERENT skill exists:
→ Prompt: "I see you're currently in /serious-research for auth-tokens. Link this as a sub-workflow? (Y/N)"

If YES:
- Set `parent: {breadcrumb path}` in new skill's frontmatter
- Create output in `{parent_folder}/sub/{slug}/` instead of normal location
- Write the new skill's breadcrumb (parent's breadcrumb stays)

If a breadcrumb from the SAME skill exists (research → sub-research):
→ Same prompt, but the existing breadcrumb gets overwritten
→ On completion/abandon: read frontmatter's parent field, restore parent's breadcrumb

### Entry 4 — 2026-03-08 Folder Structure for Sub-Workflows
**Current structure:** Each skill has its own folder convention:
- conversation → Research/conversations/{slug}/
- research → Research/{category}/{slug}/
- mock-ups → {research_folder}/mock-ups/
- plan → {research_folder}/ or Research/features/{slug}/
- code → {plan_folder}/
- review → QA/{slug}/

**Sub-workflow structure:** The `sub/` folder goes inside the PARENT's folder:
```
Research/features/auth/              ← parent research
├── research.md
└── sub/
    ├── token-expiry/                ← sub-research
    │   └── research.md
    └── session-discussion/          ← sub-conversation
        ├── conversation.md
        └── summary.md
```

**Key insight:** Sub-workflows DON'T follow the normal folder convention. They DON'T go to Research/conversations/ or QA/. They nest inside their parent. This is intentional — it keeps the hierarchy visible in the file tree.

**What about QA review sub-workflows?** If a code task spawns a review sub-workflow, it lives at:
```
Research/features/auth/sub/post-impl-review/
├── findings.md
└── review-summary.md
```
Not at `QA/post-impl-review/`. This breaks the convention but maintains hierarchy.

### Entry 5 — 2026-03-08 /serious-status Tree Reconstruction

**What /serious-status needs to scan:**
1. `Research/conversations/*/` — conversation workflows
2. `Research/{bugs|features|exploratory}/*/` — research/plan/code workflows
3. `Research/**/sub/*/` — nested sub-workflows at any depth
4. `QA/*/` — review workflows
5. `.active-*` breadcrumbs — currently active workflows

**Primary output files to check per folder:**
Priority order (first found = this folder's skill type):
1. `execution_log.md` → /serious-code
2. `implementation_plan.md` or `phase_map.md` → /serious-plan
3. `mock-ups/mock-up-summary.md` → /serious-mock-ups (check mock-ups subfolder)
4. `research.md` → /serious-research
5. `conversation.md` or `summary.md` → /serious-conversation
6. `findings.md` → /serious-review

**Determining current stage for a folder:**
A single folder can have outputs from MULTIPLE skills (research done, plan done, code active).
The "current stage" = the most advanced skill output present.
- If execution_log.md exists → stage = /serious-code
- If implementation_plan.md exists but no execution_log → stage = /serious-plan
- etc.

Active vs done: check the `.active-*` breadcrumb. If a breadcrumb points to this folder, it's `● active`. Otherwise check frontmatter `status:` field.

**Tree reconstruction algorithm:**
1. Glob for all folders containing skill output files
2. For each folder, read frontmatter from the most advanced skill output
3. Build a map: { folder_path → { skill, status, parent, slug } }
4. Build tree from parent references
5. Sort roots by creation date
6. Render flat table with indentation

### Entry 6 — 2026-03-08 /serious-abandon + Worktree Interaction

**Current worktree usage in /serious-code (SKILL.md lines 164-223):**
- Worktrees created at: `.claude/worktrees/serious-code-{plan_slug}`
- One worktree per plan in parallel phases
- Each gets its own branch based on current HEAD
- On success: merged into main, worktree cleaned up
- On failure: worktree preserved for inspection (NOT merged, NOT deleted)

**What /serious-abandon needs to do:**

Case 1: Abandoning a non-code sub-workflow (conversation, research, mock-ups, plan)
- Read the sub-workflow's frontmatter to get parent path
- Set `status: abandoned` in frontmatter
- Remove the sub-workflow's breadcrumb file
- If same-skill drilling: restore parent's breadcrumb from frontmatter parent path
- Report: "Abandoned {slug}. Returning to {parent_slug}."
- No worktree involved — straightforward.

Case 2: Abandoning a /serious-code sub-workflow
- Same as Case 1, PLUS:
- If worktrees exist for this code session:
  - Stop any running plan agents (they're sub-agents, so they'll stop when session ends)
  - Do NOT merge worktree branches
  - Do NOT delete worktrees — mark as abandoned
  - Record which worktrees belong to this abandoned session in frontmatter or execution_log
- The worktrees remain at `.claude/worktrees/serious-code-{plan_slug}` for recovery
- `/serious-cleanup` (Phase 2) will handle explicit deletion later

Case 3: Abandoning a top-level workflow (no parent)
- Same as Case 1, but no parent to return to
- Just mark as abandoned and report

**Key insight:** /serious-abandon doesn't need to know about worktrees ITSELF. It just marks the status. The worktrees were created by /serious-code, and they persist independently. When /serious-code's execution_log.md is marked abandoned, the worktrees become orphaned but still accessible. /serious-cleanup handles their cleanup.

**Breadcrumb restoration logic:**
When abandoning, the skill needs to know which breadcrumb to restore:
1. Read frontmatter: `parent: Research/features/auth`
2. Determine parent's skill type (from parent folder's output files)
3. Write parent path to the parent skill's breadcrumb file
   e.g., if parent was /serious-research → write to `.active-research`

But wait — what if the parent's breadcrumb already exists? (cross-skill drilling)
Example: Research spawns conversation. Both .active-research and .active-conversation exist.
Abandoning the conversation: just remove .active-conversation. .active-research is already there.

Only need restoration for same-skill drilling (research → sub-research).
When abandoning sub-research: restore .active-research to point to parent research folder.

### Entry 7 — 2026-03-08 YAML Frontmatter Standard

**Proposed standard for ALL skill primary output files:**

```yaml
---
skill: serious-research
slug: auth-token-expiry
status: active
parent: Research/features/auth
created: 2026-03-08
---
```

Fields:
- `skill` — which /serious-* skill created this (for /serious-status stage display)
- `slug` — the workflow slug (for display names)
- `status` — active | done | abandoned (for /serious-status glyphs)
- `parent` — relative path from project root to parent folder, empty/absent for top-level
- `created` — date (for sorting)

Optional fields (conversation decided but not mandatory for Phase 1):
- `spawned_from` — e.g., "plan/task-3" (which specific item triggered this)
- `depth` — nesting level (0 = top-level, 1 = sub, 2 = sub-sub)

**Where frontmatter goes (per skill):**
- conversation → `conversation.md` (created Phase 0d)
- research → `research.md` (created Phase 1b) — REPLACES current markdown bold headers
- mock-ups → `mock-up-summary.md` (must be created early in Phase 0e, not Phase 4)
- plan → `implementation_plan.md` (created Phase 1)
- code → `execution_log.md` (created Phase 0e)
- review → `findings.md` (created Phase 1b)

### Entry 8 — 2026-03-08 Persona Reviews Complete

**Reviewers:** Senior Engineer, Architect, DX Advocate

**Critical finding (DX Advocate):** The parent-link prompt as originally designed would fire on EVERY normal pipeline transition (research → plan → code), not just genuine branching. This was the biggest design flaw. Fixed by adding "advancing vs branching" distinction using pipeline order comparison.

**Key feedback integrated:**
1. Advancing vs branching distinction (DX Advocate) — most important change
2. Multi-breadcrumb disambiguation via parent chain depth, not path containment (all three)
3. Use frontmatter `skill:` field as authoritative for stage, not file existence (Architect)
4. Stale breadcrumb validation and cleanup (Senior Engineer, DX Advocate)
5. Migration strategy for existing files — fallback to markdown bold headers (all three)
6. Breadcrumb format: relative paths from project root, no trailing slash (Senior Engineer, Architect)
7. Depth-2 same-skill chain walkthrough proving restoration works (Senior Engineer, DX Advocate)
8. "Returning to parent context" means: read parent state, summarize, suggest next step (DX Advocate)
9. Frontmatter parser leniency: defaults for missing fields, skip on malformed (Architect)
10. .gitignore for .active-* breadcrumbs (Senior Engineer)
11. Breadcrumbs live in main repo root, not worktree roots (Senior Engineer)
12. Mock-up stub vs completed detection: use `status:` field (Architect)
13. Known limitations section: concurrency, stage column, auto-pause, compaction (all three)

**NOT integrated (deferred):**
- Consolidate 6 breadcrumbs into single state file (Architect suggestion) — adds complexity; 6 files is manageable
- Add `status: paused` for parents (Architect) — explicitly deferred to Phase 3
- `/serious-status --active` filter — noted for Phase 2

Research marked as Complete.
