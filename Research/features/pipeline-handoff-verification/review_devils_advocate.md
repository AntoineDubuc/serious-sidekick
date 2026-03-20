# Devil's Advocate Review: Pipeline Handoff Verification

**Reviewer:** Devil's Advocate persona
**Date:** 2026-03-19
**Files reviewed:** research.md, notebook.md, result_v6.md, summary.md, SKILL.md files for serious-plan and serious-research

---

## Verdict: The design has a sound core idea — independent verification of handoffs — but it is hiding fundamental difficulties behind confident language. Several assumptions will not survive contact with real execution. The biggest risk is that the verifier itself is an LLM doing the exact kind of semantic reasoning the design claims to avoid, and nothing in the system verifies the verifier.

---

## 1. Accuracy — Where Assumptions Will Not Hold

### 1a. "Placement-based pattern matching, not semantic reasoning" is a fiction

The conversation summary (Key Insight #3) states: *"Shirking detection is achievable via placement-based pattern matching, not semantic reasoning."*

This is the central claim, and it is wrong.

Consider the shirking pattern table in research.md Finding #3. Every single pattern — "future work," "out of scope," "nice-to-have," "parenthetical mention," "passive deferral," "hollow section" — requires the LLM to:

1. **Identify** that a sentence in the downstream artifact refers to the same concept as an upstream item (semantic matching)
2. **Classify** the rhetorical intent of the surrounding prose (is "We will implement rate limiting in the next sprint" a plan or a deferral?)
3. **Judge** whether the substance threshold is met (does the section contain "a concrete action item" — which requires understanding what constitutes "concrete")

None of this is pattern matching. It is semantic reasoning wearing a structural hat. The phrases in the pattern table are examples, not an exhaustive grammar. The LLM will encounter formulations not in the table — "Rate limiting considerations are captured in the security review" — and must reason about whether that constitutes coverage. That is the definition of semantic reasoning.

**Why this matters:** The design presents itself as more reliable than it is. If you tell users "this catches shirking via structural patterns," they will trust PASS verdicts they should not trust. Call it what it is: heuristic semantic judgment with known false-negative rates.

**Action item:** Remove the claim that this is "not semantic reasoning." Replace with: "The verifier uses heuristic checks that reduce but do not eliminate the need for human review. PASS verdicts have a false-negative rate that should be assumed non-zero."

### 1b. The "minimum substance threshold" is not operationalizable

Research.md says an item is COVERED only if its section contains at least one of:
- A concrete action item or task
- A design decision with rationale
- Acceptance criteria
- A code reference
- A data model or schema definition

Who decides what constitutes a "concrete action item"? The LLM. "Implement rate limiting using Redis" — is that concrete? It names a technology. But there is no acceptance criterion, no file path, no task decomposition. The threshold is vague enough that the verifier LLM will apply it inconsistently across runs. Nondeterminism is inherent — the same artifact verified twice may get different dispositions.

**Action item:** Define the threshold as a conjunction, not a disjunction. Require at least TWO of the five signals, or require one signal PLUS a minimum word/sentence count in the section. Test this on 10+ real sections and document the false-positive and false-negative rates.

### 1c. "Read and execute the handoff verification protocol at [path]" — Claude may not

The sharing mechanism (Finding #2) depends on Claude reading a secondary file mid-execution when it hits a prose instruction in the SKILL.md. This works in practice when:
- Context is not near capacity
- The instruction is prominent and unambiguous
- The model does not decide the verification step is optional

But the instruction is at the END of the skill execution ("Before marking this skill complete..."). By that point, the context window may be 80-90% full from the skill's own work. Claude frequently abbreviates late-stage instructions when context pressure is high. The verification step is the one most likely to be skipped, shortened, or half-executed — precisely because it runs at the exhaustion point of the session.

**Action item:** Measure how often the verifier step is actually executed when serious-plan runs on a moderately complex input (5+ tasks, 20+ acceptance criteria). If skip rate exceeds 10%, the design needs a hook-based enforcement mechanism rather than a prose instruction.

---

## 2. Completeness — Missing Failure Modes

### 2a. No handling for verifier errors

The design accounts for five dispositions of upstream items. It does not account for:

- **False COVERED:** The verifier says an item is covered when it is not. This is the most dangerous failure because the user trusts PASS and moves forward.
- **False SHIRKED:** The verifier flags an item as shirked when it is genuinely covered under different terminology. This wastes the user's time and erodes trust.
- **Extraction errors:** The verifier extracts 6 items from an upstream artifact that actually contains 9. The three missed items are never checked.
- **Hallucinated items:** The verifier "extracts" an item that does not exist in the upstream artifact. This wastes time and confuses the user.

The design says "Extracted checklist shown in output so user can catch bad extractions." That is the ONLY mitigation for ALL four failure modes. It shifts the burden back to the user — the same user this system is supposed to protect from manual checking.

**Action item:** Add a verification count sanity check. After extraction, output "Extracted N items from M sections" and cross-reference with section headers. If a section has 5 bullet points but extraction found 3, flag it. For false-COVERED risk, add a confidence indicator per item (high/medium/low) based on how strong the structural match was, so users know where to focus their spot-checks.

### 2b. No handling for the verifier gaming itself

The conversation summary (Key Insight #1) says: *"Self-verification doesn't work. The same agent that produced work can't audit it."*

But the design then proposes that the verification prompt is READ AND EXECUTED by the same Claude session that just produced the downstream artifact. It is not a separate API call. It is not a separate session. It is the same context window, with the same completion incentives. The "independent sub-agent" language in result_v6.md is aspirational — the actual implementation described in research.md Finding #2 is a prose instruction in the SKILL.md that Claude reads and executes inline.

If the verifier is spawned as a genuine sub-agent (via the Agent tool with `subagent_type`), it gets a fresh context. If it is executed inline as a continuation of the skill, it has the same sycophantic incentive to declare its own work complete. The research does not specify which execution mode is used, and the implementation description ("Read and execute the upstream traceability verification protocol") sounds like inline execution.

**Action item:** Explicitly specify that the verification MUST be a sub-agent spawn (Agent tool), not inline execution. Add this as a non-negotiable constraint in the handoff-verifier.md prompt. Test to confirm that Claude actually spawns it as a sub-agent rather than interpreting the protocol inline.

### 2c. No cost or latency analysis

The design adds a sub-agent at every handoff. For a 5-skill pipeline (conversation -> research -> mock-ups -> plan -> code), that is at minimum 4 extraction calls + 4 verification calls = 8 additional LLM invocations per pipeline run. Each reads two full artifacts.

For a moderately complex project:
- research.md: 2,000-5,000 tokens
- implementation_plan.md: 5,000-15,000 tokens
- The verifier prompt itself: ~1,000 tokens

Each verification call consumes 8,000-21,000 input tokens plus output. At 8 calls per pipeline, that is 64,000-168,000 additional tokens per pipeline run — $0.50-$2.00+ at current Opus pricing. More importantly, each sub-agent call adds 30-90 seconds of wall-clock time. Eight calls = 4-12 minutes of verification overhead per pipeline.

Is that acceptable? The design never asks the question.

**Action item:** Add estimated token cost and latency per transition type. Consider a "verify only the highest-risk handoff" mode for cost-sensitive users. The plan->code handoff is where drift hurts most; maybe verify that one strictly and make the others optional.

### 2d. Context window limits when reading two large artifacts

The verifier must read both the upstream and downstream artifacts in full to do its job. A research.md (2,000-5,000 tokens) compared against an implementation_plan.md (5,000-15,000 tokens) is manageable. But what about:

- A conversation result_v6.md (which can be 3,000+ tokens) + a research.md (5,000+ tokens)?
- A deep-mode research with synthesis.md (could be 10,000+ tokens) + a multi-plan phase_map.md + individual plans?
- An implementation_plan.md (15,000 tokens) being verified against by a code execution agent that has already consumed 80% of its context?

The design assumes the verifier always has enough context to read both artifacts and reason about each item. For large artifacts, this may not hold — especially if the verifier is a sub-agent that also receives the verification prompt (another 1,000+ tokens).

**Action item:** Define maximum artifact sizes that the verifier can reliably handle. For artifacts that exceed the limit, define a chunking strategy or a "verify top-N most critical items" fallback.

---

## 3. Depth — Is Shirking Detection Really Achievable?

### 3a. The pattern table is an optimistic sample

The six shirking patterns in research.md Finding #3 are all clear-cut cases where a reasonable human would agree the item is being shirked. Real artifacts will contain:

- **Genuine partial coverage:** "Rate limiting is handled at the API gateway level (see infrastructure plan)" — is this COVERED (because there is a concrete reference) or SHIRKED (because the plan does not actually contain the referenced infrastructure plan)?
- **Cross-reference coverage:** "See Task 3 for rate limiting implementation" — is this COVERED? What if Task 3 exists but its acceptance criteria do not mention rate limiting?
- **Implicit coverage:** The upstream says "handle authentication errors gracefully." The downstream has a section on error handling that covers 401, 403, and 500 responses but never uses the word "authentication." Is it COVERED?

The design's match strategy table (Finding #8) acknowledges this by splitting into "semantic" vs "structural" matching. But it provides no definition of what "semantic match" means in the verifier prompt, or how the LLM should handle ambiguous cases. "Match by meaning, not by title" is an instruction that gives the LLM maximum latitude — and maximum inconsistency.

**Action item:** For each transition type, provide 3-5 worked examples in the verifier prompt showing ambiguous cases and the correct disposition. Without examples, the LLM will apply its own judgment inconsistently.

### 3b. No ground truth for calibration

The design estimates 12-15 hours of implementation but allocates only 3-4 hours for "test on 3 real artifacts, tune shirking patterns." Three artifacts is not enough to calibrate a system with five disposition categories across four transition types.

To establish reliability, you need:
- At least 5 artifacts per transition type = 20 test cases
- Each test case hand-labeled with expected dispositions per item
- The verifier run on each test case
- Agreement rate computed (verifier vs human label)
- False-positive and false-negative rates per disposition

Without this calibration, the design is shipping a system with unknown accuracy. The 3-artifact test plan will catch obvious prompt bugs but will not reveal systematic biases (e.g., the verifier being too lenient on hollow sections, or too aggressive on cross-references).

**Action item:** Expand test plan to 15-20 real artifacts with hand-labeled ground truth. Define acceptable accuracy thresholds (e.g., >85% agreement with human labels). If the threshold is not met, the system needs human-in-the-loop confirmation before PASS verdicts are trusted.

---

## 4. Blind Spots

### 4a. The verifier cannot catch upstream incompleteness

The design acknowledges this ("Catches downstream drift, not upstream incompleteness"). But it underestimates the impact. If the upstream conversation produced a summary.md that missed a critical insight from the discussion, the research skill will be verified against an incomplete contract. PASS will be stamped. The gap propagates silently through the entire pipeline.

This is not a limitation to note in passing — it is a class of failure that the system structurally cannot prevent. The verification is only as good as the upstream artifact's completeness, and there is no mechanism to validate that.

**Action item:** At minimum, add a warning to the verifier output: "This check verifies downstream coverage of upstream items. It does NOT verify that the upstream artifact is complete. If the upstream artifact missed important items, this check will not catch the gap." Make this warning prominent, not buried.

### 4b. Hash-based retroactive verification is fragile

The design proposes hashing the upstream artifact at verification time and comparing later. But:

- Whitespace changes, comment additions, or frontmatter updates to the upstream artifact will change the hash, triggering unnecessary re-verification.
- The hash is of the full file content, not the extractable items. Adding a "References" entry to research.md invalidates the hash even though no findings changed.
- If the upstream is edited to ADD items (not change existing ones), re-verification will correctly catch the new items. But if the upstream is edited to REMOVE items, the new verification will simply not check them — the removal is invisible.

**Action item:** Hash only the extractable sections (Findings, Recommendations, Key Insights, etc.), not the full file. For removed-item detection, store the extracted item list alongside the hash and compare item counts on re-verification.

### 4c. The [DEFERRED] and [OVERRIDE] markers create a bypass highway

Any skill (or the user) can add `[DEFERRED: reason]` to an item and it passes the gate with a warning. Any user can add `[VERIFIED: override -- reason]` and it counts as covered. The design requires a reason string, but there is no validation that the reason is substantive. `[DEFERRED: later]` and `[VERIFIED: override -- it's fine]` are both syntactically valid.

Over time, users under deadline pressure will learn that slapping `[DEFERRED: TBD]` on shirked items makes the gate pass. The verifier becomes a rubber stamp.

**Action item:** Consider limiting the number of DEFERRED items per artifact (e.g., max 3 without user confirmation). Track DEFERRED items across pipeline runs and surface "items deferred more than once" as a distinct warning.

### 4d. No consideration of multi-plan verification complexity

The design describes verification for single-plan handoffs. But serious-plan can produce MULTIPLE plans with a phase_map.md. In this case:

- Which plan gets verified against the upstream research? All of them individually? The phase map?
- If research Finding #3 is addressed in plan 02 but not plan 01, is plan 01 failing? Or is the verification supposed to be against the union of all plans?
- If the verifier runs per-plan, it will flag items as MISSING that are covered by a sibling plan. If it runs against the union, it needs to read all plans simultaneously — a much larger context requirement.

The research does not address this at all.

**Action item:** Define multi-plan verification strategy explicitly. Recommended approach: verify the phase_map.md + all plan executive summaries against the upstream, then verify each plan individually against the tasks assigned to it in the phase map.

---

## 5. The Single Biggest Risk

**The verifier is an LLM doing semantic classification, and there is no ground truth, no accuracy measurement, and no feedback loop.**

The design will be implemented. It will produce PASS and FAIL verdicts. Users will trust those verdicts. But no one will know the false-negative rate (items wrongly classified as COVERED). The system has no mechanism to learn from its mistakes because:

1. There is no labeled test set to measure accuracy against.
2. There is no feedback mechanism for users to report incorrect verdicts.
3. There is no logging of verifier decisions for later audit.
4. There is no A/B comparison between verifier output and human judgment.

The most likely failure mode is not spectacular failure (FAIL when it should PASS) — it is quiet false PASSes where the verifier declares items covered that are not, and the user skips their own review because the tool said it was fine. This is worse than having no verifier at all, because it replaces an imperfect human check with an imperfect automated check that the human no longer performs.

**Action item:** Before rolling this to all transitions, build the feedback loop:
1. Log every verifier run's full output to a `verification_log.md` in the research folder.
2. After implementation (when the user sees real results), prompt: "Were any items in the traceability check misclassified? (Y/N)."
3. Use accumulated feedback to tune the verifier prompt.
4. Define a launch gate: the verifier must achieve >85% agreement with human labels on a test set of 15+ artifacts before it is trusted to PASS without human review.

Without this, you are shipping an untested classifier and calling it a safety mechanism.

---

## Summary of Action Items

| # | Item | Priority | Effort |
|---|------|----------|--------|
| 1 | Remove "not semantic reasoning" claim; reframe as heuristic with known false-negative rates | High | 15 min |
| 2 | Tighten substance threshold to conjunction (2+ signals required) | High | 1 hr |
| 3 | Measure skip rate when verifier runs as late-stage prose instruction | High | 2-3 hrs |
| 4 | Add extraction count sanity check and per-item confidence indicators | Medium | 1-2 hrs |
| 5 | Mandate sub-agent spawn (not inline execution) for verification | Critical | 30 min |
| 6 | Add cost/latency analysis per transition type | Medium | 1 hr |
| 7 | Define maximum artifact sizes and chunking fallback | Medium | 1 hr |
| 8 | Add worked examples (3-5 per transition) to verifier prompt | High | 3-4 hrs |
| 9 | Expand test plan to 15-20 artifacts with ground truth labels | High | 4-6 hrs |
| 10 | Add upstream incompleteness warning to verifier output | Low | 15 min |
| 11 | Hash extractable sections only, store item list for removal detection | Medium | 1-2 hrs |
| 12 | Limit DEFERRED items and track cross-run deferral patterns | Low | 1-2 hrs |
| 13 | Define multi-plan verification strategy | High | 2-3 hrs |
| 14 | Build feedback loop: logging, user feedback prompt, launch gate | Critical | 3-4 hrs |

**Total additional effort if all items addressed:** ~20-30 hours — roughly doubling the current 12-15 hour estimate. The critical and high-priority items alone add ~15 hours.

---

## Final Note

The conversation that produced this design (round 6 specifically) was born from the user calling out the panel for deferring the hard problems. The irony is that the research then validated the design without applying the same adversarial pressure to its own assumptions. The research confirms extractability (true), confirms sharing mechanisms (true), and defines shirking patterns (partially true) — but never tests the core question: **does the verifier actually produce correct classifications on real artifacts?** That question remains unanswered, and it is the only question that matters.
