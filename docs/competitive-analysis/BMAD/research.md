# BMAD-AT-CLAUDE Competitive Analysis

**Repository:** https://github.com/24601/BMAD-AT-CLAUDE
**License:** MIT
**Stars:** 217 | **Forks:** 15 | **Language:** JavaScript
**Created:** 2025-07-25 | **Last Updated:** 2026-03-26
**Repo Size:** ~6.3 MB

---

## 1. Overview

### What is BMAD?

BMAD stands for "BMad-Method: Breakthrough Method of Agile AI-driven Development" (also styled as "Foundations in Agentic Agile Driven Development"). It is a framework that combines AI agent personas with Agile/Scrum methodology to create a structured workflow from project ideation through to code delivery.

### Core Philosophy

BMAD positions the user as a **"Vibe CEO"** -- directing a team of specialized AI agents through structured workflows. The two key innovations:

1. **Agentic Planning** -- Dedicated AI agents (Analyst, PM, Architect, UX Expert) collaborate with the user to create detailed PRDs, architecture documents, and UI specs through advanced prompt engineering and human-in-the-loop refinement.
2. **Context-Engineered Development** -- A Scrum Master agent converts detailed plans into "hyper-detailed" development stories containing full context, implementation details, and architectural guidance embedded directly in story files, so the Dev agent never needs to read architecture docs.

### Two-Phase Approach

- **Phase 1: Planning (Web UI)** -- Use large context windows (e.g., Gemini 1M tokens, Claude web) to generate PRDs, architecture docs. Cost-effective for document creation.
- **Phase 2: Development (IDE)** -- Shard documents into small pieces, execute focused SM -> Dev -> QA cycles. One story at a time, sequential progress.

### Target Audience

Software development teams using AI-assisted workflows across any IDE with AI agent support: Cursor, Claude Code, Windsurf, Trae, Cline, Roo Code, GitHub Copilot. Also markets to non-technical domains via "expansion packs" (game dev, infrastructure/DevOps, and potentially entertainment, wellness, etc.).

### Installation

```bash
npx bmad-method install
```

Interactive installer auto-detects IDE, creates `.bmad-core/` folder with agent configs, and supports v4 migration with `.bak` backups.

---

## 2. Architecture

### Directory Layout

```
BMAD-AT-CLAUDE/
├── bmad-core/                        # Core framework (IDE-installable)
│   ├── agents/           (10 files)  # Agent persona definitions (.md with embedded YAML)
│   ├── agent-teams/      (4 files)   # Pre-configured team bundles (.yaml)
│   ├── checklists/       (6 files)   # Quality gate checklists (.md)
│   ├── data/             (4 files)   # Knowledge base & reference data (.md)
│   ├── tasks/            (15 files)  # Discrete task procedures (.md)
│   ├── templates/        (12 files)  # Document templates (.yaml)
│   ├── workflows/        (6 files)   # Workflow definitions (.yaml)
│   ├── core-config.yaml              # Project-level configuration
│   ├── user-guide.md                 # Comprehensive user guide
│   ├── enhanced-ide-development-workflow.md
│   └── working-in-the-brownfield.md
├── bmad-claude-integration/          # Claude Code specific integration
│   ├── hooks/            (4 files)   # Shell hooks for session management
│   ├── routers/          (11 files)  # Router subagent definitions (.md)
│   ├── core/             (4 files)   # JS core: message queue, session mgr, etc.
│   ├── lib/                          # Router generator utility
│   ├── installer/                    # Installation scripts
│   └── tests/                        # Test suites
├── common/                           # Shared utilities
│   ├── tasks/
│   └── utils/            (2 files)   # workflow-management.md, bmad-doc-template.md
├── dist/                             # Pre-built team bundles for web UIs
│   ├── agents/
│   ├── expansion-packs/
│   └── teams/                        # .txt files for ChatGPT/Gemini/etc.
├── expansion-packs/                  # Domain-specific extensions
│   ├── bmad-2d-phaser-game-dev/
│   ├── bmad-2d-unity-game-dev/
│   └── bmad-infrastructure-devops/
├── tools/                            # CLI tooling (Node.js)
│   ├── builders/                     # Agent/team bundle builders
│   ├── flattener/                    # Codebase flattener for AI context
│   ├── installer/                    # npx installer logic
│   └── upgraders/                    # Version migration tools
└── docs/                             # Project documentation
```

### Core Configuration (`core-config.yaml`)

```yaml
markdownExploder: true          # Auto-shard via md-tree CLI tool
prd:
  prdFile: docs/prd.md
  prdSharded: true
  prdShardedLocation: docs/prd
  epicFilePattern: epic-{n}*.md
architecture:
  architectureFile: docs/architecture.md
  architectureSharded: true
  architectureShardedLocation: docs/architecture
devLoadAlwaysFiles:             # Files always in Dev agent context
  - docs/architecture/coding-standards.md
  - docs/architecture/tech-stack.md
  - docs/architecture/source-tree.md
devDebugLog: .ai/debug-log.md
devStoryLocation: docs/stories
slashPrefix: BMad               # All commands use * prefix internally
```

### Key Architectural Patterns

1. **Document Sharding** -- Large PRDs and architecture docs are split by H2 sections into individual files for context window management. Uses `@kayvan/markdown-tree-parser` npm package or manual task.
2. **Lazy Loading** -- Agents never pre-load resources. Templates, tasks, data, and checklists are loaded only when a command invokes them.
3. **YAML-in-Markdown** -- Agent definitions are Markdown files with embedded YAML blocks defining persona, commands, and dependencies.
4. **Story-Driven Development** -- Stories in `docs/stories/` are the unit of work. Each story is self-contained with all context the Dev agent needs.
5. **Fresh Context Per Agent** -- Each agent interaction starts a new chat/conversation to avoid context degradation.
6. **Dual Environment** -- Planning in web UIs (cost-effective), execution in IDEs.

---

## 3. Agents/Personas (Detailed)

BMAD defines **10 agent personas**, each with a human name, icon, role, style, and dependency list:

### 3.1 Analyst (Mary)
- **Icon:** Clipboard Chart
- **Role:** Insightful Analyst & Strategic Ideation Partner
- **Style:** Analytical, inquisitive, creative, facilitative, objective
- **When to Use:** Market research, brainstorming, competitive analysis, project briefs, brownfield discovery
- **Commands:** `create-project-brief`, `perform-market-research`, `create-competitor-analysis`, `brainstorm`, `elicit`, `research-prompt`
- **Key Templates:** project-brief, market-research, competitor-analysis, brainstorming-output

### 3.2 PM -- Product Manager (John)
- **Icon:** Clipboard
- **Role:** Investigative Product Strategist & Market-Savvy PM
- **Style:** Analytical, inquisitive, data-driven, user-focused, pragmatic
- **When to Use:** Creating PRDs, product strategy, feature prioritization, roadmap planning
- **Commands:** `create-prd`, `create-brownfield-prd`, `create-brownfield-epic`, `create-brownfield-story`, `shard-prd`, `correct-course`
- **Key Templates:** prd, brownfield-prd

### 3.3 Architect (Winston)
- **Icon:** Building Construction
- **Role:** Holistic System Architect & Full-Stack Technical Leader
- **Style:** Comprehensive, pragmatic, user-centric, technically deep yet accessible
- **When to Use:** System design, architecture documents, technology selection, API design, infrastructure planning
- **Commands:** `create-full-stack-architecture`, `create-backend-architecture`, `create-front-end-architecture`, `create-brownfield-architecture`, `research`
- **Core Principles:** Holistic system thinking, pragmatic technology selection ("choose boring technology where possible, exciting where necessary"), progressive complexity, cost-conscious engineering

### 3.4 UX Expert (Sally)
- **Icon:** Art Palette
- **Role:** User Experience Designer & UI Specialist
- **Style:** Empathetic, creative, detail-oriented, user-obsessed
- **When to Use:** UI/UX design, wireframes, prototypes, front-end specifications
- **Commands:** `create-front-end-spec`, `generate-ui-prompt`
- **Unique Feature:** Can generate prompts for AI UI tools like v0, Lovable -- this is a bridge to external AI UI generation

### 3.5 PO -- Product Owner (Sarah)
- **Icon:** Memo
- **Role:** Technical Product Owner & Process Steward
- **Style:** Meticulous, analytical, detail-oriented, systematic, collaborative
- **When to Use:** Backlog management, story refinement, acceptance criteria, document validation
- **Commands:** `execute-checklist-po`, `shard-doc`, `correct-course`, `create-epic`, `create-story`, `validate-story-draft`
- **Key Role:** Runs the PO Master Checklist (massive quality gate) to validate all artifacts

### 3.6 SM -- Scrum Master (Bob)
- **Icon:** Runner
- **Role:** Technical Scrum Master - Story Preparation Specialist
- **Style:** Task-oriented, efficient, precise, focused on clear developer handoffs
- **When to Use:** Story creation, epic management, agile process guidance
- **Commands:** `draft` (create-next-story), `correct-course`, `story-checklist`
- **Critical Design:** Stories must be hyper-detailed so "dumb AI agents can implement without confusion"

### 3.7 Dev -- Developer (James)
- **Icon:** Computer
- **Role:** Expert Senior Software Engineer & Implementation Specialist
- **Style:** Extremely concise, pragmatic, detail-oriented, solution-focused
- **When to Use:** Code implementation, debugging, refactoring
- **Commands:** `run-tests`, `explain`, `exit`
- **Key Protocol (`develop-story`):** Read task -> Implement -> Write tests -> Execute validations -> Mark checkbox -> Repeat. HALT on: unapproved deps, ambiguity, 3 failures, missing config, failing regression.
- **Strict File Permissions:** Can ONLY update Dev Agent Record sections of story files (checkboxes, debug log, completion notes, change log, file list)

### 3.8 QA (Quinn)
- **Icon:** Test Tube
- **Role:** Senior Developer & Test Architect
- **Style:** Methodical, detail-oriented, quality-focused, mentoring, strategic
- **When to Use:** Senior code review, refactoring, test planning, quality assurance
- **Commands:** `review`
- **Unique:** Can actively REFACTOR code (not just review), then explain why. Operates as a "senior developer mentoring juniors."
- **Strict File Permissions:** Can ONLY update "QA Results" section of story files

### 3.9 BMad Master (Wizard)
- **Icon:** Wizard
- **Role:** Master Task Executor & BMad Method Expert
- **When to Use:** Comprehensive expertise across all domains, one-off tasks, do-everything agent
- **Has Access To:** ALL tasks, templates, workflows, checklists, data (13 tasks, 11 templates, 6 workflows, 6 checklists, 4 data files)
- **Design:** For users who don't want to switch agents. Caveat: context degrades with heavy use.

### 3.10 BMad Orchestrator
- **Icon:** Theater Masks
- **Role:** Master Orchestrator & BMad Method Expert
- **When to Use:** Workflow coordination, multi-agent tasks, role switching guidance. WEB UI ONLY -- not for IDE.
- **Commands:** `help`, `chat-mode`, `kb-mode`, `status`, `agent [name]`, `workflow`, `workflow-guidance`, `plan`, `plan-status`, `yolo`, `party-mode`, `doc-out`
- **Unique Features:** Can dynamically transform into any specialist agent. 85% fuzzy matching threshold for commands. `*party-mode` for group chat with all agents.

### Agent Pattern Summary

All agents share a common pattern:
- Embedded YAML in Markdown defining persona, commands, dependencies
- `*` prefix for all commands (e.g., `*help`, `*draft`)
- Lazy resource loading (dependencies loaded only on command execution)
- `*yolo` toggle to skip confirmations
- `*exit` to return to previous state
- Numbered list presentation for all options
- "STAY IN CHARACTER" instruction
- Activation instructions that establish persona on load

---

## 4. Workflows

Six pre-defined workflow configurations organized by project type and architecture scope:

### 4.1 Greenfield Workflows
- **greenfield-fullstack** -- Complete new full-stack application
- **greenfield-service** -- Backend/API service only
- **greenfield-ui** -- Frontend UI only

### 4.2 Brownfield Workflows
- **brownfield-fullstack** -- Enhancing existing full-stack application
- **brownfield-service** -- Enhancing existing backend/API
- **brownfield-ui** -- Enhancing existing frontend

### Greenfield Fullstack Workflow (Most Comprehensive)

Full pipeline with mermaid flow diagram. Sequence:

1. **Analyst** creates `project-brief.md` (optional: brainstorming, market research)
2. **PM** creates `prd.md` from project brief
3. **UX Expert** creates `front-end-spec.md` from PRD
4. **UX Expert** (optional) generates v0/Lovable AI prompt
5. **Architect** creates `fullstack-architecture.md` from PRD + UX spec
6. **PM** updates PRD if architect suggests changes
7. **PO** validates all artifacts via master checklist
8. Loop: fix issues found by PO
9. **PO** shards documents for IDE development
10. **SM** creates stories (repeats for each epic)
11. (Optional) **Analyst/PM** reviews draft story
12. **Dev** implements story
13. (Optional) **QA** reviews implementation
14. **Dev** addresses QA feedback if needed
15. Repeat SM -> Dev -> QA cycle for all stories
16. (Optional) **PO** epic retrospective

### Brownfield Fullstack Workflow

Adds brownfield-specific intelligence:

1. **Analyst** classifies enhancement scope (single story / small feature / major enhancement)
2. **Routing decision** -- single story exits early via `brownfield-create-story`; small feature via `brownfield-create-epic`; major continues
3. **Documentation check** -- Assesses if existing docs are adequate
4. **Architect** analyzes existing project via `document-project` if docs inadequate
5. **PM** creates PRD using brownfield template
6. Architecture decision point -- only create arch doc if significant changes needed
7. Rest follows similar pattern to greenfield

### Key Workflow Design Principles

- Each workflow includes a **mermaid flow diagram** for visual reference
- **Handoff prompts** are defined for each transition (e.g., "PRD is ready. Save it as docs/prd.md then create UI/UX specification")
- **Decision guidance** with explicit `when_to_use` criteria
- Workflows are **YAML-defined** with structured `sequence` arrays, not code
- Human-in-the-loop at every major transition point

---

## 5. Templates (12 Total)

All templates are YAML files defining sections with instructions, elicitation rules, and output formatting.

### Planning Templates
| Template | Purpose | Key Sections |
|----------|---------|-------------|
| `project-brief-tmpl.yaml` | Initial project definition | Problem, users, success metrics, MVP scope |
| `prd-tmpl.yaml` | Product Requirements Document | Goals, FRs, NFRs, UI goals, tech assumptions, epic list, epic details with stories + ACs |
| `brownfield-prd-tmpl.yaml` | PRD for existing system enhancements | Same but with existing system context |

### Architecture Templates
| Template | Purpose |
|----------|---------|
| `architecture-tmpl.yaml` | Backend/service architecture |
| `fullstack-architecture-tmpl.yaml` | Full-stack architecture |
| `front-end-architecture-tmpl.yaml` | Frontend architecture |
| `brownfield-architecture-tmpl.yaml` | Brownfield enhancement architecture |

### UX Templates
| Template | Purpose |
|----------|---------|
| `front-end-spec-tmpl.yaml` | Frontend UI/UX specification |

### Development Templates
| Template | Purpose |
|----------|---------|
| `story-tmpl.yaml` | User story with tasks, dev notes, testing, dev agent record, QA results |

### Research Templates
| Template | Purpose |
|----------|---------|
| `brainstorming-output-tmpl.yaml` | Structured brainstorming session output |
| `competitor-analysis-tmpl.yaml` | Competitive analysis document |
| `market-research-tmpl.yaml` | Market research document |

### Story Template (Deep Dive)

The story template (`story-tmpl.yaml` v2) is central to BMAD's "context-engineered development." Key design:

- **Status tracking:** Draft -> Approved -> InProgress -> Review -> Done
- **Strict section ownership:** SM owns Story/AC/Tasks/Dev Notes. Dev owns Dev Agent Record. QA owns QA Results.
- **Dev Notes section (CRITICAL):** Must contain ALL relevant technical details extracted from architecture docs so the Dev agent "should NEVER need to read the architecture documents." This is the context engineering innovation.
- **Dev Agent Record:** Tracks agent model used, debug log references, completion notes, file list, change log.
- **QA Results:** Separate section for QA review findings.

### PRD Template (Deep Dive)

The PRD template (`prd-tmpl.yaml` v2) enforces:

- **Goals & Background** from project brief
- **Requirements** with FR/NFR prefix numbering
- **UI Design Goals** with accessibility choices (WCAG AA/AAA), platform targeting
- **Technical Assumptions** including repo structure (mono/poly), service architecture, testing requirements
- **Epic List** with strict sequencing rules: each epic delivers deployable increment, Epic 1 = foundation + initial functionality, cross-cutting concerns flow through all epics (not deferred to end)
- **Epic Details** with story templates: "As a [role], I want [action], so that [benefit]" + numbered acceptance criteria
- **Story sizing:** "Think junior developer working for 2-4 hours" -- small, focused, self-contained, completable by a single AI agent in one session
- **Checklist Results Report** -- PM runs pm-checklist before completion
- **Next Steps** -- Auto-generated prompts for UX Expert and Architect

---

## 6. Tasks (15 Total)

Tasks are the operational procedures that agents execute. Each is a Markdown file with step-by-step instructions.

| Task | Agent(s) | Purpose |
|------|----------|---------|
| `advanced-elicitation.md` | Many | Structured information gathering from user |
| `brownfield-create-epic.md` | PM | Create epic for existing system enhancement |
| `brownfield-create-story.md` | PM, SM | Create story for brownfield context |
| `correct-course.md` | PM, SM, PO | Navigate changes mid-sprint, produce "Sprint Change Proposal" |
| `create-brownfield-story.md` | SM | Alternative brownfield story creation |
| `create-deep-research-prompt.md` | Analyst, Architect | Generate research prompts (9 focus types: product validation, market opportunity, user research, competitive intelligence, technology, industry, strategic options, risk/feasibility, custom) |
| `create-next-story.md` | SM | Identify and create next sequential story from sharded docs |
| `document-project.md` | Architect, Analyst | Document an existing brownfield project |
| `facilitate-brainstorming-session.md` | Analyst | 4-step brainstorming (setup, technique selection, execution, document output) |
| `generate-ai-frontend-prompt.md` | UX Expert | Generate prompts for AI UI tools (v0, Lovable) |
| `index-docs.md` | BMad Master | Index project documentation |
| `kb-mode-interaction.md` | Orchestrator | Knowledge base Q&A interaction |
| `review-story.md` | QA | Comprehensive code review with active refactoring ability |
| `shard-doc.md` | PO, BMad Master | Split large docs into sharded files by H2 sections |
| `validate-next-story.md` | PO, Dev | Validate story readiness |

### `create-next-story` (Deep Dive)

The story creation task is BMAD's most sophisticated task:

1. **Load core-config.yaml** -- Extract paths, patterns, settings
2. **Identify next story** -- Find highest `{epicNum}.{storyNum}.story.md`, check status, determine next
3. **Gather architecture context** -- Different reading strategies for backend/frontend/fullstack stories (reads specific arch shard files)
4. **Extract story-specific technical details** -- ONLY information from source docs, never invented. Every detail must cite `[Source: architecture/{filename}.md#{section}]`
5. **Verify project structure alignment** -- Cross-reference with `unified-project-structure.md`
6. **Populate story template** -- Fill Dev Notes with all context so Dev agent never needs to read architecture

### `correct-course` (Deep Dive)

Sprint change management procedure:
1. Acknowledge change trigger, verify access to artifacts
2. Choose interaction mode: Incremental (section-by-section) or YOLO (batch)
3. Execute change-checklist analysis (Sections 1-4)
4. Draft specific proposed edits for each affected artifact
5. Generate "Sprint Change Proposal" document
6. Determine next steps: direct implementation or fundamental replan

---

## 7. Checklists (6 Total)

Quality gates executed at specific workflow points:

| Checklist | Used By | Purpose |
|-----------|---------|---------|
| `architect-checklist.md` | Architect | Validate architecture completeness |
| `change-checklist.md` | PM, SM, PO | Guide sprint change analysis |
| `pm-checklist.md` | PM | Validate PRD completeness |
| `po-master-checklist.md` | PO | Master validation of ALL planning artifacts (10 categories) |
| `story-dod-checklist.md` | Dev | Definition of Done self-assessment before marking story complete |
| `story-draft-checklist.md` | SM | Validate story draft quality |

### PO Master Checklist (Deep Dive)

The most comprehensive quality gate. 10 categories across ~80 checklist items:

1. **Project Setup & Initialization** -- Scaffolding (greenfield) or integration safety (brownfield)
2. **Infrastructure & Deployment** -- DB, API, CI/CD, testing infrastructure
3. **External Dependencies & Integrations** -- Third-party services, APIs, cloud resources
4. **UI/UX Considerations** -- Design system, frontend infrastructure, UX flow (skipped for backend-only)
5. **User/Agent Responsibility** -- Human vs AI task assignment
6. **Feature Sequencing & Dependencies** -- Functional, technical, cross-epic dependencies
7. **Risk Management** (brownfield only) -- Breaking changes, rollback, user impact
8. **MVP Scope Alignment** -- Core goals, user journeys, technical requirements
9. **Documentation & Handoff** -- Developer docs, user docs, knowledge transfer
10. **Post-MVP Considerations** -- Future enhancements, monitoring

Produces a validation report with: Go/No-Go recommendation, risk assessment (top 5 risks), MVP completeness, implementation readiness score (1-10), specific recommendations.

### Story DoD Checklist (Deep Dive)

Developer self-assessment before marking "Ready for Review":
1. Requirements met (all FRs, all ACs)
2. Coding standards & project structure compliance
3. Testing (unit, integration, E2E, coverage)
4. Manual verification
5. Story administration (tasks marked complete, decisions documented)
6. Dependencies, build & configuration
7. Documentation

---

## 8. Agent Teams

Pre-configured bundles that package agents + workflows together:

| Team | Agents Included | Workflows |
|------|----------------|-----------|
| `team-all` | All 10 agents | All 6 workflows |
| `team-fullstack` | orchestrator, analyst, pm, ux-expert, architect, po | All 6 workflows |
| `team-ide-minimal` | (Minimal set for IDE) | Subset |
| `team-no-ui` | (Backend focused, no UX) | Service workflows |

For web UIs, teams are built into single `.txt` files in `dist/teams/` that can be uploaded to ChatGPT Custom GPTs or Gemini Gems.

---

## 9. Claude Code Integration

The `bmad-claude-integration/` directory provides a specific integration layer for Claude Code:

### Architecture Components

1. **Message Queue** (`core/message-queue.js`) -- Async communication between agents, retry logic, TTL management
2. **Elicitation Broker** (`core/elicitation-broker.js`) -- Manages interactive Q&A phases, tracks history per session
3. **Session Manager** (`core/session-manager.js`) -- Multiple concurrent agent sessions with switching
4. **BMAD Loader** (`core/bmad-loader.js`) -- Parses agent YAML configs and markdown content

### Router Subagents (11 files)

Each agent gets a router that acts as a thin wrapper:
- `bmad-router.md` -- Main router with pattern recognition and routing logic
- `analyst-router.md`, `architect-router.md`, `dev-router.md`, `pm-router.md`, `po-router.md`, `qa-router.md`, `sm-router.md`, `ux-expert-router.md`, `bmad-master-router.md`, `bmad-orchestrator-router.md`

### Hooks (4 shell scripts)

- `bmad-context-save.sh` -- Save context when subagent completes
- `bmad-elicitation-handler.sh` -- Handle elicitation phases
- `bmad-session-check.sh` -- Check for active BMAD sessions on startup
- `bmad-session-switch.sh` -- Handle session switching

### Claude Code Slash Commands

- `/bmad-pm` -- Invoke Project Manager
- `/bmad-architect` -- Invoke Architect
- `/bmad-dev` -- Invoke Developer
- `/bmad-sessions` -- View active sessions
- `/bmad-switch <number>` -- Switch between sessions

### Natural Language Routing

The main router (`bmad-router.md`) can automatically route requests to the appropriate agent based on pattern recognition:
- "Create user stories for a shopping cart feature" -> Routes to PM
- "Design a microservices architecture" -> Routes to Architect
- "Review this code for quality" -> Routes to QA

---

## 10. Expansion Packs

Domain-specific extensions that add specialized agents, templates, and workflows:

### Available Packs
1. **bmad-2d-phaser-game-dev** -- 2D game development with Phaser framework
2. **bmad-2d-unity-game-dev** -- 2D game development with Unity
3. **bmad-infrastructure-devops** -- Infrastructure and DevOps workflows

Each pack has its own `agents/`, `templates/`, `tasks/`, `checklists/`, `data/`, and `config.yaml`.

### Additional Tools
- **Codebase Flattener** -- Aggregates project files into XML format for AI consumption with smart filtering and binary detection
- **Version management** -- Semantic release integration, version bumping tools

---

## 11. Key Differentiators

### What Makes BMAD Unique/Clever

1. **Context Engineering via Story Files** -- The most distinctive innovation. Stories contain ALL context a Dev agent needs, extracted from architecture docs with source citations. The Dev agent never reads architecture docs directly. This is a smart solution to the context window problem.

2. **Multi-Platform Support** -- Same agent definitions work across ChatGPT (Custom GPTs), Gemini (Gems), Cursor, Claude Code, Windsurf, Cline, Roo Code, and more. The `.txt` bundle format for web UIs is particularly clever.

3. **Two-Phase Planning/Execution Split** -- Planning in cheap web UIs, execution in IDEs. Acknowledges the economics of AI token costs.

4. **Brownfield First-Class Support** -- Dedicated brownfield workflows, templates, and tasks. Not just greenfield. Enhancement classification (single story / small feature / major enhancement) to right-size the process.

5. **Agile Methodology Deep Integration** -- Not just "AI personas" but a full Scrum implementation: epics, stories, sprints, DoD checklists, PO validation, retrospectives, sprint change proposals.

6. **`*yolo` Mode** -- Skip confirmation prompts. Small touch but shows attention to power-user workflows.

7. **Document Sharding** -- Automatic splitting of large docs by H2 sections using `md-tree` CLI tool. Practical solution to context window limits.

8. **Strict File Permissions Per Agent** -- Dev can only update Dev Agent Record sections. QA can only update QA Results. SM can only update story fields. Prevents agents from accidentally modifying each other's work.

9. **Source Citation Requirements** -- Dev Notes must cite `[Source: architecture/{filename}.md#{section}]` for every technical detail. Forces traceability.

10. **Change Navigation** -- `correct-course` task with structured "Sprint Change Proposal" for mid-sprint changes. Most frameworks ignore change management.

11. **Expansion Pack Architecture** -- Extensible to non-software domains with self-contained packs.

12. **Codebase Flattener Tool** -- Utility to aggregate project files into XML for AI consumption.

---

## 12. Feature Inventory

### Complete Capability List

| Category | Feature | Description |
|----------|---------|-------------|
| **Agents** | 10 Agent Personas | Analyst, PM, Architect, UX, PO, SM, Dev, QA, Master, Orchestrator |
| **Agents** | Human Names | Each agent has a personality (Mary, John, Winston, Sally, Sarah, Bob, James, Quinn) |
| **Agents** | Agent Transformation | Orchestrator can morph into any agent on demand |
| **Agents** | Party Mode | Group chat with all agents simultaneously |
| **Agents** | YOLO Mode | Skip confirmation prompts |
| **Agents** | KB Mode | Interactive knowledge base Q&A |
| **Templates** | 12 Document Templates | PRD, architecture (4 variants), frontend spec, story, project brief, brainstorming, competitor analysis, market research |
| **Templates** | YAML-Based Templates | Structured with sections, instructions, elicitation rules, output format |
| **Workflows** | 6 Workflow Definitions | Greenfield/brownfield x fullstack/service/UI |
| **Workflows** | Mermaid Flow Diagrams | Visual workflow documentation |
| **Workflows** | Handoff Prompts | Scripted agent-to-agent transitions |
| **Workflows** | Enhancement Classification | Brownfield triage: single story / small feature / major |
| **Tasks** | 15 Task Procedures | Story creation, research, brainstorming, course correction, etc. |
| **Tasks** | Context-Engineered Stories | Stories embed all architecture context with source citations |
| **Tasks** | Deep Research Prompts | 9 research focus types for structured investigation |
| **Tasks** | AI Frontend Prompts | Generate prompts for v0/Lovable UI generation tools |
| **Tasks** | Document Sharding | Auto-split large docs by sections |
| **Tasks** | Brainstorming Facilitation | 4-step process with technique selection |
| **Tasks** | Sprint Change Management | Structured change proposals with checklist-driven analysis |
| **Checklists** | 6 Quality Gates | PO master (80 items), story DoD, story draft, architect, PM, change |
| **Checklists** | Adaptive Checklists | Auto-skip greenfield/brownfield/UI sections based on project type |
| **Teams** | 4 Team Bundles | All, fullstack, IDE-minimal, no-UI |
| **Teams** | Web UI Bundles | Single .txt files for ChatGPT/Gemini upload |
| **Integration** | Claude Code Integration | Routers, hooks, session management, message queue |
| **Integration** | Multi-IDE Support | Cursor, Claude Code, Windsurf, Trae, Cline, Roo Code, Copilot |
| **Integration** | Natural Language Routing | Auto-detect appropriate agent from request |
| **Integration** | Concurrent Sessions | Multiple agents active simultaneously |
| **Expansion** | 3 Expansion Packs | Phaser game dev, Unity game dev, Infrastructure/DevOps |
| **Tools** | npx Installer | Interactive install with IDE detection and v4 migration |
| **Tools** | Codebase Flattener | Aggregate files to XML for AI context |
| **Tools** | Version Management | Semantic release, version bumping |
| **Config** | core-config.yaml | Project-level settings for paths, sharding, preferences |
| **Config** | technical-preferences.md | User-customizable tech preferences |
| **Data** | Knowledge Base | bmad-kb.md with comprehensive method documentation |
| **Data** | Brainstorming Techniques | Reference data for facilitation |
| **Data** | Elicitation Methods | Reference data for information gathering |

---

## 13. Comparison with Serious Sidekick

### What BMAD Has That We Don't

| BMAD Feature | Significance | Should We Adopt? |
|-------------|-------------|-----------------|
| **Named agent personas** (Winston, James, etc.) | Personality makes agents memorable and adds character | LOW -- fun but not functional. Our personas are already rich. |
| **Multi-platform support** (ChatGPT, Gemini, Cursor, etc.) | Much broader reach beyond Claude Code | MEDIUM -- we are Claude-native; this breadth dilutes depth. But exporting to other platforms is worth considering. |
| **Web UI planning phase** | Cost optimization via cheap web context windows | LOW -- Claude Code already handles large context. The economics argument is weaker with 1M context models. |
| **Document sharding** | Splits large docs into smaller files for context management | HIGH -- Very practical. We should consider this for large research files, plans, etc. |
| **Brownfield-specific workflows/templates** | First-class support for existing codebases | HIGH -- We lack this. `/serious-research` could discover existing codebase, but we don't have brownfield-specific planning templates or enhancement classification. |
| **Story-driven development with embedded context** | Self-contained stories with all arch context cited | MEDIUM -- Our `/serious-code` uses plans, but the idea of embedding ALL context into the implementation unit is powerful. |
| **PRD generation** | Structured PRD with epics and stories | MEDIUM -- Our `/serious-scope` generates scope manifests, but not full PRDs with FRs/NFRs/epic details. |
| **PO Master Checklist (80 items)** | Comprehensive cross-artifact validation | HIGH -- Very thorough. Our `/serious-review` does plan review, but not cross-artifact validation of this depth. |
| **Sprint change management** (`correct-course`) | Structured mid-sprint change proposals | MEDIUM -- We don't handle mid-implementation changes formally. |
| **AI frontend prompt generation** (v0/Lovable) | Bridge to external AI UI tools | LOW -- Niche feature. Our `/serious-mock-ups` generates actual mockups. |
| **Expansion packs** (game dev, DevOps) | Domain-specific extensions | LOW for now -- interesting extensibility model but we should focus on core first. |
| **Codebase flattener** | Aggregate files to XML for AI | LOW -- Claude Code already reads files natively. |
| **Concurrent agent sessions with switching** | Multiple agents active in parallel | MEDIUM -- Our subagent model handles this differently via Agent Teams. |
| **`*yolo` mode** | Skip confirmations | LOW -- Nice UX touch, easy to add. |
| **Agent file permissions** | Strict section ownership in story files | MEDIUM -- Prevents agents from stepping on each other's work. Smart guard rail. |
| **Source citation requirements** | `[Source: architecture/{file}#{section}]` | HIGH -- Forces traceability. We should adopt this in our plan/code artifacts. |

### What We Have That BMAD Doesn't

| Serious Sidekick Feature | BMAD Equivalent | Our Advantage |
|--------------------------|-----------------|---------------|
| **`/serious-conversation`** (persona panel, hub-and-spoke) | `*party-mode` (basic group chat) | Much richer -- we have 10+ personas with independent sub-agent responses, orchestrator synthesis, iterative refinement, versioned artifacts |
| **`/serious-research`** (quick/deep modes, evidence grading) | `create-deep-research-prompt` (generates prompts, doesn't DO research) | We actually perform research. BMAD generates a prompt for you to take elsewhere. |
| **`/serious-mock-ups`** (wireframe/visual/interactive) | UX Expert `generate-ui-prompt` (generates prompts for v0/Lovable) | We generate actual mockups at 3 fidelity levels. BMAD outsources UI generation. |
| **`/serious-scope`** (scope manifests, splitting) | PRD with epics (static) | We generate dynamic scope manifests that split into independently-plannable units. BMAD's PRD is more traditional. |
| **`/serious-plan`** (v6 template with TDD protocol, inline QA) | Architect creates architecture, SM creates stories | Our plans are implementation-level with TDD protocol, test specifications, and QA steps. BMAD's stories are requirement-level. |
| **`/serious-review`** (adaptive persona pipeline, anti-slop auditor) | PO Master Checklist + QA review-story | We have automated multi-agent review with specialized anti-slop detection. BMAD's review is manual checklist + single QA agent. |
| **`/serious-code`** (parallel worktrees, 5-agent TDD cycle) | Dev agent (single agent, sequential) | We orchestrate 5 agents (implementer, reviewer, test-runner, runtime-checker, QA) in parallel worktrees. BMAD has one Dev agent executing sequentially. |
| **Claude Code feature documentation** (39 features) | None | We document Claude Code capabilities extensively. BMAD is platform-agnostic. |
| **Hooks system** (6 Stop hooks) | 4 shell script hooks (basic) | Our hooks are deeply integrated into workflow lifecycle. BMAD's are session management only. |
| **Workflow frontmatter tracking** | core-config.yaml (project-level only) | We track individual artifact status, lineage, verification hashes. BMAD has no per-artifact metadata. |
| **Breadcrumb files** (`.active-{skill-name}`) | None | We have active workflow tracking. BMAD relies on user memory. |
| **Handoff verification** (cross-artifact hash checking) | PO Master Checklist (manual) | We automatically detect stale artifacts via SHA-256 hashes. |
| **Plan versioning with diffing** | None | Our plans are versioned artifacts. BMAD stories overwrite in place. |

### Strategic Assessment

**BMAD's strengths relative to us:**
- More complete Agile/Scrum methodology (epics, stories, DoD, PO validation, change management)
- Broader platform support (not Claude-locked)
- Better context engineering for Dev agents (stories as self-contained units)
- More mature document management (sharding, always-loaded files)
- Richer template library (12 templates covering more document types)
- Brownfield support is a significant gap for us

**Our strengths relative to BMAD:**
- Deeper automation (research is performed, not just prompted; mockups are generated, not outsourced)
- More sophisticated multi-agent orchestration (5-agent TDD cycle, parallel worktrees, persona panels)
- Better artifact lifecycle management (frontmatter, hashes, breadcrumbs, handoff verification)
- More powerful review system (anti-slop auditor, structural reviewer, multi-agent pipeline)
- Claude Code native -- deeper platform integration

**BMAD's approach is wider but shallower; ours is narrower but deeper.**

### Recommendations for Adoption

**High Priority:**
1. **Document sharding** -- Implement for research files and large plans. BMAD's `md-tree` approach is simple and effective.
2. **Brownfield workflow support** -- Add brownfield-specific templates and enhancement classification to `/serious-scope` and `/serious-plan`.
3. **PO-style cross-artifact validation** -- Expand `/serious-review` to validate not just plans but cross-artifact consistency (PRD vs architecture vs stories).
4. **Source citation in plans** -- Require `[Source: ...]` references when plans cite architecture or research decisions.

**Medium Priority:**
5. **Story-level context embedding** -- When `/serious-code` generates implementation tasks, embed all relevant context so the executing agent doesn't need to re-read upstream artifacts.
6. **Sprint change management** -- Add a structured change procedure when implementation discovers that plans need revision.
7. **Agent file permissions** -- Formalize which sections of shared artifacts each agent can modify.
8. **Epic/story structuring in scope** -- Add PRD-like epic/story structure to `/serious-scope` output for projects that follow Agile methodology.

**Low Priority:**
9. **YOLO mode** -- Quick win, skip confirmations toggle.
10. **Named personas** -- Character names for agents (cosmetic).
11. **Multi-platform export** -- Generate bundles for non-Claude platforms.
12. **Expansion pack architecture** -- Domain-specific extensions.

---

## 14. Summary

BMAD-AT-CLAUDE is a well-structured, Agile-methodology-first AI development framework with 10 specialized agents, 12 templates, 6 workflows, 15 tasks, and 6 quality checklists. Its standout innovation is **context-engineered stories** where the Scrum Master embeds all relevant architecture context directly into story files so the Dev agent operates self-sufficiently.

Key takeaways:
- **Different philosophy**: BMAD follows traditional Agile/Scrum closely (PRDs, epics, stories, sprints). Serious Sidekick follows a research-first, plan-then-execute approach.
- **Different depth**: BMAD spreads wide (multi-platform, many templates, expansion packs). Serious Sidekick goes deep (multi-agent orchestration, automated research, TDD cycles).
- **Complementary strengths**: BMAD's brownfield support, document sharding, cross-artifact validation, and context engineering are features we should adopt. Our research depth, mockup generation, parallel execution, and artifact lifecycle management are advantages to preserve.
- **Market positioning**: BMAD targets the broader "AI-assisted development" market with IDE-agnostic support. Serious Sidekick is Claude Code native, enabling deeper integration at the cost of platform lock-in.
