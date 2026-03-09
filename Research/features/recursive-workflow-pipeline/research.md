# Recursive Workflow Pipeline — Phase 1 Technical Implementation

**Date:** 2026-03-08
**Classification:** Feature
**Scope:** Codebase only
**Mode:** Quick
**Status:** Complete

## Summary

Six existing workflow skills need modification and two new skills must be created to support recursive/nested workflows. The core mechanism is YAML frontmatter (new — none exists today) with a `parent:` field, plus breadcrumb files for active workflow detection. The single most important design decision is distinguishing "advancing to the next pipeline stage" (research → plan → code) from "branching into a sub-workflow" (plan → sub-research) — these look similar but require different behavior. The parent-link prompt should only fire when branching, not when advancing.

**Scope:** 6 skill modifications + 2 new skills + `.gitignore` update + frontmatter standard

---

## Background

The `/serious-conversation` on recursive workflows (3 rounds, 5 personas) converged on four Phase 1 deliverables:
1. `parent:` field in YAML frontmatter of skill output files (auto-detected, yes/no prompt)
2. Nested folder convention (`{parent}/sub/{slug}/`)
3. `/serious-status` command (flat table, universal across all workflows)
4. `/serious-abandon` command (mark abandoned, return to parent, preserve worktree)

Full conversation record: `Research/conversations/recursive-workflow-pipeline/summary.md`

---

## Finding 1: Current Skill Architecture Audit

### Output Files & Breadcrumbs

| Skill | Primary Output File | Created When | Breadcrumb File | Stop Hook |
|-------|-------------------|-------------|----------------|-----------|
| /serious-conversation | `conversation.md` | Phase 0d (start) | `.active-conversation` | Yes |
| /serious-research | `research.md` | Phase 1b (start) | `.active-research` | Yes |
| /serious-mock-ups | `mock-up-summary.md` | Phase 4 (END) | None | No |
| /serious-plan | `implementation_plan.md` | Phase 1 (mid) | None | No |
| /serious-code | `execution_log.md` | Phase 0e (start) | `.active-code` | Yes |
| /serious-review | `findings.md` | Phase 1b (start) | None | No |

### Key Observations

1. **No YAML frontmatter exists anywhere.** Research.md uses markdown bold headers (`**Date:**`, `**Status:**`), not YAML `---` blocks. All 6 skills need frontmatter added.

2. **3 of 6 skills lack breadcrumbs.** Mock-ups, plan, and review have no `.active-*` breadcrumb. These are needed for parent auto-detection.

3. **Mock-ups has a timing problem.** `mock-up-summary.md` is created at Phase 4 (the end). For `/serious-status` to track an active mock-up workflow, the file must exist from the start with frontmatter. Fix: create it in Phase 0e as a stub with frontmatter and `## Summary\n{To be completed}` placeholder. Auto-detection tools that scan for `mock-up-summary.md` must check the `status:` field — a stub file has `status: active`, a completed file has `status: done`.

4. **Breadcrumb filenames don't conflict.** Each skill uses a unique breadcrumb filename (`.active-conversation`, `.active-research`, `.active-code`). Cross-skill breadcrumbs coexist naturally.

### Folder Conventions

| Skill | Current Output Location |
|-------|------------------------|
| conversation | `Research/conversations/{slug}/` |
| research | `Research/{bugs\|features\|exploratory}/{slug}/` |
| mock-ups | `{research_folder}/mock-ups/` |
| plan | `{research_folder}/` or `Research/features/{slug}/` |
| code | `{plan_folder}/` |
| review | `QA/{slug}/` |

---

## Finding 2: Parent Field Auto-Detection Mechanism

### The Critical Distinction: Advancing vs. Branching

This is the most important design decision in the entire feature. There are two fundamentally different intents when a skill is invoked while another is active:

**Advancing (forward flow):** The user finished research and is moving to planning. This is the normal pipeline progression. The parent-link prompt should NOT fire — it would be noise on every standard workflow step.

**Branching (sub-workflow):** The user is mid-planning and discovers a sub-problem that needs its own research. This is a genuine drill-down. The parent-link prompt SHOULD fire.

**How to distinguish them:**

The pipeline has a defined order:
```
conversation → research → mock-ups → plan → code → review
```

| If active skill is... | And new skill is... | Intent | Action |
|---|---|---|---|
| research | plan | **Advancing** | No prompt. Co-locate in same folder. |
| research | code | **Advancing** | No prompt. |
| plan | code | **Advancing** | No prompt. |
| research | mock-ups | **Advancing** | No prompt. |
| plan | research | **Branching** | Prompt: "Link as sub-workflow?" |
| plan | conversation | **Branching** | Prompt. |
| code | research | **Branching** | Prompt. |
| research | research | **Branching** | Prompt (same-skill drilling). |
| code | conversation | **Branching** | Prompt. |

**Rule:** If the new skill is EARLIER in the pipeline than the active skill, or is the SAME skill, it's branching → prompt. If the new skill is LATER in the pipeline, it's advancing → no prompt.

### The Detection Flow (Revised)

```
1. Read ALL breadcrumb files in the project root.

2. If NO breadcrumbs exist → normal top-level workflow, skip parent check.

3. If breadcrumbs exist, determine if this is advancing or branching:
   a. Find the deepest active workflow (see Multi-Breadcrumb section below)
   b. Compare pipeline order: is the new skill LATER than the active skill?
      - YES (advancing) → No prompt. Create output in the active workflow's
        folder (co-locate, no parent field needed for co-located work).
      - NO (branching/same stage) → Prompt:
        "I see you're in /serious-{skill} for {slug}.
         This looks like a sub-problem. Link as a sub-workflow? (Y/N)"

4. If YES to sub-workflow:
   - Set parent = {active workflow path} in frontmatter
   - Create output at {parent_folder}/sub/{slug}/
   - Check depth: if > 2, warn "This is depth {N}. Continue? (Y/N)"

5. If NO to sub-workflow:
   - Create output in the normal location, no parent
```

### Multi-Breadcrumb Disambiguation

When multiple breadcrumbs coexist (e.g., `.active-research` + `.active-conversation` from cross-skill drilling), the system must determine which is the "deepest" active workflow:

1. Read frontmatter from each breadcrumb's target folder
2. Follow the `parent` chain to determine depth
3. The workflow with the greatest depth is the "deepest" — this is the one the user is currently working in
4. If two workflows are at the same depth (siblings), present both and let the user choose

**Do NOT use path containment** to determine depth — it breaks when the user declines parent linking (creating a sibling top-level workflow that happens to be in a different directory tree).

### Cross-Skill Drilling (Easy Case)

When research spawns a conversation:
- `.active-research` → `Research/features/auth/` (stays)
- `.active-conversation` → `Research/features/auth/sub/token-discussion/` (new)
- Both breadcrumbs coexist — no conflict
- When conversation wraps up: `.active-conversation` is removed, `.active-research` still there

### Same-Skill Drilling and Depth-2 Chain

When research spawns sub-research:
- `.active-research` → overwritten from `Research/features/auth/` to `Research/features/auth/sub/token-expiry/`
- Sub-research frontmatter has `parent: Research/features/auth`

**Depth-2 walkthrough (grandparent → parent → child):**

1. Research A starts. `.active-research` → A. A's frontmatter: `parent: (none)`
2. Sub-research B spawns under A. `.active-research` → B. B's frontmatter: `parent: A`
3. Sub-sub-research C spawns under B. `.active-research` → C. C's frontmatter: `parent: B`
4. C completes/abandoned. Read C's frontmatter → parent = B. Restore `.active-research` → B. ✓
5. B completes/abandoned. Read B's frontmatter → parent = A. Restore `.active-research` → A. ✓
6. A completes. Remove `.active-research`. ✓

**Multi-level abandon:** If the user abandons C, they return to B. They must also abandon B separately to return to A. You cannot skip levels — each abandon pops one level of the stack. This is by design: the user should confirm each level.

### Breadcrumb Format

**All breadcrumbs use relative paths from the project root.** This matches the frontmatter `parent:` field format and ensures portability. Example:

```
# .active-research contains:
Research/features/auth/sub/token-expiry
```

Not absolute paths. No trailing slash.

### Stale Breadcrumb Handling

When reading a breadcrumb, always validate:
1. Does the target folder exist?
2. Does the target folder contain a valid output file with parseable frontmatter?

If not, discard the stale breadcrumb (delete the `.active-*` file) and show a warning: "Cleaned up stale breadcrumb for {path} — the workflow folder no longer exists."

### When User Declines Linking

If the user says "No," the new workflow is created as a normal top-level workflow in its standard location. No parent field, no nesting.

### Depth Guard

- Depth 0: top-level workflow
- Depth 1: sub-workflow (auto-prompted)
- Depth 2: sub-sub-workflow (auto-prompted)
- Depth 3+: requires explicit confirmation: "This is getting deep (depth {N}). Are you sure?"

Implementation: count depth by following the `parent` chain in frontmatter, not by counting `sub/` path segments (since paths could be manually reorganized).

---

## Finding 3: Nested Folder Convention

### Structure

```
Research/features/auth/                    ← parent research (depth 0)
├── research.md                            ← parent: (none), status: done
├── implementation_plan.md
└── sub/
    ├── token-expiry/                      ← sub-research (depth 1)
    │   ├── research.md                    ← parent: Research/features/auth
    │   └── sub/
    │       └── jwt-claims/                ← sub-sub-conversation (depth 2)
    │           ├── conversation.md        ← parent: Research/features/auth/sub/token-expiry
    │           └── summary.md
    └── session-discussion/                ← sub-conversation (depth 1)
        ├── conversation.md                ← parent: Research/features/auth
        └── summary.md
```

### Sub-Workflows Don't Follow Normal Location Rules

Sub-workflows ALWAYS go to `{parent}/sub/{slug}/`, regardless of their skill type. A conversation sub-workflow lives at `Research/features/auth/sub/session-discussion/`, not at `Research/conversations/session-discussion/`.

**Why:** The folder hierarchy IS the relationship hierarchy. Scattering sub-workflows to normal locations loses the visual parent-child connection.

**What this breaks:** Any tool, script, or human expectation that uses folder path to infer skill type (e.g., "everything under `Research/conversations/` is a conversation") will be wrong for sub-workflows. The frontmatter `skill:` field is the authoritative source for skill type, not the folder path. File existence is a fallback for pre-frontmatter files only.

### Auto-Detection Scan Paths (Updated)

Skills that auto-detect previous outputs need expanded glob patterns:

| Skill | Current Scan | New Scan (add) |
|-------|-------------|----------------|
| /serious-plan | `Research/{bugs,features,exploratory}/*/research.md` | + `Research/**/sub/*/research.md` |
| /serious-plan | (mock-ups) `*/mock-ups/mock-up-summary.md` | + `**/sub/*/mock-ups/mock-up-summary.md` |
| /serious-code | `Research/features/*/implementation_plan.md` | + `Research/**/sub/*/implementation_plan.md` |
| /serious-code | `Research/features/*/phase_map.md` | + `Research/**/sub/*/phase_map.md` |
| /serious-review | (recent commits/plans) | + scan `**/sub/*/` for recent work |

Auto-detection must also respect the frontmatter `status:` field. A `status: active` stub is not a completed research ready for planning. Only `status: done` files should be offered as input to the next pipeline stage.

---

## Finding 4: YAML Frontmatter Standard

### Format

```yaml
---
skill: serious-research
slug: auth-token-expiry
status: active
parent: Research/features/auth
created: 2026-03-08
---
```

### Fields

| Field | Required | Values | Purpose |
|-------|----------|--------|---------|
| `skill` | Yes | `serious-conversation`, `serious-research`, `serious-mock-ups`, `serious-plan`, `serious-code`, `serious-review` | Stage display — this is the AUTHORITATIVE source for what skill a workflow belongs to |
| `slug` | Yes | kebab-case string | Workflow display name |
| `status` | Yes | `active`, `done`, `abandoned` | Status glyph in /serious-status |
| `parent` | No | Relative path from project root | Tree reconstruction. Absent or empty for top-level workflows. |
| `created` | Yes | YYYY-MM-DD | Sort order |

**Excluded from Phase 1:** `spawned_from` (which task triggered this) and `depth` (nesting level) were discussed in the conversation but are NOT included. Depth is computable from the parent chain. `spawned_from` has no consumer yet. Add them in Phase 2 only if needed.

### Which File Gets Frontmatter

| Skill | File | Current Init Timing | Change Needed |
|-------|------|--------------------|----|
| conversation | `conversation.md` | Phase 0d (start) | Add YAML block |
| research | `research.md` | Phase 1b (start) | Convert bold headers → YAML |
| mock-ups | `mock-up-summary.md` | Phase 4 (end) | **Create stub in Phase 0e** |
| plan | `implementation_plan.md` | Phase 1 | Add YAML block |
| plan (multi) | `phase_map.md` | Phase 1b | Add YAML block. This is the canonical status file for multi-plan workflows. |
| code | `execution_log.md` | Phase 0e (start) | Add YAML block |
| review | `findings.md` | Phase 1b (start) | Add YAML block |

### Research.md Format Change

Current markdown bold headers become YAML frontmatter:

```yaml
---
skill: serious-research
slug: recursive-workflow-pipeline
status: active
created: 2026-03-08
classification: feature
scope: codebase-only
mode: quick
---
```

Research-specific fields (`classification`, `scope`, `mode`) move into the YAML block alongside standard fields.

### Frontmatter Parser Behavior

When reading frontmatter, tools should be lenient:
- **Missing fields:** Use defaults (`status: active`, `parent: none`, `created: file modification date`)
- **Malformed YAML:** Skip the file, show a warning in `/serious-status` output: `⚠ {path} — invalid frontmatter`
- **`parent` path doesn't resolve:** Treat as orphaned (show at top level with a warning)
- **No frontmatter at all (pre-existing files):** Check for legacy markdown bold headers (`**Status:**`). If found, parse those as a fallback. Show `?` status glyph in `/serious-status`.

### Migration for Existing Files

Existing research.md files use markdown bold headers. No migration script is needed. Instead:
- `/serious-status` falls back to parsing `**Status: Complete**` as `status: done` and `**Status: In Progress**` as `status: active`
- These files show with a `?` glyph prefix indicating they predate the frontmatter system
- Over time, as skills are re-run, files naturally get updated to YAML frontmatter

---

## Finding 5: /serious-status Implementation

### What It Is

A new SKILL.md file (user-invocable, no hooks) that scans the project and displays a flat table of all workflows.

### Scan Algorithm

```
1. Glob for all workflow folders:
   - Research/conversations/*/
   - Research/{bugs,features,exploratory}/*/
   - Research/**/sub/*/          (recursive sub-workflows)
   - QA/*/
   - Also check any folder with .active-* breadcrumb pointing to it

2. For each folder found:
   a. Find the primary output file (first match):
      conversation.md, research.md, mock-up-summary.md (or mock-ups/),
      implementation_plan.md, phase_map.md, execution_log.md, findings.md
   b. Read YAML frontmatter (or fall back to markdown bold headers)
   c. Extract: skill, slug, status, parent, created

3. Determine the "current stage" for each folder:
   PRIMARY: Use the frontmatter `skill:` field — this is authoritative.
   FALLBACK (no frontmatter): Use file existence priority:
     execution_log.md → /serious-code
     phase_map.md or implementation_plan.md → /serious-plan
     mock-up-summary.md → /serious-mock-ups
     research.md → /serious-research
     conversation.md → /serious-conversation
     findings.md → /serious-review

4. Build tree:
   a. Map: { folder_path → { skill, slug, status, parent } }
   b. Roots = entries with no parent
   c. Attach children to parents via parent field
   d. Sort roots by created date (newest first)

5. Determine active status:
   - If a .active-* breadcrumb points to this folder → ● active
   - Else use frontmatter status field
   - Precedence: breadcrumb overrides frontmatter for "active" detection.
     Frontmatter "done"/"abandoned" are authoritative terminal states.

6. Render table
```

### Output Format

```
Status       Workflow                          Stage                  Path
✓ done       auth-system                       /serious-plan          Research/features/auth/
  ● active   └ token-expiry                    /serious-research      Research/features/auth/sub/token-expiry/
  ✓ done     └ session-model                   /serious-conversation  Research/features/auth/sub/session-model/
  ✗ abandoned└ rate-limiting                   /serious-research      Research/features/auth/sub/rate-limiting/
○ pending    onboarding-flow                   /serious-research      Research/features/onboarding/
? legacy     old-notifications                 /serious-research      Research/features/notifications/
```

Glyphs: `✓` done, `●` active, `○` pending, `✗` abandoned, `?` legacy (no frontmatter)

### Known Limitation: Stage Column Shows Latest Stage Only

A folder that progressed through research → plan → code shows only the code stage (the latest). This is a simplification — it hides the fact that earlier stages are complete. Acceptable for Phase 1. Phase 2 could add `--verbose` to show all stages per folder.

---

## Finding 6: /serious-abandon Implementation

### What It Is

A new SKILL.md file (user-invocable, no hooks) that marks the current sub-workflow as abandoned and returns to the parent.

### Logic Flow

```
1. Find the currently active workflow:
   - Read ALL .active-* breadcrumb files
   - Validate each: does the target folder exist? Is frontmatter parseable?
   - Discard stale breadcrumbs with a warning
   - Determine deepest by following parent chains in frontmatter (NOT path containment)
   - If no valid breadcrumbs: "No active workflow to abandon."

2. Read the active workflow's frontmatter:
   - If no parent field: "This is a top-level workflow. Abandon it? (Y/N)"
   - If parent field exists: proceed

3. Mark as abandoned:
   - Set status: abandoned in the output file's YAML frontmatter
   - Remove the breadcrumb file for this workflow

4. Handle worktrees (if /serious-code):
   - Check for worktrees at .claude/worktrees/serious-code-* matching slug
   - Do NOT delete or merge — leave for inspection/recovery
   - Update execution_log.md status to "Abandoned"
   - Report which worktrees exist (informational)
   - NOTE: /serious-abandon should only be invoked after code agents have
     stopped or failed. If agents are still running, the user should stop
     them first (Ctrl+C or wait for completion).

5. Restore parent context:
   - Read parent path from frontmatter
   - Read parent's frontmatter to determine parent's skill type
   - If same-skill drilling: write parent path to the skill's breadcrumb
   - If cross-skill: parent's breadcrumb already exists (they coexist)

6. Return to parent (user-facing experience):
   - Read parent's primary output file and summarize its current state
   - Report what the abandoned sub-workflow produced (if anything useful)
   - Suggest what to do next:
     "Abandoned {slug}. Returning to {parent_slug} (/serious-{parent_skill}).
      Parent status: {summary of where parent left off}.
      Sub-workflow produced: {brief summary or 'nothing actionable'}.
      You can continue with /serious-{parent_skill} or run /serious-status
      to see the full picture."
```

### Worktree Interaction

Worktrees are created by `/serious-code` at `.claude/worktrees/serious-code-{plan_slug}`.

`/serious-abandon` does NOT manage worktree internals. It just:
1. Marks execution_log.md as abandoned
2. Removes .active-code
3. Reports which worktrees exist for this session

The worktree branches persist — uncommitted work stays. Recovery path: user can cd into the worktree, inspect, cherry-pick, or resume. `/serious-cleanup` (Phase 2) handles explicit deletion.

### Top-Level Abandon

Prompt for confirmation. Mark as abandoned. Remove breadcrumb. Report: "Abandoned {slug}. No parent to return to."

---

## Finding 7: Per-Skill Changes Required

### Common Changes (All 6 Skills)

**1. Add "Parent Check" step at Phase 0:**

```
### 0-pre. Check for active parent workflow

Read all .active-* breadcrumb files in the project root.
Validate each (folder exists, frontmatter parseable). Discard stale.

If valid breadcrumbs exist:
  Determine the pipeline order of the active skill vs this new skill.

  If this skill is LATER in the pipeline (advancing):
    → No prompt. This is normal forward flow.
    → Co-locate output in the active workflow's folder.

  If this skill is EARLIER or SAME in the pipeline (branching):
    → Find the deepest active workflow (by parent chain depth).
    → Prompt: "I see you're in /serious-{skill} for {slug}.
       This looks like it needs its own investigation.
       Link as a sub-workflow? (Y/N)"
    → If YES: set parent, create in {parent}/sub/{slug}/, check depth
    → If NO: create in normal location, no parent

If no breadcrumbs exist:
  → Normal top-level workflow.
```

**Pipeline order for comparison:**
```
conversation(1) → research(2) → mock-ups(3) → plan(4) → code(5) → review(6)
```

New skill's order > active skill's order = **advancing** (no prompt)
New skill's order ≤ active skill's order = **branching** (prompt)

**2. Add YAML frontmatter** to the primary output file at creation time.

**3. Update `status: done`** in frontmatter during the wrap-up phase.

**4. Add breadcrumb** (for skills that lack one): write `.active-{skill}` at startup, remove at completion.

**5. Add `.active-*` to `.gitignore`** — breadcrumbs are transient session state and must not be committed.

### Per-Skill Specific Changes

#### /serious-conversation
- Phase 0: add parent check (0-pre)
- Phase 0d: add YAML frontmatter to `conversation.md`
- Phase 3c: set `status: done` in conversation.md frontmatter
- If parent: create at `{parent}/sub/{slug}/` instead of `Research/conversations/{slug}/`

#### /serious-research
- Phase 0: add parent check (0-pre)
- Phase 1b: convert `research.md` from markdown bold headers to YAML frontmatter
- Phase 6: set `status: done` in research.md frontmatter
- If parent: create at `{parent}/sub/{slug}/` instead of `Research/{category}/{slug}/`
- `notebook.md` does NOT get frontmatter — it's a scratchpad

#### /serious-mock-ups
- Phase 0: add parent check (0-pre)
- Phase 0e: create `mock-up-summary.md` as a **stub** with YAML frontmatter + placeholder content
- Phase 4: backfill mock-up-summary.md with real content, set `status: done`
- **Add breadcrumb:** `.active-mock-ups` at startup, remove at completion

#### /serious-plan
- Phase 0: add parent check (0-pre)
- Phase 1: add YAML frontmatter to `implementation_plan.md` (or `phase_map.md` for multi-plan)
- For multi-plan: `phase_map.md` is the canonical frontmatter-bearing file
- Set `status: done` after user accepts (not during presentation — plan may be revised)
- **Add breadcrumb:** `.active-plan` at startup, remove at completion
- Auto-detect: add `**/sub/*/research.md` and `**/sub/*/mock-ups/mock-up-summary.md` to scan paths
- Auto-detect filter: only offer files with `status: done` (not stubs)

#### /serious-code
- Phase 0: add parent check (0-pre)
- Phase 0e: add YAML frontmatter to `execution_log.md`
- Phase 2b: set `status: done` before removing breadcrumb
- Worktrees still go to `.claude/worktrees/` regardless of parent (they're git-level)
- Auto-detect: add `**/sub/*/implementation_plan.md` and `**/sub/*/phase_map.md`

#### /serious-review
- Phase 0: add parent check (0-pre)
- Phase 1b: add YAML frontmatter to `findings.md`
- Phase 5b: set `status: done`
- **Add breadcrumb:** `.active-review` at startup, remove at completion
- If parent: create at `{parent}/sub/{slug}/` instead of `QA/{slug}/`

### New Skills to Create

#### /serious-status
- **Location:** `.claude/skills/serious-status/SKILL.md`
- **Type:** User-invocable, no hooks
- **Does:** Scans project, reads frontmatter, builds tree, displays flat table
- **Arguments:** none (Phase 2 adds `--active` filter and `--tree` view)

#### /serious-abandon
- **Location:** `.claude/skills/serious-abandon/SKILL.md`
- **Type:** User-invocable, no hooks
- **Does:** Marks current sub-workflow as abandoned, removes breadcrumb, restores parent context, summarizes parent state
- **Arguments:** none (operates on the deepest active workflow)

---

## Known Limitations (Phase 1)

1. **Single-session assumption.** Breadcrumb files have no locking. Two concurrent Claude sessions on the same project may clobber each other's breadcrumbs. Acceptable for Phase 1 (single user, single session). Document as known limitation.

2. **Stage column shows latest stage only.** A folder that progressed through multiple pipeline stages shows only the most recent. Hides completed stages. Phase 2 could add `--verbose`.

3. **No auto-pause for parents.** When a child spawns, the parent's status stays `active`. This is technically true (parent isn't done) but could be misleading (user isn't actively working on it). Auto-pausing was explicitly deferred to Phase 3 in the conversation. For now, both parent and child can show as `active`.

4. **Compaction recovery.** After Claude Code context compaction, the agent loses in-memory state of which workflow it was in. The breadcrumb files survive (they're on disk). The parent check at Phase 0 of any skill also serves as a reconstruction mechanism — after compaction, the next skill invocation will re-read breadcrumbs and restore context. No additional mechanism needed, but this behavior should be documented in each skill.

5. **Breadcrumbs live in the main project root, not in worktree roots.** When `/serious-code` creates git worktrees, sub-agents running inside worktrees must resolve breadcrumbs relative to the main repo root, not the worktree root. The parent check must use the git `rev-parse --show-toplevel` equivalent to find the actual project root.

---

## Recommendations

### Implementation Order

1. **First: YAML frontmatter standard + `.gitignore` update**
   - Define the standard in a shared document (or as a section in CLAUDE.md)
   - Add `.active-*` to `.gitignore`
   - This is the foundation everything else builds on

2. **Second: Add breadcrumbs to mock-ups, plan, review**
   - Simple additions to 3 skills
   - Enables parent auto-detection across all skills

3. **Third: Add parent check (0-pre) to all 6 skills**
   - The "advancing vs branching" logic
   - Frontmatter writing
   - Nested folder creation
   - This is the largest change — affects all 6 skill SKILL.md files

4. **Fourth: Create `/serious-status`**
   - Depends on frontmatter being in place
   - Can be developed and tested against manually-created test folders

5. **Fifth: Create `/serious-abandon`**
   - Depends on breadcrumbs and frontmatter
   - Test against active workflows from step 3

6. **Last: Update auto-detection scan paths in plan, code, and review**
   - Add `**/sub/*/` patterns
   - Filter by `status: done`

### Recommended next step

`/serious-plan` to create the implementation plan, using this research as input.

---

## References

| File | What It Contains |
|------|-----------------|
| `.claude/skills/serious-conversation/SKILL.md` | Conversation skill — breadcrumb, folder structure, lifecycle |
| `.claude/skills/serious-research/SKILL.md` | Research skill — breadcrumb, file templates, markdown headers |
| `.claude/skills/serious-mock-ups/SKILL.md` | Mock-ups skill — no breadcrumb, late file creation |
| `.claude/skills/serious-plan/SKILL.md` | Plan skill — auto-detection, file templates |
| `.claude/skills/serious-code/SKILL.md` | Code skill — worktrees, breadcrumb, execution tracking |
| `.claude/skills/serious-review/SKILL.md` | Review skill — findings capture, no breadcrumb |
| `Research/conversations/recursive-workflow-pipeline/summary.md` | Conversation decisions driving this research |
