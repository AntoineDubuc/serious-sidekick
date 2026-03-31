<div align="center">

# Serious Sidekick

**Your AI says "done." It isn't.**

Shell-level gates for Claude Code — deterministic checks the AI can't reason around, skip, or hallucinate through. You stop re-doing AI work. You ship with evidence, not hope.

[![Version](https://img.shields.io/badge/version-1.5.0-blue?style=flat-square)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Claude Code](https://img.shields.io/badge/requires-Claude_Code-purple?style=flat-square)](https://docs.anthropic.com/en/docs/claude-code/overview)

[Landing Page](https://antoinedubuc.github.io/serious-sidekick/) · [Changelog](CHANGELOG.md) · [Report an Issue](https://github.com/AntoineDubuc/serious-sidekick/issues)

</div>

---

## Quick Start

```bash
git clone https://github.com/AntoineDubuc/serious-sidekick.git
```

Open Claude Code in your project and run:

```
/serious-init
```

That's it. You get 11 slash commands, 6 enforcement hooks, 8 specialized agents, and templates for plans, research, and scope manifests. Nothing outside the repo is modified.

**Prerequisites:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview) and a Claude account (Pro, Max, Team, or Enterprise).

---

## The Problem

You tell an AI to build something. It says "done." You check — half the requirements are missing, three are marked "future enhancement," and one is contradicted by the implementation.

**Every toolkit that tells the AI to check itself has this problem.** Prompt-based verification lives inside the AI's reasoning loop. It can be rationalized, skipped, or hallucinated.

Serious Sidekick fixes this. Not with better prompts — with shell-level enforcement.

---

## How It's Different

Most Claude Code toolkits verify with prompts. **We verify with bash.**

That's not a style choice — it's a structural one. Prompts live inside the AI's reasoning loop. Bash lives outside it. One can be rationalized. The other can't.

### Deterministic enforcement

Shell hooks run outside the AI's process. The AI cannot disable, skip, or override them.

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write",
      "hooks": [{
        "type": "command",
        "if": "Write(*gate_passed*)",
        "command": "verify-completion-gate.sh"
      }]
    }]
  }
}
```

The AI says it's done. A 50-line bash script checks if `gate_passed.md` exists. It doesn't. Session stays open. The AI can't argue — it fixes the work.

### Conditional precision

Hooks declare exactly which tool calls they care about. `Write(*verdict*)` fires the review gate. `Write(*.ts)` fires the TDD gate. `Write(*implementation_plan*)` fires the hedge language check. No wasted process spawning. No false positives.

### Fail-closed

If a hook hits an unexpected error, it blocks instead of silently passing. No silent failures. No false confidence.

---

## The Pipeline

Seven steps. Each produces artifacts that feed the next. A verifier checks every handoff — nothing gets dropped between stages.

| Step | Command | What it does |
|:-----|:--------|:-------------|
| 1 | `/serious-conversation` | Structured ideation with a panel of AI personas (10 built-in, custom supported) |
| 2 | `/serious-research` | Investigation with evidence grading — quick mode or deep parallel analysis |
| 3 | `/serious-mock-ups` | UI wireframes and visuals before planning (3 fidelity levels) |
| 4 | `/serious-scope` | Splits research into discrete, independently-plannable units |
| 5 | `/serious-plan` | Implementation plan with TDD protocol, acceptance criteria, and anti-rationalization rules |
| 6 | `/serious-review` | Adversarial plan review — 3 mandatory agents read the plan cold |
| 7 | `/serious-code` | Execution with 5 verification agents, TDD enforcement, and completion gates |

**Research feeds plans.** Findings become constraints. Nothing is invented mid-implementation.

**Plans feed code.** TDD sequences are defined before a single line is written. Anti-rationalization tables tell the AI what it's NOT allowed to skip.

**Hooks verify every handoff.** A shell script checks that the plan references the research. That the code matches the plan. That the tests ran before the implementation. That the gate file exists before the session closes.

---

## What You Get

### 11 Workflow Commands

| Command | Purpose |
|:--------|:--------|
| `/serious-conversation` | Persona panel for ideation and exploration |
| `/serious-research` | Structured investigation with evidence |
| `/serious-mock-ups` | UI wireframes and visuals before planning |
| `/serious-scope` | Scope manifest — splits research into plan boundaries |
| `/serious-plan` | Implementation plan with TDD protocol |
| `/serious-review` | Plan quality gate — 3 mandatory agents, 10 anti-slop checks |
| `/serious-code` | Plan execution with 5 verification agents |
| `/serious-debug` | Systematic debugging — 3 modes, reproducer-driven feedback |
| `/serious-init` | Scaffold a new project with the toolkit |
| `/serious-status` | View active and completed workflows |
| `/serious-abandon` | Abandon a sub-workflow and restore parent context |

### 6 Enforcement Hooks

| Hook | Skill | What it blocks |
|:-----|:------|:---------------|
| Completion Gate | `/serious-code` | Missing `gate_passed.md`, missing agent evidence files, FAIL verdicts |
| Extraction Check | `/serious-plan` | Missing upstream extraction, zero source citations, hedge language |
| Manifest Check | `/serious-scope` | Missing manifest, missing verification stamps |
| Verdict Check | `/serious-review` | Missing verdict, review theater (PASS with no specifics), missing agent reports |
| Conversation Capture | `/serious-conversation` | Status "done" without summary |
| Research Capture | `/serious-research` | Active research abandoned without completion |

All hooks use a **fail-closed pattern** — unexpected errors block instead of silently passing. All are **worktree-safe** — they resolve paths via `$CLAUDE_PROJECT_DIR` and validate against path traversal.

### 3 PreToolUse Gates

| Gate | Trigger | What it catches |
|:-----|:--------|:----------------|
| TDD Gate | `Write(*.ts)` | Implementation files written before their tests exist |
| Hedge Language Gate | `Write(*implementation_plan*)` | Vague language in plans ("consider whether", "as appropriate") |
| Review Theater Gate | `Write(*verdict*)` | Generic approval without specific file:line references |

### 8 Specialized Agents

**Code agents** (5): Implementer, Code Reviewer, Test Runner, Runtime Checker, QA — each with anti-rationalization tables and anti-sycophancy rules. Non-implementer agents are mechanically blocked from `Edit`/`Write` via `disallowedTools`.

**Review agents** (3): Anti-Slop Auditor (10 checks), Structural Reviewer, Security Mind — all read the plan cold with no research context.

### 18 Auto-Loading Knowledge Skills

Context-aware documentation for hooks, MCP, subagents, worktrees, permissions, plugins, and 12 more Claude Code features. Loads only when the topic comes up — zero context cost when you don't need it.

---

## How Verification Works

The handoff verifier runs automatically at every pipeline stage. Each upstream item gets classified:

| Disposition | Meaning |
|:------------|:--------|
| **Covered** | Substantive treatment — own section, acceptance criteria, design decisions |
| **Deferred** | Explicitly marked with reason — passes with warning |
| **Shirked** | Mentioned but waved away — "future enhancement," hollow sections |
| **Missing** | Not mentioned at all |
| **Contradicted** | Downstream says the opposite of upstream |

Shirked, Missing, and Contradicted items **block the pipeline**. The AI must fix them before moving on.

---

## Init Variants

```
/serious-init                   # Everything — skills, agents, docs, CLAUDE.md
/serious-init --skills-only     # Just skills and agents, no docs
/serious-init --docs-only       # Just docs + CLAUDE.md
/serious-init --no-claude-md    # Skip CLAUDE.md if you already have one
```

---

<div align="center">

*Built by a TPM who got tired of cleaning up after AI.*

*Most Claude Code toolkits verify with prompts. This one verifies with bash.*

[Get Started](#quick-start) · [Changelog](CHANGELOG.md) · [Report an Issue](https://github.com/AntoineDubuc/serious-sidekick/issues)

</div>
