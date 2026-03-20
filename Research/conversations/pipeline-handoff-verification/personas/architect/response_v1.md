# The Architect -- Round 1

## The Core Design Question

This is a boundary enforcement problem. You already have the answer buried in serious-code: an independent agent that verifies against acceptance criteria before the gate opens. The question is where to generalize that pattern.

## Where the Responsibility Lives

Verification cannot live inside the downstream skill. That's asking the contractor to inspect their own work -- it violates separation of concerns at the most fundamental level. Self-verification clauses in prompts are architectural wishful thinking. They'll always be the first thing the agent optimizes away under token pressure.

The verification layer must be a **separate boundary component** that sits between every skill transition. Think of it like a building inspector: they don't pour the concrete, they don't design the structure, but nothing proceeds without their sign-off.

## The Pattern: Pipeline Middleware

I'd argue for a **handoff verification middleware** -- a thin, independent agent invoked automatically at every skill boundary. Its interface is simple:

- **Input:** upstream artifact + downstream artifact
- **Output:** pass/fail + specific divergence list (omissions, contradictions, deferrals)
- **Trigger:** automatic, fires when the downstream skill writes its primary output

This is middleware, not a skill. It doesn't belong in the skill chain. It wraps the transitions between skills the same way hooks wrap tool calls. The skills shouldn't even know it exists -- that's clean separation.

## Why Not Per-Skill Verification

Embedding verification logic into each skill's prompt creates N copies of the same responsibility, each slightly different, each drifting over time. One middleware component means one place to fix, one pattern to evolve. The skills stay focused on their domain. The middleware stays focused on fidelity.

## The Precedent

serious-code's QA agent already proves the sub-agent model works. The design move is: extract that pattern, generalize it, and make it fire at every handoff -- not just the last one.
