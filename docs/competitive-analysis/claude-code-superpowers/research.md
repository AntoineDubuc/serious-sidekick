# Competitive Analysis: Claude Code Superpowers

**Repository:** https://github.com/obra/superpowers
**Creator:** Jesse Vincent (obra) / Prime Radiant
**License:** MIT
**Stars:** 115,202 | **Forks:** 9,225 | **Open Issues:** 165
**Latest Release:** v5.0.6 (March 25, 2026)
**Created:** October 9, 2025
**Tagline:** "An agentic skills framework & software development methodology that works."

---

## 1. Overview

Superpowers is a **multi-platform** agentic skills framework that provides a structured software development methodology for AI coding agents. Unlike tools that target a single platform, Superpowers works across **five platforms simultaneously**: Claude Code, Cursor, Codex, OpenCode, and Gemini CLI.

The framework implements a seven-phase sequential workflow:
1. **Brainstorming** — Refine specs through dialogue, present design sections for approval
2. **Git Worktrees** — Establish isolated development branches with baseline testing
3. **Writing Plans** — Decompose work into 2-5 minute tasks with exact specs
4. **Execution** — Subagent-driven or batch development with quality reviews
5. **Test-Driven Development** — RED-GREEN-REFACTOR cycles with mandatory testing
6. **Code Review** — Severity-based feedback with blocking for critical issues
7. **Branch Completion** — Verification and merge/PR decision workflow

**Language breakdown:** Shell 57.4%, JavaScript 30.6%, HTML 4.4%, Python 3.9%, TypeScript 2.9%

**Target audience:** Developers using AI coding agents who want structured, repeatable workflows rather than ad-hoc prompting. The framework is opinionated about process (TDD mandatory, plans before code, verification before claims).

---

## 2. Architecture

### Directory Layout

```
superpowers/
├── .claude-plugin/                       # Claude Code plugin manifest
│   ├── plugin.json                       # Plugin metadata (name, version, author, keywords)
│   └── marketplace.json                  # Dev marketplace registration
├── .cursor-plugin/                       # Cursor IDE plugin
│   └── plugin.json                       # Points to skills/, agents/, commands/, hooks/
├── .codex/                               # Codex platform
│   └── INSTALL.md
├── .opencode/                            # OpenCode platform
│   ├── INSTALL.md
│   └── plugins/                          # JS plugin for OpenCode
├── agents/
│   └── code-reviewer.md                  # Dedicated code review agent definition
├── commands/
│   ├── brainstorm.md                     # DEPRECATED — redirects to skill
│   ├── execute-plan.md                   # DEPRECATED — redirects to skill
│   └── write-plan.md                     # DEPRECATED — redirects to skill
├── skills/                               # 14 skill directories (see Section 3)
├── hooks/
│   ├── hooks.json                        # Claude Code hook config
│   ├── hooks-cursor.json                 # Cursor hook config
│   ├── run-hook.cmd                      # Windows hook runner
│   └── session-start                     # Bash: injects skill context at session start
├── docs/
│   ├── superpowers/
│   │   ├── specs/                        # Design spec documents (date-prefixed)
│   │   └── plans/                        # Implementation plan documents (date-prefixed)
│   ├── plans/                            # Historical plans
│   ├── windows/                          # Windows-specific docs
│   ├── testing.md                        # Comprehensive test framework docs
│   ├── README.codex.md
│   └── README.opencode.md
├── tests/                                # Integration test suites
│   ├── brainstorm-server/
│   ├── claude-code/                      # Headless Claude Code integration tests
│   ├── explicit-skill-requests/
│   ├── opencode/
│   ├── skill-triggering/
│   └── subagent-driven-dev/
├── CHANGELOG.md
├── RELEASE-NOTES.md
├── GEMINI.md                             # Gemini CLI system prompt
├── gemini-extension.json                 # Gemini extension manifest
├── package.json                          # v5.0.6, ES module
└── README.md
```

### Multi-Platform Architecture

The most distinctive architectural decision is **cross-platform support**. Each platform has a separate plugin directory with platform-specific manifests:

| Platform | Plugin Dir | Config |
|----------|-----------|--------|
| Claude Code | `.claude-plugin/` | `plugin.json` + `marketplace.json` |
| Cursor | `.cursor-plugin/` | `plugin.json` (refs skills/, agents/, commands/, hooks/) |
| Codex | `.codex/` | `INSTALL.md` |
| OpenCode | `.opencode/` | `INSTALL.md` + JS plugin |
| Gemini CLI | root | `GEMINI.md` + `gemini-extension.json` |

### Plugin Distribution

Superpowers is distributed via the **Claude Code marketplace** (first-party plugin system) and manual installation for other platforms. The `marketplace.json` registers it as a dev marketplace plugin. Installation for Claude Code users is a single marketplace install action.

### Skill Loading Architecture

Skills use Anthropic's first-party skill system (adopted in v3.0+):
- **Metadata pre-loads at session start** (name + description only)
- **SKILL.md reads on-demand** when a skill is invoked
- Supporting files are read only when needed
- This is token-efficient: unused skills cost near-zero context

The `using-superpowers` meta-skill enforces a **1% rule**: "If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill."

### Document Output Convention

Plans and specs are saved to dated paths:
- Specs: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Plans: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

---

## 3. Skills Inventory (14 Skills)

### Core Workflow Skills

| Skill | Files | Purpose | Key Details |
|-------|-------|---------|-------------|
| **brainstorming** | SKILL.md, visual-companion.md, spec-document-reviewer-prompt.md, scripts/ | Structured design dialogue before implementation | 9-step process. Hard gate: NO implementation until design approved. One question per message. Multiple choice preferred. Includes visual companion (browser-based mockups via WebSocket server). Spec self-review via subagent. |
| **writing-plans** | SKILL.md, plan-document-reviewer-prompt.md | Decompose work into 2-5 minute atomic tasks | Each step = one atomic action. Plans contain actual code, not placeholders. No TBD/TODO allowed. Self-review subagent checks spec coverage. Two execution paths offered after writing. |
| **executing-plans** | SKILL.md | Execute pre-written implementation plans | Load plan, critical review, execute tasks step-by-step, mark progress. Halt on blockers. Never start on main/master without consent. Transitions to finishing-a-development-branch. |
| **subagent-driven-development** | SKILL.md, implementer-prompt.md, code-quality-reviewer-prompt.md, spec-reviewer-prompt.md | Orchestrate per-task subagents with two-stage review | Fresh subagent per task. Two-stage review: spec compliance first, then code quality. Model selection by task complexity. Status protocol: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED. |
| **finishing-a-development-branch** | SKILL.md | Branch completion and merge workflow | 5 steps: verify tests, determine base branch, present 4 options (merge/PR/keep/discard), execute, cleanup worktree. Typed confirmation for destructive actions. |

### Development Practice Skills

| Skill | Files | Purpose | Key Details |
|-------|-------|---------|-------------|
| **test-driven-development** | SKILL.md, testing-anti-patterns.md | Enforce RED-GREEN-REFACTOR TDD | The "iron principle": write test first, watch fail, write minimal code. If code written before test, DELETE it (no exceptions). Extensive rationalization rebuttals. Red flags requiring restart. Anti-patterns reference covers 5 common mistakes. |
| **systematic-debugging** | SKILL.md + 8 supporting files | Root-cause analysis debugging | 4 phases: Root Cause Investigation, Pattern Analysis, Hypothesis & Testing, Implementation. "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST." If 3+ fixes fail, question architecture. Supporting files: root-cause-tracing.md, defense-in-depth.md, condition-based-waiting.md, find-polluter.sh, plus test pressure scenarios. |
| **verification-before-completion** | SKILL.md | Pre-completion verification checks | "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE." Must run actual commands, read actual output, check actual exit codes. Anti-rationalization table. References 24 failure memories. |
| **using-git-worktrees** | SKILL.md | Isolated workspace creation | 3-tier directory selection. Safety verification (git check-ignore). Auto-detects project tooling (npm/cargo/pip/go). Baseline test execution. |

### Collaboration Skills

| Skill | Files | Purpose | Key Details |
|-------|-------|---------|-------------|
| **requesting-code-review** | SKILL.md, code-reviewer.md | Dispatch code review subagent | Uses git SHAs for diff-based review. Template-based reviewer dispatch. Severity: Critical/Important/Minor. Integration with subagent-driven-dev and executing-plans. |
| **receiving-code-review** | SKILL.md | Process code review feedback | Anti-performative: NEVER say "You're absolutely right!" or "Great point!" Verify before implementing. YAGNI checks. Push back when reviewer is wrong. "Strange things are afoot at the Circle K" as discomfort signal. |
| **dispatching-parallel-agents** | SKILL.md | Coordinate concurrent subagents | For 3+ failures across different domains. Group by domain, design focused tasks, launch concurrently, integrate results. Quality prompt guidance. |

### Meta Skills

| Skill | Files | Purpose | Key Details |
|-------|-------|---------|-------------|
| **using-superpowers** | SKILL.md, references/ | Framework introduction and enforcement | 1% rule for skill invocation. Instruction hierarchy: user > skills > system prompt. Platform-specific tool references. Skill classification: rigid vs. flexible. |
| **writing-skills** | SKILL.md + 5 supporting files | How to create custom skills | TDD applied to skill creation: write pressure tests, watch agent fail, write skill addressing failures. Description optimization ("Use when..." format). Token budgets (<500 lines). Persuasion principles from research. Anthropic best practices reference. |

---

## 4. Hooks

### Hook Configuration

Superpowers uses a **single hook** — `SessionStart` — configured in two files:

**hooks.json (Claude Code):**
```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|clear|compact",
      "hooks": [{
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
        "async": false
      }]
    }]
  }
}
```

**hooks-cursor.json (Cursor):** Same pattern adapted for Cursor's hook format.

### session-start Script

The `session-start` hook script:
1. Determines plugin root directory
2. Checks for legacy config at `~/.config/superpowers/skills` (migration warning)
3. Reads `using-superpowers/SKILL.md` content
4. Escapes content for JSON embedding
5. Wraps in `EXTREMELY_IMPORTANT` context marker
6. Outputs platform-specific JSON:
   - **Cursor:** `additional_context` field
   - **Claude Code:** `hookSpecificOutput.hookEventName` + `hookSpecificOutput.additionalContext`
   - **Fallback:** `additional_context`

**Key insight:** The session-start hook injects the `using-superpowers` meta-skill content directly into the session context, ensuring the framework's enforcement rules (1% invocation rule, instruction hierarchy) are always active. This is how Superpowers "bootstraps" itself.

### Comparison to Our Hooks

Superpowers uses hooks **minimally** — just one SessionStart hook for bootstrapping. We use 6 hooks (PreToolUse, PostToolUse, Stop, etc.) for more granular workflow control. Their approach is simpler but less powerful for enforcement.

---

## 5. Templates and Prompts

### Subagent Prompt Templates

Superpowers includes **5 specialized prompt templates** for subagent dispatch:

| Template | Location | Purpose |
|----------|----------|---------|
| **Implementer Prompt** | `subagent-driven-development/implementer-prompt.md` | Per-task implementation subagent. Includes pre-implementation checkpoint, self-review, status reporting (DONE/BLOCKED/NEEDS_CONTEXT). |
| **Spec Compliance Reviewer** | `subagent-driven-development/spec-reviewer-prompt.md` | First-stage review. Skeptical by design: "The implementer finished suspiciously quickly." Line-by-line comparison against requirements. Binary output: compliant or issues found. |
| **Code Quality Reviewer** | `subagent-driven-development/code-quality-reviewer-prompt.md` | Second-stage review. Only runs after spec compliance passes. Checks SRP, independence, structural compliance, file growth. Uses the code-reviewer agent template. |
| **Spec Document Reviewer** | `brainstorming/spec-document-reviewer-prompt.md` | Validates spec completeness, consistency, clarity, scope. High threshold — only real issues, not stylistic preferences. |
| **Plan Document Reviewer** | `writing-plans/plan-document-reviewer-prompt.md` | Validates plan completeness, spec alignment, task decomposition, buildability. |

### Agent Definition

| Agent | Location | Purpose |
|-------|----------|---------|
| **code-reviewer** | `agents/code-reviewer.md` | Comprehensive code review agent. 6 responsibility areas: plan alignment, code quality, architecture/design, documentation, issue identification (Critical/Important/Suggestion), and communication protocol. |

### Document Templates

Plans and specs follow date-prefixed naming convention. No formal template file exists — the structure is defined inline within the `writing-plans` and `brainstorming` skills.

### Visual Companion

The brainstorming skill includes a **browser-based visual companion** (`visual-companion.md` + `scripts/`):
- WebSocket-based server using zero dependencies (Node.js built-ins only)
- Monitors a directory for HTML files, serves the newest one
- Users click to select options; interactions recorded to JSON events file
- Pre-built CSS classes: `.options`, `.cards`, `.mockup`, `.split`, `.pros-cons`
- Frame template provides consistent UI wrapper
- Auto-exits after 30 minutes of inactivity

---

## 6. Key Differentiators

### 6.1 Multi-Platform Support

The biggest differentiator. Superpowers works on 5 platforms while most frameworks target one. This means:
- Larger potential user base
- Skills are platform-agnostic markdown
- Platform-specific concerns isolated to plugin directories
- Users can switch platforms without losing methodology

### 6.2 Persuasion-Based Skill Design

The `writing-skills` skill includes a `persuasion-principles.md` file citing a 2025 study showing persuasion techniques doubled AI compliance rates (33% to 72%). Skills deliberately use:
- **Authority:** "YOU MUST", "No exceptions"
- **Commitment:** Require explicit announcements before actions
- **Social Proof:** Establish universal patterns
- **Scarcity:** Time constraints and sequential dependencies

This is backed by actual research and consciously applied across all skills.

### 6.3 TDD Applied to Skill Creation

The `writing-skills` skill applies TDD methodology to documentation itself:
- **RED:** Run scenarios WITHOUT the skill, document agent failures
- **GREEN:** Write minimal skill addressing observed failures
- **REFACTOR:** Identify new rationalizations, add explicit counters

Skills are tested against "pressure scenarios" combining 3+ pressures (time, sunk cost, authority) to ensure they work under realistic conditions.

### 6.4 Anti-Rationalization Engineering

Nearly every skill includes explicit tables mapping common rationalizations to rebuttals:
- "Issue is simple, don't need process" → "Simple issues have root causes too"
- "Emergency, no time for process" → "Systematic debugging is FASTER than thrashing"
- "Just try this first" → "First fix sets the pattern"

This is more thorough than typical frameworks at preventing agents from cutting corners.

### 6.5 Two-Stage Code Review

The subagent-driven-development workflow uses **two separate review stages**:
1. **Spec compliance review** — Did the implementer build what was specified? (skeptical by design)
2. **Code quality review** — Is the implementation well-structured? (only runs after spec passes)

This separation prevents quality review from overshadowing functional correctness.

### 6.6 The "1% Rule" for Skill Invocation

The meta-skill `using-superpowers` mandates: "If you think there is even a 1% chance a skill might apply, you ABSOLUTELY MUST invoke the skill." This aggressive threshold ensures skills are actually used rather than forgotten.

### 6.7 Status Protocol for Subagents

Implementer subagents report one of four statuses:
- **DONE** — Proceed to review
- **DONE_WITH_CONCERNS** — Review concerns, proceed if minor
- **NEEDS_CONTEXT** — Provide missing info, re-dispatch
- **BLOCKED** — Assess cause, may need model upgrade or task decomposition

### 6.8 Visual Brainstorming Companion

A zero-dependency Node.js WebSocket server that renders HTML mockups in the browser during brainstorming. Users interact by clicking options; events are recorded for the agent to process. This bridges the gap between text-based agent interaction and visual design work.

### 6.9 Anthropic Best Practices Integration

The `writing-skills/anthropic-best-practices.md` file is a comprehensive guide to skill authoring incorporating Anthropic's own recommendations:
- Progressive disclosure (SKILL.md as table of contents)
- Cross-model testing (Haiku, Sonnet, Opus)
- Token budget guidelines (<500 lines for SKILL.md)
- Filesystem-based architecture for minimal token consumption
- "Solve, don't punt" philosophy for scripts

### 6.10 Integration Test Suite

Superpowers has a real test suite that:
- Runs Claude Code in headless mode
- Parses JSONL session transcripts
- Verifies skill invocation, subagent dispatch, TodoWrite usage
- Includes token usage analysis (`analyze-token-usage.py`)
- Tests take 10-30 minutes (real integration, not mocks)

---

## 7. Complete Feature Inventory

### Workflow Features
- [x] Brainstorming with structured dialogue
- [x] Design spec writing with self-review
- [x] Plan decomposition into 2-5 minute tasks
- [x] Plan execution with progress tracking
- [x] Subagent-driven development (fresh agent per task)
- [x] Two-stage code review (spec compliance + quality)
- [x] Branch completion with 4 options (merge/PR/keep/discard)
- [x] Git worktree management with auto-tooling detection
- [x] Parallel agent dispatch for independent problems
- [x] Visual brainstorming companion (browser-based)

### Development Practice Features
- [x] TDD enforcement (RED-GREEN-REFACTOR, iron principle)
- [x] Systematic debugging (4-phase root cause analysis)
- [x] Testing anti-patterns reference
- [x] Root cause tracing technique
- [x] Defense-in-depth validation pattern
- [x] Condition-based waiting (anti-flaky-test)
- [x] Test polluter detection script (`find-polluter.sh`)
- [x] Verification-before-completion enforcement

### Meta/Extensibility Features
- [x] Custom skill authoring guide with TDD methodology
- [x] Persuasion principles for effective skill design
- [x] Anthropic best practices integration
- [x] Skill testing with subagent pressure scenarios
- [x] CLAUDE.md testing reference
- [x] Graphviz conventions for flowcharts

### Platform Features
- [x] Claude Code marketplace plugin
- [x] Cursor plugin support
- [x] Codex support
- [x] OpenCode support (with JS plugin)
- [x] Gemini CLI extension
- [x] Windows/WSL cross-platform support
- [x] Session-start hook bootstrapping

### Documentation Features
- [x] Date-prefixed specs and plans
- [x] Comprehensive release notes and changelog
- [x] PR and issue templates
- [x] Platform-specific installation guides
- [x] Testing documentation with transcript analysis

---

## 8. Comparison with Serious Sidekick

### What They Have That We Don't

| Superpowers Feature | Impact | Adoption Difficulty |
|---------------------|--------|---------------------|
| **Multi-platform support** (5 platforms) | Massive reach advantage (115K stars) | High — requires maintaining 5 plugin formats |
| **Visual brainstorming companion** (browser-based mockups) | Bridges text/visual gap during design | Medium — WebSocket server + HTML templates |
| **Marketplace distribution** (Claude Code marketplace) | One-click install for users | Medium — requires Anthropic marketplace approval |
| **Persuasion-based skill design** (research-backed) | Measurably higher agent compliance | Low — adopt principles in our skill writing |
| **Anti-rationalization tables** in every skill | Prevents agents from cutting corners | Low — add tables to our existing skills |
| **TDD for skill creation** (pressure scenario testing) | Skills tested against real failure modes | Medium — need to build test infrastructure |
| **Subagent status protocol** (DONE/BLOCKED/NEEDS_CONTEXT) | Clearer orchestration communication | Low — formalize in our /serious-code |
| **Two-stage code review** (spec then quality) | Better separation of concerns | Low — already have review in /serious-review |
| **Integration test suite** (headless Claude Code + transcript parsing) | Verifiable skill behavior | High — sophisticated test infrastructure |
| **Token usage analysis** tool | Cost visibility per subagent/task | Low — useful standalone tool |
| **Systematic debugging skill** with supporting techniques | Deep debugging methodology | Medium — significant content to create |
| **`receiving-code-review` skill** (anti-performative feedback) | Better quality review responses | Low — adopt anti-performative principles |
| **1% skill invocation rule** | Ensures skills are actually used | Low — adopt in our meta-skill guidance |
| **Condition-based waiting** for test reliability | Eliminates flaky tests | Low — reference material |
| **Test polluter detection** script | Identifies test interference | Low — single shell script |
| **Anthropic best practices** for skill authoring | Better skill quality | Low — reference material |

### What We Have That They Don't

| Serious Sidekick Feature | Our Advantage |
|--------------------------|---------------|
| **Persona panel discussions** (/serious-conversation) | No equivalent — they brainstorm 1-on-1 with the agent |
| **UI mock-ups skill** (/serious-mock-ups) with 3 fidelity levels | They have visual companion but it's brainstorming-only, not dedicated mockup workflow |
| **Scope manifests** (/serious-scope) | No equivalent — they go straight from brainstorming to plans |
| **Implementation plan template** (v6) | They define plan structure inline; we have a versioned, reusable template |
| **Plan quality gate** (/serious-review) with agent reviewers | They have plan-document-reviewer but less structured |
| **Workflow frontmatter standard** (YAML tracking) | No equivalent — they use date-prefixed filenames only |
| **Breadcrumb files** (.active-{skill}) for status tracking | No equivalent — no cross-skill state tracking |
| **Pipeline order enforcement** (advancing vs branching) | No equivalent — their skills are more loosely coupled |
| **Handoff verification** with source hash checking | No equivalent |
| **39 Claude Code feature docs** | They have no feature documentation library |
| **6 Stop/PreToolUse/PostToolUse hooks** | They use only 1 SessionStart hook |
| **Deep workflow orchestration** (7 skills in strict pipeline) | Their 14 skills are more loosely organized |

### What We Both Have (Overlapping)

| Capability | Their Approach | Our Approach |
|------------|---------------|--------------|
| Brainstorming/Design | `brainstorming` skill — 9-step dialogue | `/serious-conversation` — persona panel |
| Plan writing | `writing-plans` — 2-5 min atomic tasks | `/serious-plan` — v6 template with TDD protocol |
| Plan execution | `executing-plans` + `subagent-driven-development` | `/serious-code` — 5 agent teams in worktrees |
| Code review | `requesting-code-review` + `receiving-code-review` + agent | `/serious-review` — anti-slop auditor + structural reviewer |
| TDD | `test-driven-development` — iron principle, anti-patterns | Built into `/serious-code` TDD cycles |
| Git worktrees | `using-git-worktrees` — auto-tooling detection | Built into `/serious-code` parallel execution |
| Verification | `verification-before-completion` — evidence before claims | Built into pipeline frontmatter verification |
| Parallel agents | `dispatching-parallel-agents` | Built into `/serious-code` worktree-based parallelism |

### Key Differences in Philosophy

| Dimension | Superpowers | Serious Sidekick |
|-----------|-------------|------------------|
| **Coupling** | Loosely coupled skills, invoked by 1% rule | Strict pipeline with frontmatter tracking |
| **Platform** | Multi-platform (5 platforms) | Claude Code exclusive |
| **Personas** | No persona system | 10 built-in personas + custom |
| **Enforcement** | Persuasion psychology + anti-rationalization tables | Hooks + frontmatter + breadcrumbs |
| **Distribution** | Marketplace plugin (one-click install) | Template repo (clone to start) |
| **Testing** | Integration tests with headless Claude Code | No equivalent test infrastructure |
| **Skill authoring** | TDD for skills, anthropic best practices, persuasion research | Skill files without formal testing methodology |
| **Scope** | Software development methodology | Broader workflow framework (research, conversations, mockups) |
| **Debug methodology** | Dedicated systematic-debugging skill (deep) | No dedicated debugging workflow |

---

## 9. Adoption Recommendations

### High Priority (Low Effort, High Impact)

1. **Anti-rationalization tables** — Add to all our skill files. Map common excuses to rebuttals. Superpowers proves this significantly improves compliance.

2. **1% invocation rule** — Add to our meta-skill guidance. "If there's a 1% chance a skill applies, invoke it."

3. **Persuasion principles** — Apply Authority, Commitment, and Social Proof patterns to our skill writing. Backed by research showing 2x compliance improvement.

4. **Anti-performative code review** — Adopt the "receiving-code-review" principles: never say "Great point!", verify before implementing, push back when wrong.

5. **Subagent status protocol** — Formalize DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED in `/serious-code`.

### Medium Priority (Medium Effort)

6. **Systematic debugging skill** — Create a `/serious-debug` skill based on their 4-phase methodology. Their supporting techniques (root-cause tracing, defense-in-depth, condition-based waiting) are excellent.

7. **Verification-before-completion** — Add explicit verification enforcement. "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE."

8. **TDD for skill creation** — Adopt their methodology: write pressure scenarios, test without skill, document failures, write skill addressing them.

9. **Token usage analysis** — Build a tool to analyze session costs per subagent/task.

### Lower Priority (High Effort or Strategic)

10. **Multi-platform support** — Major strategic decision. Would massively increase reach but requires maintaining multiple plugin formats.

11. **Marketplace distribution** — Publish to Claude Code marketplace for easier adoption.

12. **Visual brainstorming companion** — Enhance `/serious-mock-ups` with their browser-based approach.

13. **Integration test suite** — Build headless Claude Code tests that verify our skill behaviors.

---

## 10. Version History Context

| Version | Date | Key Changes |
|---------|------|-------------|
| v2.0.0 | 2025-10 | Separated skills into dedicated repo |
| v3.0+ | ~2025-11 | Adopted Anthropic first-party skills system |
| v3.5.0 | ~2025-12 | OpenCode support |
| v4.0.0 | ~2026-01 | Hard gates, graphviz flowcharts, subagent-driven dev, Codex support |
| v4.3.1 | ~2026-02 | Cursor support |
| v5.0.0 | ~2026-03 | Visual brainstorming, document review subagents, plan execution |
| v5.0.2 | 2026-03 | Zero-dependency brainstorm server |
| v5.0.6 | 2026-03-25 | Self-review replaces subagent review loops, Node.js 22+ fix |

The project has evolved rapidly — from monolithic plugin (v1) to marketplace-distributed multi-platform framework (v5) in about 5 months. The trajectory shows consistent movement toward **enforcement through structure rather than prose**.

---

## 11. Raw File Inventory

All files read during this analysis:

**Skills (SKILL.md for all 14):**
- `skills/brainstorming/SKILL.md` — 9-step design dialogue
- `skills/brainstorming/visual-companion.md` — Browser-based visual tool
- `skills/brainstorming/spec-document-reviewer-prompt.md` — Spec review subagent
- `skills/writing-plans/SKILL.md` — 2-5 minute atomic task decomposition
- `skills/writing-plans/plan-document-reviewer-prompt.md` — Plan review subagent
- `skills/executing-plans/SKILL.md` — Plan execution workflow
- `skills/subagent-driven-development/SKILL.md` — Per-task subagent orchestration
- `skills/subagent-driven-development/implementer-prompt.md` — Implementer subagent template
- `skills/subagent-driven-development/spec-reviewer-prompt.md` — Spec compliance reviewer
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md` — Quality reviewer
- `skills/test-driven-development/SKILL.md` — TDD iron principle
- `skills/test-driven-development/testing-anti-patterns.md` — 5 testing anti-patterns
- `skills/systematic-debugging/SKILL.md` — 4-phase root cause analysis
- `skills/systematic-debugging/root-cause-tracing.md` — Backward tracing technique
- `skills/systematic-debugging/defense-in-depth.md` — Multi-layer validation
- `skills/systematic-debugging/condition-based-waiting.md` — Anti-flaky-test pattern
- `skills/verification-before-completion/SKILL.md` — Evidence before claims
- `skills/using-git-worktrees/SKILL.md` — Worktree management
- `skills/finishing-a-development-branch/SKILL.md` — Branch completion
- `skills/requesting-code-review/SKILL.md` — Review dispatch
- `skills/receiving-code-review/SKILL.md` — Review processing
- `skills/dispatching-parallel-agents/SKILL.md` — Parallel agent coordination
- `skills/using-superpowers/SKILL.md` — Meta-skill (1% rule)
- `skills/writing-skills/SKILL.md` — TDD for skill creation
- `skills/writing-skills/persuasion-principles.md` — Compliance research
- `skills/writing-skills/anthropic-best-practices.md` — Anthropic skill authoring guide
- `skills/writing-skills/testing-skills-with-subagents.md` — Pressure scenario testing

**Configuration:**
- `.claude-plugin/plugin.json` — Claude Code manifest
- `.claude-plugin/marketplace.json` — Dev marketplace
- `.cursor-plugin/plugin.json` — Cursor manifest
- `gemini-extension.json` — Gemini manifest
- `package.json` — v5.0.6 ES module
- `hooks/hooks.json` — SessionStart hook
- `hooks/session-start` — Bootstrap script

**Documentation:**
- `README.md` — Project overview
- `RELEASE-NOTES.md` — v2.0.0 through v5.0.6
- `CHANGELOG.md` — Recent fixes
- `docs/testing.md` — Test framework guide
- `agents/code-reviewer.md` — Review agent definition

---

*Analysis completed 2026-03-26. All 14 skills, 5 prompt templates, 1 agent definition, all configuration files, hooks, and documentation reviewed.*
