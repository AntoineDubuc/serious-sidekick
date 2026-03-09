# DX Advocate — Round 3 Response

## Answering the open questions

**1. `/serious-status` output format: ASCII tree, flat table, or both?**

Default to a flat indented list, not a full ASCII tree. Trees look elegant in docs but are hard to scan when you just need "where am I?" The format should be:

```
Pipeline: auth-token-validation
  research     ✓ complete    Research/features/auth/
  ├ sub-research  ● active   Research/features/auth/sub/token-formats/
  plan         ○ pending     —
  code         ○ pending     —
```

Two spaces for depth. Status glyphs: `✓` complete, `●` active, `○` pending, `✗` abandoned. That's it. No box-drawing beyond a single `├` to show parent-child. Add `--tree` flag later if anyone asks. Nobody will.

**2. Parent field storage: frontmatter or separate manifest?**

Frontmatter in the output file itself. A separate manifest is a second source of truth that will drift. Put `parent: auth-token-validation` in the YAML frontmatter of every output file the sub-workflow creates. The status command reads frontmatter. One source. No sync problems.

**3. Abandon sub-workflow + worktrees?**

Agree with the Skeptic: kill switch belongs in Phase 1. Abandoning must: (a) mark the sub-workflow folder as `status: abandoned` in its output frontmatter, (b) leave the worktree intact but detached — do not delete work. The user typed `/serious-abandon`, sees "Marked token-formats as abandoned. Returning to auth-token-validation." Deleting worktrees is destructive; abandoned is a status, not a deletion.

**4. Should `/serious-status` cover flat (non-recursive) pipelines too?**

Yes, absolutely. Make it universal. A flat pipeline is just a tree of depth 1. If `/serious-status` only works for recursive workflows, users have to remember *which kind* of workflow they're in before knowing which command to run. That's a sharp edge. One command, always works, shows whatever exists.
