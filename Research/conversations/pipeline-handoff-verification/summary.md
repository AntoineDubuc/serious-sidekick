# Conversation Summary: Pipeline Handoff Verification

## Topic
How to eliminate manual correction loops at pipeline handoffs — making upstream traceability automatic so skills don't silently drop, contradict, or defer work from their upstream artifact.

## Desired outcome
Decision — choose between approaches for where and how automatic verification lives in the pipeline.

## Personas
- The Architect — systems boundaries, composability, long-term design
- The Pragmatist — shipping speed, minimal complexity, concrete effort
- The Skeptic — stress-testing assumptions, finding holes, demanding evidence
- The DX Advocate — user experience, failure paths, actionable output

## Rounds
6 rounds. Arc: Round 1-2 explored mechanism options and converged on independent sub-agent with shared prompt. Round 3 resolved the "contract" problem (existing artifact structure IS the contract). Round 4 closed architecture questions (generic prompt, heading standardization, `_shared/` directory). Round 5 reached consensus but deferred four hard items. Round 6 was a forced reckoning — user called out the deferral pattern, all four items were solved and validated.

## Key insights
1. **Self-verification doesn't work.** The same agent that produced work can't audit it — it has an incentive to declare itself done. Verification must be an independent sub-agent.
2. **The upstream artifact's existing structure IS the contract.** No new "handoff contract sections" needed — numbered lists and bulleted findings are already enumerable.
3. **Scope shirking is the hardest failure mode.** Omission detection (is the item present?) is easy. Shirking detection (is the item given substantive treatment or just waved away?) is what actually matters — and it's achievable via placement-based pattern matching, not semantic reasoning.
4. **`@include` doesn't work in SKILL.md files.** The sharing mechanism must be markdown link references, not `@` syntax.
5. **The panel deferred the hard stuff — exactly the behavior the system is meant to prevent.** All four "future enhancements" (shirking detection, manual override, startup check, retroactive verification) turned out to be achievable and were brought into v1 scope after the user called it out.

## Unresolved tensions
- None. All design decisions are settled after round 6.

## Open questions
- None for the design. Implementation and testing are the next steps.

## Design decisions (complete)

### Architecture
- Shared verification prompt: `.claude/skills/_shared/handoff-verifier.md`
- Referenced via markdown link by each downstream skill
- Two modes: extract (startup) and verify (completion)
- Independent sub-agent execution
- `@include` does NOT work in SKILL.md — use markdown link references instead

### Five dispositions
| Disposition | Rule |
|---|---|
| COVERED | Item has own section/task/AC with substantive content |
| DEFERRED | Item has `[DEFERRED: reason]` marker |
| SHIRKED | Item in dismissive placement without marker, or hollow section |
| MISSING | Item not mentioned at all |
| OVERRIDE | Item has `[VERIFIED: override — reason]` marker |

### Verdict rules
- All COVERED/OVERRIDE → PASS
- Any DEFERRED, no SHIRKED/MISSING → PASS WITH DEFERRALS
- Any SHIRKED or MISSING → FAIL

### Frontmatter stamps
```yaml
verified: 2026-03-19
verified_source: Research/features/auth/research.md
verified_hash: a3b2c1d4
```

### Retroactive verification
- No `verified` field → verify before proceeding
- Hash mismatch → re-verify
- Both present and matching → skip

### Implementation sequence
1. Standardize key headings in skill output templates
2. Write handoff-verifier.md with both modes
3. Add source field to downstream frontmatter specs
4. Wire into serious-plan first (highest-value handoff)
5. Test on real artifacts
6. Roll to remaining transitions
Estimated effort: 12-15 hours

## Recommended next step
`/serious-research` — validate the design against real artifacts, test extraction reliability, tune shirking patterns, and produce a research document that feeds into `/serious-plan`.
