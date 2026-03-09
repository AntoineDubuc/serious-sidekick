# The Architect — Round 3

## Answering the Open Questions

**1. `/serious-status` output format: ASCII tree with flat fallback.**

Default view is a shallow tree — two levels max, so it stays readable:

```
Pipeline: auth-system
├─ conversation/auth-approach    ✅ done (v3)
├─ research/auth-tokens          ✅ done
│  └─ research/jwt-claims        ✅ done (sub)
├─ plan/auth-implementation      🔄 active
│  └─ research/rate-limiting     ⚠️  abandoned
└─ code/                         ⏳ pending
```

Add `--flat` for a scannable table (grep-friendly, CI-friendly). The tree is the default because parent-child relationships are the whole point. But the flat table is a one-flag escape hatch — not a separate mode to maintain.

**2. Parent field: in the output file frontmatter, not a separate manifest.**

A separate manifest is a coordination problem. Every skill would need to know where to find and update it. Frontmatter in each output file (research.md, plan.md, conversation result) is self-describing — the metadata travels with the artifact. `/serious-status` reconstructs the tree by scanning frontmatter plus folder structure. This is the "flat file as registry" principle from Round 2: the registry emerges from the files themselves.

Format: `parent: research/auth-tokens` (relative path from project root). Simple, greppable, no UUIDs.

**3. Abandon + worktrees: mark and orphan, don't delete.**

When you abandon a sub-workflow spawned inside `/serious-code`, the worktree gets detached — not destroyed. Mark it `status: abandoned` in frontmatter, stop the agent, but leave the branch. Users can recover abandoned work or inspect what went wrong. Destroying worktrees on abandon is a data-loss footgun. The kill switch should feel like closing a browser tab, not shredding a document.

**4. `/serious-status` should be universal.**

Yes. Show every workflow, recursive or flat. A flat pipeline is just a tree of depth 1. This makes `/serious-status` the single "where am I?" command regardless of whether you've ever used recursion. That's clean — one entry point, one mental model.

**On the kill switch moving to Phase 1:** Agreed. You can't ship "pause and drill down" without "unpause and come back up." Spawn and abandon are symmetric operations — shipping one without the other is an incomplete interface.
