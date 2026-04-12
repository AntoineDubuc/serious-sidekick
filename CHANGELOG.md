# Changelog

All notable changes to Serious Sidekick are documented here. Written for humans — if you're a PM, you can read this and know exactly what changed and why it matters.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [Semantic Versioning](https://semver.org/).

---

## [1.7.0] — 2026-04-12

### Live status line, dispatch audit trail, supply-chain hardening

Three features shipped in one weekend, built on top of a security hardening prerequisite that closed 3 attack vectors.

#### Added

- **Live status line for `/serious-code`** — Terminal footer shows a second line during active runs: `[serious-code · Phase 2/4 · Task 3/5 · implementer: running]`. Reads `status.json` written by the orchestrator (Plan 4a). Integrated into the existing `~/.claude/statusline-command.sh`. 18 tests. All output sanitized (terminal injection, bidi overrides, control chars). Secret env vars scrubbed at script start.

- **Dispatch audit trail** — `PreToolUse/Agent` hook logs every agent dispatch to `dispatch_log.md` with task ID, agent type, and timestamp. The completion report warns if any task dispatched fewer than 5 agents. Always exits 0 — never blocks, never loops. Input sanitized, file mode 0600. 47 tests. End-to-end verified with live agent dispatch.

- **Status JSON orchestrator** — `/serious-code` SKILL.md updated to write `status.json` on every state transition (phase change, task start, agent dispatch). Schema at `.claude/skills/_shared/status-schema.md`. Sanitization at write time. Atomic write via `.tmp` + `mv`.

- **TASK_ID tagging** — `/serious-code` SKILL.md updated to include `TASK_ID: task_{NN}` in every agent dispatch prompt. The dispatch audit hook parses this to attribute log entries to tasks.

- **Dispatch Audit section in completion report** — Reads `dispatch_log.md` and summarizes per-task dispatch counts. Advisory warning if fewer than 5 distinct agent types.

#### Fixed

- **Supply-chain hardening** — 3 attack vectors in `serious-update` and `/serious-init` closed:
  - Manifest tier-swap: `parse_manifest` now rejects `.claude/settings.json` with ownership other than `merge`
  - Dead hash verification: SHA-256 hashes in manifest were read but never compared. Now enforced.
  - Loose regex: `is_serious()` end-anchored to prevent `serious-evil/` bypass. Template key allowlist enforced on fresh install.
  - 32 new supply-chain tests covering 7 attack probes.

- **Path canonicalization** — 6 Stop hooks updated to use `resolve_breadcrumb_path` from `_shared/path-resolve.sh`. Replaces glob-pattern rejection with `cd -P && pwd -P` + trust-root prefix check. TOCTOU mitigation via symlink re-check. CI lint blocks new glob-pattern usage. 18 attack-vector tests.

---

## [1.6.0] — 2026-04-05

### Breadcrumb silence + staleness detection

#### Changed

- **Skills no longer narrate "No active breadcrumbs"** during normal advancing workflows. This was noise — the previous skill completed and cleaned up its breadcrumb. Normal state, no output needed.

- **Stale breadcrumbs auto-detected** — If a breadcrumb's target file has `status: done` or `abandoned`, the breadcrumb is removed silently. If the breadcrumb file is older than 4 hours and status is `active`, the user is prompted.

- **`debug(8)` added to pipeline order** in all 9 skill files and CLAUDE.md. Pipeline is now: `youtube-tldr(0.5) → conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7) → debug(8)`.

---

## [1.4.0] — 2026-03-29

### Mechanical enforcement gap closed

9 enforcement gaps identified by `/serious-research` — things the system called "mandatory" but didn't mechanically enforce.

#### Fixed

- **Gaps 1-3, 5, 7-9 closed** via Stop hook extensions (zero new hook types):
  - Review agent verification: verdict must contain all mandatory agent signatures
  - Dispatch log validation: `/serious-code` must dispatch all 5 agent types per task
  - Upstream extraction check: plan must cross-reference `_extracted_items.md`
  
- **All 9 hooks converted to fail-closed** — Unexpected errors block instead of silently passing. `exit 1` on unknown state replaced with `exit 2` (block) across all hooks.

---

## [1.5.0] — 2026-03-31

### Worktree-safe hooks + pre-existing bug sweep

All 15 hook scripts were silently bypassing enforcement when running in git worktrees — the exact parallel execution mode `/serious-code` was designed for. This release fixes that, plus 8 pre-existing bugs found while editing every file.

#### Fixed

- **Worktree breadcrumb resolution** — All 15 hooks now use `PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"` to find breadcrumb files instead of assuming CWD is the project root. In worktrees, CWD changes to the worktree path, causing every hook to exit 0 (allow) — a complete fail-open bypass. Fixed with a consistent prefix pattern across all hooks.
- **Path traversal protection** — 6 Stop hooks now validate breadcrumb content, rejecting absolute paths (`/...`) and traversal sequences (`../`) before path construction. Warns to stderr on rejection.
- **PROJECT_ROOT directory validation** — All 15 hooks verify `$CLAUDE_PROJECT_DIR` points to an existing directory before proceeding.
- **Extension allowlists expanded** — `check-verdict.sh` and `review-theater-gate.sh` now recognize 25 file extensions (was 5-7). Covers tsx, jsx, go, rs, java, kt, c, cpp, cs, swift, css, scss, html, vue, svelte, and more. Prevents false "zero file:line references" warnings for non-JS/TS stacks.
- **Missing `+` quantifier** — `check-verdict.sh` `lines [0-9]` changed to `lines [0-9]+` (was only matching single-digit line numbers).
- **Word boundary on pass/fail detection** — `check-verdict.sh` changed from `grep -qi 'pass'` to `grep -qiE '\bpass\b'` (was matching "password", "bypass"). Consistent with the fix already in `verify-completion-gate.sh`.
- **Frontmatter parsing limit** — `head -20` changed to `head -50` across 9 occurrences in 4 hooks. Prevents truncation as frontmatter grows with verification stamps.
- **"if needed" false positive** — Removed from `hedge-language-gate.sh` pattern list. Too common in legitimate technical prose.
- **Hedge pattern sync** — `check-extraction.sh` hedge patterns updated to match `hedge-language-gate.sh` (was 4 patterns, now 6).
- **"review" filename matching** — `review-theater-gate.sh` changed from `verdict|review` to `verdict` only. Prevents false triggers on `code_review.json` and similar evidence files.

#### Changed

- **9 test scripts restructured** — All tests now use a simulated project root with `CLAUDE_PROJECT_DIR` export and relative breadcrumb paths, matching production behavior.
- **New test suite** — `tests/hooks/test_worktree_simulation.sh` (12 scenarios) verifies hooks work when CWD differs from `CLAUDE_PROJECT_DIR`. Covers PreToolUse hooks, Stop hooks, content resolution, fallback, path traversal rejection, and negative cases.

---

## [1.3.0] — 2026-03-25

### Pipeline split: scope, review-before-code

The pipeline grew from 6 steps to 7. Two new skills change how work flows through the system.

#### Breaking Changes

- **`/serious-review` now runs before `/serious-code` (plan quality gate), not after.** The old workflow was `plan → code → review → done`. The new workflow is `scope → plan → review → code → done`. If you were using `/serious-review` after code to capture bugs, that workflow no longer exists. Review is now a mandatory quality gate between planning and coding. Post-code defect capture will move to `/serious-qa` in a future release.

#### Added

- **`/serious-scope`** — New skill at pipeline position 4. Generates a scope manifest from research findings. Defines plan boundaries, dependencies, shared contracts, and tags. Splits complex implementations into discrete, independently-plannable units. The manifest is consumed by `/serious-plan`.

- **Pipeline expanded to 7 steps** — `conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7)`. All breadcrumb scan lists, pipeline ordering strings, and self-order numbers updated across all skills.

- **Handoff verifier: `research → scope` transition** — The handoff verifier now validates that scope manifests align with research findings using structural matching.

#### Changed

- **`/serious-plan` narrowed to single-plan generation** — No longer supports multiple plans or phase maps directly. Scope splitting is now handled by `/serious-scope` upstream.

- **`/serious-review` repurposed as plan quality gate** — Uses adaptive persona pipeline with anti-slop auditor and structural reviewer agents. Runs before code, not after.

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

[1.7.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/AntoineDubuc/serious-sidekick/releases/tag/v1.0.0
