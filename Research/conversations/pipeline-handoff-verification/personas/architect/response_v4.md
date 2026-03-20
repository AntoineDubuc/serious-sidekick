# The Architect — Round 4

## Answering the Open Questions Through the Lens of Composability

**Generic prompt vs. handoff-specific knowledge:** One generic prompt. Here's why: the verifier's job is structural — extract enumerable items from artifact A, check for their presence or deferral in artifact B. That algorithm is identical whether A is a conversation result or a research notebook. The content is different; the extraction pattern is not. If we build five transition-specific prompts, we're coupling the verifier to the internal format of each skill, which means every template change in any skill requires a corresponding verifier update. That's a maintenance surface area problem. One prompt, parameterized by the upstream artifact path, is the right abstraction boundary.

**Heading standardization — now.** Not because it's urgent, but because it costs five minutes per template and prevents the verifier from needing fuzzy extraction heuristics. A verifier that works "most of the time" is worse than no verifier — it trains users to distrust or ignore it. Standardized headings (`## Key Insights`, `## Findings`, `## Open Questions`) make extraction deterministic. Do it before the verifier ships, not after it fails.

**Coexistence with Phase 0-pre:** Same `_shared/` directory, different files. `_shared/phase-0-pre.md` and `_shared/handoff-verifier.md`. They serve different lifecycle moments — Phase 0-pre runs at skill startup, the verifier runs at skill completion — so they never conflict. One directory, clear naming, no ambiguity about where shared prompts live.

**Implementation sequence:** (1) Standardize headings in templates. (2) Write the generic verifier prompt. (3) Wire it into one transition (research→plan) as proof of concept. (4) Roll to all transitions once validated. Don't parallelize steps 2 and 3 — the prompt needs to exist before you can test it.
