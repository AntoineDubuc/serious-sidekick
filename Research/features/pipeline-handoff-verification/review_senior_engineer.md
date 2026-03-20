# Senior Engineer Review: Pipeline Handoff Verification Research

**Reviewer:** Senior Engineer (persona)
**Date:** 2026-03-19
**Files reviewed:** `research.md`, `notebook.md`
**Cross-referenced:** All 5 workflow SKILL.md files, conversation summary.md, result_v6.md, implementation plan template v6

---

## 1. Accuracy

### 1a. Terminology inconsistency: "markdown link references" vs "direct path + instruction"

The upstream conversation (`summary.md`, `result_v6.md`) repeatedly says the sharing mechanism is "markdown link references." The research correctly identifies that the actual mechanism is Pattern 1: direct path + prose instruction (e.g., "Read the v6 template file at `./_implementation_plan_template_v6.md`"). These are not the same thing. Markdown link references are a specific syntax (`[text][ref-id]` with `[ref-id]: url` at the bottom of the file). No SKILL.md file uses that syntax. The research silently corrected the conversation's error without flagging it. This should be called out explicitly -- the conversation design says "markdown link references" and that is wrong. Anyone implementing from the conversation output alone would try to use link reference syntax, which has no special behavior in SKILL.md files.

**Action:** Add a note in the research explicitly stating the conversation used imprecise terminology and what the actual mechanism is.

### 1b. Sharing mechanism example is accurate but incomplete

The proposed instruction block in Finding 2 shows:

```
Read and execute the upstream traceability verification
protocol at `.claude/skills/_shared/handoff-verifier.md`.
```

This matches how `serious-plan` references `_implementation_plan_template_v6.md`. However, `serious-plan` uses a code block with the path, not inline prose. The actual pattern in the SKILL.md (line 14-16) is:

```
./_implementation_plan_template_v6.md
```

inside a fenced code block, followed by "**Read this file before generating any plan.**"

Minor difference, but the verifier reference should match the exact established pattern to be consistent. The proposed prose-only form might work, but it has not been validated as equally reliable as the code-block-then-instruction form.

**Action:** Match the existing pattern exactly: code block with path, then bold instruction.

### 1c. The `_shared/` directory does not exist

The research proposes placing the verifier at `.claude/skills/_shared/handoff-verifier.md`, but this directory does not exist in the skills tree. No `_shared/` directory exists anywhere under `.claude/skills/`. This is a net-new convention. Not wrong, but not "following existing patterns" -- it is establishing a new pattern. The research should acknowledge this and specify that the directory must be created, and whether it needs any special handling (e.g., should SKILL.md files inside `_shared/` have frontmatter? Should they be non-invocable? Will Claude Code's skill discovery scan this directory?).

**Action:** Clarify that `_shared/` is new, must be created, and document whether files there are treated as skills by Claude Code's auto-discovery. If they are, the verifier file must NOT have `user-invocable: true` to avoid appearing as a slash command.

### 1d. Frontmatter claims are technically correct

The proposed `verified`, `verified_source`, `verified_hash` fields are valid YAML. The existing frontmatter standard (5 required fields: `skill`, `slug`, `status`, `parent`, `created`) is well-documented in CLAUDE.md. Adding new fields is forward-compatible. No issues here.

### 1e. SHA-256 hash -- how is it computed?

The research says `verified_hash` is "First 8 chars of SHA-256 hash of upstream artifact content at verification time." But it does not specify: hash of what exactly? The raw file bytes? The content with or without frontmatter? With or without trailing whitespace? Normalized line endings?

This matters because: if a user opens the upstream file and saves it without changes (editor adds trailing newline), the hash changes, triggering unnecessary re-verification.

**Action:** Specify exactly what is hashed. Recommend: strip YAML frontmatter, normalize line endings to LF, strip trailing whitespace, then SHA-256 the result. This makes the hash insensitive to metadata changes and editor formatting.

---

## 2. Completeness

### 2a. The `source` field is proposed but not wired into any template

Finding 4 proposes adding a `source` field to downstream artifact frontmatter, but no skill output template currently includes it. The research doesn't specify which templates need modification, what the exact YAML looks like for each skill, or how the value is populated at skill execution time.

For example: when `serious-plan` runs from a research file, who writes `source: Research/features/auth/research.md` into the plan's frontmatter? The plan skill itself? Manually? The verifier? This is the critical wiring gap.

**Action:** For each downstream skill, specify: (1) where in the SKILL.md the `source` field is set, (2) what populates its value, (3) what happens when there is no upstream (e.g., plan created from a verbal description).

### 2b. Recommendations section is empty

The research.md has `{To be written after research is complete}` for both Summary and Recommendations. The Findings are substantive, but the document is technically incomplete. A reviewer or planner who reads only the Summary and Recommendations gets nothing.

**Action:** Complete both sections. The recommendations should include the implementation sequence (already present in the conversation output and partially in Finding 5-8) and any deviations from the conversation design that the research uncovered.

### 2c. No handling of multi-plan scenarios

The research covers single upstream-to-single downstream transitions. But `serious-plan` produces multi-plan outputs (`phase_map.md` + `plans/01_*.md`, `plans/02_*.md`). Which artifact does the verifier check? The phase map? Each individual plan? If each plan, do they each get their own `verified` stamp? What if one plan covers items 1-4 and another covers items 5-8 -- does the verifier run once against the phase map or N times against N plans?

**Action:** Add a section on multi-plan verification. Define whether verification runs against the phase map (aggregated) or against each individual plan (granular), and how the traceability checklist maps items to specific plans.

### 2d. No handling of the mock-ups -> plan transition in detail

The research lists `mock-ups -> plan` in the transition table (Finding 1) but the extraction rules (Finding 8) say "Structural (components should appear in plan tasks)." This is vague. `mock-up-summary.md` has a Component Inventory table and a Design Decisions table. Are both tables extracted? Each row becomes an item? What about the Screen Flow Summary and Responsive Notes sections -- are those extracted too?

**Action:** Specify exactly which sections of `mock-up-summary.md` are extracted and how each row maps to a verifiable item.

### 2e. No specification for what "save extracted items to a scratch location" means

Finding 5 (Extract Mode, step 5) says "Save extracted items to a scratch location for verify-mode to reuse." Where? A temp file? A frontmatter field? An in-memory state that persists across the skill execution? Given that extract runs at startup and verify runs at completion, possibly hours later (and potentially across context compaction), this persistence mechanism is critical.

**Action:** Specify the scratch location explicitly. Recommend: write an `_extracted_items.md` file to the downstream artifact's folder. This survives compaction, is inspectable by the user, and is trivially re-readable.

---

## 3. Depth

### 3a. Shirking patterns are good but missing common LLM-specific patterns

The six shirking patterns (future work, out of scope, nice-to-have, parenthetical mention, passive deferral, hollow section) cover the standard cases. But LLM agents have additional shirking patterns not listed:

- **Abstraction escalation:** "This should be handled by a configurable policy layer" -- sounds substantive but produces no concrete implementation.
- **Conditional coverage:** "If rate limiting is needed, the system supports it via middleware." -- conditionalizes the item's existence.
- **Complexity acknowledgment:** "Rate limiting is a complex topic that requires careful consideration of..." -- acknowledges complexity without producing any artifact.
- **Reference pass-through:** "See the rate limiting documentation for implementation details" -- cites a source that does not exist.
- **Delegation to future skill:** "Rate limiting will be addressed during /serious-code" -- pushes it to a later pipeline stage without a plan.

**Action:** Add these 5 patterns to the shirking detection list. They are common in LLM output and distinct from the 6 already listed.

### 3b. Minimum substance threshold is necessary but underspecified

The threshold requires "at least one of: concrete action item, design decision with rationale, acceptance criteria, code reference, data model." This is a good start, but how does the verifier distinguish a genuine action item from a rephrased restatement?

Example: "We will implement rate limiting using a token bucket algorithm" -- this names an algorithm. Is that a "design decision with rationale"? It has no rationale. Is it an "action item"? It restates the requirement with an implementation hint.

**Action:** Provide 2-3 positive examples and 2-3 negative examples for each substance category. The verifier prompt needs concrete exemplars, not just category names.

### 3c. Semantic vs structural matching is acknowledged but not operationalized

Finding 8 says earlier transitions (conversation -> research) use "semantic" matching while later transitions use "structural" matching. But the verifier is a single prompt file. How does it know which mode to use? Is this a parameter passed by the calling skill? A heuristic based on artifact type? An instruction in the prompt that says "if the upstream artifact is summary.md, use semantic matching"?

**Action:** Define the switching mechanism. Recommend: the calling skill passes a `match_strategy: semantic|structural|exact` parameter alongside the upstream/downstream paths. The verifier prompt has a conditional block for each strategy.

---

## 4. Blind Spots

### 4a. Context window pressure

The verifier runs as a sub-agent that must read both the upstream artifact and the downstream artifact, extract items from one, search for them in the other, and produce a detailed report. For a research.md with 8 findings and a plan with 7 tasks (each with 5+ acceptance criteria), this is a significant amount of text. If the upstream artifact is a deep-mode research with 30+ findings and the plan is multi-plan with 20+ tasks, the verifier sub-agent may hit context limits.

**Action:** Add a size guard. If extracted items exceed a threshold (e.g., 20), chunk the verification: run the verifier in batches of 10 items, then aggregate results.

### 4b. False positives from keyword matching

The verifier matches upstream items to downstream content. But keyword overlap does not mean coverage. A plan that mentions "rate limiting" in a table of "related concerns we considered" would keyword-match against an upstream finding about rate limiting, but it is not covering that item.

The research acknowledges this indirectly (the "dismissive placement" patterns). But the verifier must first FIND the mention before classifying its placement. If the find step is keyword-based, it will produce matches that then need placement analysis. If the find step is semantic, it is unreliable at scale.

**Action:** Specify the search algorithm. Recommend: first keyword search for mentions (fast, comprehensive), then for each mention, analyze its placement context (parent heading, section type, surrounding content). This two-pass approach is implementable and testable.

### 4c. What happens when verification fails mid-skill?

The verify mode runs at skill completion. If it returns FAIL, what does the user do? The research says "output actionable message with specific gaps and re-run instruction." But re-running the skill means re-running the entire skill from scratch. For `serious-plan`, that means regenerating the entire plan. For `serious-code`, that means... what? You cannot re-run code execution to add missing items.

The research does not address the remediation workflow for each downstream skill. "Fix gaps and re-run" is only feasible for plan generation, not for code execution.

**Action:** Define remediation paths per transition. For plan: re-run or manually edit. For code: the verification should run BEFORE code starts (which it does via retroactive check), not after code completes. Make this explicit.

### 4d. No versioning of verifier output

The traceability checklist is output once. If the user fixes gaps and re-runs, the previous checklist is overwritten. There is no history of what was flagged, what was fixed, and what was overridden. This matters for audit trails.

**Action:** Version the output. Recommend: `_traceability_check_v1.md`, `_traceability_check_v2.md`, etc. Each run creates a new version. The latest is the authoritative one.

### 4e. Circular verification risk

The retroactive verification system (Finding 6) says: "When a downstream skill starts, check the upstream's `verified` field. If missing, verify before proceeding." But what if the upstream's upstream is also unverified? Do you chain all the way back to the conversation? The research doesn't address transitive verification.

**Action:** Specify the depth limit. Recommend: verify only the immediate upstream. If the entire chain needs verification, the user should run `/serious-review` or a dedicated verification sweep, not a recursive chain at skill startup.

### 4f. No test plan for the verifier itself

The research proposes testing on "3 real artifacts" but does not define what a passing test looks like for the verifier. What are the test cases? Deliberately shirked items? Clean passes? Edge cases like empty upstream? A verifier that passes all its own tests is the minimum bar for shipping.

**Action:** Define 5-10 specific test scenarios with expected verifier output. Include: (1) clean pass, (2) one missing item, (3) one shirked item with hollow section, (4) one legitimately deferred item, (5) one override, (6) upstream with no structured items (warning case), (7) hash mismatch triggering re-verification, (8) multi-plan target.

---

## 5. Recommendations

### Must-fix before planning (blockers)

1. **Complete Summary and Recommendations sections.** The document is not ready for `/serious-plan` with placeholder sections.
2. **Resolve the "markdown link references" terminology error.** The conversation and research contradict each other. The research has the right answer but needs to explicitly correct the record.
3. **Specify the scratch location for extracted items.** Without this, the two-mode design (extract at startup, verify at completion) has no persistence mechanism.
4. **Define multi-plan verification behavior.** Plans frequently produce multiple output files; the verifier must handle this.
5. **Add the 5 missing LLM-specific shirking patterns.** These are the most common failure modes the verifier will encounter.

### Should-fix before planning (significant gaps)

6. **Specify hash computation rules.** Without normalization, the hash will trigger false re-verifications constantly.
7. **Define who populates the `source` field.** The field is proposed but has no owner.
8. **Add positive/negative examples to the substance threshold.** The categories are too abstract for a prompt to execute reliably.
9. **Define the match strategy switching mechanism.** Semantic vs structural matching needs an explicit parameter, not a vague hint.
10. **Define remediation workflows per transition.** "Fix and re-run" only works for plan generation.

### Nice-to-have (would improve quality)

11. **Add verifier output versioning.** Helps with audit trails.
12. **Add context window size guard.** Prevents verifier failures on large artifacts.
13. **Define specific test scenarios for the verifier.** Makes implementation verification unambiguous.
14. **Clarify `_shared/` directory implications for skill auto-discovery.** Prevents the verifier from appearing as a user command.
15. **Specify transitive verification depth limit.** Prevents recursive chain verification at startup.
