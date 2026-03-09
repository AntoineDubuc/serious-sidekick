# Round 1 — Recursive Workflow Pipeline

## What the panel said

### The Architect
Proposes a clean three-layer architecture: a Work Item Registry (flat process table with parent-child IDs), a Stage Boundary Router (the only component aware of the tree, makes routing decisions at every stage exit), and Stage Executors (existing skills, kept dumb — they process one item and return control). Recursion is an emergent property of parent-child links, not baked into stages.

### The Pragmatist
Pushes back hard. The actual pain is traceability (losing track of why a sub-workflow was spawned), not orchestration. Proposes the minimum viable solution: a `parent` reference field in artifact metadata + a `blocked` status convention. No registry, no router, no automation. See if convention solves 80% before building machinery.

### The Product Thinker
Reframes the problem around user pain: mid-stage discoveries stall momentum, no way to track spawned sub-work, no lineage. Wants the mental model to be "pause and drill down" (browser tabs) not "spawn child workflows" (process tree). Success criteria: never manually copy context, never lose your place. Also demands validation — how often does this actually happen?

### The DX Advocate
Four non-negotiable DX requirements regardless of architecture: (1) explicit user consent before any sub-workflow spawns, (2) a `/status` command showing the full tree in a flat scannable view, (3) sub-workflows nested inside parent folders not scattered, (4) error messages that trace the full parent-child chain. Core concern: recursive systems are only acceptable if legible.

### The Skeptic
Challenges the foundational premise — is this a frequent structural problem or a niche annoyance? Raises: infinite recursion risk (what's the base case?), complexity explosion (workflow engines are where projects die), the 80/20 trap (20% of usage consuming 80% of effort), and debuggability concerns. Demands evidence of frequency before committing.

## Where they agree

- **The pain is real** — mid-stage discoveries that need earlier stages happen. Everyone acknowledges this.
- **Traceability is the core need** — knowing *why* a sub-workflow exists and linking its output back to the parent is more important than automated orchestration.
- **User control is non-negotiable** — no silent spawning, the user decides when to drill down.
- **The flat pipeline's simplicity is a feature, not a bug** — any solution must preserve the ability to hold the system in your head.

## Where they disagree

- **How much infrastructure to build:** The Architect wants a registry + router. The Pragmatist wants a metadata field and a convention. The Skeptic wants evidence before building anything.
- **Orchestration vs convention:** Should the system automatically manage parent-child blocking, or should users manually track it? The Architect and Product Thinker lean toward automation; the Pragmatist and Skeptic lean toward convention.
- **Whether to validate first:** The Skeptic and Product Thinker want evidence that this is frequent enough to justify the investment. The Architect and DX Advocate treat it as an obvious structural need.

## Synthesis

The panel reveals a clear spectrum from "build the machine" to "just add a field." Here's my proposed position:

**Start with the Pragmatist's minimum, but design it so the Architect's layers can grow from it.**

1. **Add a `parent` reference to every skill's output metadata.** When you invoke `/serious-research` from within `/serious-plan`, you can pass the parent context. The research output links back. This is the Pragmatist's "one field" — but it's also the foundation of the Architect's registry.

2. **Add a triage step at every stage exit.** When a stage produces output items, classify each: "ready for next stage" vs "needs its own sub-workflow at stage X." This is a lightweight version of the Architect's router — a decision point, not an engine. The user makes the call.

3. **Nest sub-workflow folders inside parents** (DX Advocate's requirement). `Research/features/auth/sub/token-formats/` not `Research/features/token-formats/`.

4. **Add `/serious-status`** — one command that shows the full work tree across all skills. What's active, what's blocked, what completed, what spawned what. Even if it's just reading folder structure and metadata fields.

5. **Don't automate blocking/unblocking yet.** Let users manually resume parent workflows after children complete. Automate only after we see the pattern in real use.

6. **Depth limit of 2** (Skeptic's base case concern). A sub-workflow can spawn, but a sub-sub-workflow requires explicit user override. This prevents runaway recursion without being arbitrary.

## Open questions

- Should the `parent` reference be a field in every skill's output, or a separate manifest file per workflow?
- What does the triage UX look like? A checklist? An automatic suggestion? A question?
- How does this interact with `/serious-code`'s parallel execution model — can sub-workflows run in parallel with their siblings?
- Should we prototype this in one skill first (e.g., `/serious-conversation` → sub-conversations) before rolling it out everywhere?
