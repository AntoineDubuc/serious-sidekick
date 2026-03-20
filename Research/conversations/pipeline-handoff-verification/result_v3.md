# Round 3 — Pipeline Handoff Verification

## What the panel said

### The Architect
Upstream structure IS the contract — most skills already output numbered lists. The only intervention is ensuring templates use numbered lists for key claims. Deferrals must be tagged inline with the upstream item ID and rationale: `[DEFERRED: insight-3 — reason]`. Verifier should emit a structured manifest (each item → `covered`/`deferred`/`missing`/`contradicted`) with a human-readable summary on top. The manifest makes the verifier itself auditable.

### The Pragmatist
Agrees the existing structure is the contract — no new format work. Deferrals: downstream skill states the deferral and reason inline, verifier flags anything neither addressed nor deferred. Output: flat numbered list, three statuses (addressed/deferred/missing), pass/fail verdict. No finding IDs, no severity, no suggested actions. Shippable in an afternoon.

### The Skeptic
Concedes the reframe mostly works — upstream numbered lists are extractable. But raises a boundary: verification catches downstream drops (research ignoring conversation findings), not upstream drops (conversation summary itself being incomplete). We should be honest about that limit. On deferrals: any skill-controlled deferral is a loophole. Deferrals should surface as a distinct category that **blocks until the user explicitly acknowledges each one.** On output: the verifier must show what it looked for (the extracted checklist), not just what it found — otherwise the denominator could be wrong.

### The DX Advocate
Agrees existing structure works with one tweak: **standardize heading names and require lists not prose** under them. A formatting guideline, not restructuring. Deferrals: `[DEFERRED: reason]` inline marker — one convention, zero infrastructure. Output: numbered checklist mapping upstream items to downstream status + location. Missing items get finding IDs. Scannable in 15 seconds.

## Where they agree
- **Existing artifact structure serves as the contract.** No new "contract sections" needed. Numbered insights, bulleted findings, open questions — already enumerable.
- **Deferrals must be explicit and inline.** No silent deferral. Some form of `[DEFERRED: reason]` marker in the downstream artifact.
- **Verifier output is a checklist mapping.** Upstream item → status → downstream location.
- **The verifier is the easy part.** Everyone agrees this is an afternoon of work for the prompt. The format standardization is minor.

## Where they disagree
- **Deferral authority:** The Pragmatist says the verifier makes the gap visible and the user decides when they see the output. The Skeptic says deferrals must actively block until user acknowledgment — making them visible isn't enough because the user might not look. The Architect and DX Advocate are in between (tagged deferrals pass the gate but are logged).
- **Output verbosity:** The Pragmatist wants the bare minimum (three statuses, pass/fail). The Architect wants a structured manifest underneath. The DX Advocate wants finding IDs and location references. The Skeptic insists on showing the extracted checklist (the denominator) alongside the mapping.
- **Boundary honesty:** The Skeptic is alone in flagging that this system can't catch upstream drops — if the conversation summary itself was incomplete, the verifier has nothing to compare against. Others haven't addressed this.

## Synthesis

The panel has reached near-consensus on the design. Here's the emerging solution:

### The Design (Settled)
1. **Shared verification prompt** — one `@include` file, referenced by all downstream skills
2. **Independent sub-agent** — runs automatically when the downstream skill finishes its primary output
3. **Contract = existing structure** — the verifier extracts enumerable items from the upstream artifact's existing numbered lists and bulleted sections
4. **Deferral convention** — `[DEFERRED: reason]` inline marker. No marker = gap = finding.
5. **Blocking by default** — with `--skip-verify` escape hatch that logs the override

### The Output (Converging)
The Pragmatist's simplicity and the Skeptic's transparency can coexist. The verifier outputs:

```
## Upstream Traceability Check
Source: Research/features/auth/research.md (8 findings)

1. Token rotation policy → ✅ Covered (plan §2.3)
2. Session invalidation  → ✅ Covered (plan §1.1)
3. Refresh token scope   → ⚠️ DEFERRED: "out of scope per user" (plan §4 note)
4. Rate limiting         → ❌ MISSING — not addressed, not deferred
5. Key storage           → ✅ Covered (plan §3.2)
...

Verdict: FAIL — 1 missing, 1 deferred
```

This satisfies everyone: the Pragmatist gets a simple list. The Architect gets structured data. The DX Advocate gets finding IDs and locations. The Skeptic gets the denominator (8 findings extracted, all visible).

### The Remaining Tension: Deferrals
The Skeptic's point is sharp: if `[DEFERRED: reason]` passes the gate automatically, we've built an official channel for shirking. The Pragmatist says visibility is enough — the user sees the deferral in the output and can object.

**Proposed resolution:** Deferrals pass the gate but appear as warnings, not passes. The verdict distinguishes between "PASS (all covered)" and "PASS WITH DEFERRALS (N items deferred — review recommended)." This makes deferrals visible without blocking the pipeline, while keeping the user in the loop. If the user wants stricter control, `--strict` mode could treat deferrals as failures.

### The Boundary (Acknowledged)
The Skeptic is right that this system catches downstream drift, not upstream incompleteness. If the conversation summary was itself incomplete, the verifier can't know. This is an honest limitation — the system verifies fidelity between artifacts, not completeness of the original capture. Worth documenting, not worth solving (it's a different problem).

## Open questions
- Should the formatting guideline (standardized headings, lists not prose) be enforced now, or only when a skill's output proves too unstructured for extraction?
- Does the verifier need handoff-specific knowledge (what conversation→research fidelity looks like vs. research→plan fidelity), or is one generic prompt enough?
- How does this interact with the Phase 0-pre `@include` discussion — should both shared prompts live in the same `_shared/` directory?
