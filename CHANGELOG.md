# Changelog

All notable changes to Serious Sidekick are documented here. Written for humans — if you're a PM, you can read this and know exactly what changed and why it matters.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [Semantic Versioning](https://semver.org/).

---

## [1.2.0] — 2026-03-22

### Harder to fool, harder to game

After a thorough competitive analysis of [obra/superpowers](https://github.com/obra/superpowers) (105K stars), we identified three patterns they use to keep AI agents honest — and adapted all three for Serious Sidekick. Credit where it's due: Superpowers showed us what "take the work seriously" looks like when you apply it to the agents themselves.

#### Added

- **Anti-rationalization tables** — Each agent now has a table of excuses it might generate to skip its own protocol, with explanations of why each excuse is wrong and what to do instead. The Implementer has 8 TDD-skipping rationalizations ("this is too simple to test," "I'll write tests after"), the Reviewer has 7 review-softening rationalizations ("the tests pass so it must be correct," "the implementer probably had a good reason"), and QA has 6 spot-check shortcuts ("the implementer already tested this," "3 spot-checks is probably enough"). Inspired by Superpowers' anti-rationalization tables in their TDD and debugging skills.

- **Two-stage code review** — The Reviewer agent now runs two separate passes. Stage 1: spec compliance — every acceptance criterion gets a verdict (COMPLIANT / PARTIAL / MISSING / WRONG). Any MISSING or WRONG = automatic FAIL regardless of code quality. Stage 2: code quality — security, consistency, test quality. This prevents "correct but wrong" implementations from slipping through because the code is clean. Inspired by Superpowers' separation of spec reviewers from code reviewers.

- **Anti-sycophancy guidance** — The Reviewer and QA agents are now explicitly forbidden from performative praise ("Great work!", "Nice implementation!"). Both are instructed to verify independently against the codebase, not against the implementer's self-report. QA is told: "If you find none, be suspicious of yourself." Inspired by Superpowers' "receiving code review" skill and pushback protocol.

- **Nano Banana 2 image generation** — `/serious-bananas` default model changed to `gemini-3.1-flash-image-preview`. New capabilities: 4K resolution, dark mode style, 14 aspect ratios, reference image support, search grounding, iterative editing, and thinking mode. Three model tiers: Nano Banana 2 (default), Pro (complex compositions), v1 (budget).

#### Fixed

- **Upstream verification enforcement** — Phase 0d (extract-mode) and Phase 3 (handoff verification) in `/serious-plan` and `/serious-research` were advisory — the agent could skip them and jump straight to generating the plan. A real-world failure on 2026-03-22 proved this: a plan generated from a 6-round conversation (36 design decisions) missed module-level summaries, route/decorator metadata, node-type-specific quality focus, and the 30-decision reasoning evaluation. All four were explicit in the upstream conversation. Now both phases are hard gates — Phase 0d blocks plan generation until `_extracted_items.md` exists, Phase 3 blocks presentation until the verifier returns PASS. The plan generator must cross-reference the extracted inventory during generation, not rely on memory. Same treatment applied to `/serious-research`.

- **Micro-plan verification gap** — The handoff verifier only checked `implementation_plan.md` or `phase_map.md`. When plans were split into micro-plans with arbitrary filenames (`A_pipeline_code.md`, `01_data_infrastructure.md`), the actual plan content was unverified. The verifier now discovers all plan files from the phase map + directory glob, and checks the UNION to ensure every upstream item is allocated to at least one plan.

- **Handoff verifier enforcement contract** — Added a "Calling Skills Must Enforce" section to the shared verifier making the contract explicit: the verifier reports, the calling skill gates. References the 2026-03-22 incident as the reason this was necessary.

- **Stop hook safety net for plans** — Added a recommended Stop hook configuration to `/serious-plan` that checks for `_extracted_items.md` in active plan directories at session end. Catches cases where sub-agents or interrupted sessions bypassed the in-skill gates.

#### Changed

- **README revamp** — Rewritten in PM-friendly language with progressive disclosure. Five dark-mode Gemini-generated diagrams (pipeline overview, conversation flow, plan review, code execution, verification). Diagrams audited against actual system behavior via `/serious-research`.

- **guide.html updated** — New "What's New" section with Superpowers credit, new Handoff Verification section documenting v1.1.0's verification system, updated agent cards with anti-rationalization and two-stage review details, updated Nano Banana 2 utility card, fixed feature counts (38 → 39).

- **Competitive analysis documented** — Full analysis of obra/superpowers at `Research/exploratory/superpowers-analysis/raw_findings.md`. 14 skills compared across 20+ feature dimensions. B+ tier backlog tracked for future iterations.

---

## [1.1.0] — 2026-03-20

### The pipeline now catches its own mistakes

Every time a skill handed off to the next one — conversation to research, research to plan, plan to code — things got quietly dropped. Items marked "future enhancement." Findings that just disappeared. You'd catch it eventually, but only after burning time on manual correction loops.

Now there's an automatic verifier that fires at every handoff. It reads the upstream artifact, extracts every item, and checks whether the downstream output actually addresses each one — not just mentions it, but gives it real substance.

#### Added

- **Automatic handoff verification** — An independent sub-agent fires at every skill transition. It reads what the upstream skill produced, extracts every enumerable item, and checks whether the downstream skill actually covered each one. No new commands, no opt-in — it just happens.

- **Scope shirking detection** — The verifier catches 11 patterns where work is acknowledged but not actually done. Things like "we'll handle this in a future iteration," hollow sections with a heading but no content, and LLM-specific dodges like "this should be handled by a configurable policy layer" (sounds smart, does nothing).

- **Contradiction detection** — When the downstream artifact says the opposite of what the upstream said (e.g., upstream says "use short-lived tokens," plan says "use long-lived tokens"), the verifier flags it.

- **Retroactive verification** — Plans created before the verifier existed get caught the moment someone tries to use them. The system checks for a verification stamp in the frontmatter, and if it's missing, runs verification before proceeding.

- **Deferral limits** — You can legitimately defer items with `[DEFERRED: reason]`, but if more than 3 items are deferred in one artifact, the verifier flags it as excessive and requires explicit approval.

- **User feedback loop** — After every verification, the system asks whether any items were misclassified. Responses are logged for future prompt tuning.

- **Shared verifier prompt** — One file (`.claude/skills/_shared/handoff-verifier.md`) is the single source of truth for all verification logic. Every downstream skill references it. Changes propagate everywhere.

- **New frontmatter fields** — `source`, `verified`, `verified_source`, `verified_hash` added as optional fields to the workflow frontmatter standard. Documented in CLAUDE.md.

#### Changed

- **Conversation synthesis is now shown in the chat** — When `/serious-conversation` completes a round, the full synthesis is presented inline in PM language — not just a pointer to a file. You're having a conversation, not reading markdown.

- **Questions follow a structured format** — When the Orchestrator has questions during a conversation, each one is presented with context, the recommended option and why, alternatives and trade-offs, and why the recommendation won. One question per message.

- **Research findings must use numbered subsections** — The `## Findings` section in research output now requires `### Finding 1: [title]` format instead of prose paragraphs. This makes the verifier's extraction reliable.

---

## [1.0.0] — 2026-03-08

### The foundation

The complete Serious Sidekick workflow toolkit — from structured conversations to implementation with verification.

#### The workflow pipeline

A sequence of skills that take you from "I have an idea" to "it's built and verified":

1. **`/serious-conversation`** — Think out loud with a panel of AI personas. Pick from 10 built-in perspectives (Architect, Skeptic, Pragmatist, etc.) or create custom ones. Each round: personas respond independently, Orchestrator synthesizes, you refine.

2. **`/serious-research`** — Two modes. Quick mode: single-threaded investigation with persona reviews. Deep mode: parallel research agents, evidence grading (A through F), adversarial verification (tries to disprove your findings), QA citation checking, and a self-contained HTML report.

3. **`/serious-mock-ups`** — Generate UI mock-ups before planning. Three fidelity levels (wireframe, visual, interactive flow). Component inventory and design decision log feed directly into the plan.

4. **`/serious-plan`** — Generates implementation plans using a structured template. Includes TDD protocol, persona review pipeline (End User, QA Engineer, Security Reviewer, etc.), mechanical verification (file paths, API signatures, import paths), and split into single or multiple plans with a phase map for parallel execution.

5. **`/serious-code`** — Executes plans with 5 Agent Teams agents (implementer, reviewer, test-runner, runtime-checker, QA). Each acceptance criterion gets TDD (write failing test first), independent QA verification, and a Completion Gate that catches dead code and stub implementations. Multi-plan execution uses git worktrees for parallel work.

6. **`/serious-review`** — Structured defect capture that bridges back into the pipeline. Findings cycle through research → plan → code again.

#### Workflow management

- **`/serious-status`** — See all active and completed workflows in a tree view.
- **`/serious-abandon`** — Safely abandon a sub-workflow and return to its parent.
- **`/serious-init`** — Scaffold a new project with all skills, agents, hooks, and documentation.

#### Quality enforcement

- **Completion Gate** — An independent sub-agent verifies every acceptance criterion has implementing code AND that the code is reachable (not dead code). A stop hook enforces this — the session can't exit without `gate_passed.md` for every task.
- **Stub detection** — Scans for placeholder patterns (`TODO`, `throw UnimplementedException`, etc.) after implementation, before verification.
- **Inter-plan regression checking** — After merging parallel plans, re-verifies all previous phases' user-visible acceptance criteria to catch breakage.
- **Smoke test bookending** — Task 0 reproduces the problem in the running app. The final task re-runs the same test to prove it's fixed.
- **Sync pair tracking** — Identifies functions that must produce equivalent output (write/apply, serialize/deserialize) and ensures both sides are covered when one changes.

#### Recursive workflows

- Sub-workflows nest up to 2 levels deep with parent tracking via breadcrumb files.
- Pipeline ordering: advancing (moving forward) vs branching (going sideways) with automatic detection.
- Same-skill restoration: when a nested workflow completes, the parent's breadcrumb is restored.

#### Claude Code feature documentation

39 feature reference files covering everything from core CLI to MCP integration, with auto-loading skills that surface the right docs when you ask about a feature.

#### Image generation

- **`/serious-bananas`** — Generate diagrams and images using Google's Gemini native image generation API.

---

[1.2.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/AntoineDubuc/serious-sidekick/releases/tag/v1.0.0
