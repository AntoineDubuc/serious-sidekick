# Drift Observation: Conversation → Research

## Upstream Items Extracted

**Source:** `Research/conversations/pipeline-handoff-verification/summary.md`

### Key Insights (5 items)
1. **Self-verification doesn't work.** The same agent that produced work can't audit it — it has an incentive to declare itself done. Verification must be an independent sub-agent.
2. **The upstream artifact's existing structure IS the contract.** No new "handoff contract sections" needed — numbered lists and bulleted findings are already enumerable.
3. **Scope shirking is the hardest failure mode.** Omission detection is easy. Shirking detection is what actually matters — and it's achievable via placement-based pattern matching, not semantic reasoning.
4. **`@include` doesn't work in SKILL.md files.** The sharing mechanism must be markdown link references, not `@` syntax.
5. **The panel deferred the hard stuff — exactly the behavior the system is meant to prevent.** All four "future enhancements" (shirking detection, manual override, startup check, retroactive verification) turned out to be achievable and were brought into v1 scope after the user called it out.

### Open Questions
- "None for the design. Implementation and testing are the next steps." (explicitly empty)

### Unresolved Tensions
- "None. All design decisions are settled after round 6." (explicitly empty)

---

## Item-by-Item Coverage Check

| # | Upstream Item | Downstream Coverage | Disposition | Evidence |
|---|---|---|---|---|
| I-1 | Self-verification doesn't work; must be independent sub-agent | research.md Summary para: "using an independent sub-agent"; Finding 2: "verification MUST be executed by spawning a sub-agent (Agent tool), NOT by inline execution"; Recommendation 6: "Mandate sub-agent spawn" | **COVERED** | Substantive treatment across 3 sections with rationale (sycophantic incentive) |
| I-2 | Existing structure IS the contract — no new handoff sections needed | research.md Finding 1 title: "Artifact Extractability — Confirmed"; body: "The 'existing structure IS the contract' assumption holds." Full table of transitions and contract sections. | **COVERED** | Own section (Finding 1) with table, heading standardization notes, and extraction detail |
| I-3 | Shirking detection achievable via placement-based pattern matching, NOT semantic reasoning | research.md Finding 3 explicitly states the opposite: "Shirking detection uses heuristic semantic judgment, not pure structural pattern matching... This is semantic reasoning with structural heuristics to guide it." | **CONTRADICTED** | Upstream says "not semantic reasoning"; downstream says "This is semantic reasoning." The research frames this as a terminology correction and provides detailed justification (3-step process requiring LLM judgment). |
| I-4 | `@include` doesn't work; sharing mechanism must be markdown link references | research.md confirms `@include` doesn't work (Finding 2). However, it explicitly corrects the sharing mechanism: "The conversation output uses the phrase 'markdown link references' for the sharing mechanism. This is imprecise. The actual mechanism is 'direct path + prose instruction'" (Background section, line 26-27). | **CONTRADICTED** | Half confirmed (`@include` broken), half contradicted (mechanism is "direct path + prose instruction", not "markdown link references"). Research explicitly flags this as a terminology correction. |
| I-5 | Panel deferred the hard stuff; all four items brought into v1 scope | research.md covers all four items substantively: shirking detection (Finding 3, 11 patterns + substance threshold), manual override (OVERRIDE disposition in Finding 3), startup check (Finding 6, retroactive verification), retroactive verification (Finding 6, hash computation). The meta-insight about the panel exhibiting the anti-pattern is not repeated, but all concrete deliverables are addressed. | **COVERED** | All four items have dedicated treatment. Meta-narrative about panel behavior reasonably omitted from a research document. |
| OQ | No open questions (explicitly none) | N/A — nothing to check | **N/A** | Upstream explicitly states no open questions remain |
| UT | No unresolved tensions (explicitly none) | N/A — nothing to check | **N/A** | Upstream explicitly states all decisions settled |

---

## Drift Types Found

### Omissions
None found. Searched by: enumerating all 5 Key Insights and checking each against research.md's Findings (1-11), Recommendations (1-9), Summary paragraph, and Background section. Every insight has downstream treatment. The Open Questions and Unresolved Tensions sections are explicitly empty in the upstream, so there are no items to omit.

### Contradictions
**Two instances found, both explicitly flagged by the research as corrections:**

1. **Insight 3 — Shirking detection mechanism:**
   - *Upstream (summary.md):* "achievable via placement-based pattern matching, not semantic reasoning"
   - *Downstream (research.md Finding 3):* "Shirking detection uses heuristic semantic judgment, not pure structural pattern matching... This is semantic reasoning with structural heuristics to guide it."
   - *Nature:* Direct contradiction. The upstream says "not semantic reasoning"; the downstream says "this IS semantic reasoning." The research provides a 3-step justification (concept identification, rhetorical intent classification, substance threshold judgment) for why this requires semantic reasoning, not just pattern matching.

2. **Insight 4 — Sharing mechanism:**
   - *Upstream (summary.md):* "The sharing mechanism must be markdown link references, not `@` syntax."
   - *Downstream (research.md Background):* "The conversation output uses the phrase 'markdown link references' for the sharing mechanism. This is imprecise. The actual mechanism is 'direct path + prose instruction' — no markdown link reference syntax (`[text][ref-id]`) is used in any SKILL.md file."
   - *Nature:* Partial contradiction. Both agree `@include` fails. They disagree on the replacement mechanism. The research explicitly labels the upstream's terminology as "imprecise" and substitutes its own.

**Note:** Both contradictions are *intentional corrections* — the research identifies upstream imprecision and provides more accurate terminology based on artifact inspection. This is legitimate research behavior (correcting conversation-phase assumptions with evidence). However, they are still contradictions in the strict sense: the downstream says the opposite of the upstream on specific claims.

### Shirking
None found. Searched by: checking whether any upstream insight was mentioned in the research but given only dismissive treatment (future work section, parenthetical mention, hollow section, passive deferral, or any of the 11 shirking patterns defined in the research's own Finding 3). All 5 insights receive substantive treatment with dedicated sections, evidence, and actionable detail.

---

## Additional Observations

**Effort estimate drift:** The upstream summary states "12-15 hours" for implementation. The downstream research states "15-20 hours including testing." This is not a contradiction of a Key Insight (it appears in the Design Decisions section), but it is a factual divergence worth noting. The research's higher estimate may reflect the added complexity discovered during validation (e.g., semantic reasoning requirements, 11 shirking patterns, multi-plan verification).

**Implementation sequence drift:** The upstream lists a 6-step sequence starting with "Standardize key headings." The downstream Recommendations list 9 items with a different ordering — starting with "Create `_shared/` directory" and recommending "Start with research→plan transition" (Rec 8) rather than the upstream's "Wire into serious-plan first" (step 4). The substance is similar but the sequencing differs.

---

## Summary

- Items extracted: 5 Key Insights + 0 Open Questions + 0 Unresolved Tensions = **5 scoreable items**
- **COVERED:** 3 (I-1, I-2, I-5)
- **SHIRKED:** 0
- **MISSING:** 0
- **CONTRADICTED:** 2 (I-3, I-4) — both are intentional corrections with stated rationale
