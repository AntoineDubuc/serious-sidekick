# Round 2 — Pipeline Handoff Verification

## What the panel said

### The Architect
Dropped the centralized middleware position. Now advocates for **`@include` shared verification prompt** — one file referenced by all skills. But the bigger shift: the verifier is the easy part. The hard part is making upstream artifacts verifiable. Each skill's output must end with a **structured handoff contract** — numbered claims, explicit scope, declared deferrals. The fix is bidirectional. Blocking by default with `--skip-verify`.

### The Pragmatist
Conceded the DRY problem — accepts `@include` shared prompt. Holds firm against everything else. No structured contracts ("you're asking the skill that drops things to produce the checklist of things it might drop"). No blocking until false-positive rate is measured. Instead: have the verifier enumerate what it found and let the user eyeball it. Ship advisory mode this week, flip to blocking after two workflows.

### The Skeptic
Called out the group for converging too fast. The architecture question (where it lives) is settled — but the capability question (does it actually work?) is unanswered. Nobody provided evidence from the serious-code gate. Structured contracts are circular — if the skill can't be complete, it can't produce a complete checklist either. **Concrete proposal:** run the gate retroactively against three known-bad workflows before generalizing anything.

### The DX Advocate
Sided with `@include` as the shipping mechanism. Sided with the Architect and Skeptic on structured handoff contracts as non-negotiable — "verifying vibes against vibes is theater." Held firm on blocking by default, actionable errors with finding IDs. Added a new point: middleware wins on **debuggability** — when verification itself breaks, one address beats five scattered copies.

## Where they agree
- **`@include` shared verification prompt** — unanimous. One file, referenced by all downstream skills. Single source of truth, no new infrastructure.
- **Independent sub-agent** — still unanimous. Not self-verification.
- **The verifier itself is the easy part** — everyone agrees the prompt is straightforward to write.

## Where they disagree
- **Structured handoff contracts:** Architect + DX Advocate say non-negotiable. Pragmatist says too much work, have the verifier enumerate instead. Skeptic says they're circular — the skill that drops things can't produce a reliable checklist.
- **Blocking vs. advisory:** DX Advocate + Architect say blocking from day one. Pragmatist says advisory first, measure, then flip. Skeptic wants evidence before either.
- **Evidence first:** The Skeptic is alone in demanding retroactive testing before any implementation. Everyone else wants to build and iterate.

## Synthesis

The panel has converged on the mechanism and the architecture. The remaining tension is about **trust and sequencing**:

**Settled decisions:**
- `@include` shared verification prompt (one file, all skills reference it)
- Independent sub-agent verifier (not self-check)
- Automatic at every handoff (not opt-in)

**The Skeptic's circularity problem is the key unsolved tension.** The Architect and DX Advocate want upstream skills to emit structured contracts. The Pragmatist and Skeptic both push back — but for different reasons. The Pragmatist says it's unnecessary work. The Skeptic says it's logically impossible: you can't trust the skill that omits things to produce a complete list of what it should include.

There's a potential resolution: **the contract comes from the upstream artifact's structure, not from the downstream skill.** If a conversation summary has "Key Insights: 1, 2, 3, 4, 5" and "Open Questions: A, B, C" — those are already enumerable. The verifier's job becomes: "research must address insights 1-5 and questions A-C." The upstream skill doesn't need a new "contract section" — its existing structure IS the contract, as long as it uses numbered/bulleted lists for its key outputs.

This reframes the work: instead of adding contract sections to upstream skills, ensure upstream skills already output their findings in enumerable form (which most already do), and teach the verifier to extract the checklist from existing structure.

**On blocking vs. advisory:** The Pragmatist's concern about false positives is legitimate — a verifier that blocks on wrong calls will get ripped out. But the DX Advocate's point that advisory mode gets ignored is equally sharp. The hybrid is: **blocking by default, `--skip-verify` logs the override, and the first two workflows get extra scrutiny on whether the verifier is catching real problems.**

## Open questions
- Does the existing structure of upstream artifacts (numbered insights, bulleted findings) provide enough enumerable surface for verification, or do the formats need to change?
- Should the verifier extract the checklist itself (more fragile, less work) or should each skill's summary section be standardized (more robust, more work)?
- What's the right disposition for legitimate deferrals? Sometimes "defer to later" IS correct — the verifier needs a way to distinguish "deferred with rationale and user consent" from "silently shirked."
