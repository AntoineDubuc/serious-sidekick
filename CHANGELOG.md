# Changelog

All notable changes to Serious Sidekick are documented here. Written for humans — if you're a PM, you can read this and know exactly what changed and why it matters.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [Semantic Versioning](https://semver.org/).

---

## [1.10.0] — 2026-08-08

### Phantom references blocked at write time, and the skills you already had are finally installable

Two skills existed on disk but were effectively invisible: `/serious-fit` had never been committed at all, and `/serious-debloat` shipped in the manifest but appeared in no skill list, so nobody knew it was there. This release closes the gap between "written" and "distributed," and adds a hook that blocks a plan or research doc from citing a file:line that does not exist.

#### Added
- **`/serious-fit` skill** — a codebase-grounded restraint pass that runs after `/serious-review` and before `/serious-code`. Four questions against the real source: does this DUPLICATE something that already exists, is every new piece minimal, does it FIT the code's conventions, does it stay self-consistent (fix X without leaving copy or behavior that contradicts X). Recommend-only — it proposes the smallest COMPLETE version and a human verifies every cut. It had been in use locally for weeks while living in no commit; the missing manifest entry was also what dirtied the working tree on every `serious-update` run and aborted the next `git pull`.
- **Phantom-reference hook** (`serious-research/hooks/validate-refs.sh`) — a PreToolUse gate that BLOCKS writing any `Research/**.md` citing a `file:line` that does not resolve: no such file, or a line past end-of-file. Fenced code blocks and URLs are ignored. Project-agnostic: a reference is "claimed by this project" when its first path segment is a real directory at the project root.
- **Plan-authoring gate on `/serious-plan`** — the plan is written by a subagent; the orchestrator may only review it. Evidence: the orchestrating agent wrote five consecutive drafts of one plan, all five FAILED review (17 CRITICAL, 26 MAJOR, several findings repeating across four rounds), consistently asserting paths and symbols from memory rather than opening them. A reviewer authoring the same plan from the same evidence reached a clean PASS.

#### Fixed
- **The phantom-reference hook could never fire.** It shipped at `skills/_shared/`, but the distributor only merges hook commands matching `skills/serious-<name>/hooks/<file>.sh` — a supply-chain check against path traversal. Any registration at the old path was silently filtered out of every install. Moved under `serious-research/hooks/` and registered, scoped to `Write(*Research/*.md)` and `Edit(*Research/*.md)`.
- **Skill rosters were two skills behind reality.** `/serious-fit` and `/serious-debloat` are now listed in the README, the project `CLAUDE.md` template, the landing guide, and `/serious-init`. The agent count in `/serious-init` was also stale (8 → 10, now 5 code + 5 review), and `/serious-init` now records *why* `serious-prospect-research` is absent from every install — it carries internal sales positioning and is deliberately skipped by the manifest generator.
- **Generated files no longer dirty the tree.** `staleness.json` and `update.log` are ignored; a dirty tree is what aborted a `git pull` in July per the audit log.

#### Note for maintainers
The installer, updater and `/serious-init` needed **no code change** to pick any of this up — all three are manifest-driven and enumerate skills from `manifest.json`. Adding a skill is: commit the skill, regenerate the manifest, commit that too. Skipping the regenerate is what produces the recurring pull conflict.

---

## [1.9.0] — 2026-07-12

### Code-aware review + a debloat pass — catch wrongness AND over-building before code

The cold-read reviewers (anti-slop, structural, security) judge a plan on its own words — they can't open the codebase. That let two whole classes of defect through: a plan that's beautifully written but **wrong against the real source** (an inert/partial fix, a half-coupled change, a bug that's already fixed), and a plan that's correct but **twice the size it needs to be** (a helper that already exists, a fix broader than the bug). Both bit us repeatedly. This release adds two code-aware reviewers and a standalone trim pass, and makes the review gate actually enforce them.

#### Added
- **`serious-review-correctness` agent** — the code-aware correctness reviewer. Reads the real codebase to verify a plan's technical claims, that the fix covers *every* path the bug can take (not just the one the author noticed), that coupled changes are complete, and that the premise is still true. This is the reviewer that caught two critical regressions and a "guarded 1 of 3 hang sites" partial fix that all three cold-read agents passed clean.
- **`serious-review-restraint` agent** — the code-aware bloat reviewer. Reads the codebase to flag reinvented idioms ("this helper already exists at file:line"), over-broad fixes, and new scaffolding, with a **premise-check-first** rule (a lean plan for a non-existent bug is worse than a bloated one) and a hard rule to never trust a `grep` miss for existence (the sandbox grep silently skips binary-looking files — a real false-negative that produced a confidently wrong claim).
- **`/serious-debloat` skill** — a standalone restraint pass you can point at a plan *or* a real diff (`--staged`, `--branch <base>`, `--apply`). Report-first; applies only tradeoff-free cuts on request. It's the "trim what's written" counterpart to `serious-simple-plan`'s "write it lean."

#### Changed
- **`/serious-review` now runs 5 mandatory reviewers** (was 3): the cold-read trio plus restraint and correctness. Restraint is advisory-strong (bloat is flagged, doesn't by itself fail the gate); correctness counts toward the verdict like the trio.
- **The review Stop-hook (`check-verdict.sh`) now enforces all 5** agent sections in `review_verdict.md`, so the two new reviewers are genuinely required, not just documented. Section-header contract and its tests updated accordingly.

#### Why it matters
"Plan passes review, code doesn't work" and "plan ships twice the change it needed" are the two failure modes this closes. A well-written plan is no longer enough — a reviewer now opens the code and checks it's right and minimal.

---

## [1.8.0] — 2026-04-14

### Observability spike — silent-pass events become visible

Shipped as a panel-endorsed spike, not a plan. The 9-plan observability roadmap (`enforcement-theater-meta-failure` research) was abandoned when the P1 plan failed review twice with the exact pathology the research catalogued. A 5-persona `/serious-conversation` panel converged on: ship the smallest thing that produces data, adopt process reforms after the log justifies them.

#### Added

- **`_log_outcome` helper at `.claude/skills/_shared/log-outcome.sh`** — 50-line shell function. Every hook that sources it can log TSV records to `.claude/logs/outcomes.log`. 7 fields: `ts_utc`, `hook`, `verdict`, `file_path`, `reason`, `pid`, `duration_ms`. Verdict enum: `SKIP | ALLOW | BLOCK | PASS | ERROR`. Newlines/tabs stripped from attacker-controllable strings. Diagnostic only — NOT a security control (banner expires on first automated consumer).

- **All 5 enforcement hooks instrumented** — `tdd-gate`, `hedge-language-gate`, `review-theater-gate`, `verify-completion-gate`, `check-verdict` now call `_log_outcome` at every exit site. Silent-pass paths (empty tool input, missing content field, non-matching filename, missing breadcrumb) now produce `SKIP` records with specific reasons instead of exiting 0 invisibly.

- **Test suite** — `tests/hooks/test_log_outcome_spike.sh`. 14 assertions covering the helper unit-tested, injection defense (newlines/tabs in reason), enum guard, concurrent invocation, and per-hook end-to-end. All green. Standalone invocation only (not in `run_tests.sh` glob — intentional, prove standalone first).

- **`.gitignore`** — excludes `.claude/logs/*.log*` so diagnostic logs don't commit.

#### What this closes and what it doesn't

Closes: the "silent-pass is invisible" problem the upstream research documented. Every future analysis has empirical data about which hooks fire, which verdicts, and on what file paths.

Does NOT close: log tampering, concurrent-write corruption, cross-tenant isolation, forensic attribution. Those are explicitly left for a follow-on plan — but only after real log data justifies the scope (panel rule: spike first, harden later).

#### Process changes (decided, not yet shipped)

- **200-line threshold rule** — fixes under 200 lines / ≤3 files / no cross-session contracts ship as single commits, skipping scope/plan/review. Documented in `Research/conversations/quality-in-planning/summary.md`.
- **Paste-before-claim discipline** — every technical claim in a plan must include pasted command output. Adopt after log data justifies the overhead.
- **Threat Model Block** — for enforcement-adjacent plans only. Defer until next enforcement-adjacent plan.

#### Abandoned

- **Cold-read-enforcement plan** (`Research/features/cold-read-enforcement/`) — status set to `abandoned`. Failed review twice with identical meta-pattern. The feature idea may return after observability data shows whether cold-read violations actually happen.
- **P1 obs-foundation plan** (`Research/bugs/enforcement-theater-meta-failure/plans/p1-obs-foundation/`) — status set to `abandoned`. Specified `flock`, `jq -cn`, rotation, 16-hex hashes, file modes — all explicitly out of scope for the spike.

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
