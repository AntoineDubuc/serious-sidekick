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

This project includes seven workflow skills for structured development:

- **`/serious-conversation`** — Think out loud with a panel of personas (hub-and-spoke model). Pick from 10 built-in personas or create custom ones. Each round: personas respond independently via sub-agents, Orchestrator synthesizes, user refines. Creates versioned artifacts in `Research/conversations/`.
- **`/serious-research`** — Structured research with two modes (quick or deep). Creates a `Research/` folder with findings, evidence grading, and persona reviews. Use for bugs, features, or exploratory questions.
- **`/serious-mock-ups`** — Generate UI mock-ups from research before planning. Three fidelity levels (wireframe, visual, interactive flow), iterative feedback with versioning, component inventory, and design decision log. Outputs feed directly into `/serious-scope`.
- **`/serious-scope`** — Generates a scope manifest from research findings. Defines plan boundaries, dependencies, shared contracts, and tags. Splits complex implementations into discrete, independently-plannable units. Outputs a manifest consumed by `/serious-plan`.
- **`/serious-plan`** — Generates a single implementation plan from a scope manifest entry. Uses the v6 template at `./_implementation_plan_template_v6.md`. Includes TDD protocol, inline QA, and split-agent verification. Auto-detects mock-ups for component inventory and design decisions.
- **`/serious-review`** — Plan quality gate with adaptive persona pipeline. Reviews implementation plans before code execution. Uses anti-slop auditor and structural reviewer agents. Mandatory step between planning and coding.
- **`/serious-code`** — Executes implementation plans from `/serious-plan`. Orchestrates parallel plan execution via git worktrees, manages TDD cycles through 5 Agent Teams agents (implementer, reviewer, test-runner, runtime-checker, qa), handles phase-by-phase verification, and generates evidence reports.

**Typical workflow:** `/serious-conversation` → `/serious-research` → `/serious-mock-ups` → `/serious-scope` → `/serious-plan` → `/serious-review` → `/serious-code` → done

## Workflow Frontmatter Standard

All skill primary output files use YAML frontmatter for workflow tracking:

```yaml
---
skill: serious-research
slug: auth-token-expiry
status: active
parent: Research/features/auth
created: 2026-03-08
---
```

**Required fields:**

| Field | Type | Description |
|-------|------|-------------|
| `skill` | string | Which `/serious-*` skill created this file |
| `slug` | string | Kebab-case workflow identifier |
| `status` | enum | `active`, `done`, `abandoned` |
| `parent` | string | Relative path from project root to parent workflow folder. Absent for top-level workflows. |
| `created` | date | ISO date when the workflow started |

**Optional fields (set by skills and verifier):**

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | Path to the upstream artifact consumed (e.g., `Research/features/auth/research.md`). Empty if no upstream. |
| `verified` | date | ISO date when the handoff verifier last passed on this artifact. Set automatically by the verifier. |
| `verified_source` | string | Path to the upstream artifact that was verified against. Set automatically by the verifier. |
| `verified_hash` | string | First 8 characters of the SHA-256 hash of the upstream artifact's contract sections. Used for staleness detection. |

**Pipeline order:** `conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7) → debug(8)`

**Advancing vs branching:**
- New skill order **>** active skill order = **advancing** (no prompt, normal behavior)
- New skill order **≤** active skill order = **branching** (prompt for sub-workflow linking)

**Breadcrumb files:** Each skill writes `.active-{skill-name}` to the project root at startup (content = relative path to output folder). Removed at completion. Used by `/serious-status` and parent auto-detection.

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
**Tools:** Built-in Tools (19), Git Worktrees (13), Checkpointing/Rewind (30), Context Management (12), Headless Mode (11), Scheduled Tasks (39)
**Infrastructure:** Cloud Providers (14), Multi-Model Support (20), Cost Management (17)

### How to Use

- Each number maps to a folder: e.g., `03` = `./Claude Code Features/03_Hooks/research.md`
- Read the specific research.md before configuring or explaining any feature
- The README at `./Claude Code Features/README.md` has categorized and chronological views
