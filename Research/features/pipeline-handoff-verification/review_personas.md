# Persona Review: QA Engineer

## Selection Rationale

**Why QA Engineer:** This project produces prompt/template files, not compiled software. The primary risk is not "does it compile" but "are the acceptance criteria precise enough that a QA agent can read the deliverable and unambiguously determine PASS or FAIL." A QA Engineer catches vague criteria, missing negative tests, untestable assumptions, and edge cases that the implementer will silently sidestep. This is exactly the failure mode the verifier itself is designed to catch — which makes it especially important to catch it in the plan.

**Why not others:** A Senior Engineer review already exists. A Security Reviewer is irrelevant (no auth, no data). A Performance Engineer would flag the 30-90s per verification, but that was already reviewed. An Architect would focus on system boundaries, which are well-defined here (shared file, sub-agent spawn, 3 SKILL.md integrations). The QA perspective is the gap.

---

## Findings

### 1. Task 1 AC for "all 6 general shirking patterns" is wrong count
**Severity:** Critical
**Task:** Task 1
**Issue:** Acceptance criterion says "File contains all 6 general shirking patterns from research Finding 3." The research document (Finding 3) lists exactly 6 general patterns AND 5 LLM-specific patterns. The next AC says "all 5 LLM-specific shirking patterns." The counts are correct. However, the criterion says "from research Finding 3" — if the research is ever updated to add or remove a pattern, this criterion becomes stale because it hardcodes the count. More importantly, the QA agent verifying this must list-match against the research. The criterion does not enumerate the 6 patterns by name, so a QA agent must read two files and cross-reference. This is verifiable but fragile.

**Fix:** List the 6 general patterns by name in the AC: (future work, out of scope, nice-to-have, parenthetical, passive deferral, hollow section). Similarly list the 5 LLM-specific patterns by name. This makes verification self-contained — the QA agent does not need to read research.md to verify Task 1's deliverable.

---

### 2. Task 5 requires "at least 3 real artifact pairs" but only 2 exist
**Severity:** Critical
**Task:** Task 5
**Issue:** The acceptance criterion states "Verifier tested on at least 3 real upstream->downstream artifact pairs." The codebase currently contains exactly 2 conversation->research pairs (pipeline-handoff-verification and recursive-workflow-pipeline) and 2 research->plan pairs (same slugs). There is no third completed workflow. The plan's Pre-Flight Readiness checklist says "At least one completed conversation->research->plan workflow exists in Research/ to test against" — this is a weaker requirement than Task 5 demands. The plan does not explain where the third pair comes from.

**Fix:** Either (a) reduce the requirement to 2 pairs with a note that a third should be tested when available, (b) explicitly require creating a synthetic test artifact as part of Task 5 (a known-bad pair with intentional omissions for negative testing — this would be the third pair), or (c) add a pre-flight check that verifies 3+ completed workflows exist before starting Task 5. Option (b) is recommended because it also satisfies the negative test requirement ("include at least one known-bad artifact").

---

### 3. No acceptance criterion for what happens when upstream artifact does not exist
**Severity:** Critical
**Task:** Task 4
**Issue:** Task 4 AC says "If `source` field is empty (no upstream), both checks are skipped with a note." But it does not cover the case where `source` is populated but the file at that path does not exist (deleted, renamed, moved). The verifier will attempt to read a non-existent file. There is no acceptance criterion specifying the expected behavior: should it warn and proceed, warn and block, or error? This is a real scenario — users rename folders, restructure Research/ directories, or delete old workflows.

**Fix:** Add an AC: "If `source` field points to a path that does not exist, the skill logs a warning ('Upstream artifact at [path] not found — skipping verification') and proceeds without blocking." Also add this as a negative test: "Phase 0 does NOT crash or block if `source` points to a missing file."

---

### 4. No acceptance criterion for malformed frontmatter in upstream artifact
**Severity:** Major
**Task:** Task 4
**Issue:** Task 4 checks for `verified`, `verified_hash`, and `source` fields in frontmatter. But there is no criterion for what happens when the upstream artifact has malformed or unparseable YAML frontmatter (missing `---` delimiters, invalid YAML syntax, frontmatter present but empty). The extract-mode step reads the upstream artifact and tries to parse frontmatter. If parsing fails, the behavior is undefined.

**Fix:** Add a negative test: "If upstream artifact has malformed frontmatter (unparseable YAML), extract-mode warns and proceeds with extraction based on headings only — it does NOT block the skill."

---

### 5. Verify-mode output format is not acceptance-tested
**Severity:** Major
**Task:** Task 1
**Issue:** The AC says "File contains the verifier output format from research Finding 8" with a parenthetical listing the components. But the QA agent verifying this must compare the verifier prompt's output format section against the exact format in research Finding 8 — which includes specific emoji markers, bracket notation, section references, and the fix-instruction footer. The AC does not specify which elements of the format are mandatory. Is the emoji (checkmark, warning, X, circle-slash) part of the spec? Is the `[high/medium/low]` confidence notation required? A QA agent reading only the AC cannot determine whether a slightly different format is PASS or FAIL.

**Fix:** Enumerate the mandatory output format elements in the AC: (1) numbered checklist, (2) disposition label per item (5 types), (3) confidence indicator `[high/medium/low]`, (4) location reference (section/line), (5) verdict line (PASS/PASS WITH DEFERRALS/FAIL), (6) fix instructions on FAIL, (7) override syntax reminder on FAIL, (8) upstream incompleteness warning footer.

---

### 6. Task 3 does not specify WHERE in SKILL.md the verifier block goes
**Severity:** Major
**Task:** Task 3
**Issue:** The AC says "completion section includes verifier instruction block." But the three SKILL.md files have different structures. serious-research has "Phase 6: Handoff," serious-plan has "Phase 3: Present to User," and serious-code has "Phase 2: Completion." The AC does not specify which section/phase is the "completion section" for each skill. A QA agent cannot verify "the block is in the right place" without knowing where "right" is.

**Fix:** Change the three ACs to be specific: "serious-research SKILL.md: Phase 6 (Handoff) includes verifier instruction block..." / "serious-plan SKILL.md: Phase 3 (Present to User) includes verifier instruction block..." / "serious-code SKILL.md: Phase 2 (Completion) includes verifier instruction block..."

---

### 7. Task 4 does not specify WHERE in Phase 0 the new steps go relative to existing steps
**Severity:** Major
**Task:** Task 4
**Issue:** Each SKILL.md's Phase 0 already has steps: 0-pre (breadcrumb check), 0a (auto-detect), 0b (present), 0c (validate), etc. Task 4 says "Phase 0 includes an extract-mode step" but does not specify the ordering relative to existing steps. Should extract-mode run before 0a (auto-detect)? After 0c (validate)? After 0-pre? The ordering matters because auto-detect determines which upstream file to use, so extract-mode logically must come after auto-detect resolves the upstream path.

**Fix:** Add to each AC: "Extract-mode step is added after the existing Phase 0 auto-detect and validation steps (after 0c in serious-plan, after 0c in serious-code, after 0b in serious-research), as a new numbered step (e.g., 0d or 0f depending on existing step count)."

---

### 8. No test scenario for the context window guard (>20 items)
**Severity:** Major
**Task:** Task 5
**Issue:** Task 1 requires "context window guard: chunk into batches of 10 if extracted items exceed 20." Task 5 (testing on real artifacts) has no criterion that tests this behavior. The real artifacts in this codebase have ~8-11 findings — none will trigger the >20 threshold. If this is never tested, it remains unverified dead logic in the verifier prompt.

**Fix:** Add a test scenario to Task 5: "Test the context window guard by running the verifier against an artifact with >20 extracted items (either a real artifact if one exists, or a synthetic artifact created for this test). Verify that the output shows batched processing: 'Batch 1/N: items 1-10' etc."

---

### 9. Hash computation rules are underspecified for QA verification
**Severity:** Major
**Task:** Task 1
**Issue:** The AC says "File contains frontmatter stamp spec: `verified`, `verified_source`, `verified_hash` with hash computation rules (extractable sections only, normalized)." The research defines the hash as SHA-256 of normalized extracted content, first 8 characters. But the AC does not ask the QA agent to verify the hash computation rules are complete in the deliverable — specifically: (1) which sections to extract for each transition, (2) normalization rules (strip whitespace, LF normalization), (3) truncation to 8 chars. A QA agent reading the AC would check "are hash computation rules mentioned?" but could not verify they are correct or complete.

**Fix:** Expand the AC: "File contains hash computation rules specifying: (a) extract only contract sections per transition, (b) strip leading/trailing whitespace per line, (c) normalize line endings to LF, (d) compute SHA-256, (e) store first 8 characters. All 5 steps must be explicit."

---

### 10. No acceptance criterion for `_traceability_check.md` versioning behavior
**Severity:** Major
**Task:** Task 6 (end-to-end smoke test)
**Issue:** Task 1 AC requires the verifier to support versioning ("rename previous to `_v{N}` on re-run"). Task 6 (end-to-end) tests that `_traceability_check.md` exists but never tests re-run versioning. If the smoke test is run once, versioning is untested. This is a user-facing behavior: if versioning fails silently, previous verification results are overwritten and lost.

**Fix:** Add an AC to Task 6: "Run the verifier twice on the same artifact. After the second run, `_traceability_check_v1.md` exists (the first run's output) and `_traceability_check.md` contains the second run's output."

---

### 11. Task 2 AC for research heading standardization is vague about current state
**Severity:** Minor
**Task:** Task 2
**Issue:** The ACs say "verify these are already correct — change only if they differ" for conversation and mock-ups headings. This is good defensive phrasing. But the AC for research.md says "requires `## Findings` section to use numbered subsections" — the word "requires" is ambiguous. Does "requires" mean "add an instruction to the template that mandates numbered subsections" or "verify the existing template already mandates it"? Looking at the current research SKILL.md template (line 207), the `## Findings` section has `{Main research content — build incrementally}` with no subsection format specified. So this IS a real change needed. The AC should say "add" not "require."

**Fix:** Change to: "serious-research SKILL.md: research.md template's `## Findings` section is updated to specify numbered subsection format (`### Finding 1: [title]`, `### Finding 2: [title]`, etc.) in the placeholder text."

---

### 12. Task 0 acceptance criteria allow a PASS even if no drift is found
**Severity:** Minor
**Task:** Task 0
**Issue:** The AC says "Identify at least one example of each drift type if present (omission, contradiction, shirking)." The phrase "if present" means a QA agent must accept a report that says "no drift found" as a PASS. But the whole purpose of Task 0 is to demonstrate the baseline drift problem. If no drift is found, either the artifacts are perfect (unlikely) or the observation was shallow. The AC should require a definitive statement about whether drift exists.

**Fix:** Change to: "Document whether each drift type (omission, contradiction, shirking) was found. For each type found, provide a specific example with upstream item and downstream disposition. If no instances of a drift type are found, state this explicitly with the search methodology used."

---

### 13. No negative test for multi-plan verification in the scope
**Severity:** Minor
**Task:** Task 1
**Issue:** Research Finding 7 describes multi-plan verification (phase map allocation, per-plan verification). Task 1's ACs do not mention multi-plan verification at all. The verifier prompt should include multi-plan handling, but there is no AC requiring it. If the implementer omits multi-plan logic from the verifier, QA has no criterion to catch it.

**Fix:** Add an AC to Task 1: "File contains multi-plan verification protocol: phase map allocation extraction, per-plan item assignment, independent verification stamps per plan."

---

### 14. Task 6 does not specify what "correct format" means for the traceability checklist
**Severity:** Minor
**Task:** Task 6
**Issue:** The AC says "Verifier produces a traceability checklist matching the format from research Finding 8." This is the same vagueness problem as Finding 5 above, but at the smoke test level. The QA agent running Task 6 must compare actual output to the Finding 8 format, but "matching the format" does not define acceptable deviations. Is a missing emoji a failure? Is a reworded verdict line a failure?

**Fix:** Reference the specific format elements from Finding 5's fix. Or more pragmatically: "Verifier output contains a numbered list of items, each with a disposition label, confidence indicator, and location reference; a verdict line; and the upstream incompleteness warning."

---

### 15. No edge case for the "Unresolved tensions" section being empty
**Severity:** Minor
**Task:** Task 4 / Task 5
**Issue:** The conversation summary template includes `## Unresolved tensions` which can be "None." (as in this very workflow's summary.md). When the verifier extracts items from the upstream conversation summary, what happens with an empty section? Does it extract zero items from that section (correct) or does it flag "0 items extracted from Unresolved tensions — upstream may be incomplete" (confusing but technically correct)? Neither Task 1 nor Task 5 tests this edge case.

**Fix:** Add a worked example to Task 1 AC: "Worked examples include: empty upstream section (e.g., 'Unresolved tensions: None') produces 0 extracted items from that section with no warning."

---

### 16. Retroactive verification does not define behavior when upstream itself needs re-verification
**Severity:** Minor
**Task:** Task 4
**Issue:** The AC says "retroactive verification depth limit: verify only the immediate upstream, not the entire chain." But what if the immediate upstream's `source` field points to an artifact that ALSO has no `verified` stamp? The plan says "don't recurse" but doesn't say whether to warn about the unverified chain. A user running `/serious-code` on an unverified plan whose research is also unverified would only see the plan verification — the research gap is invisible.

**Fix:** Add an AC: "If retroactive verification discovers that the upstream artifact's own `source` is unverified (chain gap), log a warning: 'Note: [upstream path]'s own upstream at [source path] has not been verified. Consider running verification on the full chain.' Do NOT recurse — warn only."

---

## Summary

| Severity | Count | Tasks Affected |
|----------|-------|----------------|
| Critical | 3 | Task 1, Task 4, Task 5 |
| Major | 7 | Task 1 (x2), Task 3, Task 4, Task 5, Task 6, Task 1 |
| Minor | 6 | Task 0, Task 1, Task 2, Task 4, Task 5, Task 6 |
| **Total** | **16** | |

**Recommendation:** Fix the 3 Critical findings before implementation begins. The Critical issues will cause either test execution failure (Task 5 cannot find 3 artifact pairs) or ambiguous QA outcomes (Task 1 patterns not enumerated, Task 4 missing file not handled). The 7 Major findings should also be addressed — they represent gaps where the QA agent cannot make an unambiguous PASS/FAIL determination, which defeats the purpose of a verification system.
