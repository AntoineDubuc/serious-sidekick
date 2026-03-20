# Round 4 — Pipeline Handoff Verification

## What the panel said

### The Architect
One generic prompt — the extraction pattern is identical across all transitions. Coupling the verifier to each skill's internal format creates a maintenance surface area problem. Standardize headings now (5 min per template) — a verifier that works "most of the time" trains users to ignore it. Shared prompts go in `_shared/` alongside Phase 0-pre: `_shared/phase-0-pre.md` and `_shared/handoff-verifier.md`. Implementation: standardize headings → write prompt → wire into research→plan → roll to all transitions.

### The Pragmatist
One generic prompt, same `_shared/` directory — agrees on both. Disagrees on heading standardization: do it later, only when extraction actually fails. Concrete 4-step shipping plan: (1) write prompt, (2) add `@include` to serious-plan (highest-value handoff), (3) test on 3 real artifacts, (4) roll to remaining transitions. Don't build `--skip-verify` or `--strict` until someone needs them.

### The Skeptic
Mostly agrees on one prompt, but raises a nuance: conversation→research is **semantic** matching (insight could be addressed under a completely different name), while research→plan is **structural** (finding either has a plan section or doesn't). A generic prompt may hallucinate matches on semantic transitions. Wants transition-specific extraction hints — even just one line like "match by meaning" vs "match by reference." Standardize headings now. New failure mode raised: **verifier confidence** — the verifier is an LLM doing semantic matching, it will be wrong sometimes. Proposes `[VERIFIED: manual override]` marker for when the user disagrees.

### The DX Advocate
One generic prompt — showing the extracted checklist (the denominator) is what keeps it honest. If extraction is wrong, the user sees it immediately. Standardize headings now — not for the verifier, but for the user's ability to debug bad extractions. Focused on failure path UX: when verifier says FAIL, the user needs 3 things in under 10 seconds: (1) what's missing, (2) where to fix it, (3) how to re-run. Proposed adding one line at the end: "Fix the gaps in [path], then re-run `/serious-[skill]`."

## Where they agree
- **One generic verification prompt** — unanimous. Don't build per-transition prompts.
- **Same `_shared/` directory** — unanimous. `handoff-verifier.md` next to `phase-0-pre.md`.
- **Implementation starts with research→plan** — unanimous. Highest-value handoff, worst pain point.
- **Show the extracted checklist in output** — unanimous. The denominator is visible so the user can catch bad extractions.

## Where they disagree
- **Heading standardization timing:** Architect + Skeptic + DX Advocate say now (3-1 majority). Pragmatist says later. The majority argument is stronger — 5 minutes of work removes an entire failure class on first use.
- **Semantic vs. structural matching:** The Skeptic raises a real nuance — early pipeline transitions are meaning-based, later ones are reference-based. Everyone else says one prompt handles both. The Skeptic's compromise (one prompt with a hint line) is lightweight enough to adopt.
- **Verifier error handling:** The Skeptic introduces `[VERIFIED: manual override]` for when the user disagrees with the verifier. Nobody else has addressed this. Worth considering but may be premature.

## Synthesis

**The design is complete.** All open questions from round 3 are answered. Here's the full picture:

### Architecture
| Decision | Answer |
|---|---|
| Where verification lives | Shared `@include` file at `.claude/skills/_shared/handoff-verifier.md` |
| Who runs it | Independent sub-agent (not the skill that produced the work) |
| When it runs | Automatically, after the downstream skill writes its primary output |
| Generic or per-transition | One generic prompt (with optional hint line for semantic vs. structural matching) |
| Shared prompt location | `.claude/skills/_shared/` alongside `phase-0-pre.md` |
| Blocking behavior | Blocking by default, `--skip-verify` escape hatch (logged) |

### Contract Mechanism
| Decision | Answer |
|---|---|
| What serves as the contract | Upstream artifact's existing numbered lists and bulleted sections |
| Heading standardization | Now — standardize 3-4 key headings per skill template |
| Deferral convention | `[DEFERRED: reason]` inline marker in downstream artifact |
| Deferral verdict | "PASS WITH DEFERRALS" — passes gate but appears as warning |

### Verifier Output Format
```
## Upstream Traceability Check
Source: Research/features/auth/research.md
Extracted items: 8

1. Token rotation policy     → ✅ Covered (plan §2.3)
2. Session invalidation      → ✅ Covered (plan §1.1)
3. Refresh token scope       → ⚠️ DEFERRED: "out of scope per user" (plan §4)
4. Rate limiting             → ❌ MISSING — not addressed, not deferred
5. Key storage               → ✅ Covered (plan §3.2)
6. Audit logging             → ✅ Covered (plan §2.5)
7. Token lifetime policy     → ✅ Covered (plan §2.1)
8. Revocation endpoint       → ✅ Covered (plan §3.4)

Verdict: FAIL — 1 missing, 1 deferred (review recommended)
Fix gaps in Research/features/auth/implementation_plan.md, then re-run /serious-plan.
```

### Implementation Sequence
1. Standardize key headings in skill output templates (conversation summary, research findings, plan tasks)
2. Write `.claude/skills/_shared/handoff-verifier.md` — one generic prompt
3. Add `@include` to `serious-plan` (research→plan, highest-value handoff)
4. Test on 3 real artifacts — validate extraction accuracy
5. Roll to remaining transitions (conversation→research, plan→code)
6. Add `--skip-verify` and `--strict` flags only if needed

### Known Limitations (Documented)
- Catches downstream drift, not upstream incompleteness (if the conversation summary itself was incomplete, the verifier can't know)
- Verifier is an LLM doing semantic matching — will occasionally be wrong in both directions
- The extracted checklist (shown in output) is the user's safeguard against bad extraction

## Open questions
- The Skeptic's `[VERIFIED: manual override]` marker — worth building now or wait until false positives become a real friction point?
- Should the verifier also check for contradictions (downstream says the opposite of upstream), or is omission-detection enough for v1?
- How does this interact with serious-code's existing completion gate — do they complement or overlap?
