## MANDATORY — VIOLATING ANY OF THESE IS A FAILURE

1. **DO NOT** enter plan mode. `EnterPlanMode` is **FORBIDDEN**.
2. **DO NOT** export, print, log, or read credentials from code. Read ONLY from `.env`. Write ONLY to `.env`. **DO NOT DELETE `.env`. EVER.**
3. **BE BRIEF.** Start every response with a short summary. No fluff. No preamble.
4. **INVESTIGATE BEFORE CODING.** When a problem is raised, **DO NOT WRITE CODE.** Investigate first. Return with:

   - **Root cause** — what broke
   - **Why** — the underlying reason
   - **Proposed fix(es)** — one or more options

   If the investigation is non-trivial (multi-file, unclear root cause, architecture question), offer to run `/serious-research` for a structured, documented investigation.
5. **DO NOT** touch, edit, create, or delete any file without **explicit user consent**.
6. **DO NOT** commit, push, create PRs, or perform any GitHub action without **explicit user consent**.
7. **PROVE IT WORKS.** Nothing is "done" without evidence — test output, screenshots, or demonstrated behavior from the user's perspective.
8. **ANSWER FIRST.** If the user asks a question, answer it **before** doing anything else.
9. **ONE QUESTION AT A TIME.** When you need input, ask **one question per message**. Format it as:
   - **Your recommended option** — with a short explanation of why
   - **3-5 other options** — with brief trade-offs for each
   - **Why you didn't pick them** — what made the recommended option better

   Do NOT dump multiple questions in one message. Wait for the answer before asking the next question.

---

# Project: Serious Sidekick

## Workflow Skills

This project includes six workflow skills for structured development:

- **`/serious-conversation`** — Think out loud with a panel of personas (hub-and-spoke model). Pick from 10 built-in personas or create custom ones. Each round: personas respond independently via sub-agents, Orchestrator synthesizes, user refines. Creates versioned artifacts in `Research/conversations/`.
- **`/serious-research`** — Structured research with two modes (quick or deep). Creates a `Research/` folder with findings, evidence grading, and persona reviews. Use for bugs, features, or exploratory questions.
- **`/serious-mock-ups`** — Generate UI mock-ups from research before planning. Three fidelity levels (wireframe, visual, interactive flow), iterative feedback with versioning, component inventory, and design decision log. Outputs feed directly into `/serious-plan`.
- **`/serious-plan`** — Generates an implementation plan from research, a PRD, or a description. Uses the v6 template at `./_implementation_plan_template_v6.md`. Includes TDD protocol, persona pipeline, inline QA, and split-agent verification. Auto-detects mock-ups for component inventory and design decisions. Supports single or multiple plans with a phase map for parallel execution.
- **`/serious-code`** — Executes implementation plans from `/serious-plan`. Orchestrates parallel plan execution via git worktrees, manages TDD cycles through 5 Agent Teams agents (implementer, reviewer, test-runner, runtime-checker, qa), handles phase-by-phase verification, and generates evidence reports.

**Typical workflow:** `/serious-conversation` → `/serious-research` → `/serious-mock-ups` → `/serious-plan` → `/serious-code` → done

## Claude Code Feature Reference

Detailed feature documentation lives in `./Claude Code Features/`. Before answering questions about Claude Code capabilities, read the relevant `research.md` file.

### Quick Feature Index

**Foundation:** Core CLI (01), CLAUDE.md (02), Memory System (16), Session Management (15)
**Config:** Settings (18), Keybindings (23), Status Line (24), Output Styles (27), Themes (36)
**Extensibility:** Hooks (03), Skills & Slash Commands (04), MCP Integration (05), Plugins (26)
**Orchestration:** Subagents (09), Agent Teams (28), Agent SDK (07)
**Modes:** Plan Mode (21), Vim Mode (22), Fast Mode (29), Interactive Features (37)
**Security:** Permissions (10), Sandboxing (35), Enterprise/Managed Settings (38)
**Platforms:** IDE Extensions (06), Chrome (25), Desktop App (33), Web (34), GitHub Actions (08), Slack (32), Remote Control (31)
**Tools:** Built-in Tools (19), Git Worktrees (13), Checkpointing/Rewind (30), Context Management (12), Headless Mode (11)
**Infrastructure:** Cloud Providers (14), Multi-Model Support (20), Cost Management (17)

### How to Use

- Each number maps to a folder: e.g., `03` = `./Claude Code Features/03_Hooks/research.md`
- Read the specific research.md before configuring or explaining any feature
- The README at `./Claude Code Features/README.md` has categorized and chronological views
