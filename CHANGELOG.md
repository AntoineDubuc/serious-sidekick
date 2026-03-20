# Changelog

All notable changes to Serious Sidekick are documented here. Written for humans — if you're a PM, you can read this and know exactly what changed and why it matters.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [Semantic Versioning](https://semver.org/).

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

[1.1.0]: https://github.com/AntoineDubuc/serious-sidekick/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/AntoineDubuc/serious-sidekick/releases/tag/v1.0.0
