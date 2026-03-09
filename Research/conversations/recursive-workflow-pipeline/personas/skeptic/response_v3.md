# The Skeptic — Round 3

Good — the kill switch moved to Phase 1. Now the open questions.

## 1. `/serious-status` output: flat table, not ASCII tree.

ASCII trees look clever until you have three active workflows and two abandoned ones. A flat table with indentation is scannable, greppable, and doesn't break in narrow terminals. One row per workflow. Columns: status, depth indicator (just `>` prefix), name, stage, parent. If someone later wants a tree view, that's a flag (`--tree`), not the default. Default must be the simplest thing that works.

## 2. Parent field: in the output files, not a separate manifest.

A separate manifest is a second source of truth. It *will* drift. Put `parent` in the frontmatter of the skill's primary output (e.g., `research.md`, `plan.md`). The data lives where the work lives. `/serious-status` reads it by scanning folders — no index to maintain, no sync bugs. If Phase 3's registry ever materializes, it can be *generated* from these fields, not the other way around.

## 3. Abandon + worktrees: mark abandoned, don't auto-delete.

Deleting a worktree on abandon is irreversible. Mark the sub-workflow as `status: abandoned` in its output frontmatter. Leave the worktree. Add a cleanup command (`/serious-cleanup`?) that lists abandoned worktrees and lets the user delete them explicitly. Automatic deletion will eventually destroy something someone needed. I guarantee it.

## 4. `/serious-status` should show all workflows. Universal.

Yes. Making it recursive-only means users need to remember *which* status command to use. One command, always works, shows flat pipelines as depth-0 entries. If your workflow has no children, the output is just one row. Zero cost, maximum consistency.
