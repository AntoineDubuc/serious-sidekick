---
name: serious-abandon
description: "Abandon the current sub-workflow and return to the parent. Use when the user says 'serious abandon', 'abandon this', 'bail out', 'go back to parent', or wants to stop the current workflow branch."
user-invocable: true
---

# Serious Abandon

Mark the deepest active workflow as abandoned, remove its breadcrumb, restore the parent context, and report status. Use this to bail out of a sub-workflow that's no longer needed.

---

## Step 1: Find the Deepest Active Workflow

### 1a. Read breadcrumbs

Read all `.active-*` breadcrumb files in the project root:
- `.active-conversation`
- `.active-research`
- `.active-mock-ups`
- `.active-scope`
- `.active-plan`
- `.active-code`
- `.active-review`

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
> "No active workflow to abandon."

Stop here.

---

## Step 2: Safety Checks

### 2a. Top-level warning

If the deepest workflow has no `parent:` field (it's top-level):

> "This is a top-level workflow ({slug}), not a sub-workflow. Abandon it? (Y/N)"

If the user says No: stop, do nothing.

### 2b. Active children check

Check if the workflow being abandoned has active children:
1. Read all OTHER valid breadcrumbs (besides the one being abandoned)
2. For each, read the target workflow's frontmatter `parent:` field
3. If any workflow's `parent:` path points INTO the workflow being abandoned (i.e., the parent path starts with or equals the abandoned workflow's folder path), it is an active child

If active children exist:

> "Cannot abandon {slug} — it has active sub-workflow(s): {list of child slugs with their skill types}. Abandon or complete the children first, or use `/serious-abandon` on them."

Stop here. Do NOT cascade-abandon children automatically.

---

## Step 3: Mark as Abandoned

### 3a. Update frontmatter

Read the primary output file of the deepest active workflow. Change the `status:` field in the YAML frontmatter from `active` to `abandoned`.

### 3b. Remove breadcrumb

**AFTER** setting `status: abandoned` in the frontmatter (reverse of creation order — frontmatter first, breadcrumb second), remove the `.active-{skill}` breadcrumb file from the project root.

---

## Step 4: Handle Worktrees (Code Workflows Only)

If the abandoned workflow's `skill:` is `code`:

### 4a. Check for worktrees

Look for worktree directories at `.claude/worktrees/serious-code-*`.

### 4b. Report but do NOT delete

If worktrees exist:
> "Found worktrees for this code workflow: {list}. These have NOT been deleted or merged — they contain work-in-progress that may be useful. To clean up manually: `git worktree remove {path}`."

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
- The `.active-{skill}` breadcrumb was overwritten when the sub-workflow started
- Restore it: write `.active-{skill}` with the parent's folder path as content

Example: Sub-research at `Research/features/auth/sub/token-expiry/` was abandoned. Parent is `Research/features/auth/`. Write `Research/features/auth` to `.active-research`.

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
> "Abandoned **{slug}** ({skill}). Returning to **{parent_slug}** (/serious-{parent_skill}). Parent status: {brief summary of parent state}."

If top-level (no parent):
> "Abandoned **{slug}** ({skill}). No parent workflow to return to."

### 6d. Suggest next step

Based on the parent's state:
- If parent is `/serious-research` with status active: "Continue with `/serious-research --resume {slug}`"
- If parent is `/serious-plan`: "Continue planning with `/serious-plan`"
- If parent is `/serious-code`: "Resume coding with `/serious-code --resume`"
- If no parent: "Start fresh with `/serious-conversation` or `/serious-research`"

---

## Arguments

`$ARGUMENTS` can specify:
- A specific slug: `/serious-abandon auth-token-fix` — abandon that specific workflow instead of the deepest
- No arguments — abandon the deepest active workflow (default)
