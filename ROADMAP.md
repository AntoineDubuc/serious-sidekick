# Serious Sidekick — Feature Roadmap

> Last updated: 2026-04-09 | Current version: v1.6.0 | Claude Code: v2.1.98

## Status Legend

| Tag | Meaning |
|-----|---------|
| DONE | Shipped and verified |
| FREEBIE | Upstream fix/feature we get for free — no work needed |
| RESEARCHED | Research complete, not yet implemented |
| PLANNED | In a prior phase plan, ready to build |
| NEW | Discovered in changelog, needs investigation |
| BACKLOG | Lower priority, standalone improvement |
| DROPPED | Investigated and rejected (reason noted) |

---

## 1. Mechanical Enforcement Gap (PRIORITY)

**Principle:** "Mandatory" without a hook is just a suggestion.

These are things the system calls mandatory but doesn't mechanically enforce today.

| # | Gap | Current State | Proposed Fix | Status |
|---|-----|--------------|--------------|--------|
| 1.1 | Which review agents ran | `review_verdict.md` could say PASS without all agents running | Hook validates agent signatures in verdict file before accepting | DONE |
| 1.2 | Whether `/serious-code` dispatched all 5 agent types per task | Could skip QA or runtime-checker | Hook validates dispatch log against required agent list | DONE |
| 1.3 | Whether plan generator used `_extracted_items.md` | Stop hook only checks file exists, not that it was cross-referenced | Content-aware validation in hook script | DONE |
| 1.4 | Cold-read principle followed | No enforcement that reviewer reads adjacent files | PreToolUse/Read hook to log reads, verify coverage | PLANNED |
| 1.5 | Architect agent mandatory in review | Agent doesn't exist yet (see 2.1) | Must ship with hook enforcement from day one | PLANNED |

**v1.4.0 (2026-03-29):** Gaps 1-3, 5, 7-9 closed via Stop hook extensions (zero new hook types). All 9 hooks converted to fail-closed. See `Research/features/mechanical-enforcement-gap/` for full research, plan, and evidence.

**v1.6.0 (2026-04-05):** Breadcrumb 0-pre silence + staleness detection. Skills no longer narrate "No active breadcrumbs" during normal advancing workflows. Stale breadcrumbs from interrupted sessions auto-detected (by frontmatter status or file age > 4 hours). `debug(8)` added to all pipeline order definitions. See `Research/bugs/breadcrumb-not-found-on-advance/`.

### New from Changelog (v2.1.85) — RESEARCHED

- **Conditional `if` field for hooks** — RESEARCHED: Only works on 4 tool events (PreToolUse, PostToolUse, PreToolEdit, PostToolEdit), cannot scope Stop hooks. Useful for PreToolUse filtering only.
- **`agent_id` and `agent_type` available in hooks** (v2.1.69) — RESEARCHED: Conditional (subagent context only). Not available in main-session Stop hooks.
- **PreToolUse hooks can answer AskUserQuestion** (v2.1.85) — RESEARCHED: Validated, works as documented. Deferred to Phase 3.

---

## 2. Architect Review Agent

| # | Item | Details | Status |
|---|------|---------|--------|
| 2.1 | 4th mandatory agent in `/serious-review` | SOLID, DRY, framework conventions, multi-tenancy, cross-boundary leaks | PLANNED |
| 2.2 | Hook enforcement from day one | Verdict cannot pass without architect agent having run | PLANNED |
| 2.3 | Big picture first, then implementation details | Review order: architecture decisions > code patterns > line-level | PLANNED |

---

## 3. Claude Code Feature Adoption (RESEARCHED)

Research complete at `Research/features/claude-code-feature-adoption/research.md` (2026-03-26).

### Phase 1 — Quick Wins

| # | Feature | Details | Risk | Status |
|---|---------|---------|------|--------|
| 3.1 | `paths:` globs for skills | Scope skill loading to relevant file patterns. YAML list format. Test on ONE auto-loader first — `paths:` + `description` interaction is unknown and could break all 18 auto-loaders if destructive. | MEDIUM | RESEARCHED |
| 3.2 | `ENV_SCRUB` | Set `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` to strip credentials from subprocess environments. One line in `/serious-init`. | LOW | RESEARCHED |

**Dropped from Phase 1:**
- ~~`initialPrompt`~~ — Only works for main session agents, not subagents. All 8 of our agents are subagents. Zero effect. (DROPPED)
- ~~`TaskOutput` audit~~ — Tool was fully removed in v2.1.84. Zero operational references in our codebase. (DROPPED)

### Phase 2 — Hook-Based Enforcement

| # | Feature | Details | Risk | Status |
|---|---------|---------|------|--------|
| 3.3 | `FileChanged` hooks | Fires when files are modified. Pipe-separated basename matchers. **Notification-only** — cannot block writes, only warn during session. Use `jq -r` for JSON parsing (injection protection). | LOW | RESEARCHED |
| 3.4 | `PreToolUse/Agent` hook | Intercepts every Agent tool call before dispatch. Can validate agent parameters, enforce required agent types, block unauthorized spawns. Replaces the originally-planned `TaskCreated` hook approach. | MEDIUM | RESEARCHED |

### Phase 3 — Directory Awareness

| # | Feature | Details | Risk | Status |
|---|---------|---------|------|--------|
| 3.5 | `CwdChanged` hooks | Fires on every directory change. No matcher support. Receives `old_cwd` and `new_cwd`. Useful for worktree validation during multi-plan execution. | LOW | RESEARCHED |

### New from Changelog — Research Corrections

| # | Finding | Details | Impact |
|---|---------|---------|--------|
| 3.6 | `TaskCreated` hook now EXISTS | v2.1.84 added `TaskCreated` hook that fires when task created via `TaskCreate`. Our research (same day) said it didn't exist. **Re-evaluate:** may be useful alongside `PreToolUse/Agent` for different enforcement purposes. | NEEDS RE-EVALUATION |
| 3.7 | Conditional `if` on hooks | v2.1.85 added `if` field using permission rule syntax. Our FileChanged and PreToolUse hooks can now be scoped conditionally — e.g., only fire during `/serious-code` runs, not during casual editing. Reduces false positives significantly. | ENHANCES 3.3, 3.4 |
| 3.8 | `paths:` fix for files outside project root | v2.1.86 fixed Write/Edit/Read failing on files outside project root with conditional skills. If we hit errors during `paths:` testing, this fix may have resolved them. | REDUCES RISK for 3.1 |
| 3.9 | Unnecessary config disk writes fixed | v2.1.86 fixed config disk writes on every skill invocation. Reduces I/O overhead for our 29 skills. | FREEBIE |

---

## 4. Agent Control Levers

Features from v2.1.69–v2.1.98 that give us finer control over subagent behavior.

| # | Feature | Version | Details | Potential Use | Status |
|---|---------|---------|---------|---------------|--------|
| 4.1 | `effort` frontmatter for agents | v2.1.78 | Set effort level (low/medium/high) per agent in frontmatter | high (6 agents), medium (runtime-checker), low (test-runner) | DONE |
| 4.3 | `disallowedTools` frontmatter for agents | v2.1.78 | Block specific tools from being used by an agent | 7 of 8 agents blocked from Edit/Write/NotebookEdit. Implementer keeps full access. | DONE |
| 4.11 | Default effort now HIGH | v2.1.94 | Default effort changed from medium to high for API-key, Bedrock/Vertex, Team, Enterprise users | Our agents already set effort explicitly via frontmatter — verify no drift if user overrides via `/effort` | FREEBIE |
| 4.12 | Agent team permission inheritance fix | v2.1.98 | Agent team members now correctly inherit leader's `--dangerously-skip-permissions` | Critical for `/serious-code` — agents no longer silently downgraded to restrictive mode | FREEBIE |
| 4.13 | Background subagent partial progress on failure | v2.1.98 | Failed background subagents now report partial progress to parent instead of silent failure | Better error recovery in `/serious-code` orchestrator when an agent crashes mid-task | FREEBIE |
| 4.15 | `/agents` Running tab with instance count | v2.1.97 | Tabbed layout: Running tab shows live subagents, Library tab adds Run/View actions; `● N running` badge | Better UX for monitoring agent teams during `/serious-code` multi-plan execution | FREEBIE |
| 4.16 | 429 rate-limit surfacing fix | v2.1.94 | Agents no longer appear stuck after 429 with long Retry-After — error surfaces immediately | Long `/serious-code` runs hit rate limits; agents now fail fast instead of silent hang | FREEBIE |
| 4.4 | `model` parameter on Agent tool | v2.1.72 | Override model per agent spawn | Cheap model for extraction, capable model for review/QA | NEW |
| 4.5 | `StopFailure` hook | v2.1.78 | Fires on API errors during agent execution | Detect and handle agent failures gracefully | NEW |
| 4.6 | `SendMessage` auto-resumes stopped agents | v2.1.77 | No need to manually resume — just send a message | Simplifies retry logic in orchestrators | NEW |
| 4.7 | `PermissionDenied` hook | v2.1.90 | Fires after auto-mode denials, supports `{retry: true}` | Recover from denials in unattended `/serious-code` runs | NEW |
| 4.8 | `defer` permission decision for PreToolUse | v2.1.90 | Headless sessions can pause and resume on tool approval | Enables unattended `/serious-code` with human-in-the-loop on sensitive ops | NEW |
| 4.9 | Named subagents in `@` typeahead | v2.1.90 | Mention running agents by name in conversation | Better orchestration UX for agent teams | NEW |
| 4.14 | Monitor tool for background scripts | v2.1.98 | Stream events from background processes in real time | Replace sleep-poll loops in `/serious-code` with event-driven monitoring of worktree agents | NEW |
| 4.2 | `maxTurns` frontmatter for agents | v2.1.78 | Cap the number of turns an agent can take | Deferred — need turn count data from real workflows first | BACKLOG |

---

## 5. Worktree & Execution Improvements

**v1.5.0 (2026-03-31):** Worktree breadcrumb path fix shipped. All 15 hooks now resolve paths via `$CLAUDE_PROJECT_DIR`. 8 pre-existing bugs fixed. 10 test suites, 96 assertions, 0 failures. See `Research/bugs/worktree-breadcrumb-paths/`.

| # | Feature | Version | Details | Potential Use | Status |
|---|---------|---------|---------|---------------|--------|
| 5.0 | Worktree-safe hooks | v1.5.0 | All 15 hooks use `PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"` + path validation + 8 bug fixes | Unblocks multi-plan parallel execution in `/serious-code` | DONE |
| 5.8 | Subagent worktree cwd leak fix | v2.1.97 | Subagents with worktree isolation or `cwd:` override no longer leak their working directory back to parent session's Bash tool | Critical fix — parent session was inheriting worktree cwd, causing file operations in wrong directory | FREEBIE |
| 5.9 | Stale worktree cleanup safety | v2.1.98 | Stale subagent worktree cleanup no longer removes worktrees containing untracked files | Prevents data loss during `/serious-code` — generated but uncommitted code in worktrees is now preserved | FREEBIE |
| 5.10 | `--resume` from other worktrees | v2.1.94 | `--resume` now resumes sessions from other worktrees of the same repo directly (no more `cd` command) | Smoother UX when resuming `/serious-code` sessions that ran in worktrees | FREEBIE |
| 5.12 | Compaction transcript dedup fix | v2.1.97 | Compaction no longer writes duplicate multi-MB subagent transcript files on prompt-too-long retries | Prevents session bloat during long `/serious-code` runs with many agent spawns | FREEBIE |
| 5.1 | `ExitWorktree` tool | v2.1.72 | Programmatically exit a worktree | Cleaner worktree lifecycle in `/serious-code` | NEW |
| 5.2 | `WorktreeCreate` / `WorktreeRemove` hooks | v2.1.50 | Fire when worktrees are created or removed | Validate worktree setup, cleanup tracking | NEW |
| 5.3 | `WorktreeCreate` supports `type: "http"` | v2.1.84 | HTTP-based hooks for worktree creation | Remote validation or logging | NEW |
| 5.4 | `worktree.sparsePaths` setting | v2.1.76 | Sparse checkout for large monorepos | Performance for template users with large repos | NEW |
| 5.5 | `worktree` field in statusline commands | v2.1.69 | Statusline scripts know which worktree is active | Better status display during multi-plan execution | NEW |
| 5.6 | `PostCompact` hook | v2.1.76 | Fires after context compaction | Re-inject critical instructions after compaction | NEW |
| 5.7 | Prompt cache expiry hint | v2.1.92 | Pro users see uncached token count when returning to stale sessions | Know when to start fresh vs resume | NEW |
| 5.11 | `workspace.git_worktree` in status line | v2.1.97 | Status line JSON input now includes `workspace.git_worktree` when inside a linked git worktree | Enables worktree-aware status line during multi-plan execution (show which plan/branch is active) | NEW |

---

## 6. Observability & Context

| # | Feature | Version | Details | Potential Use | Status |
|---|---------|---------|---------|---------------|--------|
| 6.3 | Read tool deduplicates re-reads | v2.1.86 | Compact format, skips unchanged content on re-read | Token savings across all skills | FREEBIE |
| 6.4 | Prompt cache improvements | v2.1.86 | Better hit rate for Bedrock/Vertex/Foundry | Cost savings for enterprise template users | FREEBIE |
| 6.19 | Plugin skills use frontmatter `name` | v2.1.94 | Skills declared via `"skills": ["./"]` use frontmatter `name` for invocation, not directory basename | Stable skill names across install methods — relevant if we distribute as a plugin | FREEBIE |
| 6.20 | `Bash(cmd:*)` wildcard spacing fix | v2.1.98 | Wildcard permission rules now match commands with extra spaces or tabs | Our `Bash(git commit *)` and similar rules now work reliably | FREEBIE |
| 6.21 | Hook stderr in transcript | v2.1.98 | Hook errors in transcript now include first line of stderr for self-diagnosis | Debug hook failures without `--debug` flag — useful for our 15+ hooks | FREEBIE |
| 6.1 | `InstructionsLoaded` hook | v2.1.69 | Fires when CLAUDE.md / skill instructions load | Verify correct instructions loaded for active workflow | NEW |
| 6.2 | `${CLAUDE_SKILL_DIR}` variable | v2.1.69 | Resolves to the directory containing the current skill | Skill-relative paths in hook scripts | NEW |
| 6.5 | `autoMemoryDirectory` setting | v2.1.74 | Custom directory for auto-memory | Organize memory per-project or per-workflow | NEW |
| 6.6 | Skills sort alphabetically + 250-char cap | v2.1.86 | `/skills` listing now sorted, descriptions capped | Review our 29 skill descriptions for truncation | NEW |
| 6.7 | `effort` frontmatter for skills | v2.1.80 | Set effort level per skill | Match effort to skill complexity | NEW |
| 6.8 | MCP tool result persistence up to 500K chars | v2.1.91 | Large results pass through without truncation via `_meta["anthropic/maxResultSizeChars"]` | Large DB schemas, big grep results no longer cut off | NEW |
| 6.9 | Per-model cost breakdown in `/cost` | v2.1.92 | See token spend by model for subscription users | Optimize which agents use which models | NEW |
| 6.10 | `disableSkillShellExecution` setting | v2.1.91 | Lock down inline shell execution in skills/plugins | Security hardening for enterprise users | NEW |
| 6.11 | Plugin executables in `bin/` | v2.1.91 | Plugins can ship executables and invoke them as bare Bash commands | Package verification scripts, custom tools | NEW |
| 6.12 | `/powerup` interactive lessons | v2.1.90 | Animated demos teaching Claude Code features | Onboarding for new template users | NEW |
| 6.13 | `refreshInterval` status line setting | v2.1.97 | Re-run status line command every N seconds | Show live `/serious-code` progress (phase, task count, pass/fail) with auto-refresh in footer | NEW |
| 6.14 | `hookSpecificOutput.sessionTitle` | v2.1.94 | `UserPromptSubmit` hooks can set session title via `hookSpecificOutput` | Auto-name sessions after active workflow slug (e.g., "serious-code: auth-token-expiry") | NEW |
| 6.15 | Focus view toggle (`Ctrl+O`) | v2.1.97 | In `NO_FLICKER` mode: shows prompt, one-line tool summary with edit diffstats, and final response | Cleaner view during long `/serious-code` runs — cuts noise from intermediate tool calls | NEW |
| 6.16 | OTEL `TRACEPARENT` in Bash subprocesses | v2.1.98 | W3C `TRACEPARENT` env var propagated to Bash tool subprocesses when OTEL tracing is enabled | End-to-end trace trees across `/serious-code` orchestrator → agent → subprocess | NEW |
| 6.17 | `--exclude-dynamic-system-prompt-sections` | v2.1.98 | Print mode flag for improved cross-user prompt caching | Headless `/serious-code` runs can cache prompts across users (enterprise/CI use case) | NEW |
| 6.18 | `keep-coding-instructions` frontmatter | v2.1.94 | Plugin output style field that preserves coding instructions through style changes | Ensure workflow instructions survive output style switches during long sessions | NEW |

---

## 7. Superpowers Backlog (B+ Tier)

From competitive analysis of [obra/superpowers](https://github.com/obra/superpowers) (2026-03-22). A-tier items shipped in v1.2.0.

| # | Feature | Details | Effort | Status |
|---|---------|---------|--------|--------|
| 7.1 | Auto-detection skill invocation | Skills fire contextually without slash commands (session-start hook injection) | HIGH | BACKLOG |
| 7.2 | Implementer status protocol | Formal status codes: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED | LOW | BACKLOG |
| 7.3 | Verification-before-completion everywhere | Currently only in `/serious-code`. Should be in ALL skills. | MEDIUM | BACKLOG |
| 7.4 | SUBAGENT-STOP gate | Prevents recursive skill loading in sub-agents | LOW | BACKLOG |
| 7.5 | Model selection guidance | Different models for different sub-agent tasks | MEDIUM | BACKLOG |
| 7.6 | Persuasion research backing | Cialdini principles in skill preambles | LOW | BACKLOG |
| 7.7 | DOT flowcharts as executable specs | Models follow diagrams more reliably than prose | MEDIUM | BACKLOG |
| 7.8 | Pressure testing skills on subagents | Simulate sunk-cost/time/authority pressures | MEDIUM | BACKLOG |

---

## 8. Process Improvements (From v1.4.0 Lessons)

Four pipeline blind spots identified during hook hardening implementation (2026-03-29).

| # | Gap | What Happened | Fix | Status |
|---|-----|---------------|-----|--------|
| 8.1 | Review agents check plans, not code | grep patterns with logic bugs passed plan review | Post-code alignment check in /serious-code | BACKLOG |
| 8.2 | Test fixtures too clean | Real directories have extra files that interact unexpectedly | Messy fixture test requirement in v6 template | BACKLOG |
| 8.3 | Parallel subagents don't cross-reference siblings | Task 5 missed the source: gating pattern used by sibling tasks | Exhaustively specific ACs for multi-agent execution | BACKLOG |
| 8.4 | Ad-hoc fixes during e2e skip review | Inline fix swung from "check PASS" to "check not FAIL" — missed empty file case | Require ad-hoc fixes to have their own ACs and tests | BACKLOG |

---

## Cross-References

| Section | Synergies |
|---------|-----------|
| 1.1–1.2 (enforcement gap) | Enabled by 3.4 (PreToolUse/Agent), 3.7 (conditional `if`), 4.6 (`agent_id` in hooks) |
| 1.5 (architect enforcement) | Depends on 2.1 (architect agent exists first) |
| 3.1 (paths: globs) | De-risked by 3.8 (v2.1.86 fix), 3.9 (config write fix) |
| 3.4 (PreToolUse/Agent) | Powers 1.1, 1.2; enhanced by 3.7 (conditional scope) |
| 4.1–4.3 (agent frontmatter) | Directly applicable to all 8 agents in `.claude/agents/` |
| 4.4 (model override) | Enables 7.5 (model selection guidance); pairs with 6.9 (cost breakdown) for data-driven model choices |
| 4.7-4.8 (PermissionDenied + defer) | Together enable unattended `/serious-code` with pause/resume on sensitive ops |
| 4.14 (Monitor tool) | Replaces sleep-poll in `/serious-code`; pairs with 6.13 (refreshInterval) for live progress |
| 5.6 (PostCompact) | Enables 7.3 (verification-before-completion — re-inject checklist after compaction) |
| 5.8-5.9 (worktree fixes) | Unblock reliable multi-plan execution; 5.8 (cwd leak) was a silent corruption vector |
| 5.11 + 6.13 (worktree status + refresh) | Together enable a live status line showing active worktree branch + progress with auto-refresh |
| 6.11 (plugin executables) | Could package hook scripts, verification tools as distributable plugins |
| 6.14 (session title hook) | Pairs with all `/serious-*` skills — each skill can auto-title the session on startup |
| 6.15 (focus view) | Requires `NO_FLICKER` mode (v2.1.89); best paired with 6.13 (refreshInterval) for minimal-noise monitoring |
| 7.2 (status protocol) | Low effort, pairs well with 1.2 (dispatch validation) |
| 7.4 (SUBAGENT-STOP) | Low effort, pairs well with 3.4 (PreToolUse/Agent can detect recursion) |
| 8.1-8.4 (process improvements) | Improvements to the pipeline itself, not to hooks or agents |
