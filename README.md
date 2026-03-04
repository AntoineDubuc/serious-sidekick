# Serious Sidekick

Your Claude Code sidekick — a knowledge base, workflow toolkit, and feature reference you drop into any project. Claude gets accurate documentation, structured research and planning skills, and always knows what it can do.

## What's Inside

```
.
├── CLAUDE.md                              # Loaded every session — feature index + workflow skills
├── _implementation_plan_template_v6.md    # V6 implementation plan template (used by /serious-plan)
├── .claude/skills/                        # Auto-loading skills
│   ├── serious-init/SKILL.md              # /serious-init — scaffold a new project
│   ├── serious-research/SKILL.md          # /serious-research — structured research workflow
│   ├── serious-plan/SKILL.md              # /serious-plan — implementation plan generation
│   ├── hooks/SKILL.md                     # 17 feature-specific skills
│   ├── subagents/SKILL.md
│   ├── mcp-integration/SKILL.md
│   ├── permissions/SKILL.md
│   └── ...and 13 more
└── Claude Code Features/                  # 38 research folders + master README
    ├── README.md                          # Categorized & chronological index
    ├── 01_Core_CLI/research.md
    ├── 02_CLAUDE_md/research.md
    ├── ...through...
    └── 38_Enterprise_and_Managed_Settings/research.md
```

## Workflow Skills

The template includes two powerful workflow skills that work together:

### `/serious-research` — Structured Research

Runs a structured research operation with two modes:

| Mode | What it does | When to use |
|------|-------------|-------------|
| **Quick** | Single-threaded research, persona reviews, markdown deliverable | Bug diagnosis, focused investigation, clear single-angle questions |
| **Deep** | Parallel thread agents, evidence grading (A-F), adversarial verification, QA citation checking, HTML report | Architecture decisions, competitive analysis, multi-dimensional topics |

The mode is auto-detected based on your request, or you can force it with `--quick` or `--deep`.

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

### `/serious-plan` — Implementation Planning

Generates a v6 implementation plan from research, a PRD, or even a verbal description. It auto-detects existing `/serious-research` output or asks what input you have.

**Key features:**
- TDD protocol (RED→GREEN→VERIFY per acceptance criterion)
- Adaptive Persona Pipeline (selects relevant reviewers based on what the plan touches)
- Inline QA Protocol v6 (every criterion gets independent QA sub-agent verification)
- Split-Agent Verification (4 parallel agents: Code Review, Static+Tests, Runtime, QA Spot-Check)
- Evidence reports per task

**Typical workflow:**
```
/serious-research [topic]     →  Research phase
/serious-plan                 →  Plan generation (auto-finds research)
                              →  Implementation follows the plan
```

## Knowledge Layers

### Three layers, each serving a different purpose

| Layer | What | When it loads | Context cost |
|-------|------|---------------|--------------|
| **CLAUDE.md** | Feature index + workflow skill references | Every session, survives compaction | Minimal — always present |
| **Skills** | How-to guides for 17 features + 3 workflow skills | On-demand when the topic comes up | Only when relevant |
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
Claude knows about its features from training data, but frequently gets specifics wrong — incorrect syntax, outdated flags, missing options, wrong defaults. The 17 feature auto-loader skills fix this. Each is a concise cheat sheet (quick reference, configuration syntax, common patterns) that gets injected into context automatically when the topic comes up. If you mention MCP servers, the MCP skill loads with the correct transport types, scope precedence, and CLI flags. If you ask about permissions, Claude gets the exact rule evaluation order and path pattern syntax. The workflow skills (`/serious-init`, `/serious-research`, `/serious-plan`) load when you invoke them.

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

### 20 skills (17 feature + 3 workflow)

| Skill | Triggers when you discuss... |
|-------|------------------------------|
| `serious-init` | `/serious-init`, bootstrap, scaffold, setup new project |
| `serious-research` | `/serious-research`, research, investigation, deep research |
| `serious-plan` | `/serious-plan`, implementation plan, planning |
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
