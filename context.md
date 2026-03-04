# Serious Sidekick — Session Context

**Last updated:** 2026-03-04
**Purpose:** Full project context for session continuity. Read this file first when starting a new session.

---

## What This Project Is

**Serious Sidekick** is a Claude Code project template — a knowledge base, workflow toolkit, and feature reference you drop into any project. It gives Claude accurate documentation about its own features (preventing hallucination), structured workflow skills for the full development lifecycle, and always-available feature awareness.

**GitHub:** `AntoineDubuc/serious-sidekick` (public, template repo)
**GitHub profile:** AntoineDubuc

---

## Project Structure

```
.
├── CLAUDE.md                              # Loaded every session — mandatory rules + feature index
├── _implementation_plan_template_v6.md    # V6 plan template (used by /serious-plan)
├── README.md                              # Project documentation (markdown)
├── README.html                            # Project documentation (HTML with light/dark mode, diagrams)
├── context.md                             # THIS FILE — session continuity context
├── .claude/
│   ├── skills/                            # 22 auto-loading skills
│   │   ├── serious-init/SKILL.md          # /serious-init — scaffold a new project
│   │   ├── serious-conversation/SKILL.md  # /serious-conversation — persona panel ideation
│   │   │   └── personas/                  # 10 built-in persona prompt files
│   │   │       ├── architect.md
│   │   │       ├── skeptic.md
│   │   │       ├── pragmatist.md
│   │   │       ├── product-thinker.md
│   │   │       ├── debugger.md
│   │   │       ├── security-mind.md
│   │   │       ├── dx-advocate.md
│   │   │       ├── mentor.md
│   │   │       ├── optimizer.md
│   │   │       └── historian.md
│   │   ├── serious-research/SKILL.md      # /serious-research — structured research (quick/deep)
│   │   ├── serious-plan/SKILL.md          # /serious-plan — implementation plan generation
│   │   ├── serious-code/SKILL.md          # /serious-code — plan execution with Agent Teams
│   │   └── [17 feature auto-loader skills: hooks, subagents, mcp-integration, permissions,
│   │        plan-mode, worktrees, headless-mode, plugins, agent-teams, chrome-integration,
│   │        fast-mode, checkpointing, remote-control, keybindings, output-styles,
│   │        status-line, skills-and-commands]
│   └── agents/                            # 5 Agent Teams agents (used by /serious-code)
│       ├── serious-code-implementer.md    # TDD implementation (RED→GREEN→VERIFY)
│       ├── serious-code-reviewer.md       # Code review, security, plan adherence
│       ├── serious-code-test-runner.md    # Static analysis + full test suite
│       ├── serious-code-runtime-checker.md # Runtime behavior verification
│       └── serious-code-qa.md             # Adversarial QA spot-check (3 random criteria)
└── Claude Code Features/                  # 38 research folders + master README
    ├── README.md
    ├── 01_Core_CLI/ through 38_Enterprise_and_Managed_Settings/
    └── (each contains research.md with official docs, citations, URLs)
```

---

## The Workflow Pipeline

```
/serious-conversation → /serious-research → /serious-plan → /serious-code → done
```

### /serious-conversation
- Hub-and-spoke model: user picks personas, orchestrator distributes topic to persona sub-agents in parallel, synthesizes results, user discusses with orchestrator, repeat
- 10 built-in personas (Architect, Skeptic, Pragmatist, Product Thinker, Debugger, Security Mind, DX Advocate, Mentor, Optimizer, Historian)
- Custom personas supported (create from description or clone existing)
- Persona library at `Research/conversations/_personas/`
- Topic pivot supported mid-conversation (logs shift marker, re-proposes personas)
- Stop hook tracks conversation.md via `.active-conversation` breadcrumb
- Creates versioned artifacts: `response_vN.md` per persona, `result_vN.md` synthesis per round

### /serious-research
- Two modes: Quick (single-threaded, persona reviews) and Deep (parallel threads, evidence grading A-F, adversarial verification, HTML report)
- Auto-detected or forced with `--quick`/`--deep`
- Stop hook tracks notebook.md via `.active-research` breadcrumb
- Output: `Research/{bugs|features|exploratory}/{slug}/`

### /serious-plan
- Generates v6 implementation plans from research, PRDs, or verbal descriptions
- **Single plan** (3-7 tasks) or **multiple plans** with `phase_map.md` for parallel execution
- Adaptive Persona Pipeline with severity-weighted convergence:
  - Severity: Critical / Major / Minor
  - Any critical → re-review, 3+ majors → re-review, minors only → done, max 3 rounds
- Cross-plan integration review: Integration Architect + Merge Strategist personas (+ optional Concurrency Engineer)
  - Same convergence rules, max 3 integration rounds
  - If integration fixes change a plan → one more individual review round
- TDD Protocol and Inline QA Protocol v6 copied verbatim into every plan

### /serious-code
- Executes plans from /serious-plan
- 3-level architecture: Orchestrator → Plan Agents (one per plan per phase) → Agent Teams (5 agents per task)
- Parallel execution via git worktrees (one per plan in parallel phases)
- Phase-by-phase user approval
- Task Execution Cycle: Implementer (TDD) → 4 parallel verifiers (reviewer, test-runner, runtime-checker, qa)
- Stop hook tracks execution_log.md via `.active-code` breadcrumb
- Two-level tracking: `execution_log.md` (orchestrator) + per-plan `progress.md`
- Failure handling: failed plan stops, other parallel plans continue, user decides (fix/skip/rollback/abort)
- Resume mode: reads execution_log.md + progress.md to find stopping point
- Completion report generated at end

---

## Knowledge Architecture (3 Layers)

| Layer | What | When Loaded |
|-------|------|-------------|
| CLAUDE.md | Feature index + mandatory rules | Every session, survives compaction |
| Skills (22) | Cheat sheets with correct syntax/patterns | On-demand when topic comes up |
| Research docs (38 folders) | Deep-dive with official docs + citations | When explicitly read |

**Why auto-loader skills exist:** Claude knows about its features from training data but frequently gets specifics wrong — incorrect syntax, outdated flags, missing options. The 17 feature skills inject correct information automatically when the topic comes up, preventing hallucination.

---

## User Preferences (CRITICAL — follow these)

### Question Format
- Ask **ONE question at a time** — never dump multiple questions in one message
- Format: recommended option first with explanation, then 3-5 alternatives with trade-offs, then why the alternatives weren't picked
- Wait for the answer before asking the next question
- This is codified in CLAUDE.md rule 9

### Communication Style
- User prefers discussion before implementation — don't jump to writing code
- User gets frustrated when instructions aren't followed exactly (naming, ordering)
- User will say when to write — don't start early
- "Serious" branding for all workflow skills
- All agents under serious-code use prefix `serious-code-{role}` for brand consistency

### CLAUDE.md Rules (mandatory)
1. DO NOT enter plan mode (EnterPlanMode is FORBIDDEN)
2. DO NOT export/print/log credentials — use .env only
3. BE BRIEF — start every response with a short summary
4. INVESTIGATE BEFORE CODING — root cause, why, proposed fixes
5. DO NOT touch files without explicit user consent
6. DO NOT commit/push/PR without explicit user consent
7. PROVE IT WORKS — evidence required
8. ANSWER FIRST before doing anything else
9. ONE QUESTION AT A TIME (see format above)

---

## What's Been Done

Everything below is COMPLETE and written to disk:

- [x] 38 Claude Code feature research folders with research.md files
- [x] 17 feature auto-loader skills
- [x] /serious-init skill (scaffold new projects)
- [x] /serious-conversation skill + 10 persona prompt files + topic pivot support
- [x] /serious-research skill + Stop hook for notebook.md tracking
- [x] /serious-plan skill (single + multi-plan, phase map, convergence reviews, integration reviews)
- [x] /serious-code skill (orchestrator)
- [x] 5 Agent Teams agents (implementer, reviewer, test-runner, runtime-checker, qa)
- [x] V6 implementation plan template
- [x] CLAUDE.md with rules + feature index
- [x] README.md with full documentation
- [x] README.html with light/dark mode, workflow diagrams, persona grid, stats
- [x] GitHub repo created (AntoineDubuc/serious-sidekick, public, template)
- [x] All skills installed to both user-level (~/.claude/skills/) and project-level (.claude/skills/)

---

## What Has NOT Been Done

### Testing (NOTHING has been tested)
- [ ] /serious-conversation — never run end-to-end
- [ ] /serious-research — Stop hook not tested
- [ ] /serious-plan — multi-plan generation not tested, convergence reviews not tested
- [ ] /serious-code — never run end-to-end, Agent Teams agents never tested
- [ ] /serious-init — not tested in a target project

### GitHub Repo Is Stale
- The repo has only the INITIAL commit from early in the session
- It does NOT include: serious-conversation, serious-code, Agent Teams agents, topic pivot, convergence reviews, or any of the recent changes
- DO NOT push without user consent and testing first

### Potential Future Work (discussed but not started)
- End-to-end testing of the full pipeline on a real project
- Refinement based on testing feedback
- Additional personas if users request them

---

## Key Design Decisions (for reference)

1. **Hub-and-spoke, not round-table:** Personas respond independently to the orchestrator, not to each other directly. The orchestrator synthesizes.
2. **Fresh sub-agents per round:** Sub-agents are stateless. Files are the memory. Each round spawns fresh agents that read from disk.
3. **Severity-weighted convergence:** Persona reviews run in rounds. Critical issues force re-review. Max 3 rounds (safety cap).
4. **Git worktrees for parallelism:** Each plan in a parallel phase gets its own worktree. Merges happen sequentially after phase completion.
5. **3-level agent architecture for /serious-code:** Orchestrator → Plan Agents → Agent Teams. Clean separation of concerns.
6. **Breadcrumb files for hooks:** `.active-conversation`, `.active-research`, `.active-code` tell Stop hooks where to write tracking data.
7. **Topic pivot over restart:** Conversations can shift topics mid-session rather than forcing a new /serious-conversation.

---

## File Locations Quick Reference

| What | Path |
|------|------|
| Project root | `/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/` |
| CLAUDE.md | `./CLAUDE.md` |
| V6 template | `./_implementation_plan_template_v6.md` |
| Conversation skill | `./.claude/skills/serious-conversation/SKILL.md` |
| Persona prompts | `./.claude/skills/serious-conversation/personas/*.md` |
| Research skill | `./.claude/skills/serious-research/SKILL.md` |
| Plan skill | `./.claude/skills/serious-plan/SKILL.md` |
| Code skill | `./.claude/skills/serious-code/SKILL.md` |
| Agent Teams | `./.claude/agents/serious-code-*.md` |
| Feature docs | `./Claude Code Features/*/research.md` |
| Memory | `~/.claude/projects/-Users-cg-adubuc-Desktop-Antoine--claude-code-template-/memory/MEMORY.md` |
