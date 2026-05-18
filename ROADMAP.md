# Serious Sidekick — Product Roadmap

> **Last updated:** 2026-05-16 · **Current version:** v1.8.0 · **Claude Code:** v2.1.143 (latest) / new substantive releases since last update: v2.1.111 (`/ultrareview`, `/less-permission-prompts`, xhigh effort), v2.1.117 (fork-subagent externally enabled, 1M-context Opus 4.7 fix, default effort raised), v2.1.118 (hooks invoke MCP tools, fork-subagent GA), v2.1.121 (PostToolUse `updatedToolOutput` for all tools — but broken at runtime, see Issue #54196), v2.1.126 (gateway model discovery, `claude project purge`), v2.1.139 (`claude agents` view, `/goal` command, hook `args:` exec form, hook `continueOnBlock`). See §A of `CLAUDE_CODE_CHANGELOG.md` for the condensed digest.

---

## What's Next

The April roadmap had eight engineer-ranked features. Since then, Claude Code shipped two big features that move the rest of the list around (`claude agents` and `/goal`), and we shipped the full PM-voice retrofit (all six phases). Below is the rewritten "next" list, sorted by **what the user feels** — not what's easiest to build.

### Now (the next two months of work — sorted by what the user feels)

| # | What we ship | What it does for the user | What it costs us |
|--:|--------------|---------------------------|------------------|
| 1 | **One-click install** | Anyone with Claude Code can add Serious Sidekick by typing one command instead of cloning a repo and running a shell script. Updates become one command too. Today the install flow filters out most non-engineers — this opens the door. | Medium-large. Repackage the file layout into the Claude-Code-native plugin format, set up a tiny marketplace, write a migration path for existing users. |
| 2 | **One screen for all your workflows** | Claude Code now ships a "one screen for every session" view (`claude agents`). Right now our `/serious-status` lives separately and tells you about your active workflows in a different place. Either we sit on top of the new screen and feed it our workflow info, or our status command starts looking outdated next to it. | Medium. Either pipe `/serious-status` data into the new view, or deprecate `/serious-status` and rely on the built-in. Open question on which is cleaner. |
| 3 | **Walk-away mode for `/serious-code`** | Tell `/serious-code` "fix this bug and don't come back until tests pass." Walk away. Come back to a working fix instead of fifty approval prompts. Today, even for low-risk work, you sit through "Go?" between every phase. This adds an unattended option for runs where you trust the plan. | Medium. Wire `/serious-code` into Claude Code's new "keep working until condition met" command, with a clean fail-safe that drops back to manual gating if anything goes red. |

### Soon (the next quarter — depends on Anthropic shipping)

| # | What we ship | What it does for the user | What we're waiting on |
|--:|--------------|---------------------------|----------------------|
| 4 | **Quick-skills (two-step recipes)** | Light-weight skills for the operational work between builds: ingest a video and discuss it, audit your workflows for stuck breadcrumbs, lint your skills for inconsistencies. Three steps, no TDD, no plan. Fast tools for the housekeeping the heavy pipeline doesn't fit. | Nothing — Anthropic shipped the underlying capability already. Effort dropped from a week to two days. Bumped down only because items 1-3 hit more pain. |
| 5 | **Skills that only load when relevant** | Today some skills load on every session even when they're irrelevant. Anthropic is expected to add a way to scope skills to file patterns ("only load this when I'm editing TypeScript"). Smaller context, faster sessions, no behavior change for the user. | Anthropic to ship file-pattern skill scoping. No new info in the last month — still waiting. |
| 6 | **Catch stale plans automatically** | If you write research on Monday, plan on Tuesday, and someone edits the research file Wednesday before you start coding, today nothing warns you. This adds a one-line warning when the source has shifted under a downstream plan. | Anthropic to ship file-change hooks. Still waiting. |
| 7 | **Safe unattended mode for risky operations** | Today, headless runs are all-or-nothing — either nothing prompts and dangerous ops fly through, or every prompt blocks the run. This adds a middle path: dangerous operations pause and wait for a human, harmless denials auto-retry. | Anthropic to ship two new hook types (pause-on-dangerous + retry-on-deny). Still waiting. |

### Watching (track-only, not actively building)

| # | Item | What changes when this resolves |
|--:|------|--------------------------------|
| 8 | **Anthropic Issue #54196** | When Anthropic fixes the broken hook that should rewrite tool output, the voice retrofit gets ~10x simpler — sub-agent output gets translated at the seam instead of per-call-site in every playbook. |
| 9 | **Interactive diagrams** | Third-party canvas tool (Excalidraw) for live editable diagrams during research and planning. Nice-to-have, our existing static-image generator covers most cases. Ship when someone asks for it. |
| 10 | **Event-driven progress monitoring** | Replace the `/serious-code` "wake up every five seconds and check" loop with event-driven notifications. Works fine today; small optimization, low priority. |

### Killed / merged

| Item | What happened |
|------|---------------|
| **Cold-read enforcement** (was #2) | Abandoned 2026-04-14 after the plan failed review twice with the same pattern. Revisit only if observability logs show this is a real problem. |
| **Auto-detect skill invocation** (was #8) | Partly obsoleted by Claude Code's new `claude agents` view and `/goal` command, which together cover most of the original need. Folded into items 3 and 4 above. |

**Legend:** S = ≤2 days, M = week, XL = month+. Detailed rationale for each feature in §B–§K below.

---

## Recently Shipped

| Version / Commit | Date | What shipped |
|:----------------|:-----|:-------------|
| **PR #2** (branch `voice-retrofit-phases-2-4`, 6 commits) | 2026-05-17 → 18 | **Voice retrofit Phases 2-6 + retroactive verification.** Stop-hook validator (`voice-gate.sh`) catches numbered stage labels, file paths, code fences in chat; UserPromptSubmit reminder hook (`voice-reminder.sh`) with hardcoded factual phrasing (closes indirect-prompt-injection vector); Haiku voice-translator sub-agent with pre-emit self-check, wired into 3 of 4 high-volume touchpoints (research handoff deferred with explicit marker per the plan); inline prose rewrites across all 14 SKILL.md (≥50% catalogued slop per skill, rest deferred with reasons); `/serious-conversation` Orchestrator switched to single-recommendation default with `/options` affordance; `/serious-status` common-case voice-card summary; `/serious-abandon` final-report framing; 25-surface canonical-block sync lint (`verify-voice-card-sync.sh`); falsification gate honestly relabeled (Part A — safety-net coverage; Part B live-touchpoint replay companion file). 15/15 voice tests pass (257 assertions total); full project suite holds at 18/20 (same 2 pre-existing failures, one fixed on main by upstream `1dc94ea`). Self-written incident report at `docs/incidents/voice-retrofit-2026-05-17.md` documents three rounds of corner-cutting during this work — read before extending. Known gaps deferred: ~10 missing evidence files, cherry-picked fire-rate samples, Orchestrator example count (1 vs plan's 2-3), translator behavior tests for malformed/timeout/injection/wrapper paths, soft jargon leak at cheap-model low effort, no fresh-session end-to-end smoke test. |
| `736ef45` | 2026-05-16 | **PM-voice retrofit Phase 1 + .gitignore hardening.** Canonical voice card at `.claude/skills/_shared/voice-card.md`; PM-voice Output Style at `.claude/output-styles/PM-voice.md` set as default in `.claude/settings.json`; `/serious-research` Phase 6 handoff rewritten to use the PM voice instead of dumping grade distributions, folder paths, and persona names. `CLAUDE.md` now has a "Working with Me" + "stupid salesguy / PM voice (DEFAULT)" section. `.gitignore` gained default-deny under `.claude/*` with explicit un-ignores, a credential-pattern block, and coverage for `.claude-active/` + root `report.html`. Deep research output graded 13A/6B/4C/4D claims; 73% citation pass rate from independent QA; one Anthropic-doc misattribution caught and corrected during verification. **Phases 2-6 shipped in PR #2** (see row above). |
| v1.8.0 · `2137748` | 2026-04-14 | **Observability spike — silent-pass becomes visible.** `_log_outcome` helper + all 5 hooks instrumented at every exit site. TSV log at `.claude/logs/outcomes.log`. 14 tests. Diagnostic only (NOT a security control). Shipped as spike after panel converged on "measure first, harden later." 9-plan observability roadmap abandoned; follow-on plans will be written from real log data, not research speculation. |
| *(unstaged)* | 2026-04-12 | **Dispatch audit trail.** PreToolUse/Agent hook logs every agent dispatch to `dispatch_log.md`. Completion report warns if any task dispatched fewer than 5 agents. 47 tests. Input sanitized, file mode 0600. End-to-end verified. |
| *(unstaged)* | 2026-04-12 | **Karpathy principles — KILLED.** `/serious-conversation` panel (4 personas, 2 rounds, unanimous). Audience mismatch: principles target bare-CLAUDE.md projects, redundant with our mechanical enforcement. Two tactical fixes survived as one-line edits. |
| *(unstaged)* | 2026-04-12 | **Live status line for `/serious-code`.** Second footer line: `[serious-code · Phase N/M · Task N/M · agent: state]`. Integrated into `~/.claude/statusline-command.sh`. 18 status-line tests. |
| *(unstaged)* | 2026-04-12 | **YouTube research sprint.** 4 videos ingested. 3 new roadmap items. |
| **`5001774`** | 2026-04-12 | **Supply-chain hardening for `serious-update` + `/serious-init`.** 3 attack vectors closed: manifest tier-swap blocked in `parse_manifest`, SHA-256 hash verification activated (was decorative), `is_serious()` regex end-anchored, template key allowlist enforced on fresh-install. 32 new supply-chain tests. Full `/serious-code` run — 6 tasks, all gates passed. Also serves as T3 live smoke test. |
| **`1907ccb`** | 2026-04-11 | **Stop-hook-loop-pattern rollout sync.** All 6 project hooks now source `_shared/stop-hook-guard.sh`. |
| **`b792fde`** | 2026-04-09 | `/serious-youtube-tldr` skill, `CLAUDE_CODE_CHANGELOG.md` initial publish, ROADMAP augmented with v2.1.94–v2.1.98 items. |
| **v1.6.0** | 2026-04-05 | Breadcrumb 0-pre silence + staleness detection. |
| **v1.5.0** | 2026-03-31 | Worktree-safe hooks. 8 path-handling bugs fixed. 96 assertions. |
| **v1.4.0** | 2026-03-29 | Mechanical enforcement gap closed. All 9 hooks fail-closed. |
| **v1.3.0** | — | Agent control levers. `disallowedTools` blocks 7/8 agents from Edit/Write. |
| **v1.2.0** | 2026-03-22 | Superpowers A-tier. Anti-rationalization tables, Agent Teams, verification-before-completion. |

---

## Resolved Spikes

All 3 Tier 0 spikes are resolved. Feature work is unblocked.

- **T1 (2026-04-11):** `disallowedTools` enforcement WORKS on subagents — tools filtered before dispatch, not runtime-blocked.
- **T2 (2026-04-11):** Monitor tool integration pattern verified — `stdbuf -oL tail -F evidence.log` works. Monitor watches shell scripts, not subagents.
- **T3 (2026-04-12):** Supply-chain hardening `/serious-code` run = full end-to-end smoke test after hook rollout sync. All gates passed.

---

## Recently Shipped

| Version / Commit | Date | What shipped |
|:----------------|:-----|:-------------|
| *(unstaged)* | 2026-04-12 | **Live status line for `/serious-code`.** Second footer line shows `[serious-code · Phase N/M · Task N/M · agent: state]` during active runs. Integrated into existing `~/.claude/statusline-command.sh`. 5 plans total (3 security prereqs + schema + integration). 18 status-line tests + 32 supply-chain tests + 16 existing tests all pass. Secret env vars scrubbed, terminal injection sanitized, path validation via `resolve_breadcrumb_path`. |
| **`5001774`** | 2026-04-12 | **Supply-chain hardening for `serious-update` + `/serious-init`.** 3 attack vectors closed: manifest tier-swap blocked in `parse_manifest`, SHA-256 hash verification activated (was decorative), `is_serious()` regex end-anchored, template key allowlist enforced on fresh-install. 32 new supply-chain tests. Full `/serious-code` run — 6 tasks, all gates passed. Also serves as T3 live smoke test. |
| *(unstaged)* | 2026-04-12 | **YouTube research sprint.** 4 videos ingested via `/serious-youtube-tldr`: Karpathy principles, Excalidraw MCP, 5 durable web verticals, `context: fork` chaining. 3 new roadmap items (#9-#11). |
| **`1907ccb`** | 2026-04-11 | **Stop-hook-loop-pattern rollout sync.** All 6 project hooks now source `_shared/stop-hook-guard.sh`. `bin/generate-manifest.sh` now walks `_shared/`. `manifest.json` includes the previously-untracked `_shared/handoff-verifier.md` plus the 3 new guard files. 15/15 unit tests pass; all 6 hooks pass susceptibility test. Discovered while researching ROADMAP item #1. |
| **`b792fde`** | 2026-04-09 | `/serious-youtube-tldr` skill, `CLAUDE_CODE_CHANGELOG.md` initial publish, ROADMAP augmented with v2.1.94–v2.1.98 items. |
| **v1.6.0** | 2026-04-05 | Breadcrumb 0-pre silence + staleness detection. Skills no longer narrate "No active breadcrumbs" during advancing workflows. Stale breadcrumbs auto-detected by frontmatter status or file age > 4 hours. `debug(8)` added to pipeline order. |
| **v1.5.0** | 2026-03-31 | **Worktree-safe hooks.** All 15 hooks resolve paths via `$CLAUDE_PROJECT_DIR`. 8 pre-existing path-handling bugs fixed. 10 test suites, 96 assertions. Unblocks multi-plan parallel execution. |
| **v1.4.0** | 2026-03-29 | **Mechanical enforcement gap closed.** Gaps 1–3, 5, 7–9 shipped via Stop hook extensions. All 9 hooks converted to fail-closed. Dispatch log validates all 5 code agents ran. |
| **v1.3.0** | — | **Agent control levers.** `effort: high/medium/low` set for all 8 agents. `disallowedTools` blocks 7 of 8 agents from Edit/Write — only Implementer can write code. **(See T1 — never empirically verified.)** |
| **v1.2.0** | 2026-03-22 | **Superpowers A-tier:** Anti-rationalization tables, Agent Teams integration, verification-before-completion in `/serious-code`. |

---

## Detailed Rationale — Top Priorities

### A. Dispatch audit trail (#1)

**Status: HOLD 1-2 weeks. Research complete at `Research/features/pretooluse-agent-hook/`.**

**The gap.** `verify-completion-gate.sh` checks that 5 evidence files exist per task. It does NOT check that 5 agents actually dispatched. A buggy or rogue orchestrator can write 5 fake evidence files and pass the gate.

**Original design (killed).** Stop hook validates a dispatch log at session end. Block if any task has fewer than 5 distinct agent dispatches.

**Why killed.** This is **Category C** by the past `Research/bugs/stop-hook-loop-pattern/` taxonomy — cross-agent precondition requiring sub-agent dispatches to fix. Same architectural class as `check-extraction.sh` which caused an ~80-turn infinite loop on April 7. Adding a Category C check to `verify-completion-gate.sh` (already loop-prone in the project repo until today's commit) would have repeated the incident.

**Replacement design — observability only.** `PreToolUse/Agent` hook logs every dispatch to `dispatch_log.md`. Always exits 0. Completion report surfaces a "Dispatch Audit" section that warns if a task has fewer than 5 distinct types — but doesn't block the session. Closes ~80% of the fabrication threat by making cheating detectable post-hoc.

**Why HOLD.** v2.1.101 fixed two related subagent inheritance bugs (MCP tools, worktree file access). The broader hook inheritance fix may land in v2.1.102 or v2.1.103. If it does, the original mechanical-enforcement design works cleanly without the loop risk — and the audit trail becomes a strict downgrade. Wait 1-2 weeks. If no upstream fix, ship the audit trail.

**Optional Phase 2 (after audit trail is stable).** PreToolUse metadata validation: exit 2 if a dispatch is missing its `TASK_ID` tag or uses an unapproved `subagent_type`. Safe because PreToolUse blocks are one-shot (verified empirically in the research). Not loop-prone.

**Effort if we ship the audit trail:** Small-Medium (~2-3 days).

### B. Monitor tool integration (#2)

**Status: PLANNED. T2 resolved the integration pattern on 2026-04-11.**

**Problem.** `/serious-code` currently polls evidence directories via `while sleep 5; do check; done` to detect when verification agents have finished. This burns API calls, misses state transitions shorter than the poll interval, and doesn't handle agent crashes gracefully.

**Original framing (wrong).** The previous version of this roadmap said "subscribe to background agent events." That's conceptually wrong — Monitor is a shell-script watcher, not a subagent-output streamer. The integration path is different.

**Correct integration pattern (verified in T2).**

1. When `/serious-code` starts, the orchestrator launches a Monitor watching a tail of the active plan's dispatch log:
   ```
   Monitor({
     command: "stdbuf -oL tail -F {PLAN_DIR}/evidence/dispatch_log.md",
     description: "agent dispatches for {plan_slug}",
     timeout_ms: 3600000,  // or persistent: true for long runs
     persistent: false
   })
   ```

2. As verification agents complete and append to the log, each line becomes a notification in the conversation stream. The orchestrator reacts to events instead of polling.

3. `stdbuf -oL` is **mandatory** — without it, `tail -F` block-buffers its stdout when piped into Monitor's capture, delaying events by 5+ seconds. T2 verified this empirically.

4. Events within 200ms are batched into a single notification. Not a problem for `/serious-code`'s pacing (agents run sequentially with multi-second gaps).

**Why it's #2.** Removes the sleep-poll (which is brittle and wastes tokens) without requiring any new upstream features. Pairs naturally with the dispatch audit trail (#1) if/when that ships — same evidence file, same tail mechanism.

**Dependencies.** Requires the dispatch audit trail (#1) to be shipped first, because Monitor needs a file to tail. Without #1, there's no per-dispatch log to watch. This means #2 effectively HOLDs on #1 — which is currently on HOLD waiting for upstream. If #1 stays blocked, an alternative `evidence_index.log` could be added independently.

**Open items for the plan phase.**
- Where exactly does the dispatch log live? (`{PLAN_DIR}/evidence/dispatch_log.md` is the current proposal from the hook research.)
- What's the timeout strategy? `persistent: true` for long runs, or a fixed 1-hour timeout with re-arming?
- How does the orchestrator handle Monitor timeout/stream-end mid-run?
- Does Monitor output need any processing (grep, jq) before it becomes useful, or is raw tail enough?

### C. Cold-read enforcement (#3)

**Problem.** `/serious-review` agents are supposed to read the plan cold — no research context, no author notes, no implementer drafts. Today nothing stops them. The cold-read principle is a guideline.

**Solution.** PreToolUse/Read hook scoped to `/serious-review` sessions. Logs which files the reviewer opens. If anything outside the plan itself (research.md, conversation summary, completed code) is opened, the verdict is automatically marked "cold-read violated" and the round restarts.

**Why safe.** PreToolUse blocks are one-shot. Verified empirically in the dispatch hook research. Even if Claude misinterprets the block reason and retries the exact same Read, the loop exits naturally — there's no infinite feedback structure like Stop hooks have.

**Why it's #3, not #1.** Review theater is the most subtle form of enforcement gap. Real but lower frequency than the dispatch fabrication threat — and safer to build than the audit trail because it doesn't depend on unresolved upstream questions.

### D. Live status line during `/serious-code` (#4)

**Promoted from #7 in the previous ranking.** Effort is small, value is high, no upstream dependencies.

**Problem.** A `/serious-code` run takes 30+ minutes with silent agent spawns in between. Output IS streaming (verified empirically) but there's no aggregated progress indicator — just a scrolling log. Users can't glance at the terminal and know "where am I in the plan?"

**Solution.** `refreshInterval` (v2.1.97) re-runs a status line script every N seconds. Script reads the active evidence directory and shows: `Phase 2/4 · Task 5/11 · runtime: passing · qa: pending`. Combined with `workspace.git_worktree` (v2.1.97), shows which worktree/plan is active.

**Why it's #4.** Smallest effort on the list, highest perceived quality improvement, no blockers, and v2.1.101 improved focus mode in ways that pair well with this. Likely the first thing to ship after T1 clears.

### E. `defer` + `PermissionDenied` hooks (#5)

**Problem.** Running `/serious-code` in headless mode is all-or-nothing today. Either you allow everything (dangerous) or the session blocks on the first permission prompt. Long unattended runs don't work.

**Solution.** Two hook types together:
- `defer`: PreToolUse can return "defer" instead of allow/deny. Session pauses, can resume with `-p --resume` after user approval. For dangerous ops (writing to protected dirs, pushing remote).
- `PermissionDenied`: Fires after auto-mode classifier denials. Can return `{retry: true}` to tell the model it can retry. For over-cautious denials.

**Why #5.** Critical for CI/headless and enterprise adoption — but lower priority than #1-4 because most users today run interactively. Bumps to higher priority once enterprise demand materializes.

**v2.1.101 note.** v2.1.101 fixed `permissions.deny` rules being downgraded to "ask" by PreToolUse hooks — tightens the security model around any future use of these features.

### F. `paths:` globs for skill auto-loading (#6)

**Problem.** 18 auto-loader skills (hooks, MCP, subagents, worktrees, etc.) load based on description matching. Every skill adds context tokens on relevant sessions. When editing TypeScript, the worktrees skill is often loaded but irrelevant.

**Solution.** Add `paths:` frontmatter to scope skill loading to file patterns. TypeScript skills only for `*.ts`. Worktree skills only when in a worktree.

**Why #6.** Quick win (Small effort), but **Medium risk** because the `paths:` + `description` interaction is untested in production. Must test on ONE auto-loader before applying to all 18 — if destructive, breaks everything. Safer to do after the more deterministic items above.

**Open question (#4 below):** Can `paths:` match on directory state, not just file patterns? Some of our skills want "load when inside a worktree" not "load for `*.foo` files."

### G. `FileChanged` hooks for drift detection (#7)

**Problem.** Sessions span days. User writes research.md Monday, runs `/serious-plan` Tuesday, runs `/serious-code` Wednesday. Between Monday and Wednesday someone edits research.md. The plan is now based on stale research. Nothing catches this.

**Solution.** `FileChanged` hooks fire when upstream artifacts are modified during an active session. Warns when research.md changes while a plan is active. Notification-only.

**Why #7.** Real failure mode but rare in solo workflows. Higher value for team workflows — bumps up if the user reports drift incidents in practice.

### H. Auto-detection skill invocation (#8)

**Problem.** Users have to remember skill names and type slash commands. New users don't know which skill fits their problem.

**Solution.** Session-start hook injects invocation cues based on intent classification. "There's a bug in auth" → offer `/serious-research`. "I know what to build" → offer `/serious-plan`.

**Why backlog.** XL effort, classification is hard, false positives are worse than no automation, AND session-start hooks don't exist as a Claude Code feature yet. Parked until the rest of the top 7 ship and the upstream feature lands.

### I. Karpathy principles enforcement in subagents (#9)

**Status: NEW. Gap analysis complete. Research at `Research/youtube/karpathy-coding-agent-principles/`.**

**The gap.** Andrej Karpathy's "skills" repo identifies 4 behavioral principles for AI coding agents. Our CLAUDE.md covers 3 of 4 at the session level. But subagents running inside `/serious-code` don't inherit most of them — they get the plan and acceptance criteria but no behavioral constraints beyond "follow TDD."

**Principle-by-principle analysis:**

| Principle | Session-level (CLAUDE.md) | Subagent-level (serious-code) | Gap |
|-----------|:-------------------------:|:-----------------------------:|:---:|
| Think before coding | CLAUDE.md #4, #9 | Missing from implementer briefing | Implementer guesses instead of flagging BLOCKED on ambiguous ACs |
| Simplicity first | **Not present anywhere** | **Not present anywhere** | Biggest gap — no constraint on minimum code, no reviewer check for over-engineering |
| Surgical changes | CLAUDE.md #5 | Plan lists Key Components but doesn't enforce "ONLY these files" | No post-implementation scope check |
| Goal-driven execution | CLAUDE.md #7 | TDD + QA + Completion Gate | Well-covered, no meaningful gap |

**Proposed changes (6 locations, all Small effort):**

1. **serious-code SKILL.md, implementer briefing** — Add: "Write the minimum code to satisfy the acceptance criteria. No additional abstractions, helpers, or error handling beyond what the criteria require. If 200 lines could be 50, rewrite."
2. **serious-code SKILL.md, implementer briefing** — Add: "If any acceptance criterion is ambiguous or has multiple valid interpretations, flag the task as BLOCKED. Do not guess."
3. **serious-code SKILL.md, guardrail table** — Add row #8: "This needs a helper/abstraction to be clean" → "Write inline first. Only extract if the plan requires reuse."
4. **serious-code SKILL.md, after Step 1.25** — Add Step 1.3 "Scope Check": compare files modified vs. Key Components. Flag unlisted files as scope violations.
5. **Plan template v6, Agent A (Code Review)** — Add "Simplicity" and "Scope" check sections.
6. **CLAUDE.md** — Add "Simplicity First" principle (the only Karpathy principle not present at session level).

**Why #9.** High impact (every `/serious-code` run benefits), Small effort (text changes to existing prompts), no upstream dependencies. Ranked below #1-8 because it's an incremental quality improvement rather than a capability gap — but could easily move to #5-6 if over-engineering becomes a recurring problem in evidence reports.

**Source:** [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) — analyzed via YouTube TLDR + direct GitHub fetch.

### J. Compound "quick skills" via `context: fork` chaining (#10)

**Status: NEW. Pattern documented. Research at `Research/youtube/chaining-claude-code-skills/`.**

**The insight.** The serious pipeline (research → scope → plan → review → code) is heavy by design — TDD, 5 verification agents, evidence, worktrees. But there's a category of operational work that needs 2-3 skills chained together without any of that overhead. Claude Code's `context: fork` frontmatter field runs an orchestrator skill in its own context window, enabling sequential `/command` invocations where each step reads the previous step's output.

**The pattern:**
- Serious-skills are for **building** things (implementation, verification, evidence)
- Quick-skills are for **understanding**, **maintaining**, and **preparing** things (the operational work between and around the serious pipeline)

**5 candidate quick-skills identified:**

| Skill | Chain | Use case |
|-------|-------|----------|
| `/quick-ingest` | `/serious-youtube-tldr` → `/serious-conversation` | Ingest a video and immediately discuss findings. Done manually today — Karpathy video then gap analysis. |
| `/quick-audit` | scan breadcrumbs → scan incomplete artifacts → produce report | Proactive health check. Today we discovered stale reviews reactively via stop hook warnings. |
| `/quick-brief` | scan Research/ for topic matches → extract findings → synthesize | Pre-planning digest from multiple research artifacts. Today: 4 videos ingested, synthesis was manual. |
| `/quick-changelog` | fetch GitHub releases → diff against local changelog → summarize delta | Monitor Claude Code releases. Done manually at the start of this session. |
| `/quick-skill-lint` | scan SKILL.md files → check hooks registration → check settings.json → lint report | Validate skill consistency. Would have caught the missing `debug(8)` pipeline order issue. |

**Implementation approach:**
1. Each quick-skill is an orchestrator SKILL.md with `context: fork` in frontmatter
2. Body lists steps as sequential `/command` invocations
3. Each step writes output to a predictable file; next step reads it
4. Final instruction specifies what to bring back to parent context
5. Optional `allowed-tools:` restricts tool access per skill

**Why #10.** Med-High impact (every session has operational work), Medium effort (5 new skills, each simple), no upstream dependencies beyond `context: fork` which already exists. Ranked below enforcement items because it's DX convenience, not correctness. But could be the highest-leverage "feels different" improvement for daily use.

### K. Excalidraw MCP integration (#11)

**Status: NEW. Research at `Research/youtube/claude-excalidraw-mcp-diagrams/`.**

**Problem.** `/serious-bananas` generates static images via Gemini. Useful for one-shot diagrams but not iterative — you can't edit the output, and Claude can't self-assess what it drew.

**Solution.** Third-party Excalidraw MCP server (not the official Excalidraw MCP) provides:
- Persistent live canvas syncing in real-time (localhost:3000)
- Claude draws on canvas, takes screenshot, visually assesses, iterates
- Exportable as PNG, SVG, or .excalidraw files for manual editing
- "3 variations then pick" workflow for creative output

**Use cases in serious-skills:**
- Architecture diagrams during `/serious-research` (iterative refinement based on findings)
- Flow diagrams in `/serious-plan` (visualize task dependencies and data flow)
- Progress visualizations in `/serious-code` (live dashboard of phase/task status)
- Workflow diagrams in `/serious-scope` (scope boundaries and dependencies)

**Why #11.** Medium impact (diagrams are nice-to-have, not blocking), Small effort (install MCP server + write a skill), but lowest priority because `/serious-bananas` covers 80% of diagram needs and the interactive canvas requires a browser open. Ships when someone wants it.

**Key insight from the video:** After iterating on diagrams you like, have Claude update the skill itself with your design preferences (colors, language level, layout). Self-improving skills — applicable beyond just Excalidraw.

**Problem.** Users have to remember skill names and type slash commands. New users don't know which skill fits their problem.

**Solution.** Session-start hook injects invocation cues based on intent classification. "There's a bug in auth" → offer `/serious-research`. "I know what to build" → offer `/serious-plan`.

**Why backlog.** XL effort, classification is hard, false positives are worse than no automation, AND session-start hooks don't exist as a Claude Code feature yet. Parked until the rest of the top 7 ship and the upstream feature lands.

### L. `claude agents` integration (#12)

**Status: NEW (2026-05-16). Driven by v2.1.139 — v2.1.143 Claude Code releases.**

**The opportunity.** v2.1.139 introduced `claude agents` — "a single list of every Claude Code session — running, blocked on you, or done. Run `claude agents` to get started." v2.1.143 added flags to configure dispatched sessions: `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions`. Background sessions are now a real workflow surface, not just a hack.

**Overlap with `/serious-status`.** Both surface "where are my active workflows." `/serious-status` reads breadcrumbs and frontmatter; `claude agents` reads daemon state. Right now they don't talk to each other — running `/serious-status` doesn't know about background sessions, and `claude agents` doesn't know about active serious workflows.

**Three integration options:**

| Option | What it means | Effort |
|---|---|---|
| A. Sit on top | `/serious-status` calls `claude agents --json` (if a JSON output flag exists) and merges results with breadcrumb data | S-M |
| B. Replace `/serious-status` | Deprecate `/serious-status` in favor of `claude agents`. Move breadcrumb info into session titles or `/rename` | M |
| C. Build parallel | Keep them separate. Both have their place. | XS (no change) |

**Why #12.** High impact on workflow visibility for the user, no upstream blockers (features shipped), Medium effort. Option A is the safest first step.

**Open questions:**
- Does `claude agents` have a `--json` or scriptable output mode? (Need to check v2.1.143 docs.)
- Can a breadcrumb be promoted into an actual background-session entry?
- What's the right naming convention so the user can read the merged list?

### M. `/goal`-driven unattended `/serious-code` (#13)

**Status: NEW (2026-05-16). Driven by v2.1.139.**

**The opportunity.** v2.1.139 introduced `/goal`: "Set a completion condition and Claude keeps working across turns until it's met. Works in interactive, `-p`, and Remote Control. Shows live elapsed/turns/tokens as an overlay panel."

**Where this fits.** `/serious-code` currently runs phase-by-phase with manual "Go" approval between phases. For trusted execution paths (low-risk plans, well-verified research, mature codebases), the manual gating is friction. `/goal` provides a structured way to say "run the plan to completion" with a clear stop condition — without going to `--dangerously-skip-permissions`.

**Proposed integration:**
- `/serious-code --autonomous` flag wraps the execution in a `/goal` with completion condition = "all phases pass, all evidence files present, no FAILED tasks."
- Falls back to manual gating if any phase produces FAILED tasks (so the user sees the failure rather than walking back to dozens of green-passing phases).
- Live `/goal` overlay shows elapsed/turns/tokens — replaces some of the live status line work from v1.8.

**Why #13.** High impact (removes the largest friction from `/serious-code`), Medium effort, no upstream dependencies. Pairs naturally with `claude --bg` (run `/serious-code` in a backgrounded session, attach later) and `claude agents` (see all autonomous runs).

**Open questions:**
- How does `/goal` interact with per-task gate hooks (verify-completion-gate, TDD-gate)?
- What happens if a gate hook returns exit-2 inside a `/goal` session? Does it count as goal-failure or just retry?
- Should the completion condition be auto-derived from the plan's evidence schema, or user-provided?

### N. Plugin packaging of Serious Sidekick (#14)

**Status: NEW (2026-05-16). Driven by plugin-ecosystem maturity across v2.1.117 — v2.1.143.**

**The opportunity.** Plugin features shipped in this window: dependency enforcement (v2.1.143), projected context cost in `/plugin` marketplace browse pane (v2.1.143), `claude plugin prune` (v2.1.121), `--plugin-url` for `.zip` archives (v2.1.129), plugin auto-installing missing dependencies on `--reload` (v2.1.117), themes shipping via `themes/` directory (v2.1.118). The Plugin distribution path is now mature enough to be the primary install method instead of `install.sh`.

**What this would change for users:** Today's install is a shell script that copies files into `~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/hooks/`, etc. New users have to clone the repo, run `./install.sh`, and trust that it doesn't break anything. As a plugin: `claude plugin install serious-sidekick` and the user is done. Updates become `claude plugin update`. Uninstall becomes `claude plugin uninstall serious-sidekick`.

**What this would change for development:** A `plugin.json` manifest declares the skills, hooks, agents, monitors, themes, and output styles. `marketplace.json` registers the plugin source (this GitHub repo). The `install.sh` flow becomes a thin "bootstrap your marketplace" shim or goes away entirely.

**Why #14.** Med-High impact (install friction is the biggest barrier to adoption), Medium-Large effort (need to refactor file layout, validate dependencies, set up marketplace), no upstream blockers.

**Open questions:**
- Does the current `manifest.json` already conform to plugin manifest expectations, or is it a custom schema?
- How does plugin packaging interact with the project-local `.claude/skills/` directory that `/serious-init` creates?
- What's the right marketplace? Self-host on this GitHub repo, or aim for an official Anthropic marketplace once that exists?
- Backward compatibility: how do existing `install.sh` users migrate without breaking their setup?

### O. Watch Anthropic Issue #54196 (#15)

**Status: WATCH (2026-05-16). Track-only.**

**The dependency.** v2.1.121 shipped: "PostToolUse hooks can now replace tool output for all tools via `hookSpecificOutput.updatedToolOutput` (previously MCP-only)." But Anthropic's own GitHub Issue #54196 (OPEN as of 2026-05-16, multiple reproducers across macOS and Ubuntu, versions v2.1.121–v2.1.123) reports the field is silently dropped at runtime for built-in tools including the Agent/Task tool.

**Why it matters here.** The voice-retrofit research (`Research/features/skill-voice-retrofit/`) found that sub-agent output translation is the single highest-leverage improvement available — but cannot be implemented today via PostToolUse because the field doesn't actually rewrite the tool output. The retrofit's Phase 3 (Haiku translator for high-value touchpoints) currently has to spawn the translator from inside the skill prose instead of intercepting tool results.

**When the bug is fixed:** Phase 3 simplifies from "rewrite call-sites in 14 skills" to "add one PostToolUse hook that translates Agent tool results into PM voice before the parent sees them." That's a ~10x reduction in retrofit work.

**Tracking strategy.** Check the issue when we hit a related Claude Code release. No active polling — that's the kind of busywork CLAUDE.md says not to do.

### P. Voice retrofit follow-through (#16)

**Status: SHIPPED FULL (2026-05-18, PR #2 on top of `736ef45`). All 6 phases landed; follow-on work catalogued in the incident report.**

Phases 1-6 shipped. The full set: canonical voice card, Output Style default, stop-hook validator, UserPromptSubmit reminder hook, Haiku voice-translator sub-agent (3 of 4 touchpoints wired; research handoff deferred with explicit marker), inline rewrites across 14 SKILL.md, Orchestrator single-recommendation default, status/abandon framing, falsification gate. 15/15 voice tests pass.

**Known gaps deferred to follow-on work** (full audit in `docs/incidents/voice-retrofit-2026-05-17.md`):

- **Missing evidence files (~10).** Per-task QA logs, before/after pairs, cost estimates, expected-output fixtures for the translator. Paperwork, not behavior.
- **Cherry-picked fire-rate samples.** The 80-touchpoint synthetic suite is constructed against the validator's hardcoded patterns. FPR=0% is a function of corpus design; representative natural traffic may evade. Rebuild with samples from real recent transcripts.
- **Orchestrator example count.** Plan demanded 2-3 example questions; only 1 ships. Add 2 more.
- **Translator behavior tests.** No malformed-payload test (AC7), no timeout-stub test (AC8), no injection-attempt test (AC9), no wrapper utility refusing unwrapped untrusted fields (AC10). Only structural tests ship today.
- **Soft jargon leak at cheap-model low effort.** Bare "phase", role-words like "Orchestrator", verifier vocab like "QA" still leak in ~4 of 5 translator runs. Hard ban (numbered labels) is enforced by the safety-net hook; soft leak is a known limitation. Could be addressed by raising translator effort or by a second tightening pass.
- **No fresh-session end-to-end smoke test for the kill-switch.** The live replay (Part B in `falsification-live-replay-evidence.md`) covered 5 touchpoints but not the symmetric inverse of the Task 0 baseline smoke test.

**Why this matters more than the gaps suggest.** Three rounds of corner-cutting during this work — documented in the incident report — show the calibration pattern: when given a corrective instruction, the agent does the literal task and skips the verification step that proves the task is sound. The retrofit shipped despite that pattern because the safety-net hook is mechanical, not voluntary. Anyone extending the retrofit should read the incident report first.

---

## Operations (do alongside features)

These are housekeeping/cleanup items from this session's discoveries. They don't compete with feature ranks — they just need doing.

| # | Item | Why | Effort |
|---|------|-----|:------:|
| O1 | **Audit other VS Code instances + old project directories** for stale `.claude/skills/` | Today's fix covered the 3 user profiles + this repo. Existing project directories with their own `.claude/skills/` from old `/serious-init` runs are still frozen at the pre-rollout version. Build a sweep script that walks parent dirs and reports which need `serious-update`. | S |
| O2 | **Commit unstaged in-conversation edits** (`CLAUDE.md`, `CLAUDE_CODE_CHANGELOG.md`, `ROADMAP.md`) | Three files have been sitting unstaged for a while. Bundle them in their own commit. CLAUDE.md is `user-init` tier in the manifest — committing it pushes the rule to all installs. Decide whether the "brief summary" rule belongs in the template or just personal config. | XS |
| O3 | **Update `lessons.md`** with two new lessons from this session | (1) "Empirical trumps secondhand" — first draft of dispatch hook research relied on stale GitHub issues and almost shipped a wrong conclusion. (2) "Grep `Research/bugs/` before proposing changes to systems with bug history" — second draft missed the architectural risk from the April 7 incident. | XS |
| O4 | **Update `/serious-research` skill** with mandatory empirical-test step in Phase 0 | When a research topic's feasibility hinges on observable behavior, "I searched the docs" is not sufficient evidence. Add a "smoke-test the claim" step before writing the feasibility verdict. | S |
| O5 | **Update `/serious-plan` skill** with mandatory `Research/bugs/` grep in Phase 0 | Before proposing changes to any system the project has a bug history with, grep `Research/bugs/` for related keywords. If a past incident is found, the plan must reference its findings. | S |

---

## Backlog

**Strategic positioning research** (from YouTube research sprint 2026-04-12):

The "5 durable web verticals" video (`Research/youtube/five-durable-web-verticals/`) identifies that AI commoditizes production — the companies that survive own structural assets the model providers can't replicate. The 5 verticals: **Trust** (verification layers), **Context** (proprietary data + permissioning), **Distribution** (curation when supply is infinite), **Taste** (orchestration quality — the human editorial decisions that make agent systems work), **Liability** (accountability guarantors).

**Relevance to Serious Sidekick:** The project lives squarely in the **Taste** vertical. The video's quote — "the winning agent systems are the ones where a human with domain expertise has carefully tuned the prompts, designed the workflows, chosen the right tools, and made a thousand small editorial decisions about how the agent should behave" — is literally the value proposition of the serious-skills pipeline. The litmus test from the video: *"What do I own that still matters if AI gets 10x better?"* Answer: the workflow design, the guardrail tables, the verification architecture, the failure evidence. Better models make the pipeline more valuable, not obsolete.

**Superpowers B-tier** (from obra/superpowers analysis 2026-03-22):

| # | Feature | Effort | Why deferred |
|---|---------|:------:|--------------|
| L1 | Verification-before-completion in ALL skills (not just `/serious-code`) | M | Big refactor. Current coverage in `/serious-code` catches 80% of cases. |
| L2 | SUBAGENT-STOP gate (prevent recursive skill loading) | S | Low frequency bug. Pair with #1 (audit trail) when it ships. |
| L3 | Model selection guidance | M | Needs cost data from `/cost` breakdown (v2.1.92) first. |
| L4 | Persuasion research backing (Cialdini principles in skill preambles) | S | Needs A/B test data to justify. |
| L5 | DOT flowcharts as executable specs | M | Experimental. Try on ONE skill first. |
| L6 | Pressure testing skills on subagents | M | Tooling doesn't exist yet. |

**Process improvements** (from v1.4.0 lessons):

| # | Gap | Fix | Status |
|---|-----|-----|:------:|
| P1 | Review agents check plans, not code (grep patterns with logic bugs passed plan review) | Post-code alignment check in `/serious-code` | BACKLOG |
| P2 | Test fixtures too clean (real dirs have extra files that interact unexpectedly) | Messy fixture test requirement in v6 template | BACKLOG |
| P3 | Parallel subagents don't cross-reference siblings | Exhaustively specific ACs for multi-agent execution | BACKLOG |
| P4 | Ad-hoc fixes during e2e skip review | Require ad-hoc fixes to have their own ACs and tests | BACKLOG |

**Claude Code features researched but parked:**

- `InstructionsLoaded` hook (v2.1.69) — verify correct skill instructions loaded at startup
- `${CLAUDE_SKILL_DIR}` variable (v2.1.69) — skill-relative paths in hook scripts
- `autoMemoryDirectory` setting (v2.1.74) — per-workflow memory organization
- `effort` frontmatter for skills (v2.1.80) — match effort to skill complexity
- `PostCompact` hook (v2.1.76) — re-inject critical instructions after compaction
- Plugin executables in `bin/` (v2.1.91) — package hook scripts as distributable plugins
- `disableSkillShellExecution` (v2.1.91) — enterprise hardening
- `/powerup` interactive lessons (v2.1.90) — onboarding
- `keep-coding-instructions` frontmatter (v2.1.94) — preserve instructions across output style changes
- `/team-onboarding` command (v2.1.101) — generates teammate ramp-up guide; investigate whether it picks up serious-* skills
- OS CA certificate trust by default (v2.1.101) — note for `/serious-init` enterprise checklist
- `hookSpecificOutput.sessionTitle` (v2.1.94) — auto-name sessions after active workflow slug
- `ENV_SCRUB` in `/serious-init` (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`) — strip credentials from subprocess env
- `CwdChanged` hooks (v2.1.??) — validate cwd stays inside expected worktree during multi-plan
- `maxTurns` frontmatter for runaway agents — needs turn count data from real workflows first
- Self-improving skills pattern (from Excalidraw video) — after iterative refinement, have Claude update the skill itself with learned preferences (colors, language level, layout). Applicable to any skill with creative output. Research at `Research/youtube/claude-excalidraw-mcp-diagrams/`
- "3 variations then pick" workflow for creative/visual output — generate multiple options, user picks direction, refine. Demonstrated with Excalidraw but applicable to `/serious-mock-ups`, `/serious-bananas`, and any skill producing design artifacts

---

## Killed (do not revisit without new evidence)

- **Architect Review Agent** — killed by `/serious-conversation` panel on 2026-04-10 (6 personas, unanimous KILL). The category is incoherent for cold LLM review (SOLID/DRY/multi-tenancy/coupling are 4 different things), no user has reported a missed architectural bug, and 20 years of architectural fitness function tools have failed in the same way (NDepend, ArchUnit, Sonargraph). The fix is updating the README to say "3 mandatory review agents covering correctness, structure, security" — not building a 4th agent. See `Research/conversations/architecture-review-agent/`.

---

## Free Wins — Already In Our Codebase

These shipped upstream and benefit us automatically. No work needed, just tracking what we got.

**Claude Code v2.1.101 (April 10, 2026) — directly relevant fixes:**

- **Subagents in isolated worktrees can now Read/Edit files inside their own worktree** — Critical for `/serious-code` multi-plan execution. Likely fixes silent failures we hadn't pinned down.
- **Subagents now inherit MCP tools from dynamically-injected servers** — Same family as the hook inheritance bugs from yesterday's research. Suggests Anthropic is actively fixing subagent inheritance — broader hook fix may be coming, which is why ROADMAP #1 is on HOLD.
- **`permissions.deny` rules now override PreToolUse hook `permissionDecision: "ask"`** — Real security fix. Buggy hooks can no longer downgrade explicit deny rules into prompts.
- **Settings resilience: unrecognized hook event names no longer disable all hooks** — Previously a typo in any hook event silently disabled the entire `settings.json` hooks block. Major safety improvement.
- **Plugin hooks force-enabled by managed settings work with `allowManagedHooksOnly`** — Enterprise hardening.
- **OTEL tracing honors `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_TOOL_CONTENT`** — Sensitive span data is opt-in. Relevant if we ever wire OTEL tracing into `/serious-code`.
- **`--resume` chain recovery fixes** — Multiple fixes for losing context, bridging into wrong subagent conversations, and crashes on missing `file_path`. Affects long `/serious-code` sessions that get resumed.
- **5-minute hardcoded request timeout fix** — Previously aborted slow backends regardless of `API_TIMEOUT_MS`. Affects long verification agent runs.
- **Memory leak fix for long sessions** — Virtual scroller no longer retains historical message-list copies. Helps marathon `/serious-code` runs.
- **Sandboxed Bash `mktemp` fix, Bedrock SigV4 + auth header conflict fix, numeric env var crash fix** — Reliability improvements.

**Claude Code v2.1.94–v2.1.98:**

- **Agent team permission inheritance fix** (v2.1.98) — `--dangerously-skip-permissions` now correctly propagates to team members.
- **Subagent worktree cwd leak fix** (v2.1.97) — Subagents no longer leak cwd back to parent. Was a silent corruption vector.
- **Stale worktree cleanup safety** (v2.1.98) — Worktrees with untracked files preserved during cleanup.
- **Background subagent partial progress on failure** (v2.1.98) — Failed agents report progress instead of silent failure.
- **Compaction transcript dedup fix** (v2.1.97) — No more multi-MB duplicate transcripts in long sessions.
- **429 rate-limit surfacing fix** (v2.1.94) — Agents fail fast instead of silent hangs.
- **`Bash(cmd:*)` wildcard spacing fix** (v2.1.98) — `Bash(git commit *)` rules now match reliably.
- **`--resume` from other worktrees** (v2.1.94) — Smoother UX resuming worktree sessions.
- **Hook stderr in transcript** (v2.1.98) — Debug hook failures without `--debug` flag.
- **Read tool deduplicates re-reads** (v2.1.86) — Token savings across all skills.
- **Prompt cache improvements** (v2.1.86) — Cost savings on Bedrock/Vertex/Foundry.
- **Default effort now HIGH** (v2.1.94) — Floor raise for user `/effort` overrides.
- **Plugin skills use frontmatter `name`** (v2.1.94) — Stable naming if we distribute as a plugin.

---

## Open Questions

1. ~~**Does `disallowedTools` actually enforce on subagents?**~~ **RESOLVED (T1 PASSED 2026-04-11).** Yes — tools filtered before dispatch, not runtime-blocked.
2. ~~**Does Monitor tool work with worktree subagents in v2.1.101?**~~ **RESOLVED (T2 PASSED 2026-04-11).** Yes, but original framing was wrong — Monitor watches shell scripts via `stdbuf -oL tail -F`, not subagent events directly.
3. **Will Anthropic ship hook inheritance fix in v2.1.102 or v2.1.103?** Watch issues #27661, #21460, #18392, #17688. If shipped, ROADMAP #1's mechanical-enforcement design becomes viable; if not, ship the audit trail.
4. **Can `paths:` scope match on directory state, not just file patterns?** Affects feature #6 viability. Some skills want "when inside a worktree" not "for `*.foo` files."
5. **How often does upstream drift actually happen in `/serious-code` runs?** Affects feature #7 priority. Could be lower than estimated in solo workflows.
6. **What `if:` field syntax scopes a hook to "only when `.active-code` exists"?** Implementation detail for any new PreToolUse hook. Resolved during planning, not blocking ranking.
7. **Is multi-plan `/serious-code` actually exercised in practice?** SKILL.md describes plan-agent orchestration that may not physically work given subagent tool restrictions. Worth verifying before optimizing it.

---

## Process Lessons (April 2026)

Captured here so they're visible during planning. Should also live in `lessons.md`.

1. **Empirical testing > secondhand sources for feasibility claims.** First draft of the dispatch hook research relied on closed GitHub issues to claim "feasibility NEGATIVE." Two persona reviews flagged this. A 15-minute test proved the issues were stale and the original design works. Always run the test when feasibility hinges on observable behavior.

2. **Grep `Research/bugs/` before proposing changes to systems with bug history.** Second draft of the dispatch hook research correctly verified feasibility but missed the architectural risk from the April 7 stop-hook-loop incident. The past research had explicitly flagged `verify-completion-gate.sh` as Category C — extending it would have repeated the incident. Always check whether a system has past incidents before adding to it.

3. **Hardening rollouts must verify deployment everywhere, not just the location of the fix.** The April 7-8 fix was applied to `~/.claude/skills/` and the rollout was marked "Tasks 0-5 complete, Task 6 (live smoke test) pending" — and then never finished. The project repo, `~/.claude-work/`, and `~/.claude-alex/` all stayed broken for ~3 days. Discovered by accident while researching a different feature.

4. **Stop hook Category C checks are loop-prone — never add new `exit 2` paths to existing Stop hooks.** Use PreToolUse for new enforcement. PreToolUse blocks are one-shot (Claude sees error, fixes the tool call, retries — single-turn fix). Stop hook blocks have an infinite feedback loop structure (Claude responds, Stop fires again, same state, same block).

5. **Stop hook stderr text must be declarative.** Imperative phrases ("Run X", "Do Y") can self-trigger Claude continuation independently of exit codes. Use observational phrasing ("X has not run", "Y is missing"). Documented in `Research/bugs/stop-hook-loop-pattern/research.md` Finding 15.

---

## Principles (How We Prioritize)

1. **Reliability before features.** Closing enforcement gaps ranks higher than new capabilities. A system that's "mandatory" but not enforced is a lie.
2. **Verification before building.** Cheap empirical tests (Tier 0 spikes) come before any feature work that depends on their answers.
3. **Impact over effort.** Effort affects timing, not order. A High-impact L-effort item beats a Low-impact S-effort item.
4. **Free wins don't get ranked.** If upstream shipped it, we get it for free. Track it, don't prioritize it.
5. **Synergies matter.** When two items together unlock a capability neither can alone, they rank as a unit.
6. **Past incidents are contracts.** If `Research/bugs/` has a record of why something fails, treat the analysis as binding for any future work in that area. Ignoring it = repeating the incident.
7. **Hold for upstream when the wait is short and the alternative is throwaway code.** If a planned workaround would be obsoleted by an upstream fix that's likely to land in 1-2 weeks, wait. Cheap to wait, expensive to ship-and-rip.
