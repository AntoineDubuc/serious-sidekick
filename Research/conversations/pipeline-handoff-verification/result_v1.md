# Round 1 — Pipeline Handoff Verification

## What the panel said

### The Architect
Verification is a boundary enforcement problem. It must be a **pipeline middleware** — a separate component that sits between skill transitions, not inside them. Input: upstream + downstream artifacts. Output: pass/fail + specific divergence list. Skills shouldn't even know it exists. One middleware component beats N copies of verification logic embedded in each skill. The serious-code QA agent proves the sub-agent model works — generalize it.

### The Pragmatist
Stop designing, start copying. The serious-code completion gate already works. Paste that pattern into each downstream SKILL.md as a final phase. No new infrastructure, no hooks, no middleware layer — just a prompt block per skill that spawns a verifier sub-agent. Start with research and plan (the two worst offenders). Don't make it blocking until you prove it catches real problems. An afternoon of work.

### The Skeptic
Three challenges: (1) A sub-agent verifier shares the same model biases — is it truly "independent" or just a second chance to rubber-stamp? Has anyone measured the serious-code gate's false-negative rate? (2) Upstream artifacts are freeform text, not machine-checkable contracts — if the verifier is "comparing vibes to vibes," it feels rigorous without being rigorous. (3) Automating verification risks false security — the user stops manually checking, and the failure mode shifts from "annoying but caught" to "silent and compounding."

### The DX Advocate
Silent failure is the worst DX anti-pattern. Three requirements: (1) Error output must be specific and actionable — "Plan omitted research finding R3 (token rotation)" not "verification failed." (2) Happy path must be frictionless — one line: "12/12 findings covered." (3) The gate must be mandatory by default, not opt-in. Generalize the serious-code completion gate, invest in error messages.

## Where they agree
- Self-verification doesn't work. The verifier must be a separate agent from the one that produced the work.
- The serious-code completion gate is the proven pattern to build from.
- The solution must be automatic — the user shouldn't have to remember to trigger it.

## Where they disagree
- **Architecture:** The Architect wants one centralized middleware component. The Pragmatist wants the verification embedded in each skill's SKILL.md. Different maintenance tradeoffs.
- **Blocking vs. warning:** The Pragmatist says start with warnings, make blocking later. The DX Advocate says mandatory from day one — opt-in verification won't get used.
- **Feasibility:** The Skeptic questions whether a sub-agent can meaningfully verify freeform prose artifacts, and whether automating this creates false confidence. The others assume the capability is proven.

## Synthesis
The panel converges on the mechanism (independent sub-agent verification at handoffs) but splits on three design decisions:

1. **Where does verification live?** Middleware (one component) vs. embedded (per-skill). The Architect's middleware is cleaner but adds a new architectural layer. The Pragmatist's embedded approach is faster to ship but creates another DRY problem. There may be a middle ground: a shared verification prompt (like the Phase 0-pre discussion) that each skill references via `@include`, giving you one source of truth without a new architectural concept.

2. **Blocking or advisory?** The Pragmatist's caution is reasonable — trust but verify the verifier first. But the DX Advocate's point is sharp: if it's not blocking, the user will ignore it, and we're back to square one. A possible hybrid: blocking by default, with an explicit `--skip-verify` flag that logs the override.

3. **Can freeform verification work?** The Skeptic's challenge is the deepest. If upstream artifacts don't have enumerable claims, the verifier is doing fuzzy comparison. This might mean the fix isn't just adding a verifier — it might also require upstream skills to produce structured "handoff contracts" (numbered findings, explicit scope declarations) that make verification checkable.

## Open questions
- Has the serious-code completion gate actually caught real omissions? What's the evidence?
- Should upstream artifacts change to include structured "handoff contracts" or should the verifier work against freeform prose?
- Is the `@include` shared-prompt approach viable for keeping verification logic DRY?
- What does "deferred" look like as a valid vs. invalid disposition? Sometimes deferral IS the right call — who decides?
