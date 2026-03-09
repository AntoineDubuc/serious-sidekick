# The Pragmatist — Round 3

## Answering the open questions. No more deliberation.

**1. `/serious-status` output: flat table, not ASCII tree.**

An ASCII tree looks pretty in demos and breaks the moment a workflow name is long or a third column is needed. Ship a flat table with indentation to show depth:

```
Status   Depth  Workflow                          Stage
active   0      auth-system                       /serious-plan
active   1      └ token-expiry-research            /serious-research
done     1      └ session-model-conversation        /serious-conversation
```

Three columns, one indent level per depth, most recent at top. No box-drawing. No color codes that break in pipes. If someone later wants `--tree`, fine — but the default is scannable text.

**2. Parent field: in the output file frontmatter. No separate manifest.**

A manifest is a second source of truth that will drift from the files within a week. Put `parent: auth-system` in the YAML frontmatter of `research.md`, `plan.md`, etc. `/serious-status` reads frontmatter from nested folders. One source of truth, zero syncing. If Phase 3's registry ever happens, it scrapes frontmatter — don't pre-build the index.

**3. Abandon + worktrees: mark abandoned, keep the worktree for 24 hours, then prompt to delete.**

`/serious-code` worktrees contain real code. Instant deletion on abandon is data loss waiting to happen. Mark the sub-workflow `status: abandoned` in frontmatter, return to parent, and leave the worktree. Next time `/serious-status` runs (or after 24h), prompt: "Abandoned worktree `token-expiry` still exists. Delete?" This is the same pattern as git stash — cheap to keep, explicit to discard.

**4. Yes, `/serious-status` shows flat pipelines too. Universal "where am I?"**

If it only works for recursive workflows, nobody will remember it exists until they need recursion. Make it the default situational awareness command. Flat pipeline with no children? Show one row. This is how it earns muscle memory.

**On the kill switch in Phase 1:** The Skeptic is right. You cannot ship "drill down" without "come back up." Move it to Phase 1. The implementation is trivial — set `status: abandoned`, cd to parent context. No cleanup automation needed yet.
