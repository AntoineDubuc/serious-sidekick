---
name: handoff-verifier
description: Internal — upstream traceability verification protocol
user-invocable: false
---

# Handoff Verifier — Upstream Traceability Verification Protocol

This file is the **single source of truth** for all handoff verification in the serious-* workflow pipeline. Every downstream skill references this file. Changes here propagate everywhere.

**Non-negotiable constraint:** Verification MUST be executed by spawning a sub-agent via the **Agent tool** — NOT by inline execution. The same Claude session that produced the downstream artifact has a sycophantic incentive to declare its own work complete. A sub-agent gets a fresh context without this bias. Any skill that invokes this verifier inline instead of spawning a sub-agent is in violation of this protocol.

---

## Calling Skills Must Enforce

This verifier **reports** — it does not enforce. The calling skill is responsible for gating on the result. Every skill that invokes this verifier MUST:

1. **Extract-mode (Phase 0):** Block Phase 1 until `_extracted_items.md` exists in the output folder. If an upstream artifact is specified and extraction fails or produces 0 items from a non-empty source, STOP — do not proceed.
2. **Verify-mode (Completion):** Block presentation/handoff until verification returns PASS or PASS WITH DEFERRALS. On FAIL: fix gaps, re-run verifier, repeat. Do NOT present, set `status: done`, or remove breadcrumbs until PASS.
3. **Use the inventory during generation.** Cross-reference `_extracted_items.md` while producing the downstream artifact. Every extracted item must appear as a task, finding, acceptance criterion, or explicit `[DEFERRED: reason]`. Do not rely on memory of the upstream — use the file.

Skills that treat these steps as advisory will produce drift. The 2026-03-22 "summary enrichment" incident (4 design decisions dropped from a 6-round, 36-item conversation) was caused by Phase 0d extraction being skipped entirely.

---

## Parameters

The calling skill passes three parameters when invoking this verifier:

| Parameter | Type | Description |
|-----------|------|-------------|
| `upstream_artifact` | string (path) | Path to the upstream artifact to verify against |
| `downstream_artifact` | string (path) | Path to this skill's primary output |
| `match_strategy` | enum | One of: `semantic`, `structural`, `exact` |

### Match Strategy Parameter Spec

The `match_strategy` determines how upstream items are matched to downstream coverage. The calling skill selects the strategy — the verifier does not infer it.

| Strategy | When used | Matching behavior |
|----------|-----------|-------------------|
| `semantic` | conversation → research | Match by meaning, not by title. An upstream insight "Users distrust silent token rotation" matches a downstream finding titled "Token Transparency Requirements" if the finding discusses the same concept. Requires semantic judgment — titles, synonyms, and rephrased concepts all count. |
| `structural` | research → scope, research → plan, scope → plan, research → mock-ups, mock-ups → plan | Match by explicit section reference or named task. An upstream finding "Rate limiting required at API gateway" must appear as a dedicated task, section, or table row in the downstream artifact — not buried in prose or parenthetical mentions. |
| `exact` | plan → code | Match by literal criterion text. An upstream acceptance criterion `- [ ] 100 req/min per API key` must have a corresponding test, implementation, or explicit code artifact. Paraphrasing alone is insufficient — the specific requirement must be traceable. |

---

## Contract Sections by Transition

The verifier extracts items only from designated contract sections, not the full file.

| Transition | Upstream Artifact | Contract Sections | Format |
|------------|-------------------|-------------------|--------|
| conversation → research | `summary.md` | Key insights, Unresolved tensions, Open questions | Bulleted lists |
| research → mock-ups | `research.md` | Findings (subsections), Recommendations | Numbered subsections + bulleted list |
| research → scope | `research.md` | Findings (subsections), Recommendations | Numbered subsections + bulleted list |
| research → plan | `research.md` | Findings (subsections), Recommendations | Numbered subsections + bulleted list |
| scope → plan | `manifest.md` | Plans (the specific `### Plan N:` subsection) | Bulleted list fields (Boundary, Dependencies, Shared contracts, Tags) |
| mock-ups → plan | `mock-up-summary.md` | Component Inventory, Design Decisions | Tables (each row = one item) |
| plan → code | `implementation_plan.md` | Master Checklist, Acceptance criteria per task | Table rows + `- [ ]` checkbox lists |

---

## Mode 1: Extract Mode (Phase 0 — Startup)

Extract mode runs at the beginning of the downstream skill, during Phase 0, to prepare the upstream item inventory.

**Steps:**

1. Read the upstream artifact at the provided `upstream_artifact` path.
2. Identify the transition type from the contract sections table above.
3. Extract all enumerable items from the designated contract sections:
   - Bulleted list items (each `- ` or `* ` line = one item)
   - Numbered subsections (each `### Finding N: [title]` = one item)
   - Table rows (each non-header row = one item)
   - Checkbox items (each `- [ ]` or `- [x]` line = one item)
4. Sanity-check: compare the extraction count against visible bullet/item counts in each section. If a section has 5 bullet points but extraction found 3, flag the discrepancy: "Warning: section [name] has 5 visible items but only 3 were extracted. Review extraction accuracy."
5. Output: **"Found N items from M sections in [path]. Proceeding."**
6. If no structured items are found: warn "Upstream artifact at [path] has no extractable items. Verification may be unreliable." — do NOT block.
7. Write extracted items to `_extracted_items.md` in the downstream artifact's folder. This file survives context compaction and is inspectable by the user.

**Empty-section handling:** If a contract section exists but contains no items (e.g., "## Unresolved tensions: None" or "## Open questions\n\nNone identified."), extract 0 items from that section. Do NOT issue a warning for intentionally empty sections — 0 items is a valid extraction result.

**`_extracted_items.md` format:**

```markdown
# Extracted Upstream Items
Source: {upstream_artifact path}
Extracted: {date}
Total items: {N}

## From: {section name}
1. {item text}
2. {item text}
...

## From: {section name}
3. {item text}
...
```

---

## Mode 2: Verify Mode (Completion — Sub-Agent)

Verify mode runs at the end of the downstream skill, after the skill has produced its output. **This mode MUST be executed by spawning a sub-agent via the Agent tool.** Inline execution is forbidden.

**Steps:**

1. Read `_extracted_items.md` from the downstream artifact's folder. If not available, re-extract from the upstream artifact.
2. For each extracted item, search the downstream artifact using the passed `match_strategy`.
3. For each match found, analyze placement and substance (see Shirking Detection and Substance Threshold below).
4. Check for contradiction (see Contradiction Detection below).
5. Assign a disposition to each item: COVERED, DEFERRED, SHIRKED, MISSING, OVERRIDE, or CONTRADICTED.
6. Assign a confidence level to each item: `[high]`, `[medium]`, or `[low]`.
7. Output the traceability checklist (see Output Format below).
8. Apply verdict rules (see Verdict Rules below).
9. On PASS or PASS WITH DEFERRALS: stamp the downstream artifact's frontmatter with `verified`, `verified_source`, `verified_hash`.
10. Log the full output to `_traceability_check.md` in the downstream artifact's folder.
11. If a previous `_traceability_check.md` exists, rename it to `_traceability_check_v{N}.md` before writing the new one (where N is the next available version number, starting at 1).

**Confidence indicators:**
- `[high]` — strong structural match with multiple substance signals
- `[medium]` — semantic match or single substance signal above threshold
- `[low]` — weak match, may be false positive; user should review

### Context Window Guard

If extracted items exceed 20, chunk into batches of 10 and process each batch independently. Aggregate all batch results into a single output checklist and single verdict. The output should note: "Processed in {N} batches of up to 10 items each."

---

## Shirking Detection

Shirking detection uses **heuristic semantic judgment** — not pure structural pattern matching. Every pattern requires the LLM to (1) identify that text refers to the same concept as an upstream item, (2) classify the rhetorical intent of surrounding prose, and (3) judge whether a substance threshold is met. This is semantic reasoning guided by structural heuristics.

**Critical framing:** PASS verdicts have a non-zero false-negative rate. The extracted checklist shown in output is the user's primary safeguard against verifier errors. The verifier catches the most common drift patterns and makes gaps visible — it does not guarantee completeness.

### 6 General Shirking Patterns

These are dismissive placement patterns. An item found in one of these patterns is classified as SHIRKED unless it carries a `[DEFERRED: reason]` marker.

#### 1. Future Work Section
The item is acknowledged but pushed to an undefined future iteration.

> **Example:** "We'll address rate limiting in a future iteration."
>
> **Why it's shirking:** Acknowledges the item exists, does nothing about it. No timeline, no plan, no ownership. The item disappears into the backlog.

#### 2. Out of Scope Dump
The item is excluded by declaring it outside the current scope — without user consent for the scope boundary.

> **Example:** "Token rotation is out of scope for this phase."
>
> **Why it's shirking:** Boundary-drawing without user consent. The upstream artifact included this item as in-scope work. Unilaterally declaring it out of scope is not a legitimate deferral.

#### 3. Nice-to-Have Downgrade
The item's priority is silently reduced from "required" to "optional."

> **Example:** "Rate limiting would be a nice-to-have enhancement."
>
> **Why it's shirking:** Priority laundering. The upstream artifact treated this as a requirement, not a nice-to-have. Downgrading priority without user approval is shirking.

#### 4. Parenthetical Mention
The item is mentioned in passing within a parenthetical or subordinate clause, rather than given its own treatment.

> **Example:** "...security measures (including rate limiting) could be added later."
>
> **Why it's shirking:** Buried acknowledgment. The item is technically mentioned but receives no substantive treatment. It exists only as a parenthetical aside.

#### 5. Passive Deferral
The item is described as deferred using passive voice, creating the appearance of a plan without one.

> **Example:** "Rate limiting is deferred to Phase 2."
>
> **Why it's shirking:** Sounds like a deliberate decision but lacks the explicit `[DEFERRED: reason]` marker. Without the marker, there is no user-visible record that this was a conscious choice rather than an oversight.

#### 6. Hollow Section
The item gets a dedicated heading or section, but the section contains no substantive content — only a restatement of the requirement.

> **Example:**
> ```
> ### Rate Limiting
> We will implement rate limiting.
> ```
>
> **Why it's shirking:** The heading creates the appearance of coverage. But the body is a tautology — "we will do X" restates the requirement without design decisions, acceptance criteria, or implementation detail. See Substance Threshold below.

### 5 LLM-Specific Shirking Patterns

These patterns are common in AI-generated output. They sound substantive but produce no actionable artifact.

#### 7. Abstraction Escalation
The item is addressed by escalating to a higher-level abstraction that sounds comprehensive but specifies nothing.

> **Example:** "This should be handled by a configurable policy layer."
>
> **Why it's shirking:** Sounds substantive ("configurable policy layer" implies design thought), but produces no implementation. What policy? What configuration options? What interface? The abstraction replaces the work.

#### 8. Conditional Coverage
The item's existence is conditionalized — covered only "if" some condition holds, when the upstream artifact already established that the condition holds.

> **Example:** "If rate limiting is needed, the system supports it via middleware."
>
> **Why it's shirking:** Conditionalizes the item's existence. The upstream artifact already determined that rate limiting IS needed. Presenting it as conditional undoes the upstream decision.

#### 9. Complexity Acknowledgment
The item is addressed by acknowledging its complexity without producing any artifact, decision, or plan.

> **Example:** "Rate limiting is a complex topic that requires careful consideration of traffic patterns, burst capacity, and distributed coordination."
>
> **Why it's shirking:** Demonstrates knowledge of the problem space but produces nothing actionable. Acknowledging complexity is not the same as addressing it. This pattern is especially common in LLM output because it appears knowledgeable.

#### 10. Reference Pass-Through
The item is addressed by citing a source that does not exist or is not accessible.

> **Example:** "See the rate limiting documentation for implementation details."
>
> **Why it's shirking:** Cites a source that does not exist. The reference creates the appearance of thoroughness while offloading the actual work to a nonexistent document.

#### 11. Delegation to Future Skill
The item is addressed by claiming a later skill in the pipeline will handle it, without establishing any plan in the current artifact.

> **Example:** "Rate limiting will be addressed during /serious-code."
>
> **Why it's shirking:** Pushes to a later pipeline stage without a plan. If the current artifact is a plan, /serious-code will implement the plan — but if the plan doesn't include rate limiting, /serious-code won't either. The delegation creates a gap.

---

## Minimum Substance Threshold

An item is COVERED only if its downstream treatment contains **at least 2 of the following 5 signals**. A single signal is insufficient — it may indicate acknowledgment without substantive treatment.

### The 5 Signals

1. **Concrete action item** — A specific task or step to be performed (not a restatement of the upstream requirement)
2. **Design decision with rationale** — A technology, approach, or architecture choice with an explanation of why (not just naming a technology)
3. **Acceptance criteria** — Checkbox items (`- [ ]`) that define done
4. **Code reference** — A file path, function name, line number, or configuration key
5. **Data model or schema definition** — A table structure, field list, API shape, or type definition

### Substance Examples

**Positive examples (COVERED):**

**Example A — 3 signals (COVERED):**
> ```
> ### Rate Limiting
> Implement token bucket algorithm using Redis. Store per-user counters with 60s TTL.
> - [ ] 100 req/min per API key
> - [ ] 429 response with Retry-After header
> ```
> **Signals:** Design decision with rationale (token bucket + Redis with TTL justification) + acceptance criteria (2 checkboxes) + code reference (Redis, TTL) = 3 signals. Verdict: COVERED.

**Example B — 2 signals (COVERED):**
> ```
> Rate limiting is tracked in the security review (see section 5.2).
> - [ ] Verify rate limits match API gateway config
> ```
> **Signals:** Code reference (section 5.2) + acceptance criterion (1 checkbox) = 2 signals. Verdict: COVERED.

**Negative examples (SHIRKED):**

**Example C — 1 signal (SHIRKED):**
> ```
> ### Rate Limiting
> Implement rate limiting using Redis.
> ```
> **Signals:** Design decision (Redis) — but no rationale for why Redis, no acceptance criteria, no code reference = 1 signal. Below threshold. Verdict: SHIRKED.

**Example D — 0 signals (SHIRKED):**
> ```
> ### Rate Limiting
> We will implement rate limiting to protect the API.
> ```
> **Signals:** This is a restatement of the upstream requirement, not a concrete action item. No design decision, no acceptance criteria, no code reference, no schema = 0 signals. Verdict: SHIRKED (hollow section).

---

## Contradiction Detection

For each upstream item found in the downstream artifact, check whether the downstream's treatment **reverses or negates** the upstream's position. Contradictions are distinct from shirking — the item IS addressed substantively, but the downstream actively opposes the upstream's direction.

**Examples:**

| Upstream position | Downstream treatment | Disposition |
|-------------------|----------------------|-------------|
| "Use short-lived tokens (15min expiry)" | "Use long-lived tokens (24h expiry) to reduce refresh overhead" | CONTRADICTED |
| "Require rate limiting on all public endpoints" | "Rate limiting is unnecessary given our expected traffic volume" | CONTRADICTED |
| "Store secrets in Vault" | "Store secrets in environment variables for simplicity" | CONTRADICTED |

**Key distinction:** A contradiction is NOT a refinement. "Use short-lived tokens (15min)" → "Use short-lived tokens (30min)" is a refinement (COVERED). "Use short-lived tokens" → "Use long-lived tokens" is a reversal (CONTRADICTED).

Contradictions always result in FAIL, the same as SHIRKED or MISSING. The user must either align the downstream with the upstream or add an explicit `[VERIFIED: override — reason]` marker.

---

## Marker Conventions

### `[DEFERRED: reason]`
Marks a legitimate deferral. The item is intentionally not covered in this artifact, with a stated reason.

- An item in a dismissive placement pattern WITH `[DEFERRED: reason]` → disposition: **DEFERRED**
- An item in a dismissive placement pattern WITHOUT `[DEFERRED: reason]` → disposition: **SHIRKED**
- The `reason` must be present — `[DEFERRED]` alone (no reason) is treated as SHIRKED

### `[VERIFIED: override — reason]`
Marks a user override. The user asserts this item is handled, regardless of what the verifier detects.

- An item with `[VERIFIED: override — reason]` → disposition: **OVERRIDE**
- The `reason` must be present — `[VERIFIED: override]` alone (no reason after the dash) is NOT recognized as a valid override and is ignored
- Overrides are treated as PASS — they do not count against the verdict

---

## DEFERRED Item Limits

If more than **3 items** are DEFERRED in a single verification run, the verdict escalates from "PASS WITH DEFERRALS" to **"FAIL — too many deferrals, user confirmation required."**

The user must explicitly approve mass deferrals by adding `[MASS-DEFER-APPROVED: reason]` anywhere in the downstream artifact's body (not frontmatter). With this marker present, the DEFERRED count limit is lifted and the standard "PASS WITH DEFERRALS" verdict applies regardless of count.

---

## Output Format

The verifier outputs a structured traceability checklist. All elements below are mandatory.

```
## Upstream Traceability Check
Source: {upstream_artifact path}
Extracted items: {N} (from {M} sections)

1. {item description}     → {emoji} {DISPOSITION} [{confidence}] ({location reference})
2. {item description}     → {emoji} {DISPOSITION} [{confidence}] ({location reference})
...

Verdict: {PASS | PASS WITH DEFERRALS | FAIL} — {summary counts}
{fix instructions if FAIL}
{override syntax reminder if FAIL}

---
This check verifies downstream coverage of upstream items. It does NOT verify
that the upstream artifact is complete. If the upstream artifact missed important
items, this check will not catch the gap.

---
Were any items misclassified? If so, note which items and the correct disposition.
This feedback improves future verification accuracy.
```

### Disposition Types (6)

| Emoji | Disposition | Meaning |
|-------|-------------|---------|
| ✅ | COVERED | Item is substantively addressed (meets substance threshold) |
| ⚠️ | DEFERRED | Item is intentionally deferred with `[DEFERRED: reason]` marker |
| 🚫 | SHIRKED | Item is mentioned but not substantively treated (fails substance threshold or in dismissive placement without marker) |
| ❌ | MISSING | Item is not addressed and not deferred — completely absent |
| ✅ | OVERRIDE | Item has `[VERIFIED: override — reason]` marker — user asserts coverage |
| 🔀 | CONTRADICTED | Downstream treatment reverses or negates the upstream's position |

### Mandatory Output Elements

1. **Numbered checklist** — one line per extracted upstream item
2. **Disposition label** — emoji + text for each item (from the 6 types above)
3. **Confidence indicator** — `[high]`, `[medium]`, or `[low]` per item
4. **Location reference** — section name, heading, or line range in the downstream artifact where the item was found (or "not found" for MISSING)
5. **Verdict line** — PASS, PASS WITH DEFERRALS, or FAIL with summary counts (e.g., "6 covered, 1 deferred, 1 shirked")
6. **Fix instructions on FAIL** — path to the downstream artifact + command to re-run the skill (e.g., "Fix gaps in {path}, then re-run /serious-plan.")
7. **Override syntax reminder on FAIL** — "To override a finding, add `[VERIFIED: override — reason]` next to the item."
8. **Upstream incompleteness warning** — the footer paragraph stating this check does not verify upstream completeness
9. **Feedback prompt** — "Were any items misclassified? If so, note which items and the correct disposition. This feedback improves future verification accuracy."

---

## Verdict Rules

| Verdict | Condition |
|---------|-----------|
| **PASS** | All items are COVERED or OVERRIDE. No DEFERRED, SHIRKED, MISSING, or CONTRADICTED items. |
| **PASS WITH DEFERRALS** | Any items DEFERRED (max 3 without `[MASS-DEFER-APPROVED]`), no SHIRKED, MISSING, or CONTRADICTED items. |
| **FAIL** | Any SHIRKED item, any MISSING item, any CONTRADICTED item, or more than 3 DEFERRED items without `[MASS-DEFER-APPROVED: reason]` in the downstream artifact. |

On PASS or PASS WITH DEFERRALS: stamp the downstream artifact's frontmatter.
On FAIL: output fix instructions + override syntax. Do NOT stamp frontmatter.

---

## Frontmatter Stamp Specification

On PASS or PASS WITH DEFERRALS, add or update these fields in the downstream artifact's YAML frontmatter:

```yaml
verified: {YYYY-MM-DD}
verified_source: {upstream_artifact path}
verified_hash: {8-character hash}
```

- `verified` — the date verification passed
- `verified_source` — the path to the upstream artifact that was verified against
- `verified_hash` — first 8 characters of the SHA-256 hash of the upstream artifact's contract sections

### Hash Computation Rules (5 Steps)

1. **Extract only contract sections** — per the Contract Sections by Transition table above, extract only the designated sections for this transition (e.g., `## Key Insights`, `## Findings`, `## Recommendations`). Do NOT hash the full file.
2. **Strip leading/trailing whitespace per line** — for each line in the extracted content, remove leading and trailing whitespace characters.
3. **Normalize line endings to LF** — replace all `\r\n` (CRLF) and `\r` (CR) with `\n` (LF).
4. **Compute SHA-256** — hash the normalized extracted content as a single string.
5. **Store first 8 characters** — the `verified_hash` value is the first 8 hexadecimal characters of the SHA-256 digest.

This makes the hash insensitive to: frontmatter changes, reference section updates, formatting adjustments, and editor-added trailing newlines. Only changes to the actual contract content trigger re-verification.

---

## `_traceability_check.md` Versioning

Every verification run writes its full output to `_traceability_check.md` in the downstream artifact's folder.

**On re-run:**
1. If `_traceability_check.md` already exists, rename it to `_traceability_check_v{N}.md` where N is the next available version number (starting at 1).
2. If `_traceability_check_v1.md` already exists, use `_traceability_check_v2.md`, and so on.
3. Write the new verification output to `_traceability_check.md`.

This preserves the full verification history for audit and feedback purposes.

**Feedback logging:** If the user provides feedback on misclassifications (in response to the feedback prompt), append it to `_traceability_check.md` under a `## Feedback` section:

```markdown
## Feedback
- Item 4 (Rate limiting): User corrected SHIRKED → COVERED. Rationale: "Addressed in middleware config at line 47."
- Item 6 (Audit logging): User confirmed MISSING. Will add in next revision.
```

---

## Multi-Plan Verification Protocol

When the downstream artifact is a `phase_map.md` with multiple plans:

1. **Discover all plan files.** Do NOT rely solely on filenames matching `plans/01_*.md` or `plans/02_*.md`. Plans may use any naming convention (e.g., `A_pipeline_code.md`, `01_data_infrastructure.md`, `auth_backend.md`). To find all plans:
   - Read the `phase_map.md` — it lists every plan file by path.
   - Glob the plan output directory for all `.md` files that are NOT `phase_map.md`, `_extracted_items.md`, or `_traceability_check*.md`.
   - Verify that every file referenced in the phase map exists. If a referenced plan is missing, report it as an error.
2. **Extract items from upstream** — same as single-plan extraction.
3. **Read the phase map** to determine item-to-plan allocation. The phase map's executive summary and task allocation tables specify which upstream items each plan is responsible for.
4. **Verify each plan independently** against its assigned subset of items. An item assigned to Plan 01 is only checked in Plan 01's artifact — it is not expected to appear in Plan 02.
5. **Verify the UNION.** After checking individual plans, verify that every upstream item is assigned to at least one plan. If an item appears in `_extracted_items.md` but is not allocated in the phase map, it is MISSING regardless of individual plan results.
6. **Each plan gets its own `verified` stamp** — `verified`, `verified_source`, and `verified_hash` are written to each plan's individual frontmatter on PASS.
7. **If an upstream item is split across multiple plans**, each plan must cover its assigned portion. The verifier checks the phase map's allocation to determine which items belong to which plan.

**Multi-plan output format:**

```
## Upstream Traceability Check (Multi-Plan)
Source: {upstream_artifact path}
Extracted items: {N}

Phase Map Allocation:
- Plan 01 ({plan-name}): items {list}
- Plan 02 ({plan-name}): items {list}

Plan 01 Verification:
1. {item}     → {emoji} {DISPOSITION} [{confidence}] ({location})
2. {item}     → {emoji} {DISPOSITION} [{confidence}] ({location})
...

Plan 02 Verification:
3. {item}     → {emoji} {DISPOSITION} [{confidence}] ({location})
...

Per-Plan Verdicts:
- Plan 01: {VERDICT}
- Plan 02: {VERDICT}

Overall Verdict: {PASS | PASS WITH DEFERRALS | FAIL}
```

If any individual plan FAILs, the overall verdict is FAIL.

---

## Worked Examples for Ambiguous Cases

These examples illustrate how the verifier handles edge cases. Each demonstrates a different match strategy and a common judgment call.

### Example 1: Semantic Match (conversation → research)

**Upstream item (from summary.md Key Insights):**
> "Users distrust silent token rotation"

**Downstream treatment (in research.md):**
> Finding titled "Token Transparency Requirements" that discusses user notification preferences, consent flows, and visibility of rotation events.

**Disposition:** ✅ COVERED `[high]` — Same concept, different title. The finding substantively addresses user distrust of silent rotation by designing transparency mechanisms. Multiple substance signals present (design decisions + acceptance criteria).

---

**Upstream item (from summary.md Open Questions):**
> "Consider WebSocket support"

**Downstream treatment (in research.md):**
> Heading "## Future Considerations: WebSocket" containing only: "WebSocket support may be beneficial for real-time features."

**Disposition:** 🚫 SHIRKED `[high]` — The item was placed in a "Future Considerations" section (dismissive placement: Future Work Section pattern) and contains no substance (0 signals — only a vague restatement). No `[DEFERRED: reason]` marker present.

### Example 2: Structural Match (research → plan)

**Upstream item (from research.md Findings):**
> "Finding 3: Rate limiting required at API gateway"

**Downstream treatment (in implementation_plan.md):**
> "Task 4: Implement API Rate Limiting" with 3 acceptance criteria checkboxes, a design decision (token bucket algorithm), and a code reference (API gateway middleware path).

**Disposition:** ✅ COVERED `[high]` — Dedicated task with 3+ substance signals. The structural match is clear (Finding → Task) and the substance threshold is exceeded.

---

**Upstream item (from research.md Findings):**
> "Finding 3: Rate limiting required at API gateway"

**Downstream treatment (in implementation_plan.md):**
> Rate limiting appears only in a "Related concerns we considered" table row with no associated task, no acceptance criteria, and no design decisions.

**Disposition:** 🚫 SHIRKED `[high]` — Dismissive placement (the item was acknowledged in a side table, not given a task). No substance signals in the table row. This matches the "Nice-to-Have Downgrade" and "Parenthetical Mention" patterns.

### Example 3: Exact Match (plan → code)

**Upstream item (from implementation_plan.md acceptance criteria):**
> `- [ ] 100 req/min per API key`

**Downstream treatment (in codebase):**
> Test file contains: `test('enforces 100 req/min limit per API key', ...)`

**Disposition:** ✅ COVERED `[high]` — The exact requirement is traceable to a specific test. The test name directly corresponds to the acceptance criterion.

---

**Upstream item (from implementation_plan.md acceptance criteria):**
> `- [ ] 100 req/min per API key`

**Downstream treatment:** No corresponding test, no implementation code referencing rate limits, no configuration for per-key limits.

**Disposition:** ❌ MISSING — The item is completely absent from the downstream artifact. Not deferred, not shirked — simply not there.

### Example 4: Empty-Section Case

**Upstream artifact (summary.md):**
> ```
> ## Unresolved tensions
> None identified during this conversation.
>
> ## Open questions
> None — all questions were resolved during the session.
> ```

**Extraction result:** 0 items extracted from "Unresolved tensions" section. 0 items extracted from "Open questions" section. No warning issued — intentionally empty sections produce 0 extracted items, which is a valid result. The total extraction count reflects only sections that had content.

---

## Upstream Incompleteness Warning

The following warning is appended as a footer to EVERY verifier output (both PASS and FAIL):

> This check verifies downstream coverage of upstream items. It does NOT verify that the upstream artifact is complete. If the upstream artifact missed important items, this check will not catch the gap.

This warning exists because the verifier is a **coverage** checker, not a **completeness** checker. It answers "did the downstream address everything the upstream raised?" — not "did the upstream raise everything it should have?"

---

## Feedback Prompt

After outputting the traceability checklist (including the upstream incompleteness warning), the verifier appends:

> Were any items misclassified? If so, note which items and the correct disposition. This feedback improves future verification accuracy.

If the user responds with corrections, log them in `_traceability_check.md` under a `## Feedback` section (see `_traceability_check.md` Versioning above for format).

Feedback is critical because shirking detection uses heuristic semantic judgment with a non-zero false-negative rate. User corrections improve the verifier's calibration over time by documenting edge cases and false positives/negatives.
