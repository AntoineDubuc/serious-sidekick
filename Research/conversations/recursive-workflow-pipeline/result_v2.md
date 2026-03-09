# Round 2 — Recursive Workflow Pipeline

## What the panel said

### The Architect
Concedes on building the registry/router upfront — the Pragmatist was right about sequencing. Doubles down on the stage boundary triage point as essential even in the minimal version: "without it, the parent field is just bookkeeping." Accepts depth-2 as a default with override, not a wall. Frames Round 1's three-layer architecture as the destination, the synthesis as the road.

### The Pragmatist
Concedes on folder nesting (cheap hygiene, not infrastructure) and `/serious-status` (can't work in a tree you can't see). Doubles down against the Stage Boundary Router — the triage step should be a user-facing question, not a routing component. Proposes a shipping order: (1) parent field, (2) folder nesting, (3) `/serious-status`, (4) spawn prompt at stage exits.

### The Product Thinker
Concedes to convention-first over orchestration and evidence as a hard gate. Doubles down on `/serious-status` as the actual product — the parent field is plumbing, `/serious-status` is where user value materializes. Flags concern about nested folder paths getting deep/unwieldy. Accepts incremental delivery of the "never lose your place" criteria.

### The DX Advocate
Concedes on sequencing — not all four Round 1 requirements need to ship at once. Accepts "pause and drill down" framing over "spawn child workflows." Doubles down on three things shipping together as the minimum viable DX: parent field, nested folders, `/serious-status`. Without all three, the convention rots.

### The Skeptic
Concedes the problem is real, not niche. Doubles down on three points: (1) triage must be a question to the user, never automated suggestions — that's how you prevent workflow-engine creep; (2) parent field must auto-detect context and offer a yes/no prompt, not require manual ID entry; (3) need a kill switch — abandoning a sub-workflow and unblocking the parent must be as frictionless as spawning one.

## Where they agree (convergence)

- **The synthesis from Round 1 is the right approach.** All five personas now endorse "start minimal, grow toward full architecture."
- **Ship three things together:** parent field, nested folders, `/serious-status`. This is the minimum where the system holds together.
- **The triage step is a user question, not automation.** "This needs sub-research — want to drill down?" No heuristics, no routing rules.
- **Depth limit of 2** as a pragmatic default with override.
- **`/serious-status`** is not a nice-to-have — it's how you read the tree. Day-one requirement.

## Where they still disagree

- **Shipping order:** The Pragmatist wants parent field first, then nesting, then status, then triage prompt (sequential). The DX Advocate wants parent + nesting + status shipped together (atomic). Minor disagreement — both get to the same place.
- **Folder nesting depth:** The Product Thinker worries nested paths get unwieldy. Others think the depth-2 limit contains this. Needs real-world testing.
- **Kill switch priority:** The Skeptic raises abandoning sub-workflows as a day-one concern. Others haven't addressed it. This is a real gap — you need to cancel as easily as you spawn.

## Synthesis

**The panel has converged.** The decision is clear:

### What to build (in order)

**Phase 1 — The Foundation (ship together):**
1. **`parent` field** in every skill's output metadata. Auto-detected: when you invoke a skill while inside another workflow, the system asks "Link this to {parent}?" — one yes/no prompt. No manual IDs.
2. **Nested folder convention.** Sub-workflows live inside their parent's folder at `{parent}/sub/{slug}/`. Depth-2 limit means paths stay manageable.
3. **`/serious-status`** — one command, flat scannable view of the full work tree. Reads folder structure and parent references. Shows: what's active, what's blocked, what completed, what spawned what.

**Phase 2 — The Triage Prompt (ship after Phase 1 is proven):**
4. **Stage-exit triage.** At every stage boundary, when output suggests a sub-problem: "This looks like it needs its own {research/conversation/plan}. Want to drill down?" User decides. No automation, no heuristics.
5. **Kill switch.** "Abandon this sub-workflow and return to {parent}?" Cleans up, marks as abandoned, unblocks parent. As frictionless as spawning.

**Phase 3 — The Full Architecture (ship only if evidence demands it):**
6. **Work Item Registry** — formalize the parent fields into a queryable index.
7. **Stage Boundary Router** — automated routing suggestions (not decisions) based on patterns observed in Phase 2 triage data.

### What NOT to build yet
- Automated blocking/unblocking (let users feel the friction first)
- Routing rules or heuristics (watch what users actually do at triage points)
- Depth 3+ without explicit override

### The mental model
"Pause and drill down" — like browser tabs, not process trees. The user opens a sub-workflow, resolves it, and the result flows back into where they were.

## Open questions

- What exactly does `/serious-status` output look like? ASCII tree? Flat table? Both?
- Should the parent field be stored in the skill's output files (e.g., research.md frontmatter) or in a separate manifest?
- How does "abandon sub-workflow" interact with `/serious-code`'s worktree model? Does abandoning discard the worktree?
- Should `/serious-status` also show non-recursive workflows (the simple flat pipeline), making it a universal "where am I?" command?
