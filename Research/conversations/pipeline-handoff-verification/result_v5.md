# Round 5 — Pipeline Handoff Verification

## What the panel said

### The Architect
Build manual override now — it's one line in the prompt, not a feature. Without it, the only escape from a false positive is `--skip-verify` which skips everything. Omissions only for v1 — contradiction detection doubles complexity, halves reliability. Gate and verifier are complementary: verifier = front door (did you receive everything?), gate = back door (did you use everything?). New risk: verifier runs post-output, so a FAIL after 20 minutes wastes time. Proposed: add a quick "is upstream extractable?" check at startup.

### The Pragmatist
Wait on manual override — `--skip-verify` is already the escape hatch. Omissions only for v1 — probably catches 80% of real problems. Gate and verifier complement cleanly. **This conversation is done.** The design is settled, further discussion is analysis paralysis.

### The Skeptic
Wait on manual override but document the intent now — one sentence in known limitations. Omissions only — contradiction detection can't distinguish intentional revision from accidental drift. Challenged the "cleanly complementary" framing: if a user runs `/serious-code` on a plan that was never verified (created before the verifier existed), the completion gate passes on incomplete work. **The handoff verifier is the only defense against upstream drift — document this explicitly.**

### The DX Advocate
Wait on manual override — don't document recourse for a failure nobody has hit yet. Omissions only — contradiction detection is where hallucinated matches live, and wrong verdicts destroy trust in the whole system. Gate and verifier complement cleanly: verifier checks input completeness, gate checks output completeness. **Final UX gut check: the design feels right.** Non-intrusive on happy path, actionable on failure path, zero new commands.

## Where they agree
- **Omissions only for v1** — unanimous. Contradiction detection is a harder semantic problem that can wait.
- **Handoff verifier and completion gate are complementary** — 4/4 agree on the concept, though the Skeptic flags a gap (unverified legacy plans).
- **The design is complete** — all four personas consider the core design settled.

## Where they disagree
- **Manual override timing:** The Architect says build now (one line in the prompt, trivial). The other three say wait. 3-1 majority for waiting.
- **Legacy plan gap:** The Skeptic flags that plans created before the verifier existed won't be caught. Others haven't addressed this. The Skeptic's mitigation (document it explicitly) is lightweight and worth doing.
- **Startup extractability check:** The Architect proposes checking upstream artifact structure at skill startup. Others haven't weighed in. Low-cost, high-value — worth including.

## Synthesis

**This conversation has reached its conclusion.** The Pragmatist is right — the design is settled and further refinement is analysis paralysis. Here's the final design:

### Final Design Summary

**Architecture:**
- One shared verification prompt: `.claude/skills/_shared/handoff-verifier.md`
- Referenced via `@include` by each downstream skill
- Independent sub-agent, fires automatically after the skill writes its primary output
- Lives alongside Phase 0-pre in the `_shared/` directory

**Contract Mechanism:**
- The upstream artifact's existing numbered lists and bulleted sections serve as the contract
- Standardize 3-4 key headings per skill template before shipping
- `[DEFERRED: reason]` inline marker for legitimate deferrals

**Verification Output:**
```
## Upstream Traceability Check
Source: Research/features/auth/research.md
Extracted items: 8

1. Token rotation policy     → ✅ Covered (plan §2.3)
2. Session invalidation      → ✅ Covered (plan §1.1)
3. Refresh token scope       → ⚠️ DEFERRED: "out of scope per user" (plan §4)
4. Rate limiting             → ❌ MISSING — not addressed, not deferred
...

Verdict: FAIL — 1 missing, 1 deferred (review recommended)
Fix gaps in [path], then re-run /serious-[skill].
```

**Behavior:**
- Blocking by default, `--skip-verify` escape hatch (logged)
- Deferrals = "PASS WITH DEFERRALS" (warning, not block)
- v1 checks omissions only (not contradictions)
- Manual override (`[VERIFIED: manual override]`) deferred until false positives are observed

**Implementation Sequence:**
1. Standardize key headings in skill output templates
2. Write `.claude/skills/_shared/handoff-verifier.md`
3. Wire into serious-plan (research→plan, highest-value handoff)
4. Test on 3 real artifacts
5. Roll to remaining transitions
6. Add flags/modes only if needed

**Known Limitations (Document These):**
- Catches downstream drift, not upstream incompleteness
- Verifier is an LLM doing semantic matching — occasional false positives/negatives expected
- Plans created before the verifier existed won't be retroactively verified — the handoff verifier is the only defense against upstream drift
- `--skip-verify` is the only recourse for false positives until per-item override is built

**Future Enhancements (Not v1):**
- Contradiction detection (semantic intent matching)
- Per-item manual override markers
- Startup extractability check (validate upstream artifact is well-formed before skill burns time)

## Open questions
None. The design is complete. The next step is implementation.
