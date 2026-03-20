# Senior Engineer Review

**Plan:** Research/features/pipeline-handoff-verification/implementation_plan.md
**Research:** Research/features/pipeline-handoff-verification/research.md
**Reviewer:** Senior Engineer (mechanical review)
**Date:** 2026-03-19

---

## File Path Verification

| # | Plan Reference | Actual | Verdict |
|---|---|---|---|
| 1 | `.claude/skills/serious-conversation/SKILL.md` (Task 2) | EXISTS at `.claude/skills/serious-conversation/SKILL.md` | PASS |
| 2 | `.claude/skills/serious-research/SKILL.md` (Tasks 2, 3, 4) | EXISTS at `.claude/skills/serious-research/SKILL.md` | PASS |
| 3 | `.claude/skills/serious-plan/SKILL.md` (Tasks 3, 4) | EXISTS at `.claude/skills/serious-plan/SKILL.md` | PASS |
| 4 | `.claude/skills/serious-code/SKILL.md` (Tasks 3, 4) | EXISTS at `.claude/skills/serious-code/SKILL.md` | PASS |
| 5 | `.claude/skills/serious-mock-ups/SKILL.md` (Task 2) | EXISTS at `.claude/skills/serious-mock-ups/SKILL.md` | PASS |
| 6 | `.claude/skills/_shared/handoff-verifier.md` (Task 1, new) | DOES NOT EXIST — expected, Task 1 creates it | PASS (intentional) |
| 7 | `.claude/skills/_shared/` directory (Task 1, new) | DOES NOT EXIST — expected, Task 1 creates it | PASS (intentional) |
| 8 | `./_implementation_plan_template_v6.md` (Pre-Flight) | EXISTS at `./_implementation_plan_template_v6.md` | PASS |
| 9 | `Research/features/pipeline-handoff-verification/research.md` (Pre-Flight) | EXISTS | PASS |
| 10 | `Research/conversations/pipeline-handoff-verification/summary.md` (Task 0, 5) | EXISTS | PASS |
| 11 | `Research/features/pipeline-handoff-verification/evidence/` (Evidence Root) | DOES NOT EXIST — must be created during Pre-Flight | PASS (Pre-Flight checklist item) |

---

## Convention Verification

### 1. Verifier instruction block pattern vs. established template reference pattern

**Established pattern** (from serious-plan SKILL.md lines 13-18):
```
```
./_implementation_plan_template_v6.md
```
**Read this file before generating any plan.**
```

**Plan's proposed verifier block** (from research Finding 2, referenced by Task 3 acceptance criteria):
```
```
.claude/skills/_shared/handoff-verifier.md
```
**Read this file and spawn a verification sub-agent as described within.**
```

**Verdict:** The plan's Task 3 acceptance criterion says "Each verifier block uses the established pattern: code block with path, then bold instruction to spawn a sub-agent (Agent tool)." This matches the structural pattern (code block + bold instruction) from serious-plan's template reference. PASS.

### 2. Frontmatter field naming conventions

**CLAUDE.md required fields:** `skill`, `slug`, `status`, `parent`, `created`

**Plan's proposed new fields:** `source`, `verified`, `verified_source`, `verified_hash`

**The plan's own frontmatter** (lines 1-8) includes `source:` — a field that does not yet exist in the CLAUDE.md frontmatter standard. The plan proposes adding it via Task 3, but the plan itself already uses it. This is a forward reference that works but creates a mild inconsistency: the plan file uses a field that won't be standardized until the plan's own Task 3 is executed.

**Verdict:** Minor inconsistency. The plan does not include a step to update CLAUDE.md's "Workflow Frontmatter Standard" section to document the new `source`, `verified`, `verified_source`, and `verified_hash` fields. See Finding 1.

### 3. Non-invocable skill frontmatter convention

The plan (Task 1 acceptance criteria) specifies frontmatter with `user-invocable: false`. This matches the research Finding 2 recommendation and follows existing SKILL.md frontmatter conventions (`user-invocable: true` in all current skills). PASS.

---

## Dependency Verification

### Can Task 3 run without Task 1 being complete?

Task 3 adds verifier instruction blocks to SKILL.md files that reference `.claude/skills/_shared/handoff-verifier.md`. If Task 1 hasn't been completed, the referenced file does not exist.

**Verdict:** Task 3 CAN be written without Task 1 — the instruction blocks are just text that says "read this file." Claude won't try to read it during Task 3 implementation; it only fires at runtime when a skill is invoked. However, Task 5 (testing on real artifacts) and Task 6 (end-to-end smoke test) absolutely require Task 1. The implicit dependency is correct: Task 3 references Task 1's output but doesn't require it to exist at write-time. **PASS** — but the plan should make this explicit in Task 3's description.

### Can Task 4 run without Task 3 being complete?

Task 4 adds Phase 0 extract-mode and retroactive verification logic. This logic checks the `source` frontmatter field (added by Task 3) and references the verifier prompt (created by Task 1). If Task 3 hasn't run, the `source` field won't exist in output templates, so the Phase 0 logic will always hit the "source field is empty, skip" path.

**Verdict:** Task 4 can technically be written without Task 3, but it would be functionally inert until Task 3 adds the `source` field. The dependency is real but not blocking for implementation. **PASS** — but the Plan should state "Depends on: Task 1 (verifier file exists) and Task 3 (source field populated)" in Task 4's description.

### Can Task 2 run independently?

Task 2 standardizes heading names in upstream output templates. It has no dependencies on Tasks 1, 3, or 4. PASS.

### Task 5 dependencies

Task 5 (testing on real artifacts) requires Task 1 (verifier prompt exists). It also implicitly requires Tasks 3 and 4 for end-to-end testing. The plan says "run the verifier against real artifacts" — this means the verifier prompt must exist. **PASS** — dependencies are implicitly correct through task ordering.

### Task 6 dependencies

Task 6 (end-to-end smoke test) requires all prior tasks. The plan's task ordering (0→1→2→3→4→5→6) correctly sequences this. PASS.

---

## Completeness Check

| Research Finding | Covered by Task | Verdict |
|---|---|---|
| **1. Artifact Extractability** — All skills produce enumerable sections; heading standardization needed for research.md Findings | Task 2 (heading standardization) | PASS |
| **2. SKILL.md Sharing Mechanism** — Direct path + prose instruction; `_shared/` directory; non-invocable frontmatter | Task 1 (creates `_shared/` and verifier file), Task 3 (adds reference blocks) | PASS |
| **3. Shirking Detection Patterns** — 6 general + 5 LLM-specific patterns, substance threshold (2 of 5 signals), marker conventions | Task 1 (verifier prompt contains all patterns) | PASS |
| **4. Frontmatter Changes** — `verified`, `verified_source`, `verified_hash` fields; hash computation rules; `source` field | Task 1 (hash/stamp spec in verifier), Task 3 (source field in SKILL.md templates) | PASS — but see Finding 1 re: CLAUDE.md update |
| **5. Verifier Prompt Design** — Two modes (extract + verify), match strategies, upstream incompleteness warning | Task 1 (verifier prompt), Task 3 (match strategy params), Task 4 (extract-mode wiring) | PASS |
| **6. Retroactive Verification Logic** — Phase 0 checks for `verified`/`source` fields, hash staleness, depth limit | Task 4 (Phase 0 wiring) | PASS |
| **7. Multi-Plan Verification** — Phase map verification, per-plan verification, item allocation checking | **NO TASK COVERS THIS** | **FAIL** — see Finding 2 |
| **8. Complete Verifier Output Format** — Numbered checklist, dispositions, confidence, verdict, fix instructions, override syntax, upstream warning | Task 1 (verifier prompt output format) | PASS |
| **9. Transition-Specific Extraction Rules** — 4 transitions with match strategies, worked examples | Task 1 (worked examples), Task 3 (match strategy params) | PARTIAL — see Finding 3 |
| **10. Cost and Operational Considerations** — Token estimates, context window guard (chunk if >20 items) | Task 1 (context window guard in verifier prompt) | PASS — cost estimates are informational, not implementable |
| **11. Feedback Loop and Logging** — `_traceability_check.md` versioning, post-implementation metrics review | Task 1 (versioning instruction in verifier prompt) | PASS — post-implementation review is operational, not implementable |

---

## Findings

### Finding 1: CLAUDE.md frontmatter standard not updated
**Severity:** Major
**Issue:** The plan introduces 4 new frontmatter fields (`source`, `verified`, `verified_source`, `verified_hash`) but includes no task to update the CLAUDE.md "Workflow Frontmatter Standard" section. CLAUDE.md is the canonical reference for frontmatter conventions. Any field not documented there risks inconsistent usage across skills and future development.
**Fix:** Add a step to Task 3 (or create a dedicated Task 2.5) to update the CLAUDE.md frontmatter standard table with the 4 new fields, their types, and descriptions. The `source` field should be documented as optional (empty when no upstream exists).

### Finding 2: Multi-plan verification not covered
**Severity:** Critical
**Issue:** Research Finding 7 describes a complete multi-plan verification protocol: verify the phase map against upstream research, verify each individual plan against its assigned subset of items, check item allocation across plans. No task in the implementation plan addresses this. The plan's Executive Summary says "Every handoff in the pipeline gets automatic drift detection" but multi-plan is a distinct handoff pattern that is silently dropped.
**Fix:** Either (a) add a Task covering multi-plan verification logic in the verifier prompt and in serious-code's SKILL.md (which consumes phase maps), or (b) explicitly mark multi-plan verification as out-of-scope with a `[DEFERRED: reason]` marker in the plan's "Out of Scope" section — noting it was a research finding that was intentionally deferred. Currently it is simply absent, which is the definition of shirking per this plan's own criteria.

### Finding 3: Mock-ups-to-plan transition missing from Tasks 3 and 4
**Severity:** Major
**Issue:** Research Finding 9 identifies 4 transitions: conversation->research, research->plan, **mock-ups->plan**, and plan->code. Research Finding 1 explicitly documents the mock-ups->plan contract (Component Inventory + Design Decisions tables). However, Task 3 only lists 3 SKILL.md files for verifier blocks (serious-research, serious-plan, serious-code) and does not include a verifier block for the mock-ups->plan handoff. Task 4 similarly only lists 3 files. The serious-plan SKILL.md already auto-detects mock-ups (line 139: "If a `mock-ups/mock-up-summary.md` exists alongside the research, read it too"), but no verification is wired for this consumption.
**Fix:** Task 3 should add verifier logic to serious-plan's SKILL.md that handles the mock-ups->plan handoff when mock-ups are present. This could be a conditional second verifier invocation: "If mock-ups were consumed, also verify against mock-up-summary.md with `match_strategy: structural`." Task 4's Phase 0 should similarly add an extract-mode step for mock-up-summary.md when present.

### Finding 4: Research->mock-ups transition not addressed
**Severity:** Minor
**Issue:** Research Finding 1 lists the research->mock-ups transition (with `research.md` Findings and Recommendations as the contract). Research Finding 9 does NOT list it in the transition table (only 4 transitions listed). The plan follows Finding 9 and omits this transition. This is a minor gap — mock-ups are optional in the pipeline, and the research->mock-ups handoff is lower-value than research->plan. But the omission should be acknowledged.
**Fix:** Add a note in the plan's "Out of Scope" section: "research->mock-ups transition — deferred until mock-ups usage patterns are established."

### Finding 5: Plan frontmatter uses `source` field before Task 3 creates it
**Severity:** Minor
**Issue:** The plan's own frontmatter (line 7) contains `source: Research/features/pipeline-handoff-verification/research.md`. This field is proposed by the plan itself (Task 3) and does not yet exist in the CLAUDE.md standard. The serious-plan SKILL.md template (lines 143-151) does not include a `source` field. This means the plan was manually given a field that would only be standard after the plan's own implementation.
**Fix:** No code change needed — this is a bootstrap issue (the plan pre-applies a convention it defines). Document it as intentional in the plan's Appendix/Technical Decisions section.

### Finding 6: Task count inconsistency in Master Checklist summary
**Severity:** Minor
**Issue:** The Master Checklist summary (line 141) says "Total tasks: 6 (implementation) + 5 (verification) + 1 (smoke test) = 12 total." But the dashboard shows Tasks 0 (smoke test), 1, 1v, 2, 2v, 3, 3v, 4, 4v, 5, 5v, 6 = 12 entries. Task 0 is a smoke test, Task 6 is a smoke test, and Tasks 1-5 are implementation. That gives 5 implementation tasks + 5 verification tasks + 2 smoke tests = 12. The summary says "6 (implementation)" which likely counts Task 0 as implementation, but Task 0 is labeled "Smoke Test" in the dashboard.
**Fix:** Change the summary to "Total tasks: 5 (implementation) + 5 (verification) + 2 (smoke tests) = 12 total" or reclassify Task 0.

### Finding 7: No explicit dependency declarations in task descriptions
**Severity:** Minor
**Issue:** No task explicitly declares its dependencies using a "Depends on:" field. Dependencies are implied by ordering and context (e.g., Task 3 references the file Task 1 creates) but never stated. For a plan that will be executed by agents, explicit dependency declarations reduce ambiguity.
**Fix:** Add a "Depends on:" line to Tasks 3, 4, 5, and 6. Examples: Task 3 depends on Task 1 (file existence at runtime). Task 4 depends on Tasks 1 and 3. Task 5 depends on Tasks 1, 3, 4. Task 6 depends on all prior tasks.

---

## Summary

| Severity | Count | Findings |
|---|---|---|
| Critical | 1 | #2 (multi-plan verification dropped) |
| Major | 2 | #1 (CLAUDE.md not updated), #3 (mock-ups->plan transition missing) |
| Minor | 4 | #4 (research->mock-ups not acknowledged), #5 (bootstrap frontmatter), #6 (task count math), #7 (no explicit dependencies) |

**Overall assessment:** The plan is structurally sound and covers the core verifier design well. The critical finding (#2) is that multi-plan verification — a full research finding with a detailed protocol — is completely absent from the plan with no acknowledgment. This is exactly the kind of drift the verifier system is designed to catch, which makes the omission ironic. The two major findings (#1, #3) are about integration gaps that would cause friction during implementation but are straightforward to address.
