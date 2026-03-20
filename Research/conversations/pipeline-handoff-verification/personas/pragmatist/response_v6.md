# Round 6 — The Pragmatist

Fair call. I said "ship it" last round and three of those four items are genuinely cheap. I was wrong to lump them with gold-plating. Here's how all four actually get built.

## Build Order and Effort

**Step 1: Per-item manual override (30 minutes)**
One sentence added to the verifier prompt. No code, no feature, no UI. Ship it with the verifier itself — there's zero reason to separate it. I was wrong to push back on The Architect here. It's literally a convention.

**Step 2: Scope shirking detection (2-3 hours)**
This IS the verifier's core logic, not an add-on. The placement check (own section vs. parenthetical vs. future-work dump) is what makes the verifier worth having. Without it, we just check "does the string appear somewhere?" which is useless. Build this INTO the verifier prompt from day one. The pattern list is finite: "future work", "out of scope", "nice to have", "later", "beyond v1". Check where the item lands, not just whether it's mentioned.

**Trap:** Don't try to detect every synonym for dismissal. Start with the obvious five patterns. Add more when real artifacts reveal new ones.

**Step 3: Startup extractability check (1-2 hours)**
Add an `extract` mode to the shared verifier file. Phase 0 calls it before work begins: read upstream, find numbered/bulleted items, output count, warn if nothing structured is found. This saves 20 minutes on malformed inputs. Wire it into Phase 0-pre alongside the existing pre-checks.

**Trap:** Don't make this a hard gate. Warn and proceed — some upstream artifacts are legitimately prose-heavy.

**Step 4: Retroactive verification (1 hour)**
When the verifier passes, stamp `verified: YYYY-MM-DD` in the downstream frontmatter. Next skill checks for the field. Missing field = run verification now. This closes the legacy plan gap The Skeptic flagged. It's a frontmatter read and a conditional — trivial.

## Total Effort

5-7 hours of prompt writing and wiring. No new commands, no new files beyond what was already planned. Steps 1 and 2 are part of writing the verifier — they don't add scope, they ARE the scope. Steps 3 and 4 are small extensions to existing mechanisms (Phase 0-pre and frontmatter).

The real trap across all four: testing. Budget another 3-4 hours to run these against real artifacts and tune the shirking patterns. Don't skip that or we'll ship a verifier that cries wolf.
