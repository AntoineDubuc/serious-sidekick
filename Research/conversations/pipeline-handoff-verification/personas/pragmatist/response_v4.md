# The Pragmatist — Round 4

## Answer the three questions, then ship

**1. Generic prompt or handoff-specific knowledge?**

One generic prompt. The verifier's job is mechanical: extract numbered/bulleted items from artifact A, check if artifact B addresses each one. That logic is identical whether A is a conversation result or a research notebook. The moment you write per-transition prompts, you're maintaining N prompts instead of one, and they'll drift. If the generic prompt can't handle a specific transition, that's a signal the upstream artifact's structure is too messy — fix the template, not the verifier.

**2. Heading standardization now or later?**

Later. The DX Advocate's right that consistency helps, but we don't know which headings will trip the verifier until we run it. Ship the verifier first, run it against real artifacts, and standardize only the headings that actually cause extraction failures. Standardizing speculatively is the definition of solving a problem you don't have yet.

**3. Same `_shared/` directory as Phase 0-pre?**

Yes. One directory for shared prompts. Don't create a second organizational layer. `_shared/verify-handoff.md` sits next to whatever Phase 0-pre puts there. If the directory gets crowded later (it won't — we have two files), reorganize then.

## Shipping plan

Build order, each step shippable independently:

1. **Write the generic verification prompt** — one file, one afternoon
2. **Add the `@include` to serious-plan** — plan is the highest-value handoff (research→plan drops are the most common pain point)
3. **Run it on three real artifacts** — if extraction fails, fix the upstream template
4. **Roll to remaining transitions** — conversation→research, plan→code

Don't build the `--skip-verify` or `--strict` flags until someone actually needs them. YAGNI.
