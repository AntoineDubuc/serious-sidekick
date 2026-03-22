---
skill: serious-research
slug: superpowers-analysis
status: active
parent: Research/exploratory
created: 2026-03-22
---

# Superpowers Repository - Complete Analysis

**Repository:** [obra/superpowers](https://github.com/obra/superpowers)
**Author:** Jesse Vincent (jesse@fsck.com)
**License:** MIT
**Current Version:** 5.0.5 (2026-03-17)
**Platforms:** Claude Code, Cursor, Gemini CLI, Codex, OpenCode

---

## Table of Contents

1. [Repository Structure](#1-repository-structure)
2. [Plugin Manifest & Config](#2-plugin-manifest--config)
3. [Hooks System](#3-hooks-system)
4. [Commands](#4-commands)
5. [Agents](#5-agents)
6. [Skill: using-superpowers](#6-skill-using-superpowers)
7. [Skill: brainstorming](#7-skill-brainstorming)
8. [Skill: writing-plans](#8-skill-writing-plans)
9. [Skill: executing-plans](#9-skill-executing-plans)
10. [Skill: subagent-driven-development](#10-skill-subagent-driven-development)
11. [Skill: test-driven-development](#11-skill-test-driven-development)
12. [Skill: systematic-debugging](#12-skill-systematic-debugging)
13. [Skill: dispatching-parallel-agents](#13-skill-dispatching-parallel-agents)
14. [Skill: requesting-code-review](#14-skill-requesting-code-review)
15. [Skill: receiving-code-review](#15-skill-receiving-code-review)
16. [Skill: using-git-worktrees](#16-skill-using-git-worktrees)
17. [Skill: finishing-a-development-branch](#17-skill-finishing-a-development-branch)
18. [Skill: verification-before-completion](#18-skill-verification-before-completion)
19. [Skill: writing-skills](#19-skill-writing-skills)
20. [Supporting Files](#20-supporting-files)
21. [Release History Summary](#21-release-history-summary)
22. [Comparison with Serious Sidekick](#22-comparison-with-serious-sidekick)

---

## 1. Repository Structure

```
obra/superpowers/
├── .claude-plugin/
│   ├── plugin.json          # Claude Code plugin manifest
│   └── marketplace.json     # Dev marketplace config
├── .cursor-plugin/
│   └── plugin.json          # Cursor plugin manifest
├── .codex/
│   └── INSTALL.md           # Codex installation guide
├── .opencode/
│   ├── INSTALL.md           # OpenCode installation guide
│   └── plugins/
│       └── superpowers.js   # OpenCode JS plugin
├── .github/
│   ├── FUNDING.yml
│   ├── ISSUE_TEMPLATE/      # Bug, feature, platform support templates
│   └── PULL_REQUEST_TEMPLATE.md
├── agents/
│   └── code-reviewer.md     # Agent definition
├── commands/
│   ├── brainstorm.md        # Deprecated slash command
│   ├── write-plan.md        # Deprecated slash command
│   └── execute-plan.md      # Deprecated slash command
├── docs/
│   ├── README.codex.md
│   ├── README.opencode.md
│   ├── testing.md
│   ├── windows/
│   │   └── polyglot-hooks.md
│   ├── plans/               # Legacy plan location
│   └── superpowers/
│       ├── plans/           # Implementation plans
│       └── specs/           # Design specs
├── hooks/
│   ├── hooks.json           # Claude Code hook config
│   ├── hooks-cursor.json    # Cursor hook config
│   ├── run-hook.cmd         # Cross-platform polyglot wrapper
│   └── session-start        # Main hook script (extensionless)
├── skills/
│   ├── brainstorming/
│   │   ├── SKILL.md
│   │   ├── spec-document-reviewer-prompt.md
│   │   ├── visual-companion.md
│   │   └── scripts/         # Brainstorm server files
│   │       ├── frame-template.html
│   │       ├── helper.js
│   │       ├── server.cjs
│   │       ├── start-server.sh
│   │       └── stop-server.sh
│   ├── dispatching-parallel-agents/
│   │   └── SKILL.md
│   ├── executing-plans/
│   │   └── SKILL.md
│   ├── finishing-a-development-branch/
│   │   └── SKILL.md
│   ├── receiving-code-review/
│   │   └── SKILL.md
│   ├── requesting-code-review/
│   │   ├── SKILL.md
│   │   └── code-reviewer.md
│   ├── subagent-driven-development/
│   │   ├── SKILL.md
│   │   ├── implementer-prompt.md
│   │   ├── spec-reviewer-prompt.md
│   │   └── code-quality-reviewer-prompt.md
│   ├── systematic-debugging/
│   │   ├── SKILL.md
│   │   ├── CREATION-LOG.md
│   │   ├── root-cause-tracing.md
│   │   ├── defense-in-depth.md
│   │   ├── condition-based-waiting.md
│   │   ├── condition-based-waiting-example.ts
│   │   ├── find-polluter.sh
│   │   ├── test-academic.md
│   │   ├── test-pressure-1.md
│   │   ├── test-pressure-2.md
│   │   └── test-pressure-3.md
│   ├── test-driven-development/
│   │   ├── SKILL.md
│   │   └── testing-anti-patterns.md
│   ├── using-git-worktrees/
│   │   └── SKILL.md
│   ├── using-superpowers/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── codex-tools.md
│   │       └── gemini-tools.md
│   ├── verification-before-completion/
│   │   └── SKILL.md
│   └── writing-skills/
│       ├── SKILL.md
│       ├── anthropic-best-practices.md
│       ├── persuasion-principles.md
│       ├── testing-skills-with-subagents.md
│       ├── graphviz-conventions.dot
│       ├── render-graphs.js
│       └── examples/
│           └── CLAUDE_MD_TESTING.md
├── tests/
│   ├── brainstorm-server/
│   ├── claude-code/
│   ├── explicit-skill-requests/
│   ├── opencode/
│   ├── skill-triggering/
│   └── subagent-driven-dev/
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── GEMINI.md
├── LICENSE
├── README.md
├── RELEASE-NOTES.md
├── gemini-extension.json
└── package.json
```

**Key observations:**
- 14 skills total, each in its own directory with SKILL.md as the main file
- 1 agent definition (code-reviewer)
- 3 deprecated slash commands
- Hooks for Claude Code and Cursor
- Multi-platform support: Claude Code, Cursor, Gemini CLI, Codex, OpenCode
- Comprehensive test suites for skill triggering, subagent behavior, brainstorm server
- Uses the Claude Code first-party plugin/skills system (`.claude-plugin/`)

---

## 2. Plugin Manifest & Config

### `.claude-plugin/plugin.json`
```json
{
  "name": "superpowers",
  "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
  "version": "5.0.5",
  "author": { "name": "Jesse Vincent", "email": "jesse@fsck.com" },
  "homepage": "https://github.com/obra/superpowers",
  "repository": "https://github.com/obra/superpowers",
  "license": "MIT",
  "keywords": ["skills", "tdd", "debugging", "collaboration", "best-practices", "workflows"]
}
```

### `package.json`
```json
{
  "name": "superpowers",
  "version": "5.0.4",
  "type": "module",
  "main": ".opencode/plugins/superpowers.js"
}
```

**Key pattern:** Uses Claude Code's native plugin system. Skills are installed as a plugin and discovered automatically. No CLAUDE.md file in the repo -- context is injected via hooks.

**Difference from Serious Sidekick:** SS uses CLAUDE.md for all instructions. Superpowers uses a SessionStart hook to inject the `using-superpowers` skill content directly into every session. No CLAUDE.md exists in the Superpowers repo.

---

## 3. Hooks System

### `hooks/hooks.json` (Claude Code)
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

**Key details:**
- Fires on `startup`, `clear`, `compact` (NOT on `--resume`)
- Runs **synchronously** (async: false) -- learned the hard way that async caused context to not be ready for first message
- Uses a polyglot wrapper (`run-hook.cmd`) that works on both Windows and Unix
- The wrapper is a cmd.exe/bash polyglot -- cmd runs the batch portion, bash runs the shell portion

### `hooks/hooks-cursor.json`
```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "./hooks/session-start" }
    ]
  }
}
```
Cursor uses camelCase (`sessionStart`) and `version: 1` format.

### `hooks/session-start` (extensionless bash script)
The session-start hook:
1. Reads the `using-superpowers/SKILL.md` content
2. Escapes it for JSON embedding using fast bash parameter substitution (not character-by-character)
3. Detects platform (Cursor vs Claude Code vs other)
4. Outputs JSON with the escaped content as either:
   - `hookSpecificOutput.additionalContext` (for Claude Code)
   - `additional_context` (for Cursor and others)
5. Checks for legacy `~/.config/superpowers/skills` directory and warns to migrate

**Key pattern:** The `using-superpowers` skill content is injected into EVERY session at startup, establishing the "check for skills" behavior. This is the bootstrap mechanism.

### `hooks/run-hook.cmd` (Polyglot Wrapper)
A clever cmd.exe/bash polyglot:
- On Windows: the `: << 'CMDBLOCK'` is a label in cmd and a heredoc in bash. Cmd runs the batch portion which searches for bash in Git for Windows paths, then PATH.
- On Unix: bash runs the script, ignores the batch portion via the heredoc, and `exec`s the actual hook script.
- Uses extensionless script names to avoid Claude Code's `.sh` auto-detection on Windows.

**Difference from Serious Sidekick:** SS doesn't need this complexity because it uses CLAUDE.md directly. But this is a very battle-tested approach for cross-platform hook execution.

---

## 4. Commands

All three commands are **deprecated** with notices pointing to skills:

### `commands/brainstorm.md`
```yaml
---
description: "Deprecated - use the superpowers:brainstorming skill instead"
---
Tell your human partner that this command is deprecated...
```

### `commands/write-plan.md`
Same pattern, pointing to `superpowers:writing-plans`.

### `commands/execute-plan.md`
Same pattern, pointing to `superpowers:executing-plans`.

**Key pattern:** Slash commands exist only as deprecation notices. The real functionality is in skills. Commands also have `disable-model-invocation: true` so Claude can't invoke them -- only humans can.

**Difference from Serious Sidekick:** SS uses skills (`.claude/commands/`) as the primary invocation mechanism. Superpowers relies on the skill discovery system and the `using-superpowers` bootstrap to auto-detect when skills should be invoked.

---

## 5. Agents

### `agents/code-reviewer.md`
A Senior Code Reviewer agent that:
1. Does plan alignment analysis
2. Code quality assessment
3. Architecture and design review
4. Documentation and standards check
5. Issue identification (Critical/Important/Minor)
6. Communication protocol (ask for confirmation on deviations)

Uses `model: inherit` to use whatever model the parent session is using.

**Key pattern:** Only ONE agent defined. Superpowers uses prompt templates for subagent dispatch rather than formal agent definitions. The implementer, spec-reviewer, and code-quality-reviewer are all dispatched via the Task tool with inline prompts.

**Difference from Serious Sidekick:** SS has 5 formal agents (implementer, reviewer, test-runner, runtime-checker, qa) defined as `.claude/agents/*.md` files. Superpowers uses prompt templates in the skill directories instead.

---

## 6. Skill: using-superpowers

**File:** `skills/using-superpowers/SKILL.md`
**Purpose:** Bootstrap skill injected at session start. Establishes the "check for skills before any action" behavior.

### Core Mechanics

**The Rule:** "Invoke relevant or requested skills BEFORE any response or action." Even a 1% chance means invoke the skill.

**SUBAGENT-STOP gate:** When a subagent is dispatched for a specific task, it skips this skill entirely. Prevents recursive skill loading.

**Priority hierarchy:**
1. User's explicit instructions (CLAUDE.md, AGENTS.md) -- highest
2. Superpowers skills
3. Default system prompt -- lowest

**Skill types:**
- **Process skills** (brainstorming, debugging) -- determine HOW to approach, execute FIRST
- **Implementation skills** -- guide execution, execute SECOND
- **Rigid skills** (TDD, debugging) -- follow exactly
- **Flexible skills** (patterns) -- adapt to context

### Anti-Rationalization System

A comprehensive table of "red flag" thoughts that indicate skill-skipping:
- "This is just a simple question"
- "I need more context first"
- "Let me explore the codebase first"
- "The skill is overkill"
- "I know what that means" (knowing concept != using skill)
- 12 total entries

### DOT Flowchart

Uses a GraphViz DOT flowchart as the authoritative decision tree. Includes an `EnterPlanMode` intercept -- if the model is about to enter plan mode, it routes through brainstorming first.

**Key pattern:** This is the "operating system" of the plugin. Everything flows from this skill being injected at session start.

**Difference from Serious Sidekick:** SS doesn't have an equivalent bootstrap mechanism. Each skill is invoked by name. The auto-detection / "1% rule" is unique to Superpowers.

---

## 7. Skill: brainstorming

**File:** `skills/brainstorming/SKILL.md`
**Purpose:** Design phase before any implementation. Equivalent to SS's `/serious-conversation` + `/serious-research` + `/serious-mock-ups` combined.

### Core Structure

**HARD-GATE:** No implementation skills, code, or scaffolding until design is presented and user approves. Applies to EVERY project regardless of perceived simplicity.

**Anti-pattern addressed:** "This is too simple to need a design" -- explicitly called out as the exact rationalization models use to skip the process.

### Checklist (9 steps)

1. Explore project context (files, docs, commits)
2. Offer visual companion (if topic involves visual questions) -- own message, not combined
3. Ask clarifying questions -- one at a time, multiple choice preferred
4. Propose 2-3 approaches with trade-offs and recommendation
5. Present design in sections scaled to complexity, get approval after each
6. Write design doc to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
7. Spec review loop -- dispatch spec-document-reviewer subagent, max 3 iterations
8. User reviews written spec
9. Transition to implementation -- invoke writing-plans skill

**Terminal state:** The ONLY next skill is `writing-plans`. No other implementation skill can be invoked.

### Visual Companion

A browser-based companion for showing mockups, diagrams, and visual options during brainstorming:
- WebSocket-based server (`server.cjs`) serving HTML files
- Dark/light themed frame template
- CSS classes for options, cards, mockups, split views, pros/cons
- Event recording via `.events` file (JSON lines)
- Per-question decision on browser vs terminal
- Auto-exit after 30 minutes idle
- Owner PID tracking for session lifecycle
- Cross-platform launch instructions (macOS, Windows, Codex, Gemini CLI)

The visual companion is offered once for consent, in its own message, then used per-question based on whether content is visual or textual.

### Design Principles

- **Design for isolation:** Break into units with one clear purpose, well-defined interfaces, independently testable
- **Working in existing codebases:** Follow existing patterns, include targeted improvements, don't propose unrelated refactoring
- **Scope assessment:** If request describes multiple independent subsystems, flag immediately and decompose into sub-projects

### Spec Review Loop

Uses a `spec-document-reviewer-prompt.md` template to dispatch a subagent that checks:
- Completeness (TODOs, placeholders, TBD)
- Consistency (internal contradictions)
- Clarity (ambiguous requirements)
- Scope (focused for single plan)
- YAGNI (unrequested features)

**Calibration note:** "Only flag issues that would cause real problems during implementation planning." Minor wording, stylistic preferences don't block approval.

**Difference from Serious Sidekick:**
- SS separates conversation (`/serious-conversation`), research (`/serious-research`), and mock-ups (`/serious-mock-ups`) into distinct skills with persona systems
- Superpowers combines all pre-implementation work into one "brainstorming" skill
- SS uses multi-persona panels (hub-and-spoke); Superpowers has no persona system
- Superpowers has a visual companion (browser-based mockups); SS's `/serious-mock-ups` is a separate skill
- Superpowers has a formal spec review loop with subagent dispatch; SS doesn't have automated spec review
- SS creates versioned artifacts in `Research/` folders; Superpowers writes to `docs/superpowers/specs/`

---

## 8. Skill: writing-plans

**File:** `skills/writing-plans/SKILL.md`
**Purpose:** Create detailed implementation plans from specs. Equivalent to SS's `/serious-plan`.

### Key Design Decisions

**Assumes zero codebase context:** Plans are written for an engineer with "zero context for our codebase and questionable taste."

**Scope check:** If spec covers multiple independent subsystems, suggests breaking into separate plans.

**File structure mapping:** Before defining tasks, map out all files with their responsibilities. Decomposition decisions get locked in here.

### Task Granularity

Each step is one action (2-5 minutes):
1. Write failing test
2. Run to verify fail
3. Implement minimal code
4. Run to verify pass
5. Commit

### Plan Document Header

Every plan starts with a mandatory header:
```markdown
# [Feature Name] Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development...
**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
```

### Task Structure

Uses checkbox syntax (`- [ ]`) for progress tracking. Each task includes:
- Files section (Create/Modify/Test with exact paths)
- Step-by-step with complete code samples
- Exact commands with expected output
- Commit messages

### Plan Review Loop

Dispatches a `plan-document-reviewer` subagent that checks:
- Completeness (TODOs, placeholders)
- Spec alignment
- Task decomposition (clear boundaries, actionable)
- Buildability ("Could an engineer follow this without getting stuck?")

Max 3 iterations before escalating to human.

### Execution Handoff

Offers two choices:
1. **Subagent-Driven (recommended):** Fresh subagent per task + two-stage review
2. **Inline Execution:** Execute tasks in current session with checkpoints

**Difference from Serious Sidekick:**
- SS uses a v6 template (`_implementation_plan_template_v6.md`) with more structured sections
- SS includes TDD protocol, persona pipeline, inline QA, and split-agent verification
- SS auto-detects mock-ups for component inventory
- SS supports multiple plans with a phase map for parallel execution
- Superpowers' plan format is simpler but includes file structure mapping
- Superpowers has an automated plan review loop; SS doesn't

---

## 9. Skill: executing-plans

**File:** `skills/executing-plans/SKILL.md`
**Purpose:** Execute plans in a separate session with review checkpoints. Fallback for platforms without subagent support.

### Process

1. **Load and Review Plan** -- Read plan, raise concerns before starting
2. **Execute Tasks** -- Mark as in_progress, follow steps exactly, verify
3. **Complete Development** -- Use finishing-a-development-branch skill

### Key Note

The skill explicitly tells users that "Superpowers works much better with access to subagents" and recommends subagent-driven-development on capable platforms.

**Integration requirements:**
- using-git-worktrees (REQUIRED before starting)
- writing-plans (creates the plan)
- finishing-a-development-branch (after all tasks)

**Difference from Serious Sidekick:** SS's `/serious-code` is more sophisticated -- it orchestrates parallel plan execution via git worktrees, manages TDD cycles through 5 Agent Teams agents, handles phase-by-phase verification, and generates evidence reports.

---

## 10. Skill: subagent-driven-development

**File:** `skills/subagent-driven-development/SKILL.md`
**Purpose:** Execute plans by dispatching fresh subagent per task with two-stage review. This is Superpowers' primary execution mechanism.

### Core Flow

For each task:
1. Dispatch **implementer subagent** (using `implementer-prompt.md` template)
2. If implementer asks questions -- answer and re-dispatch
3. Implementer implements, tests, commits, self-reviews
4. Dispatch **spec compliance reviewer** (using `spec-reviewer-prompt.md`)
5. If issues found -- implementer fixes, reviewer re-reviews (loop)
6. Dispatch **code quality reviewer** (using `code-quality-reviewer-prompt.md`)
7. If issues found -- implementer fixes, reviewer re-reviews (loop)
8. Mark task complete
9. After all tasks -- dispatch final code reviewer for entire implementation
10. Use finishing-a-development-branch

### Model Selection

Tiered model usage to conserve cost:
- **Cheap model:** Isolated functions, clear specs, 1-2 files (mechanical)
- **Standard model:** Multi-file coordination, pattern matching, debugging
- **Most capable model:** Architecture, design, review tasks

### Implementer Status Protocol

Four statuses:
- **DONE:** Proceed to review
- **DONE_WITH_CONCERNS:** Read concerns before proceeding
- **NEEDS_CONTEXT:** Provide missing context and re-dispatch
- **BLOCKED:** Assess blocker (context problem? capability issue? too large? plan wrong?)

### Prompt Templates

#### `implementer-prompt.md`
- Receives FULL text of task (doesn't read plan file)
- Scene-setting context (where task fits)
- Encouraged to ask questions before AND during work
- Code organization guidance (follow plan's file structure, don't split files without plan guidance)
- "When You're in Over Your Head" escalation section
- Self-review checklist (completeness, quality, discipline, testing)
- Report format with 4 status codes

#### `spec-reviewer-prompt.md`
- Explicitly told: "The implementer finished suspiciously quickly. Their report may be incomplete, inaccurate, or optimistic."
- Must verify independently by reading actual code
- Checks for: missing requirements, extra/unneeded work, misunderstandings
- Returns: Spec compliant or Issues found (with file:line references)

#### `code-quality-reviewer-prompt.md`
- Only dispatched AFTER spec compliance passes
- Uses the `code-reviewer.md` template from requesting-code-review
- Additional checks: file responsibility, unit decomposition, plan conformance, file growth
- Returns: Strengths, Issues (Critical/Important/Minor), Assessment

**Key pattern:** Two-stage review is a core differentiator. Spec compliance catches "well-written code that doesn't match requirements." Code quality catches "correct code that's poorly written."

**Difference from Serious Sidekick:**
- SS uses 5 formal agent definitions (implementer, reviewer, test-runner, runtime-checker, qa) via Agent Teams
- Superpowers uses 3 roles with inline prompt templates (implementer, spec-reviewer, code-quality-reviewer)
- SS runs test-runner and runtime-checker as separate verification passes
- Superpowers bundles testing into the implementer's responsibilities
- SS has a QA agent; Superpowers relies on the spec reviewer + code quality reviewer
- Superpowers' model selection guidance (cheap/standard/capable) is a unique feature
- Superpowers' status protocol (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED) is more formalized

---

## 11. Skill: test-driven-development

**File:** `skills/test-driven-development/SKILL.md`
**Purpose:** Enforce strict TDD discipline. RED-GREEN-REFACTOR cycle.

### The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before test? **Delete it. Start over.** No exceptions:
- Don't keep it as "reference"
- Don't "adapt" it
- Don't look at it
- Delete means delete

### Verification Points

Both RED and GREEN phases have **mandatory** verification:
- **Verify RED:** Test fails (not errors), failure message expected, fails because feature missing
- **Verify GREEN:** Test passes, other tests still pass, output pristine

### Anti-Rationalization System

Comprehensive table of 12 excuses with counters:
- "Too simple to test" -- Simple code breaks. Test takes 30 seconds.
- "I'll test after" -- Tests passing immediately prove nothing.
- "Tests after achieve same goals" -- Tests-after = "what does this do?" vs Tests-first = "what should this do?"
- "Already manually tested" -- Ad-hoc != systematic. No record, can't re-run.
- "Deleting X hours is wasteful" -- Sunk cost fallacy.
- "Keep as reference" -- You'll adapt it. That's testing after.
- etc.

### Red Flags (13 items)

"All of these mean: Delete code. Start over with TDD."

### Testing Anti-Patterns (supplementary file)

`testing-anti-patterns.md` covers 5 anti-patterns:
1. Testing mock behavior instead of real behavior
2. Test-only methods in production classes
3. Mocking without understanding dependencies
4. Incomplete mocks hiding structural assumptions
5. Integration tests as afterthought

Each has a "Gate Function" -- a decision procedure to run before the problematic action.

**Difference from Serious Sidekick:** SS doesn't have a standalone TDD skill. TDD is embedded in the plan template and code execution workflow. Superpowers treats TDD as a first-class skill with its own anti-rationalization system.

---

## 12. Skill: systematic-debugging

**File:** `skills/systematic-debugging/SKILL.md`
**Purpose:** Enforce systematic root cause analysis before any fix attempt.

### The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

### Four Phases

1. **Root Cause Investigation:** Read errors carefully, reproduce consistently, check recent changes, gather evidence at component boundaries, trace data flow
2. **Pattern Analysis:** Find working examples, compare against references, identify differences, understand dependencies
3. **Hypothesis and Testing:** Form single hypothesis, test minimally (one variable), verify before continuing
4. **Implementation:** Create failing test, implement single fix, verify, and if 3+ fixes fail -- QUESTION THE ARCHITECTURE

### Architecture Escalation (Phase 4 Step 5)

After 3 failed fixes:
- Pattern indicates architectural problem (shared state, coupling, different symptoms each time)
- Stop and question fundamentals
- Discuss with human before attempting more fixes
- "This is NOT a failed hypothesis - this is a wrong architecture"

### Supporting Techniques (bundled files)

#### `root-cause-tracing.md`
Complete methodology for tracing bugs backward through call stack to find original trigger. Includes:
- The 5-step tracing process
- Adding stack traces for instrumentation
- Real example: empty `projectDir` traced through 5 levels

#### `defense-in-depth.md`
Four-layer validation pattern:
1. Entry point validation (reject invalid input at API boundary)
2. Business logic validation (data makes sense for operation)
3. Environment guards (prevent dangerous operations in specific contexts like tests)
4. Debug instrumentation (capture context for forensics)

#### `condition-based-waiting.md`
Replace arbitrary timeouts with condition polling. Includes:
- Generic `waitFor()` implementation
- Quick patterns table
- When arbitrary timeout IS correct (documented timing behavior)

#### `find-polluter.sh`
Bisection script to find which test creates unwanted files/state. Runs tests one-by-one, stops at first polluter.

**Difference from Serious Sidekick:** SS embeds debugging guidance in the `/serious-research` skill's deep mode. Superpowers has a standalone debugging skill with bundled technique files. The "3+ fixes = question architecture" escalation is unique to Superpowers.

---

## 13. Skill: dispatching-parallel-agents

**File:** `skills/dispatching-parallel-agents/SKILL.md`
**Purpose:** When facing 2+ independent tasks, dispatch one agent per problem domain.

### Decision Flow

```
Multiple failures? -> Are they independent? -> Can they work in parallel?
-> Parallel dispatch (if yes to all)
-> Sequential agents (if shared state)
-> Single agent (if related)
```

### Agent Prompt Structure

Good prompts are:
1. **Focused** -- one clear problem domain
2. **Self-contained** -- all context needed
3. **Specific about output** -- what should agent return

### Common Mistakes

- Too broad ("Fix all the tests") vs Specific ("Fix agent-tool-abort.test.ts")
- No context vs paste error messages and test names
- No constraints vs "Do NOT change production code"
- Vague output vs "Return summary of root cause and changes"

**Context isolation principle:** Subagents receive only the context they need, preventing context window pollution.

**Difference from Serious Sidekick:** SS doesn't have a standalone parallel dispatch skill. This capability is embedded in `/serious-code`'s phase-by-phase execution with git worktrees.

---

## 14. Skill: requesting-code-review

**File:** `skills/requesting-code-review/SKILL.md`
**Purpose:** Dispatch the code-reviewer agent with properly structured context.

### When to Review

**Mandatory:** After each task in SDD, after major feature, before merge to main
**Optional:** When stuck, before refactoring, after complex bug fix

### Process

1. Get git SHAs (base and head)
2. Dispatch `superpowers:code-reviewer` agent with template placeholders
3. Act on feedback: Fix Critical immediately, Important before proceeding, note Minor

### Code Review Template (`code-reviewer.md`)

Structured template with:
- `{WHAT_WAS_IMPLEMENTED}` / `{PLAN_OR_REQUIREMENTS}` / `{BASE_SHA}` / `{HEAD_SHA}` / `{DESCRIPTION}` placeholders
- Review checklist: Code Quality, Architecture, Testing, Requirements, Production Readiness
- Output format: Strengths, Issues (Critical/Important/Minor with file:line), Recommendations, Assessment

**Difference from Serious Sidekick:** SS uses a formal `serious-code-reviewer` agent. Superpowers uses a template-based approach with the same agent.

---

## 15. Skill: receiving-code-review

**File:** `skills/receiving-code-review/SKILL.md`
**Purpose:** How to handle incoming code review feedback with technical rigor.

### Response Pattern

READ -> UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND -> IMPLEMENT

### Forbidden Responses

- "You're absolutely right!" (performative)
- "Great point!" (sycophantic)
- "Let me implement that now" (before verification)
- ANY gratitude expression

### Key Principles

- **External feedback = suggestions to evaluate, not orders to follow**
- Verify against codebase reality before implementing
- Push back with technical reasoning when wrong
- YAGNI check: grep codebase for actual usage before "implementing properly"
- If unclear on any item, clarify ALL items first before implementing any
- Implementation order: blocking issues -> simple fixes -> complex fixes
- GitHub thread replies in comment threads, not top-level

### Signal Phrase

"Strange things are afoot at the Circle K" -- signal if uncomfortable pushing back out loud.

**Difference from Serious Sidekick:** SS doesn't have a standalone code review reception skill. This is unique to Superpowers and very well thought out -- the anti-sycophancy guidance is strong.

---

## 16. Skill: using-git-worktrees

**File:** `skills/using-git-worktrees/SKILL.md`
**Purpose:** Create isolated workspaces for feature development.

### Directory Selection Priority

1. Check existing `.worktrees/` or `worktrees/` directories
2. Check CLAUDE.md for preference
3. Ask user (offer `.worktrees/` or `~/.config/superpowers/worktrees/<project>/`)

### Safety Verification

- For project-local directories: MUST verify directory is ignored via `git check-ignore`
- If NOT ignored: add to `.gitignore` and commit immediately
- For global directory: no verification needed

### Creation Steps

1. Detect project name
2. Create worktree with new branch
3. Auto-detect and run setup (npm install, cargo build, pip install, etc.)
4. Run tests to verify clean baseline
5. Report location and test status

**Difference from Serious Sidekick:** SS has git worktree support documented in `Claude Code Features/13_Git_Worktrees/` and used by `/serious-code`. The approach is similar but Superpowers' skill is more formalized with the directory selection priority and safety verification.

---

## 17. Skill: finishing-a-development-branch

**File:** `skills/finishing-a-development-branch/SKILL.md`
**Purpose:** Complete development work with structured options for integration.

### Process

1. **Verify tests pass** -- stop if they don't
2. **Determine base branch** -- try main, then master
3. **Present exactly 4 options:**
   1. Merge locally
   2. Push and create PR
   3. Keep branch as-is
   4. Discard (requires typed "discard" confirmation)
4. **Execute choice**
5. **Cleanup worktree** (for options 1 and 4 only)

**Difference from Serious Sidekick:** SS doesn't have a standalone branch completion skill. This is handled within `/serious-code`'s execution flow.

---

## 18. Skill: verification-before-completion

**File:** `skills/verification-before-completion/SKILL.md`
**Purpose:** Enforce evidence-based verification before any success claims.

### The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

### The Gate Function

Before claiming ANY status:
1. IDENTIFY what command proves the claim
2. RUN the FULL command (fresh, complete)
3. READ full output, check exit code
4. VERIFY output confirms claim
5. ONLY THEN make the claim

### Red Flags

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting agent success reports
- ANY wording implying success without having run verification

### Key Patterns

- Tests: Run command -> See "34/34 pass" -> "All tests pass" (not "Should pass now")
- Regression tests: RED-GREEN verification (write -> pass -> revert fix -> MUST FAIL -> restore -> pass)
- Agent delegation: Agent reports success -> Check VCS diff -> Verify changes -> Report actual state

**Difference from Serious Sidekick:** SS doesn't have a standalone verification skill. This discipline is embedded in the serious-code execution flow but not as explicitly formalized.

---

## 19. Skill: writing-skills

**File:** `skills/writing-skills/SKILL.md`
**Purpose:** Meta-skill for creating new skills using TDD methodology.

### Core Concept

**Writing skills IS TDD applied to process documentation.** Same RED-GREEN-REFACTOR cycle:
- RED: Run pressure scenario WITHOUT skill, watch agent fail, document rationalizations
- GREEN: Write skill addressing specific failures, verify agent complies
- REFACTOR: Close loopholes, add counters for new rationalizations, re-test

### Claude Search Optimization (CSO)

Critical discovery insight: **description = when to use, NOT what the skill does.** Testing revealed that descriptions summarizing workflow create shortcuts Claude follows instead of reading the full skill. The "Description Trap" -- descriptions with process details caused Claude to do ONE review instead of the two-stage review defined in the flowchart.

### Flowchart Usage

Uses DOT/GraphViz flowcharts as **executable specifications**:
- Only for non-obvious decision points and process loops
- Never for reference material, code examples, or linear instructions
- Comprehensive `graphviz-conventions.dot` style guide

### Persuasion Principles (`persuasion-principles.md`)

Research-backed approach to skill design (Cialdini, 2021; Meincke et al., 2025):
- **Authority:** Imperative language ("YOU MUST"), non-negotiable framing
- **Commitment:** Required announcements, force explicit choices, TodoWrite tracking
- **Scarcity:** Time-bound requirements, sequential dependencies
- **Social Proof:** Universal patterns, failure mode documentation
- **Unity:** Collaborative language, shared goals
- Avoid: Reciprocity (manipulative), Liking (creates sycophancy)

Compliance rates: 33% -> 72% with persuasion techniques (N=28,000 conversations).

### Testing Skills With Subagents (`testing-skills-with-subagents.md`)

Comprehensive testing methodology:
- How to write pressure scenarios (combine 3+ pressure types)
- Pressure types: time, sunk cost, authority, economic, exhaustion, social, pragmatic
- Meta-testing: ask agent how skill could be written to prevent violations
- Bulletproofing: agent chooses correct option under maximum pressure, cites skill sections

### Anthropic Best Practices (`anthropic-best-practices.md`)

Official Anthropic skill authoring guide covering:
- Conciseness ("context window is a public good")
- Degrees of freedom (high/medium/low)
- Progressive disclosure patterns
- Evaluation-driven development
- Runtime environment details
- MCP tool references

**Difference from Serious Sidekick:** SS doesn't have a meta-skill for creating skills. This is a significant gap -- Superpowers' approach to TDD for documentation, with pressure testing and rationalization tables, is very sophisticated.

---

## 20. Supporting Files

### `GEMINI.md`
Just two `@` imports:
```
@./skills/using-superpowers/SKILL.md
@./skills/using-superpowers/references/gemini-tools.md
```

### `gemini-extension.json`
Gemini CLI extension definition.

### `.codex/INSTALL.md`
Installation instructions for Codex.

### `.opencode/INSTALL.md` and `.opencode/plugins/superpowers.js`
OpenCode plugin that auto-registers the skills directory via a config hook.

### `docs/testing.md`
Guide to testing skills with Claude Code integration tests.

### `docs/windows/polyglot-hooks.md`
Documentation for the polyglot hook wrapper approach.

### Test Suites

**`tests/brainstorm-server/`:** HTTP serving, WebSocket protocol, file watching, integration tests for the zero-dependency brainstorm server.

**`tests/claude-code/`:** Integration tests using `claude -p` for headless testing. Includes:
- `run-skill-tests.sh` -- run skills test suite
- `test-document-review-system.sh` -- end-to-end document review
- `test-subagent-driven-development.sh` -- SDD integration
- `analyze-token-usage.py` -- cost tracking script

**`tests/skill-triggering/`:** Tests that skills trigger from naive prompts without explicit naming. 6 skills tested with natural language prompts.

**`tests/explicit-skill-requests/`:** Tests that Claude invokes skills when users request by name. Multi-turn and extended tests.

**`tests/subagent-driven-dev/`:** Two complete test projects:
- `go-fractals/` -- CLI tool (10 tasks)
- `svelte-todo/` -- CRUD app with Playwright (12 tasks)

---

## 21. Release History Summary

### Version Timeline

| Version | Date | Key Changes |
|---------|------|-------------|
| 5.0.5 | 2026-03-17 | ESM fix, Windows PID monitoring, stop-server reliability, restore execution choice |
| 5.0.4 | 2026-03-16 | Single whole-plan review, raised bar for blocking issues, max 3 review iterations, OpenCode one-line install |
| 5.0.3 | 2026-03-15 | Cursor support, stop firing on --resume, bash 5.3+ hang fix, POSIX-safe shebangs, brainstorm on Windows |
| 5.0.2 | 2026-03-11 | Zero-dependency brainstorm server, auto-exit idle, owner PID tracking, subagent context isolation |
| 5.0.1 | 2026-03-10 | Agentskills compliance, Gemini CLI support, multi-platform brainstorm launch, Windows hook fixes |
| 5.0.0 | 2026-03-09 | Visual brainstorming, document review system, architecture guidance, SDD improvements, slash commands deprecated |
| 4.3.1 | 2026-02-21 | Cursor support, Windows polyglot hook fixes |
| 4.3.0 | 2026-02-12 | Hard gates for brainstorming, EnterPlanMode intercept, synchronous hooks |
| 4.2.0 | 2026-02-05 | Worktree isolation required, main branch protection, Codex native discovery |
| 4.1.0 | 2026-01-23 | OpenCode native skills, agent reset fix, Windows installation |
| 4.0.3 | 2025-12-26 | Strengthened explicit skill requests |
| 4.0.2 | 2025-12-23 | Slash commands user-only |
| 4.0.1 | 2025-12-23 | Skill tool access clarification |
| 4.0.0 | 2025-12-17 | Two-stage code review, DOT flowcharts, debugging techniques, testing anti-patterns, skill test infrastructure |
| 3.x | 2025-10-28 | Codex support, OpenCode support, skill consolidation, namespace standardization |
| 2.0.0 | 2025-10-09 | Skills repository separation, 9 new skills |

### Key Evolution Patterns

1. **Anti-rationalization became central:** Each version added more counters for agent avoidance patterns
2. **DOT flowcharts became executable specs:** Replaced prose with graphviz diagrams as authoritative process definitions
3. **Two-stage review was a breakthrough:** Separating spec compliance from code quality (v4.0.0)
4. **Cross-platform became a major focus:** Windows, Linux, macOS, Cursor, Gemini CLI, Codex, OpenCode
5. **Visual brainstorming was added late:** v5.0.0 added the browser-based companion
6. **Review loop calibration:** v5.0.4 reduced max iterations from 5 to 3 and raised the bar for blocking issues

---

## 22. Comparison with Serious Sidekick

### What Superpowers Has That We Don't

| Feature | Superpowers | Serious Sidekick |
|---------|-------------|------------------|
| **Auto-detect skill invocation** | "1% rule" -- invoke if even 1% chance applies | Explicit invocation by name only |
| **Anti-rationalization tables** | Comprehensive tables in TDD, debugging, verification, writing-skills | Not present |
| **DOT flowcharts as specs** | Used as authoritative process definitions that models follow | Not used |
| **Visual brainstorming companion** | Browser-based WebSocket server with mockups, diagrams, selections | Separate mock-ups skill (text-based) |
| **Two-stage code review** | Spec compliance + code quality as separate passes | Single reviewer agent |
| **Verification-before-completion skill** | Standalone skill enforcing evidence before claims | Not a standalone skill |
| **Receiving code review skill** | Anti-sycophancy guidance, YAGNI checks, pushback protocol | Not present |
| **Finishing-a-development-branch skill** | 4 structured options for branch completion | Embedded in code execution |
| **Model selection guidance** | Cheap/standard/capable model per task type | Not present |
| **Implementer status protocol** | DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED | Not formalized |
| **Skill testing with pressure scenarios** | TDD for documentation with subagent pressure tests | Not present |
| **Persuasion principles** | Research-backed (Cialdini) approach to skill design | Not present |
| **CSO (Claude Search Optimization)** | Detailed guidance for skill discoverability | Not present |
| **Cross-platform support** | Cursor, Gemini CLI, Codex, OpenCode | Claude Code only |
| **Session start hook injection** | Bootstrap context via hooks.json | Uses CLAUDE.md |
| **Spec review loop** | Automated subagent dispatch for spec validation | Not present |
| **Plan review loop** | Automated subagent dispatch for plan validation | Not present |
| **Condition-based waiting** | Standalone technique for replacing arbitrary timeouts | Not present |
| **Defense-in-depth** | 4-layer validation pattern | Not present |
| **Root-cause tracing** | Standalone backward tracing technique | Not present |
| **Find-polluter script** | Bisection script for test pollution | Not present |
| **Testing anti-patterns** | 5 anti-patterns with gate functions | Not present |
| **Graphviz conventions** | Style guide for process diagrams | Not present |

### What Serious Sidekick Has That Superpowers Doesn't

| Feature | Serious Sidekick | Superpowers |
|---------|------------------|-------------|
| **Multi-persona system** | 10 built-in personas, hub-and-spoke conversation model | No personas |
| **Conversation skill** | `/serious-conversation` with versioned artifacts | Brainstorming combines everything |
| **Research skill** | `/serious-research` with quick/deep modes, evidence grading | No standalone research |
| **Separate mock-ups skill** | `/serious-mock-ups` with 3 fidelity levels | Visual companion is part of brainstorming |
| **5 Agent Teams agents** | Formal agent definitions for implementer, reviewer, test-runner, runtime-checker, qa | 1 agent + 3 prompt templates |
| **Runtime verification** | Dedicated runtime-checker agent | Bundled into implementer responsibilities |
| **QA agent** | Dedicated qa agent for final verification | Final code reviewer covers this |
| **Workflow frontmatter** | YAML frontmatter with skill, slug, status, parent, created | Not present |
| **Breadcrumb files** | `.active-{skill-name}` files for workflow tracking | Not present |
| **Stop hooks** | Captures artifacts via stop hooks | Not present |
| **Inter-plan regression** | Regression testing between plans | Not present |
| **Stub detection** | Detects incomplete implementations | Not present |
| **Phase map** | Parallel execution support with phase mapping | Sequential task execution only |
| **Workflow pipeline tracking** | conversation -> research -> mock-ups -> plan -> code | brainstorming -> writing-plans -> execution (simpler) |
| **CLAUDE.md as instruction center** | Comprehensive rules in CLAUDE.md | No CLAUDE.md (uses hook injection) |
| **Feature auto-loaders** | 17 feature auto-loader skills | Not present |
| **Claude Code feature documentation** | 39 detailed feature research docs | Not present |

### Architectural Differences

| Aspect | Superpowers | Serious Sidekick |
|--------|-------------|------------------|
| **Bootstrap mechanism** | SessionStart hook injects using-superpowers content | CLAUDE.md rules + skill invocation |
| **Skill invocation** | Auto-detected via "1% rule" from using-superpowers | Explicit `/slash-command` invocation |
| **Skill format** | YAML frontmatter (name + description only) | YAML frontmatter (skill, slug, status, parent, created) |
| **Subagent prompts** | Inline templates in skill directories | Formal agent definitions in `.claude/agents/` |
| **Process enforcement** | DOT flowcharts + HARD-GATE tags | Template-driven with checklist |
| **Anti-rationalization** | Systematic tables in every discipline skill | Not present |
| **Testing philosophy** | Skills are tested with pressure scenarios on subagents | Skills are not pressure-tested |
| **Platform support** | 5 platforms (Claude Code, Cursor, Gemini, Codex, OpenCode) | 1 platform (Claude Code) |
| **Output artifacts** | `docs/superpowers/specs/` and `docs/superpowers/plans/` | `Research/` folder hierarchy |
| **Plan execution** | 1 implementer + 2 reviewers per task | 5 agents per task (implementer, reviewer, test-runner, runtime-checker, qa) |

### Key Techniques Worth Adopting

1. **Anti-rationalization tables** -- Every discipline skill should have a table of excuses and counters
2. **DOT flowcharts as executable specs** -- Models follow diagrams more reliably than prose
3. **Two-stage code review** -- Separating spec compliance from code quality catches different failure modes
4. **Verification-before-completion** -- "Evidence before claims" as a standalone discipline
5. **Implementer status protocol** (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED) -- Formal escalation paths
6. **Model selection guidance** -- Using cheaper models for mechanical tasks saves cost
7. **CSO principles** -- Description = when to use, NOT what it does (the Description Trap)
8. **SUBAGENT-STOP gate** -- Prevents recursive skill loading in subagents
9. **Pressure testing skills** -- TDD for documentation is a powerful validation approach
10. **The "1% rule"** -- If even 1% chance a skill applies, invoke it
11. **Spec review + plan review loops** -- Automated quality gates before execution
12. **Context isolation principle** -- "Subagents receive only the context they need"
13. **Receiving code review** -- Anti-sycophancy guidance is valuable
14. **EnterPlanMode intercept** -- Routing through brainstorming instead of plan mode
15. **Condition-based waiting / defense-in-depth / root-cause tracing** -- Debugging technique bundling
