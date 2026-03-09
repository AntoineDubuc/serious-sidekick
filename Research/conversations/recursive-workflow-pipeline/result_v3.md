# Round 3 — Recursive Workflow Pipeline

## What the panel said

### The Architect
ASCII tree as default (depth-2 keeps it readable), `--flat` flag for table view. Parent field in frontmatter with relative paths, no UUIDs. Abandon marks `status: abandoned` and detaches worktree but never deletes. Universal `/serious-status` — flat pipelines are depth-1 trees.

### The Pragmatist
Flat table as default, not tree. Three columns, indent for depth, no box-drawing, no colors that break in pipes. Frontmatter, no manifest. Abandon keeps worktree for 24h then prompts to delete. Universal status so it earns muscle memory before recursion ships.

### The Product Thinker
Flat table default, `--tree` deferred to Phase 2. Frontmatter where the user already looks. Abandon should DELETE the worktree — "abandoned means abandoned, not parked." Universal status is where user value materializes.

### The DX Advocate
Flat indented list with status glyphs (✓ ● ○ ✗). Frontmatter, no manifest. Abandon marks status, leaves worktree intact — "abandoned is a status, not a deletion." Mentions `/serious-abandon` as the command. Universal status, one command always works.

### The Skeptic
Flat table, greppable, narrow-terminal safe. Frontmatter, no manifest — a manifest WILL drift. Abandon marks status, never auto-deletes. Suggests `/serious-cleanup` for explicit worktree deletion later. Universal status shows flat pipelines as depth-0 entries.

## Full convergence

### Unanimous agreement (5/5)
- **Parent field in frontmatter** — not a separate manifest. One source of truth. Data lives where the work lives. Format: `parent: {relative-path}` in YAML frontmatter of each skill's output file.
- **`/serious-status` is universal** — shows all workflows (flat and recursive). A flat pipeline is depth 1. One command, always works. No mode awareness needed.
- **Kill switch in Phase 1** — you can't ship "drill down" without "come back up."

### Near-unanimous (4/5)
- **Flat table as default output** for `/serious-status` — the Architect prefers ASCII tree but accepts `--flat`. Everyone else wants table-first with tree as a later flag.
- **Don't auto-delete abandoned worktrees** — the Product Thinker is the lone dissenter ("abandoned means clean it up"). Everyone else says preserve the worktree, mark the status, let the user delete explicitly.

### The one real disagreement: what happens to abandoned worktrees?

| Position | Who | Argument |
|----------|-----|----------|
| Mark abandoned, never auto-delete | Architect, DX Advocate, Skeptic | Irreversible deletion will eventually destroy needed work |
| Mark abandoned, prompt to delete after 24h | Pragmatist | Cheap to keep briefly, explicit to discard |
| Delete immediately on abandon | Product Thinker | Dead ends get cleaned up, not parked |

## Synthesis — Final Decision

The panel has fully converged. Here are the concrete decisions:

### 1. `/serious-status` output format

**Default: flat indented table.** One row per workflow, indentation for depth.

```
Status     Workflow                          Stage                 Path
✓ done     auth-system                       /serious-plan         Research/features/auth/
  ● active └ token-expiry                    /serious-research     Research/features/auth/sub/token-expiry/
  ✓ done   └ session-model                   /serious-conversation Research/features/auth/sub/session-model/
  ✗ abandoned └ rate-limiting                /serious-research     Research/features/auth/sub/rate-limiting/
○ pending  onboarding-flow                   /serious-research     Research/features/onboarding/
```

- Status glyphs: `✓` done, `●` active, `○` pending, `✗` abandoned
- Shows ALL workflows (flat and recursive) — universal "where am I?"
- `--tree` flag deferred to Phase 2 if demand appears

### 2. Parent field storage

**YAML frontmatter in the skill's primary output file.** No separate manifest.

```yaml
---
parent: Research/features/auth
status: active
spawned_from: plan/task-3
---
```

- Relative path from project root
- `/serious-status` reconstructs the tree by scanning frontmatter + folder structure
- Phase 3's registry (if ever needed) generates from these fields

### 3. Nested folder convention

```
Research/features/auth/
├── research.md                    # parent workflow
├── mock-ups/
├── sub/                           # sub-workflows live here
│   ├── token-expiry/
│   │   └── research.md            # parent: Research/features/auth
│   └── session-model/
│       └── conversation.md        # parent: Research/features/auth
└── implementation_plan.md
```

### 4. Abandon / kill switch

**Mark `status: abandoned` in frontmatter. Do NOT auto-delete worktrees.**
- The user says "abandon this" → status marked, returned to parent context
- Worktree preserved for inspection/recovery
- Add `/serious-cleanup` (Phase 2) that lists abandoned worktrees and prompts for explicit deletion
- The 4-1 panel split favors preservation over cleanup

### 5. Phase 1 scope (updated)

Ship together:
1. `parent` field in frontmatter (auto-detected, yes/no prompt)
2. Nested folder convention (`{parent}/sub/{slug}/`)
3. `/serious-status` (flat table, universal)
4. Kill switch (mark abandoned, return to parent)

### 6. Commands

| Command | Phase | Purpose |
|---------|-------|---------|
| `/serious-status` | 1 | Show full work tree across all skills |
| `/serious-abandon` | 1 | Abandon current sub-workflow, return to parent |
| `/serious-cleanup` | 2 | List and delete abandoned worktrees/folders |

## Open questions (resolved)

All four open questions from Round 2 are now answered with concrete decisions. No remaining open questions on the architecture.

The conversation is ready to wrap up.
