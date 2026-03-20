---
skill: serious-research
slug: pipeline-handoff-verification
status: done
parent: Research/conversations/pipeline-handoff-verification
created: 2026-03-19
classification: Feature
scope: Codebase only
mode: Quick
---

# Pipeline Handoff Verification

## Summary

Every handoff in the serious-* pipeline suffers from drift — downstream skills silently drop, shirk, or contradict upstream work. This research validates a design for automatic upstream traceability verification at each handoff, using an independent sub-agent that extracts enumerable items from the upstream artifact, checks each one's disposition in the downstream output, and blocks on gaps.

Key validated findings: (1) All skill output artifacts have extractable enumerable sections — the "existing structure IS the contract" assumption holds. (2) The sharing mechanism for SKILL.md files is "direct path + prose instruction" (not `@include` or markdown link references). (3) Shirking detection uses heuristic semantic judgment — not pure pattern matching — and must be treated as a classifier with a non-zero false-negative rate. (4) Verification MUST run as a sub-agent spawn, not inline execution, to preserve independence.

The system has five dispositions (COVERED, DEFERRED, SHIRKED, MISSING, OVERRIDE), two operational modes (extract at startup, verify at completion), and retroactive verification via frontmatter hash stamps. Estimated implementation: 15-20 hours including testing.

## Background

Every handoff in the serious-* workflow pipeline (conversation→research, research→plan, plan→code) suffers from drift: the downstream skill silently drops, contradicts, or defers work from its upstream artifact. The user currently must manually invoke /loop to fix divergence. A /serious-conversation session (Research/conversations/pipeline-handoff-verification/) produced a complete design over 6 rounds. This research validates that design against real artifacts and fills in implementation specifics.

**Terminology correction:** The conversation output uses the phrase "markdown link references" for the sharing mechanism. This is imprecise. The actual mechanism is "direct path + prose instruction" — no markdown link reference syntax (`[text][ref-id]`) is used in any SKILL.md file. This research uses the correct terminology throughout.

## Findings

### 1. Artifact Extractability — Confirmed

Every skill in the pipeline produces output with enumerable sections. The "existing structure IS the contract" assumption holds.

**Handoff contracts by transition:**

| Transition | Upstream Artifact | Contract Sections | Format |
|---|---|---|---|
| conversation → research | `summary.md` | Key insights, Unresolved tensions, Open questions | Bulleted lists (3-5 items each) |
| research → mock-ups | `research.md` | Findings (subsections), Recommendations | Numbered subsections + bulleted list |
| research → plan | `research.md` | Findings (subsections), Recommendations | Numbered subsections + bulleted list |
| mock-ups → plan | `mock-up-summary.md` | Component Inventory, Design Decisions | Tables (each row = one item) |
| plan → code | `implementation_plan.md` | Master Checklist, Acceptance criteria per task | Table rows + `- [ ]` checkbox lists |

**Mock-ups → plan extraction detail:** Both the Component Inventory table and the Design Decisions table are extracted. Each table row becomes one verifiable item. Screen Flow Summary and Responsive Notes are NOT extracted (they inform layout, not feature coverage).

**Heading standardization needed:**
- research.md `## Findings` can be prose or subsections — must require numbered subsections (`### Finding 1: [title]`)
- conversation `summary.md` is already well-structured (bulleted lists under standard headings)
- Plan template already uses highly structured formats (tables, checkboxes)

### 2. SKILL.md Sharing Mechanism — Resolved

`@include` / `@file` syntax does NOT work in SKILL.md files. The actual mechanism is **direct path + prose instruction** — the same pattern serious-plan uses to reference `_implementation_plan_template_v6.md`.

**The established pattern** (from serious-plan SKILL.md):
```
./_implementation_plan_template_v6.md
```
Followed by: **"Read this file before generating any plan."**

**The verifier reference in each downstream SKILL.md:**

```
.claude/skills/_shared/handoff-verifier.md
```

**Read this file and spawn a verification sub-agent as described within. Pass these parameters:**
- **Upstream artifact:** {path to the upstream artifact this skill consumed}
- **Downstream artifact:** {path to this skill's primary output}
- **Match strategy:** semantic | structural | exact

**Important: The verification MUST be executed by spawning a sub-agent (Agent tool), NOT by inline execution.** The same Claude session that produced the downstream artifact has a sycophantic incentive to declare its own work complete. A sub-agent gets a fresh context without this bias.

**The `_shared/` directory:** This directory (`.claude/skills/_shared/`) does not currently exist and must be created. Files in `_shared/` must NOT have `user-invocable: true` frontmatter — they are internal shared prompts, not slash commands. Claude Code's skill auto-discovery may scan this directory; the verifier file should use frontmatter that prevents it from appearing as a user command:

```yaml
---
name: handoff-verifier
description: Internal — upstream traceability verification protocol
user-invocable: false
---
```

### 3. Shirking Detection Patterns

The verifier must distinguish five dispositions. The key innovation is SHIRKED — detecting items that are mentioned but not given substantive treatment.

**Important framing:** Shirking detection uses **heuristic semantic judgment**, not pure structural pattern matching. Every pattern requires the LLM to (1) identify that text refers to the same concept as an upstream item, (2) classify the rhetorical intent of surrounding prose, and (3) judge whether a substance threshold is met. This is semantic reasoning with structural heuristics to guide it. PASS verdicts have a non-zero false-negative rate. The extracted checklist shown in output is the user's primary safeguard.

**Dismissive placement patterns (SHIRKED if no `[DEFERRED]` marker):**

| Pattern | Example text | Why it's shirking |
|---|---|---|
| Future work section | "We'll address rate limiting in a future iteration" | Acknowledges the item, does nothing |
| Out of scope dump | "Token rotation is out of scope for this phase" | Boundary-drawing without user consent |
| Nice-to-have downgrade | "Rate limiting would be a nice-to-have enhancement" | Priority laundering |
| Parenthetical mention | "...security measures (including rate limiting) could be added later" | Buried acknowledgment |
| Passive deferral | "Rate limiting is deferred to Phase 2" | Sounds like a plan but isn't one |
| Hollow section | "### Rate Limiting\nWe will implement rate limiting." | Heading exists, no substance |

**LLM-specific shirking patterns (common in AI-generated output):**

| Pattern | Example text | Why it's shirking |
|---|---|---|
| Abstraction escalation | "This should be handled by a configurable policy layer" | Sounds substantive, produces no implementation |
| Conditional coverage | "If rate limiting is needed, the system supports it via middleware" | Conditionalizes the item's existence |
| Complexity acknowledgment | "Rate limiting is a complex topic that requires careful consideration of..." | Acknowledges complexity without any artifact |
| Reference pass-through | "See the rate limiting documentation for implementation details" | Cites a source that does not exist |
| Delegation to future skill | "Rate limiting will be addressed during /serious-code" | Pushes to later pipeline stage without a plan |

**Minimum substance threshold:** An item is COVERED only if its section contains at least TWO of the following signals:
1. A concrete action item or task (not a restatement of the requirement)
2. A design decision with rationale (not just naming a technology)
3. Acceptance criteria (checkbox items)
4. A code reference (file path, function name, line number)
5. A data model or schema definition

**Substance examples:**

| Text | Signals present | Verdict |
|---|---|---|
| "### Rate Limiting\nImplement token bucket algorithm using Redis. Store per-user counters with 60s TTL.\n- [ ] 100 req/min per API key\n- [ ] 429 response with Retry-After header" | Design decision (token bucket + Redis) + code reference (Redis, TTL) + acceptance criteria (2 checkboxes) = 3 signals | ✅ COVERED |
| "### Rate Limiting\nImplement rate limiting using Redis." | Design decision (Redis) but no rationale, no AC, no code ref = 1 signal | 🚫 SHIRKED (below threshold) |
| "### Rate Limiting\nWe will implement rate limiting to protect the API." | Restatement of requirement = 0 signals | 🚫 SHIRKED (hollow section) |
| "Rate limiting is tracked in the security review (see §5.2).\n- [ ] Verify rate limits match API gateway config" | Code reference (§5.2) + acceptance criterion = 2 signals | ✅ COVERED |

**Interaction with markers:**
- Item in dismissive placement WITH `[DEFERRED: reason]` → DEFERRED (legitimate)
- Item in dismissive placement WITHOUT marker → SHIRKED
- Item with `[VERIFIED: override — reason]` → OVERRIDE (user asserts it's handled)

### 4. Frontmatter Changes

**New fields for downstream artifacts (added on successful verification):**

```yaml
verified: 2026-03-19
verified_source: Research/features/auth/research.md
verified_hash: a3b2c1d4
```

- `verified`: Date verification passed
- `verified_source`: Path to the upstream artifact that was verified against
- `verified_hash`: First 8 chars of SHA-256 hash of the upstream artifact's **extractable sections only** (not the full file)

**Hash computation rules:**
1. Read the upstream artifact
2. Extract only the contract sections (e.g., `## Key Insights`, `## Findings`, `## Recommendations` — the sections the verifier checks)
3. Normalize: strip leading/trailing whitespace per line, normalize line endings to LF
4. Compute SHA-256 of the normalized extracted content
5. Store first 8 characters

This makes the hash insensitive to: frontmatter changes, reference section updates, formatting adjustments, and editor-added trailing newlines. Only changes to the actual contract content trigger re-verification.

**The `source` field** (added to all downstream skill output templates):

```yaml
source: Research/features/auth/research.md
```

**Who populates it:** The downstream skill itself, during its output generation. Each skill already knows which upstream artifact it consumed (it reads it during execution). The SKILL.md instruction specifies: "Set the `source` field in your output frontmatter to the path of the upstream artifact you consumed. If no upstream artifact exists (e.g., plan created from verbal description), leave `source` empty."

When `source` is empty, retroactive verification is skipped (no upstream to verify against).

### 5. Verifier Prompt Design — Two Modes

The verifier lives at `.claude/skills/_shared/handoff-verifier.md` and operates in two modes.

**Extract mode (runs at startup, Phase 0):**
1. Read the upstream artifact at the provided path
2. Extract all enumerable items from contract sections (bulleted lists, numbered findings, table rows, checkbox items)
3. Output: "Found N items from M sections in [path]. Proceeding."
4. Sanity check: if a section has 5 bullet points but extraction found 3, flag it
5. If no structured items found: warn "Upstream artifact at [path] has no extractable items. Verification may be unreliable."
6. Write extracted items to `_extracted_items.md` in the downstream artifact's folder (survives context compaction, inspectable by user)

**Verify mode (runs at completion, as a SUB-AGENT):**
1. Read `_extracted_items.md` (or re-extract if not available)
2. For each item, search the downstream artifact using the match strategy:
   - `semantic`: match by meaning, not by title (conversation → research)
   - `structural`: match by explicit section or reference (research → plan, mock-ups → plan)
   - `exact`: match by literal criterion text (plan → code)
3. For each match found, analyze placement and substance
4. Assign disposition: COVERED / DEFERRED / SHIRKED / MISSING / OVERRIDE
5. Output the traceability checklist with per-item confidence (high/medium/low)
6. Apply verdict rules: PASS / PASS WITH DEFERRALS / FAIL
7. On PASS: stamp frontmatter with `verified`, `verified_source`, `verified_hash`
8. On FAIL: output actionable message with specific gaps, override syntax, and re-run instruction
9. Log full output to `_traceability_check.md` in the downstream artifact's folder

**The match strategy is passed as a parameter by the calling skill**, not inferred. Each SKILL.md specifies which strategy to use when invoking the verifier.

**Upstream incompleteness warning** (appended to every verifier output):
> "This check verifies downstream coverage of upstream items. It does NOT verify that the upstream artifact is complete. If the upstream artifact missed important items, this check will not catch the gap."

### 6. Retroactive Verification Logic

When a downstream skill starts (during Phase 0):
1. Read the artifact's frontmatter for `verified` and `source` fields
2. If `source` is empty: skip (no upstream to verify against)
3. If `verified` is missing: this artifact was never verified → run extract + verify before proceeding
4. If `verified` is present: compute current hash of `verified_source` file's extractable sections → compare with `verified_hash`
5. If hash mismatch: upstream was edited after verification → re-verify
6. If match: skip, already verified

**Depth limit:** Verify only the immediate upstream. If the entire chain needs verification, the user should run a dedicated verification sweep, not a recursive chain at skill startup.

### 7. Multi-Plan Verification

When serious-plan produces multiple plans (`phase_map.md` + `plans/01_*.md`, `plans/02_*.md`):

1. **Verify the phase map** against the upstream research — the phase map's executive summary and task allocation must account for all upstream findings
2. **Verify each individual plan** against the subset of items assigned to it in the phase map
3. Each plan gets its own `verified` stamp independently
4. If an upstream item is split across multiple plans, each plan must cover its assigned portion — the verifier checks the phase map's allocation to determine which items belong to which plan

The verifier's output for multi-plan shows:
```
## Upstream Traceability Check (Multi-Plan)
Source: Research/features/auth/research.md
Extracted items: 8

Phase Map Allocation:
- Plan 01 (auth-core): items 1, 2, 5, 7
- Plan 02 (auth-security): items 3, 4, 6, 8

Plan 01 Verification:
1. Token rotation     → ✅ Covered (plan 01 §2.3)
2. Session invalidation → ✅ Covered (plan 01 §1.1)
...

Plan 02 Verification:
3. Refresh token scope → ✅ Covered (plan 02 §1.2)
...
```

### 8. Complete Verifier Output Format

```
## Upstream Traceability Check
Source: Research/features/auth/research.md
Extracted items: 8 (from 3 sections)

1. Token rotation policy     → ✅ Covered [high] (plan §2.3 — 3 acceptance criteria defined)
2. Session invalidation      → ✅ Covered [high] (plan §1.1 — design decision + implementation task)
3. Refresh token scope       → ⚠️ DEFERRED: "out of scope per user" (plan §4 note)
4. Rate limiting             → 🚫 SHIRKED [high] — mentioned in "Future Considerations" without [DEFERRED] marker
5. Key storage               → ✅ Covered [high] (plan §3.2 — schema definition + migration task)
6. Audit logging             → ❌ MISSING — not addressed, not deferred
7. Token lifetime policy     → ✅ Covered [medium] (plan §2.1 — configuration task + test criteria)
8. Revocation endpoint       → ✅ Override (plan §3.4) [VERIFIED: override — handled via existing middleware]

Verdict: FAIL — 1 shirked, 1 missing, 1 deferred (review recommended)
Fix gaps in Research/features/auth/implementation_plan.md, then re-run /serious-plan.
To override a finding, add [VERIFIED: override — reason] next to the item.

⚠️ This check verifies downstream coverage of upstream items. It does NOT verify
that the upstream artifact is complete.
```

Confidence indicators: `[high]` = strong structural match with multiple substance signals. `[medium]` = semantic match or single substance signal. `[low]` = weak match, may be false positive.

### 9. Transition-Specific Extraction Rules

One generic verifier handles all transitions. The calling skill passes the match strategy as a parameter.

| Transition | Extraction source | Match strategy | Passed by |
|---|---|---|---|
| conversation → research | `summary.md` Key insights + Open questions | `semantic` | serious-research SKILL.md |
| research → plan | `research.md` Findings + Recommendations | `structural` | serious-plan SKILL.md |
| mock-ups → plan | `mock-up-summary.md` Component Inventory + Design Decisions | `structural` | serious-plan SKILL.md |
| plan → code | `implementation_plan.md` Acceptance criteria | `exact` | serious-code SKILL.md |

**Worked examples for ambiguous cases** (included in the verifier prompt):

**Semantic match (conversation → research):**
- Upstream: "Users distrust silent token rotation" → Downstream research finding titled "Token Transparency Requirements" that discusses user notification → ✅ COVERED (same concept, different title)
- Upstream: "Consider WebSocket support" → Downstream has "## Future Considerations: WebSocket" with no findings → 🚫 SHIRKED

**Structural match (research → plan):**
- Upstream: "Finding 3: Rate limiting required at API gateway" → Plan has "Task 4: Implement API Rate Limiting" with 3 acceptance criteria → ✅ COVERED
- Upstream: "Finding 3: Rate limiting required at API gateway" → Plan mentions rate limiting in "Related concerns we considered" table → 🚫 SHIRKED (dismissive placement)

**Exact match (plan → code):**
- Upstream: "- [ ] 100 req/min per API key" → Test file has `test('enforces 100 req/min limit per API key')` → ✅ COVERED
- Upstream: "- [ ] 100 req/min per API key" → No corresponding test → ❌ MISSING

### 10. Cost and Operational Considerations

**Token cost per verification (estimated):**

| Transition | Upstream size | Downstream size | Verifier overhead | Total |
|---|---|---|---|---|
| conversation → research | ~1,500 tokens | ~3,000 tokens | ~1,000 tokens | ~5,500 tokens |
| research → plan | ~3,000 tokens | ~8,000 tokens | ~1,000 tokens | ~12,000 tokens |
| plan → code | ~8,000 tokens | N/A (checks tests exist) | ~1,000 tokens | ~9,000 tokens |

For a full pipeline run with 4 handoffs: ~35,000-55,000 additional tokens. At current Opus pricing, this is roughly $0.30-$0.50 per pipeline run. Wall-clock time: 30-90 seconds per verification sub-agent, totaling 2-6 minutes of verification overhead.

**Context window guard:** If extracted items exceed 20, the verifier should chunk into batches of 10 and aggregate results.

### 11. Feedback Loop and Logging

Every verifier run logs its full output to `_traceability_check.md` in the downstream artifact's folder. If the user fixes gaps and re-runs, the previous log is renamed `_traceability_check_v1.md` (versioned).

**Post-implementation feedback:** After the verifier has been used on 5+ real workflows, review the logs to measure:
- False-positive rate (items flagged SHIRKED/MISSING that were actually covered)
- False-negative rate (items marked COVERED that were later found to be shirked — harder to measure, requires user reporting)
- Extraction accuracy (were the right items extracted? Were any missed?)

This data is used to tune the verifier prompt and adjust the substance threshold.

## Recommendations

1. **Create `.claude/skills/_shared/` directory** and write `handoff-verifier.md` with both modes, all 11 shirking patterns, worked examples, and the output format defined above.

2. **Standardize headings** in research.md output template: require `### Finding N: [title]` format for all findings. Conversation summary.md and plan template are already well-structured.

3. **Add the verifier instruction block** to serious-research, serious-plan, and serious-code SKILL.md files. Each block specifies the upstream path, downstream path, and match strategy.

4. **Add `source` field** to the frontmatter specs of research.md, implementation_plan.md, and execution_log.md output templates. The downstream skill populates it during output generation.

5. **Wire extract-mode into Phase 0** for serious-plan first (highest-value handoff, most common pain point). Test on 3+ real artifacts before rolling to other transitions.

6. **Mandate sub-agent spawn** in the verifier instruction block — not inline execution. The instruction must say "Spawn a verification sub-agent using the Agent tool."

7. **Build versioned logging** from day one — `_traceability_check.md` with version numbering on re-runs.

8. **Start with research→plan transition**, then roll to conversation→research and plan→code after validating extraction accuracy and false-positive rates.

9. **Do not claim the verifier eliminates manual review.** Frame it as "catches the most common drift patterns and makes gaps visible" — not as a guarantee. The extracted checklist is the user's primary safeguard against verifier errors.

## References
- Conversation output: Research/conversations/pipeline-handoff-verification/
- Final design: Research/conversations/pipeline-handoff-verification/result_v6.md
- Implementation plan template: ./_implementation_plan_template_v6.md
- Skill files: .claude/skills/serious-{conversation,research,plan,code,mock-ups}/SKILL.md
- Senior Engineer review: Research/features/pipeline-handoff-verification/review_senior_engineer.md
- Devil's Advocate review: Research/features/pipeline-handoff-verification/review_devils_advocate.md
