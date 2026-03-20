# Extracted Upstream Items
Source: Research/features/pipeline-handoff-verification/research.md
Extracted: 2026-03-20
Total items: 20

## From: Findings (subsections)
1. Finding 1: Artifact Extractability — Confirmed (all skill output artifacts have extractable enumerable sections; handoff contracts by transition table; heading standardization needed)
2. Finding 2: SKILL.md Sharing Mechanism — Resolved (direct path + prose instruction, not @include; _shared/ directory convention; user-invocable: false frontmatter)
3. Finding 3: Shirking Detection Patterns (5 dispositions; 6 general shirking patterns; 5 LLM-specific shirking patterns; minimum substance threshold 2-of-5 signals; substance examples; marker interactions)
4. Finding 4: Frontmatter Changes (verified, verified_source, verified_hash fields; hash computation rules; source field for downstream artifacts)
5. Finding 5: Verifier Prompt Design — Two Modes (extract mode at startup; verify mode at completion via sub-agent; match strategy parameter; upstream incompleteness warning)
6. Finding 6: Retroactive Verification Logic (Phase 0 checks for verified/source fields; hash staleness detection; depth limit — immediate upstream only)
7. Finding 7: Multi-Plan Verification (phase_map.md with multiple plans; per-plan verification against assigned items; per-plan verified stamps; split-item handling)
8. Finding 8: Complete Verifier Output Format (numbered checklist; disposition labels with emoji; confidence indicators; location references; verdict line; fix instructions; override syntax; upstream incompleteness warning)
9. Finding 9: Transition-Specific Extraction Rules (generic verifier handles all transitions; match strategy passed as parameter; worked examples for semantic/structural/exact)
10. Finding 10: Cost and Operational Considerations (token cost estimates per transition; context window guard — chunk into batches of 10 if >20 items)
11. Finding 11: Feedback Loop and Logging (versioned _traceability_check.md; post-implementation feedback metrics; false-positive/negative rate measurement)

## From: Recommendations
12. Create `.claude/skills/_shared/` directory and write `handoff-verifier.md` with both modes, all 11 shirking patterns, worked examples, and output format
13. Standardize headings in research.md output template: require `### Finding N: [title]` format
14. Add the verifier instruction block to serious-research, serious-plan, and serious-code SKILL.md files
15. Add `source` field to the frontmatter specs of research.md, implementation_plan.md, and execution_log.md output templates
16. Wire extract-mode into Phase 0 for serious-plan first (highest-value handoff)
17. Mandate sub-agent spawn in the verifier instruction block — not inline execution
18. Build versioned logging from day one — `_traceability_check.md` with version numbering on re-runs
19. Start with research->plan transition, then roll to conversation->research and plan->code after validating
20. Do not claim the verifier eliminates manual review — frame as "catches the most common drift patterns and makes gaps visible"
