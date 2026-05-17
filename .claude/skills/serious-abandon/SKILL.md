---
name: serious-abandon
description: "Abandon the current sub-workflow and return to the parent. Use when the user says 'serious abandon', 'abandon this', 'bail out', 'go back to parent', or wants to stop the current workflow branch."
user-invocable: true
---

# Serious Abandon

Mark the deepest active workflow as abandoned, remove its breadcrumb, restore the parent context, and report status. Use this to bail out of a sub-workflow that's no longer needed.

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

---

## Step 1: Find the Deepest Active Workflow

### 1a. Read breadcrumbs

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 17 -->
<!-- WHY: this section is the internal mechanics for locating active workflows on disk
     (breadcrumb files, path-resolve helper). The user never sees this language; it's
     instructions to the implementing agent. No chat output is generated from this step
     except via Step 1d ("No active workflow") which is rewritten separately above. -->

Source `.claude/skills/_shared/path-resolve.sh`. Run `breadcrumb_migrate` once to delete legacy `.active-{skill}` files at the project root under the agreement-or-orphan condition (preserves `.active-conversation` as the in-flight parent carve-out; emits `MIGRATE:` lines to stderr for every action). Then for each known skill name in the writer roster (`conversation`, `research`, `mock-ups`, `scope`, `plan`, `review`, `code`, `debug`), compute this terminal's per-session breadcrumb path via `bc=$(breadcrumb_path {skill})` and read it if it exists (resolves to `.claude-active/{claude_pid}-{skill}`). For transition-window completeness, also check the legacy `.active-{skill}` at the project root and warn `dual-read fallback for {skill}` to stderr if only the legacy is present.

### 1b. Validate each

For each breadcrumb found:
1. Read the content (relative path to the workflow folder)
2. Check that the folder exists
3. Check that the primary output file exists and has parseable YAML frontmatter
4. If invalid: discard this breadcrumb (do not delete it here — `/serious-status` handles stale warnings)

### 1c. Find the deepest

For each valid breadcrumb, read the frontmatter `parent:` field of the target workflow. Follow `parent:` chains to compute depth:
- No `parent:` field → depth 0 (top-level)
- Has `parent:` → follow the chain, count hops. Depth = number of hops from root.

The workflow with the greatest depth is the deepest active workflow. If multiple workflows have the same depth, prefer the most recently modified breadcrumb.

### 1d. Error state

If no valid breadcrumbs exist:

<!-- voice-retrofit: rewritten; thread-1 line: 38 -->

> What this does: nothing's running right now, so there's nothing to drop.
>
> Question: want me to look at what you finished recently, or just stop?

Stop here.

---

## Step 2: Safety Checks

### 2a. Top-level warning

If the deepest workflow has no `parent:` field (it's top-level):

<!-- voice-retrofit: rewritten; thread-1 line: 50 -->

> What this does: heads up — this is a top-level piece of work, not a sub-piece. Dropping it means the whole thread goes away.
>
> Question: drop it anyway?

Use the workflow's descriptive name in plain English (what it builds), NOT the kebab-case slug. If the user says No: stop, do nothing.

### 2b. Active children check

Check if the workflow being abandoned has active children:
1. Read all OTHER valid breadcrumbs (besides the one being abandoned)
2. For each, read the target workflow's frontmatter `parent:` field
3. If any workflow's `parent:` path points INTO the workflow being abandoned (i.e., the parent path starts with or equals the abandoned workflow's folder path), it is an active child

If active children exist:

<!-- voice-retrofit: rewritten; thread-1 line: 63 -->

> What this does: can't drop this — there's still other work running underneath it ({N} pieces). Dropping this one would leave them orphaned.
>
> What I need from you: finish or drop the inner pieces first. I can do that for each.
>
> Question: want me to walk through the inner pieces?

Use plain-English descriptions of each child workflow (what it builds), NOT kebab-case slugs or "skill types". Stop here. Do NOT cascade-abandon children automatically.

---

## Step 3: Mark as Abandoned

### 3a. Update frontmatter

Read the primary output file of the deepest active workflow. Change the `status:` field in the YAML frontmatter from `active` to `abandoned`.

### 3b. Remove breadcrumb

**AFTER** setting `status: abandoned` in the frontmatter (reverse of creation order — frontmatter first, breadcrumb second), source `.claude/skills/_shared/path-resolve.sh` and compute the breadcrumb path via `bc=$(breadcrumb_path {skill})`, then `rm -f "$bc"` to remove this terminal's breadcrumb. For transition cleanup, also `rm -f "${CLAUDE_PROJECT_DIR}/.active-{skill}"` to remove the legacy file at the project root if it still exists.

---

## Step 4: Handle Worktrees (Code Workflows Only)

If the abandoned workflow's `skill:` is `code`:

### 4a. Check for worktrees

Look for worktree directories at `.claude/worktrees/serious-code-*`.

### 4b. Report but do NOT delete

If worktrees exist:

<!-- voice-retrofit: rewritten; thread-1 line: 92 -->

> What this does: I dropped the work, but the in-progress code copies are still on disk in case you want to look at them later. They haven't been merged or deleted.
>
> Question: want me to clean those up too, or leave them?

### 4c. Update execution log

If `execution_log.md` exists in the workflow folder, update its `**Status:**` (or frontmatter `status:`) to `Abandoned`.

### 4d. Timing note

> "Note: `/serious-abandon` should only be invoked after code agents have stopped. If agents are still running, wait for them to finish or stop them first."

---

## Step 5: Restore Parent Context

### 5a. Read parent path

Read the `parent:` field from the abandoned workflow's frontmatter. This is the relative path to the parent workflow folder.

If no `parent:` field (top-level workflow): skip to Step 6.

### 5b. Determine parent's skill type

Read the parent folder's primary output file. Extract the `skill:` field from its frontmatter. This tells us which skill the parent was using.

### 5c. Restore breadcrumb (same-skill drilling)

If the abandoned workflow's skill type MATCHES the parent's skill type (same-skill drilling — e.g., both are `research`):
- The breadcrumb was overwritten when the sub-workflow started
- Restore it by **re-running the writer block** with the parent's folder path as `${RELATIVE_OUTPUT_PATH}` and `${SKILL}={parent_skill}`. The writer block writes to `.claude-active/$(claude_pid)-{parent_skill}`, NOT the legacy `.active-{parent_skill}` at the project root.

Example: Sub-research at `Research/features/auth/sub/token-expiry/` was abandoned. Parent is `Research/features/auth/`. Re-run the writer block with `${RELATIVE_OUTPUT_PATH}=Research/features/auth` and `${SKILL}=research` (writes `.claude-active/$(claude_pid)-research`).

**Edge case — depth 2 parent:** If the parent itself is a sub-workflow (its frontmatter also has a `parent:` field), restoration still works correctly. The breadcrumb just needs to point to the IMMEDIATE parent. The parent's own parent relationship is tracked in the parent's frontmatter, not in the breadcrumb.

### 5d. Cross-skill: no restoration needed

If the abandoned workflow's skill type DIFFERS from the parent's skill type (cross-skill branching — e.g., sub-research from a plan):
- The parent's breadcrumb (e.g., `.active-plan`) was never overwritten — cross-skill breadcrumbs coexist
- No restoration needed

---

## Step 6: Report

### 6a. Read parent state

If there's a parent: read the parent's primary output file and summarize its current state (status, last activity, key findings or progress).

### 6b. Report abandoned work

Summarize what the abandoned sub-workflow produced (if anything):
- Number of rounds (conversation), findings (research), tasks completed (code), etc.
- Note any artifacts that were created and may still be useful

### 6c. Final message

Format:

<!-- voice-retrofit: rewritten; thread-1 line: 149 -->

> What this does: dropped the inner piece. You're back on the bigger thread — here's where it stands in one sentence.
>
> Question: pick the bigger thread back up, or do something else?

Translate the workflow names to plain English (what they build), not kebab-case slugs. Don't surface the `/serious-{skill}` command labels in chat.

If top-level (no parent):

> What this does: dropped it. Nothing's running now.
>
> Question: start something new?

### 6d. Suggest next step

<!-- voice-retrofit: rewritten; thread-1 line: 157 -->

Based on the parent's state, suggest ONE next step in plain English. NOT a 4-option menu, NOT slash commands with `--flag {slug}`, NOT bare ordinals. Just one recommendation: "Want me to pick the research back up where it stopped?" or "Want to start fresh on something new?" The user can always ask for alternatives.

---

## Arguments

`$ARGUMENTS` can specify:
- A specific slug: `/serious-abandon auth-token-fix` — abandon that specific workflow instead of the deepest
- No arguments — abandon the deepest active workflow (default)

