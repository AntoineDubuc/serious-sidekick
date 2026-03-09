# Conversation Summary: Recursive Workflow Pipeline

## Topic
How should the Serious Sidekick workflow pipeline evolve from a flat sequence into something that handles real-world complexity — where mid-work discoveries send you back to earlier stages, and sub-problems need their own mini-pipelines before the parent work can continue?

## Desired outcome
Decision — what specifically to build, in what order, and what to deliberately NOT build yet.

## Personas
- The Architect (systems design, abstractions, layered architecture)
- The Pragmatist (ship it, minimum viable, prove the need first)
- The Product Thinker (user value, mental models, who is this for?)
- The DX Advocate (developer experience, legibility, "will future-you understand this?")
- The Skeptic (challenge assumptions, demand evidence, guard against over-engineering)

## Rounds
Three rounds. The first round surfaced the full spectrum from "build a workflow engine" to "just add a metadata field." The second round converged on a phased approach — start minimal, grow only with evidence. The third round resolved all remaining open questions with concrete, implementable decisions.

---

## The Problem (in plain language)

Today, the Serious Sidekick pipeline works like an assembly line:

```
Talk about it → Research it → Mock it up → Plan it → Build it → Review it → Done
```

That's fine when the work flows cleanly from one stage to the next. But in practice, things get messy:

- You're halfway through **planning** and realize one piece needs its own **research** first
- You're in **research** and discover a sub-question that needs its own **conversation** to think through
- You're in **code** and hit a failure that needs **research** to diagnose
- A **conversation** produces 5 ideas — 3 are ready for research, but 2 need their own conversations first

When this happens today, you have two bad options:
1. **Hack it inline** — do the sub-work inside the current stage, losing the structure and traceability that the pipeline provides
2. **Start a new pipeline from scratch** — lose your context, lose your place, and manually track that the new pipeline's output needs to feed back into the original

Neither is good. The pipeline pretends work flows in one direction. Real work branches, dives, and resurfaces.

---

## The Decision

### What we're building

**Think of it like browser tabs.** You're working in a tab (your main pipeline). You discover something that needs its own investigation. You open a new tab (a sub-workflow). When you're done with that tab, the result flows back into your original tab. You never lost your place.

That's the mental model: **"pause and drill down."** Not "spawn child processes" — just "hold my place while I go figure this out."

### The 4 things we're shipping (Phase 1)

#### 1. The Parent Link

Every piece of work the pipeline creates (a research doc, a plan, a conversation summary) gets a small tag in its header that says "I was created because of this other piece of work." Like a reply chain in email — you can always trace back to what spawned what.

**What it looks like technically:** A `parent:` field in the YAML header of every output file. When you invoke a skill while inside another workflow, the system detects this and asks: "Link this to {parent workflow}? Yes/No." One question, one click. No manual IDs, no copying paths.

**Why it matters:** This is traceability. When you finish a sub-research and come back to your plan, you (and the system) know exactly why that research exists and where its results should go.

#### 2. Nested Folders

Sub-workflows live inside their parent's folder, not scattered across the project. If your auth research spawns a sub-research on token expiry, it lives at:

```
Research/features/auth/
├── research.md              ← the parent research
└── sub/
    └── token-expiry/
        └── research.md      ← the sub-research (has parent: link)
```

**Why it matters:** You can see the hierarchy just by looking at the file tree. No need to trace metadata — the folder structure tells the story. And when you delete or archive the parent, the children go with it.

#### 3. `/serious-status` — The "Where Am I?" Command

One command that shows you everything that's happening across all your serious workflows. Active, pending, done, abandoned — all in one flat, scannable view:

```
Status       Workflow                          Stage                  Path
✓ done       auth-system                       /serious-plan          Research/features/auth/
  ● active   └ token-expiry                    /serious-research      Research/features/auth/sub/token-expiry/
  ✓ done     └ session-model                   /serious-conversation  Research/features/auth/sub/session-model/
  ✗ abandoned└ rate-limiting                   /serious-research      Research/features/auth/sub/rate-limiting/
○ pending    onboarding-flow                   /serious-research      Research/features/onboarding/
```

**Why it matters:** Without this, the parent link and nested folders are just plumbing nobody sees. `/serious-status` is the product — it's what you actually look at to understand your work. It works for simple pipelines too (they just show as a single row), so you use it all the time, not just when things get recursive.

#### 4. `/serious-abandon` — The Kill Switch

You drilled down into a sub-workflow and realized it's a dead end. You need to get out and go back to where you were. `/serious-abandon` does exactly that:

- Marks the sub-workflow as abandoned (it stays on disk for reference, but it's clearly marked as "I stopped this")
- Returns you to the parent workflow's context
- The abandoned sub-workflow shows up with a ✗ in `/serious-status`

**Why it matters:** If you can open a tab, you need to be able to close it. Drilling down without being able to come back up is a trap. The panel was adamant: you can't ship "drill down" without "come back up."

**What about the files and code?** Abandoned work is NOT deleted. It's marked as abandoned and left alone. You might want to look at it later. You might realize it wasn't a dead end after all. Deleting is irreversible — marking is not. Later (Phase 2), a `/serious-cleanup` command will let you explicitly review and delete abandoned work.

---

### What we're NOT building yet

#### The Triage Prompt (Phase 2)

When a stage finishes and its output suggests a sub-problem, the system would ask: "This looks like it needs its own research. Want to drill down?" Today, the user decides this themselves. The prompt would make the system smarter about surfacing the option.

**Why not now:** We want to see how people use Phase 1 first. If users naturally drill down at the right moments without prompting, we don't need it. If they consistently miss opportunities to drill down, then the prompt earns its place.

#### The Cleanup Command (Phase 2)

`/serious-cleanup` — lists all abandoned sub-workflows and worktrees, lets you delete them one by one. Not urgent because abandoned work takes up negligible space.

#### The Full Work Item Registry (Phase 3)

A formal database of all work items, queryable, with automated blocking/unblocking (parent auto-pauses when child spawns, auto-resumes when child completes). The Architect's vision — but only worth building if Phase 1 and 2 prove that people actually use recursive workflows frequently enough to justify the complexity.

#### The Stage Boundary Router (Phase 3)

Automated routing suggestions at every stage exit. The system learns from your triage patterns and starts recommending when to drill down. Full workflow engine territory — only if the data from Phase 2 shows clear patterns worth automating.

---

### Guardrails

#### Depth Limit: 2 Levels

A sub-workflow can drill down, but a sub-sub-workflow needs your explicit approval. This prevents runaway nesting. In practice, depth 2 covers the real cases:
- Plan discovers something → spawns a research (depth 1)
- Research discovers a sub-question → spawns a conversation (depth 2)
- Deeper than that? The system asks "Are you sure? This is getting deep." You can override, but it makes you think.

#### The User Always Decides

The system never automatically spawns a sub-workflow. It can suggest ("this might need its own research"), but the user always makes the call. This is how we prevent the pipeline from turning into an uncontrollable workflow engine.

---

## The Updated Pipeline

```
/serious-conversation → /serious-research → /serious-mock-ups → /serious-plan → /serious-code → /serious-review → done
        ↑                       ↑                                      ↑              ↑
        └───────────────────────┴──────── drill down from any stage ───┴──────────────┘

New commands:
  /serious-status   — "Where am I?" across all workflows
  /serious-abandon  — "Get me out of this sub-workflow"
  /serious-cleanup  — "Clean up my abandoned work" (Phase 2)
```

---

## Key Insights from the Panel

1. **Traceability matters more than orchestration.** The pain isn't "I need the system to manage my sub-workflows." The pain is "I lost track of why I started this and where it feeds back into." The parent link solves that.

2. **Convention before automation.** Start with a field and a folder convention. See if people use it. Automate only what you've seen people do manually enough times to justify the investment.

3. **One command for everything.** `/serious-status` works for simple pipelines AND recursive ones. Don't make users learn different commands for different modes. One entry point, always works.

4. **Abandoning is as important as starting.** Most sub-workflows are exploratory — many will be dead ends. Making it easy to back out is not an afterthought; it's a core feature.

5. **Don't build a workflow engine.** The moment you add routing rules, heuristics, and automated decisions, you've left "helpful tool" territory and entered "enterprise BPM" territory. Stay on the helpful side.

## Unresolved Tensions

- **The Product Thinker wants abandoned worktrees deleted immediately.** Everyone else wants them preserved. We're going with preservation (4-1), but this may need revisiting if abandoned work accumulates and becomes confusing.

## Recommended Next Step

`/serious-research` on the technical implementation:
- How exactly does the `parent` field auto-detection work across different skills?
- What does `/serious-status` read and how does it reconstruct the tree from frontmatter + folders?
- How does `/serious-abandon` interact with `/serious-code`'s worktree and agent model?
- What changes are needed in each existing skill to support the parent field?

Then `/serious-plan` to create the implementation plan for Phase 1 (the four features above).
