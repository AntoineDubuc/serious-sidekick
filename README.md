# Serious Sidekick

Your Claude Code sidekick — a knowledge base, workflow toolkit, and feature reference you drop into any project. Claude gets accurate documentation, structured research and planning skills, and always knows what it can do.

## What's Inside

```
.
├── CLAUDE.md                              # Loaded every session — rules + feature index
├── _implementation_plan_template_v6.md    # V6 plan template (used by /serious-plan)
├── context.md                             # Session continuity context
├── README.md                              # Project documentation (markdown)
├── README.html                            # Project documentation (HTML with light/dark mode)
├── .claude/
│   ├── skills/                            # 25 auto-loading skills
│   │   ├── serious-init/SKILL.md          # /serious-init — scaffold a new project
│   │   ├── serious-conversation/SKILL.md  # /serious-conversation — persona panel ideation
│   │   │   └── personas/                  # 10 built-in persona prompt files
│   │   │       ├── architect.md, skeptic.md, pragmatist.md
│   │   │       ├── product-thinker.md, debugger.md, security-mind.md
│   │   │       └── dx-advocate.md, mentor.md, optimizer.md, historian.md
│   │   ├── serious-research/SKILL.md      # /serious-research — structured research
│   │   ├── serious-mock-ups/SKILL.md     # /serious-mock-ups — UI mock-ups before planning
│   │   ├── serious-plan/SKILL.md          # /serious-plan — implementation planning
│   │   ├── serious-code/SKILL.md          # /serious-code — plan execution with Agent Teams
│   │   ├── serious-review/SKILL.md        # /serious-review — structured review & defect capture
│   │   ├── serious-bananas/SKILL.md       # /serious-bananas — image generation via Gemini
│   │   ├── hooks/SKILL.md                 # 17 feature-specific auto-loader skills
│   │   ├── subagents/SKILL.md
│   │   ├── mcp-integration/SKILL.md
│   │   ├── permissions/SKILL.md
│   │   └── ...and 13 more
│   └── agents/                            # 5 Agent Teams agents (used by /serious-code)
│       ├── serious-code-implementer.md    # TDD implementation (RED→GREEN→VERIFY)
│       ├── serious-code-reviewer.md       # Code review, security, plan adherence
│       ├── serious-code-test-runner.md    # Static analysis + full test suite
│       ├── serious-code-runtime-checker.md # Runtime behavior verification
│       └── serious-code-qa.md             # Adversarial QA spot-check
└── Claude Code Features/                  # 38 research folders + master README
    ├── README.md                          # Categorized & chronological index
    ├── 01_Core_CLI/research.md
    ├── ...through...
    └── 38_Enterprise_and_Managed_Settings/research.md
```

## Workflow Skills

The template includes eight workflow skills that form a pipeline:

### `/serious-conversation` — Persona Panel

Think out loud with a panel of personas before committing to research or planning. Pick from 10 built-in personas (Architect, Skeptic, Pragmatist, Product Thinker, Debugger, Security Mind, DX Advocate, Mentor, Optimizer, Historian) or create custom ones. Hub-and-spoke model: personas respond independently via sub-agents, the Orchestrator synthesizes, you refine.

Each round produces versioned artifacts — persona responses (`response_vN.md`), synthesized results (`result_vN.md`), and a conversation log. Personas can read each other's previous responses in later rounds to converge.

**Additional features:**
- **Topic pivot** — shift topics mid-conversation without restarting (logs a shift marker, re-proposes personas)
- **Persona library** — custom personas saved to `Research/conversations/_personas/` for reuse across conversations
- **Stop hook tracking** — uses `.active-conversation` breadcrumb to track `conversation.md` across tool calls

### `/serious-research` — Structured Research

Runs a structured research operation with two modes:

| Mode | What it does | When to use |
|------|-------------|-------------|
| **Quick** | Single-threaded research, persona reviews, markdown deliverable | Bug diagnosis, focused investigation, clear single-angle questions |
| **Deep** | Parallel thread agents, evidence grading (A-F), adversarial verification, QA citation checking, HTML report | Architecture decisions, competitive analysis, multi-dimensional topics |

The mode is auto-detected based on your request, or you can force it with `--quick` or `--deep`. During scoping, you choose a **research scope** — online only, codebase only, or both — so agents only use the tools that matter (no pointless web searches for a local bug hunt, no codebase exploration for a tech evaluation). Before diving into research, mandatory pre-research steps capture a smoke test baseline, trace the full execution path from user action to visible result, identify optimization/caching layers, and map downstream consumers. A Stop hook uses the `.active-research` breadcrumb to track `notebook.md` across tool calls.

**What it creates:**
```
Research/
├── bugs/
│   └── {slug}/          # notebook.md, research.md, evidence files, report.html
├── features/
│   └── {slug}/
└── exploratory/
    └── {slug}/
```

### `/serious-mock-ups` — UI Mock-Ups

Generate UI mock-ups from research output before moving to implementation planning. A visual checkpoint so you validate layout, flow, and interaction before committing to a plan.

**Three fidelity levels:**
- **Wireframe** — ASCII/text-based layouts right in the terminal. Fast, no dependencies, great for structure decisions.
- **Visual mock-up** — Generated via Gemini image API with proper styling and realistic components. Requires `GEMINI_API_KEY`.
- **Interactive flow** — Screen-to-screen navigation maps showing user journeys and state variations.

**Key features:**
- Auto-detects UI surfaces from `/serious-research` output
- Iterative feedback with versioned wireframes and visuals (`v1`, `v2`, `v3`)
- Design decision log — every layout choice is recorded with rationale
- Component inventory — extracted from approved mock-ups, feeds directly into `/serious-plan` task breakdown
- Responsive variants — optional desktop, tablet, and mobile versions with breakpoint notes
- State variations — empty states, error states, loading states surfaced early

**What it creates:**
```
Research/features/{slug}/
└── mock-ups/
    ├── mock-up-summary.md        # Component inventory + design decisions
    ├── 01_{surface}/
    │   ├── wireframe_v1.md       # ASCII wireframe
    │   ├── visual_v1.png         # Gemini-generated
    │   └── feedback.md           # What changed and why
    └── flow.md                   # Screen-to-screen navigation map
```

### `/serious-plan` — Implementation Planning

Generates a v6 implementation plan from research, a PRD, or even a verbal description. It auto-detects existing `/serious-research` output and `/serious-mock-ups` deliverables, or asks what input you have.

**Key features:**
- TDD protocol (RED→GREEN→VERIFY per acceptance criterion)
- Adaptive Persona Pipeline with severity-weighted convergence:
  - Severity levels: Critical / Major / Minor
  - Any critical → re-review, 3+ majors → re-review, minors only → done, max 3 rounds
- Inline QA Protocol v6 (every criterion gets independent QA sub-agent verification)
- Split-Agent Verification (4 parallel agents: Code Review, Static+Tests, Runtime, QA Spot-Check)
- Single plan (3-7 tasks) or multiple plans with `phase_map.md` for parallel execution
- Cross-plan integration review: Integration Architect + Merge Strategist personas (+ optional Concurrency Engineer)
  - Same convergence rules, max 3 integration rounds
  - If integration fixes change a plan → one more individual review round
- Evidence reports per task
- Task 0 smoke test (reproduce problem in running app before any implementation)
- Scope clarity per task (data layer, UI layer, or full round-trip)
- Impact analysis per task (downstream consumers of changed code)
- Every user-facing task requires a "visible to user" acceptance criterion

### `/serious-code` — Plan Execution

Executes implementation plans produced by `/serious-plan`. Uses a 3-level agent architecture:

**Orchestrator → Plan Agents → Agent Teams**
- **Orchestrator** manages phases, user approval, and cross-plan coordination
- **Plan Agents** (one per plan per phase) execute via git worktrees for isolation
- **Agent Teams** (5 agents per task): implementer (TDD), code reviewer, test runner, runtime checker, QA spot-checker

**Key features:**
- **SMOKE→RED→GREEN→VERIFY→SMOKE cycle:** Smoke test before implementation, TDD during, smoke test after — "tests pass" is necessary but not sufficient
- **Gap investigation:** When unit tests pass but the feature doesn't work, investigates the missing layer (caches, indexes, visibility culling, event propagation, async timing, build caches)
- **Monorepo awareness:** Rebuilds dependency packages and restarts dev servers after modifying shared modules
- **Multi-plan execution:** Reads `phase_map.md` and runs plans in parallel phases via git worktrees
- **Phase-by-phase approval:** User approves each phase before execution begins
- **Two-level tracking:** `execution_log.md` (orchestrator level) + per-plan `progress.md`
- **Evidence generation:** Every task produces implementation, review, test, runtime, and QA reports
- **Failure handling:** Failed plans stop immediately; other parallel plans continue; user decides to fix, skip, rollback, or abort
- **Resume mode:** Reads `execution_log.md` + `progress.md` to find the stopping point and pick up where it left off
- **Completion report:** Generated at end of execution with full evidence summary
- **Stop hook tracking:** Uses `.active-code` breadcrumb to track `execution_log.md` across tool calls

### `/serious-review` — Structured Review & Defect Capture

Review what was built and funnel feedback back into the pipeline. Not a testing framework — a structured defect collection phase that bridges `/serious-code` output back into `/serious-research` → `/serious-plan` → `/serious-code`.

**The flow:**
1. **Auto-detect context** — scans for recent `/serious-code` output, flags missing deliverables (evidence/completion reports)
2. **Confirm scope** — presents what was found, asks to confirm
3. **Choose mode** — live capture (you report issues as you find them), QA plan first (generates checklist from acceptance criteria), or both (default)
4. **Live capture** — each issue gets an ID (REVIEW-001), classified (bug, missed requirement, improvement, security, UX), severity-rated, and written to `QA/{slug}/findings.md` immediately
5. **Synthesize** — consolidates all findings into `review-summary.md` formatted as research input
6. **Hand off** — offers to kick off `/serious-research` → `/serious-plan` → `/serious-code` on the findings

**What it creates:**
```
QA/
└── {slug}/
    ├── findings.md        # All captured issues with IDs, types, severities
    ├── qa-plan.md         # Generated QA checklist (if requested)
    └── review-summary.md  # Final synthesis — feeds into /serious-research
```

### `/serious-bananas` — Image Generation

Generate images (especially diagrams) using Google's Gemini native image generation API (Nano Banana). Interviews you with 6 questions, crafts an optimized prompt, and runs the API call.

**Interview questions:**
1. **What do you need?** — plain language description
2. **What type?** — flowchart, architecture, sequence, ER, infographic, concept map, freeform
3. **Style?** — clean/minimal, technical/blueprint, whiteboard sketch, polished/presentation-ready
4. **Aspect ratio?** — 1:1, 16:9, 3:2, 9:16
5. **How many variations?** — 1-4 (each a separate API call)
6. **Where to save?** — current directory, ./images/, ~/Desktop, or custom path

**Models:** `gemini-3-pro-image-preview` (Pro, highest quality) or `gemini-3.1-flash-image-preview` (faster/cheaper). Requires `GEMINI_API_KEY` in `.env` and `pip install google-genai pillow`.

**Typical workflow:**
```
/serious-conversation [topic] →  Ideation & exploration with persona panel
/serious-research [topic]     →  Structured investigation with evidence
/serious-mock-ups             →  UI wireframes & visuals before planning
/serious-plan                 →  Plan generation (auto-finds research + mock-ups)
/serious-code                 →  Execution with TDD, verification, evidence
/serious-review               →  Review, capture defects, cycle back ↩
```

## Knowledge Layers

### Three layers, each serving a different purpose

| Layer | What | When it loads | Context cost |
|-------|------|---------------|--------------|
| **CLAUDE.md** | Feature index + workflow skill references | Every session, survives compaction | Minimal — always present |
| **Skills** | How-to guides for 17 features + 8 workflow skills | On-demand when the topic comes up | Only when relevant |
| **Research docs** | Deep-dive documentation with citations | When Claude reads the file | Only when explicitly needed |

## Quick Start

### Option A: Use the setup command (recommended)

If you've installed the global skill, open Claude Code in any project and run:

```
/serious-init
```

This copies everything into your current project:
- CLAUDE.md (appends if one already exists)
- All skills (feature skills + workflow skills)
- Feature documentation (38 folders)
- v6 implementation plan template

**Variants:**

```
/serious-init --skills-only     # Just skills, no docs or template
/serious-init --docs-only       # Just docs + CLAUDE.md, no skills
/serious-init --no-claude-md    # Skip CLAUDE.md if you have one
```

### Option B: Copy manually

```bash
# From your target project directory:
cp /path/to/this/template/CLAUDE.md ./CLAUDE.md
cp -r /path/to/this/template/.claude/skills/* .claude/skills/
cp -r "/path/to/this/template/Claude Code Features" "./Claude Code Features"
cp /path/to/this/template/_implementation_plan_template_v6.md ./_implementation_plan_template_v6.md
```

## How It Works

Once installed, Claude Code gains awareness of its own features at three levels:

**1. Always aware (CLAUDE.md)**
Every session, Claude sees the feature index and knows about `/serious-research` and `/serious-plan`. If you ask "can you use hooks for this?", it knows hooks exist and where to find the details.

**2. Deep knowledge on demand (Skills)**
Claude knows about its features from training data, but frequently gets specifics wrong — incorrect syntax, outdated flags, missing options, wrong defaults. The 17 feature auto-loader skills fix this. Each is a concise cheat sheet (quick reference, configuration syntax, common patterns) that gets injected into context automatically when the topic comes up. If you mention MCP servers, the MCP skill loads with the correct transport types, scope precedence, and CLI flags. If you ask about permissions, Claude gets the exact rule evaluation order and path pattern syntax. The workflow skills (`/serious-init`, `/serious-conversation`, `/serious-research`, `/serious-mock-ups`, `/serious-plan`, `/serious-code`, `/serious-review`, `/serious-bananas`) load when you invoke them.

**3. Full reference when needed (Research docs)**
For edge cases or deep configuration, Claude can read the full `research.md` which includes official documentation excerpts, all configuration options, and source URLs.

## What Features Are Covered

### 38 documented features across 9 categories

| Category | Features |
|----------|----------|
| **Foundation** | Core CLI, CLAUDE.md, Memory System, Session Management |
| **Configuration** | Settings, Keybindings, Status Line, Output Styles, Themes |
| **Extensibility** | Hooks, Skills & Slash Commands, MCP Integration, Plugins |
| **Orchestration** | Subagents, Agent Teams, Agent SDK |
| **Modes** | Plan Mode, Vim Mode, Fast Mode, Interactive Features |
| **Security** | Permissions, Sandboxing, Enterprise/Managed Settings |
| **Platforms** | IDE Extensions, Chrome, Desktop App, Web, GitHub Actions, Slack, Remote Control |
| **Tools** | Built-in Tools, Git Worktrees, Checkpointing/Rewind, Context Management, Headless Mode |
| **Infrastructure** | Cloud Providers, Multi-Model Support, Cost Management |

### 25 skills (17 feature + 8 workflow)

| Skill | Triggers when you discuss... |
|-------|------------------------------|
| `serious-init` | `/serious-init`, bootstrap, scaffold, setup new project |
| `serious-conversation` | `/serious-conversation`, brainstorm, ideation, think through |
| `serious-research` | `/serious-research`, research, investigation, deep research |
| `serious-mock-ups` | `/serious-mock-ups`, mock up, wireframe, show me the UI, visualize |
| `serious-plan` | `/serious-plan`, implementation plan, planning |
| `serious-code` | `/serious-code`, execute plan, start coding, implement |
| `serious-review` | `/serious-review`, review, QA, defect capture, feedback |
| `serious-bananas` | `/serious-bananas`, generate image, generate diagram, Nano Banana |
| `hooks` | lifecycle events, pre/post tool use, automation |
| `skills-and-commands` | creating custom commands, SKILL.md files |
| `mcp-integration` | MCP servers, external tools, databases |
| `subagents` | multi-agent workflows, parallel agents |
| `plan-mode` | read-only exploration, planning |
| `worktrees` | parallel branches, isolated development |
| `permissions` | allow/deny rules, security, sandboxing |
| `headless-mode` | scripting, CI/CD, -p flag |
| `plugins` | plugin creation, marketplace, distribution |
| `agent-teams` | multi-agent swarms, collaboration |
| `chrome-integration` | browser automation, debugging |
| `fast-mode` | /fast toggle, speed |
| `checkpointing` | rewind, undo, restoring code |
| `remote-control` | mobile access, teleport |
| `keybindings` | keyboard shortcuts, chords |
| `output-styles` | explanatory/learning mode, custom styles |
| `status-line` | status bar, footer customization |

## Browsing the Documentation

The feature docs live in `Claude Code Features/`. Each folder contains a `research.md` with:

- **Overview** — What the feature does
- **Key Capabilities** — Bullet-point summary
- **Configuration / Setup** — How to enable and configure
- **Usage Examples** — Practical patterns
- **Important Details** — Gotchas and limitations
- **References** — Source URLs and citations

The [feature README](./Claude%20Code%20Features/README.md) provides two views:
- **By category** — Features grouped by theme
- **By release date** — Chronological timeline from Feb 2025 to Feb 2026

## Keeping It Updated

This knowledge base was compiled in March 2026. Claude Code evolves rapidly. To refresh:

1. Open Claude Code in this template directory
2. Ask Claude to update specific research files with the latest docs
3. Run `/serious-init` again in your projects to pick up changes

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) installed (`npm install -g @anthropic-ai/claude-code`)
- A Claude account (Pro, Max, Team, or Enterprise)
- For the `/serious-init` command: the global skill installed at `~/.claude/skills/serious-init/SKILL.md`
