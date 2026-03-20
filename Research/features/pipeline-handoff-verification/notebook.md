# Research Notebook: Pipeline Handoff Verification
**Started:** 2026-03-19
**Status:** In Progress
**Classification:** Feature
**Scope:** Codebase only
**Mode:** Quick

## Research Question
Validate the handoff verification design from /serious-conversation and fill in implementation specifics: (1) Are real skill output artifacts extractable? (2) What are the exact shirking detection patterns? (3) How should the shared verifier prompt work? (4) How do markdown link references work in SKILL.md for sharing? (5) What frontmatter changes are needed?

---

## Log

### Entry 1 — 2026-03-19 Initial Setup
Conversation output at Research/conversations/pipeline-handoff-verification/ produced a complete design over 6 rounds. Key design decisions settled:
- Shared verifier at .claude/skills/_shared/handoff-verifier.md
- Two modes: extract (startup) and verify (completion)
- Five dispositions: COVERED, DEFERRED, SHIRKED, MISSING, OVERRIDE
- Frontmatter stamps: verified, verified_source, verified_hash
- @include doesn't work in SKILL.md — need alternative sharing mechanism

### Entry 2 — 2026-03-19 Artifact Extractability Analysis

**Investigated:** All 4 workflow skill output templates (conversation, research, plan, mock-ups)

**Found:** The "existing structure IS the contract" assumption HOLDS. Every skill produces enumerable sections:

| From Skill | Key Enumerable Sections | Format |
|---|---|---|
| conversation (summary.md) | Key insights, Unresolved tensions, Open questions | Bulleted lists |
| conversation (result_vN.md) | Where they agree, Where they disagree, Open questions | Bulleted lists |
| research (research.md) | Findings (subsections), Recommendations | Prose subsections + bulleted lists |
| plan (implementation_plan.md) | Master Checklist (table), Acceptance criteria per task | Table rows + checkbox lists `- [ ]` |
| mock-ups (mock-up-summary.md) | Component Inventory, Design Decisions | Tables |

**Issues found:**
- research.md Findings section can be prose (not always enumerable) — needs heading standardization
- Conversation uses persona names as h3 (dynamic, not numbered) — verifier must handle named subsections
- Plan's acceptance criteria use `- [ ]` checkbox format — highly extractable

**Implications:** Extraction is feasible with minimal template changes. The main fix: research.md Findings should use numbered subsections (### Finding 1, ### Finding 2) consistently.

### Entry 3 — 2026-03-19 SKILL.md Sharing Mechanism

**Investigated:** How SKILL.md files reference external content

**Found:** Five patterns exist, NO file inclusion:
1. **Direct path + instruction** — "Read this file at: {path}" (serious-plan references _implementation_plan_template_v6.md this way)
2. **Breadcrumb files** — .active-{skill} with folder path as content
3. **$ARGUMENTS substitution** — file paths passed at invocation
4. **Subagent prompts** — paths embedded in agent spawn prompts
5. **Hooks** — Stop hooks read breadcrumbs to find output folders

**The sharing mechanism for the verifier:**
Each downstream SKILL.md includes a line like:
"Read and execute the handoff verification protocol at `.claude/skills/_shared/handoff-verifier.md`"

This is Pattern 1 — the same way serious-plan references its template. Claude reads the file when it hits that instruction. One source of truth, each skill just has one line pointing to it.

**No @include, no markdown link inclusion, no file injection.** All sharing is explicit instruction + path.

### Entry 4 — 2026-03-19 Persona Reviews Integration

**Reviewed by:** Senior Engineer + Devil's Advocate

**Key corrections integrated:**
1. Removed "not semantic reasoning" claim — shirking detection IS heuristic semantic judgment, not structural pattern matching. Reframed throughout.
2. Mandated sub-agent spawn (Agent tool) for verification — inline execution has sycophantic bias. This is non-negotiable.
3. Added 5 LLM-specific shirking patterns (abstraction escalation, conditional coverage, complexity acknowledgment, reference pass-through, delegation to future skill).
4. Tightened substance threshold from "at least 1 of 5 signals" to "at least 2 of 5 signals" with concrete positive/negative examples.
5. Fixed terminology: "markdown link references" → "direct path + prose instruction."
6. Specified hash computation: extractable sections only, normalized, not full file.
7. Defined who populates `source` field (the downstream skill itself).
8. Added multi-plan verification strategy.
9. Specified scratch location: `_extracted_items.md` in downstream artifact's folder.
10. Added cost/latency estimates (~$0.30-$0.50, 2-6 min per pipeline run).
11. Added upstream incompleteness warning to verifier output.
12. Added per-item confidence indicators (high/medium/low).
13. Added versioned logging (`_traceability_check.md`).
14. Added worked examples for ambiguous cases per transition type.
15. Added context window guard (chunk if >20 items).

**What was NOT integrated (and why):**
- Devil's Advocate's suggestion to expand test plan to 15-20 artifacts: valid but belongs in the implementation plan, not the research. Noted in recommendations.
- Devil's Advocate's suggestion for conjunction-based substance threshold: partially adopted (raised to 2 signals from 1), but full conjunction (ALL signals) was too strict — would flag legitimate coverage.
- Senior Engineer's suggestion for verifier output versioning: adopted (v1, v2, etc.).
- Devil's Advocate's suggestion to limit DEFERRED items per artifact: deferred to post-v1 (need usage data first).
