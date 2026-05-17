# Claude Code Changelog (v2.1.87 — v2.1.143)

> Covers ~50 releases over ~48 days (March 29 — May 16, 2026).
> Earlier window (v2.1.87 — v2.1.108) detailed per-version below.
> Later window (v2.1.109 — v2.1.143) condensed in the §A summary that follows because 35 versions in 32 days would dwarf the file otherwise. Big releases in the new window: **v2.1.111** (`/ultrareview`, `/less-permission-prompts`, Opus 4.7 xhigh effort), **v2.1.117** (fork-subagent toggle exposed externally; default effort raised; 1M context for Opus 4.7), **v2.1.118** (vim visual mode, named themes, hooks invoking MCP tools, fork-subagent generally available), **v2.1.121** (PostToolUse `updatedToolOutput` for all tools), **v2.1.126** (gateway model discovery, `claude project purge`), **v2.1.139** (`claude agents` view, `/goal` command, hook `args:` exec form, hook `continueOnBlock`), **v2.1.143** (`claude agents` flags + PowerShell rollout). Original v2.1.87 — v2.1.108 entries continue below.

---

## §A — v2.1.109 through v2.1.143: condensed summary (April 14 — May 16, 2026)

This section is the digest. Full per-version detail lives at the official Anthropic changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>. Items below are filtered for impact on Serious Sidekick. Skipped versions (no relevant entries or VS-Code-only / Windows-only fixes): v2.1.115, v2.1.124, v2.1.125, v2.1.127, v2.1.130, v2.1.134, v2.1.135, v2.1.137, v2.1.138.

### Headline features (impact-ranked for this project)

| # | Feature | Version | Why it matters |
|--:|---------|:--------|----------------|
| 1 | **`claude agents` view + `claude agents` flags** | v2.1.139, v2.1.141, v2.1.142, v2.1.143 | "A single list of every Claude Code session — running, blocked on you, or done." Direct overlap with `/serious-status`. Now accepts `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions`. Background sessions become a real workflow surface. |
| 2 | **`/goal` command** | v2.1.139 | "Set a completion condition and Claude keeps working across turns until it's met." Works in interactive, `-p`, and Remote Control. Live overlay shows elapsed/turns/tokens. Direct competition / collaboration with our multi-phase `/serious-code`. |
| 3 | **PostToolUse `hookSpecificOutput.updatedToolOutput` for all tools** | v2.1.121 | Replaces the MCP-only `updatedMCPToolOutput`. **Critical caveat:** the voice-retrofit research found this is silently dropped at runtime for built-in tools including the Agent tool (Issue #54196, OPEN as of 2026-05-16). When fixed, sub-agent output translation becomes possible without per-call-site rewrites. |
| 4 | **Fork subagents (`context: fork`) generally available** | v2.1.117 (external builds via env var), v2.1.118 (general) | "Forked subagents can now be enabled on external builds by setting `CLAUDE_CODE_FORK_SUBAGENT=1`" then generally available. Roadmap #3 (compound quick skills) effort drops from M to S. |
| 5 | **Hook `args: string[]` exec form** | v2.1.139 | "Spawns the command directly without a shell, so path placeholders never need quoting." Refactor target for existing hooks that currently shell-escape inputs. |
| 6 | **Hook `continueOnBlock` for PostToolUse** | v2.1.139 | "Set to `true` to feed the hook's rejection reason back to Claude and continue the turn." Replaces the awkward exit-2+stderr pattern in PostToolUse hooks. Voice-validator hook design can use this. |
| 7 | **`/ultrareview` for code review in the cloud** | v2.1.111, `claude ultrareview` CLI in v2.1.120 | "Comprehensive code review in the cloud using parallel multi-agent analysis and critique." Already referenced in CLAUDE.md. CI-callable since v2.1.120. |
| 8 | **`/less-permission-prompts` skill** | v2.1.111 | Scans transcripts for common read-only Bash/MCP calls and proposes a prioritized allowlist for `.claude/settings.json`. Complements existing onboarding work. |
| 9 | **Hooks can invoke MCP tools (`type: "mcp_tool"`)** | v2.1.118 | "Hooks can now invoke MCP tools directly." Hook-based integrations gain a new affordance. |
| 10 | **`Skill(name *)` wildcard permission rules** | v2.1.139 | "The wildcard form now works as a prefix match." Cleaner permission rules for the `/serious-*` family. |
| 11 | **1M-context Opus 4.7 context window fix** | v2.1.117 | "Computing against a 200K context window instead of Opus 4.7's native 1M" — fixed. Long `/serious-code` runs no longer autocompact early. |
| 12 | **`xhigh` effort + interactive `/effort` slider** | v2.1.111, v2.1.139 (`effort.level` in hook input) | New effort tier between `high` and `max` for Opus 4.7. Hooks now see effort level. |
| 13 | **Native binary CLI** | v2.1.113 | "Spawn a native Claude Code binary (via a per-platform optional dependency) instead of bundled JavaScript." Faster startup; no Serious Sidekick action needed. |
| 14 | **`claude project purge`** | v2.1.126 | Deletes all Claude Code state for a project (transcripts, tasks, file history, config entry) with `--dry-run`, `-y`, `-i`, `--all`. Useful for testing the install flow. |
| 15 | **Subagent skill discovery via Skill tool** | v2.1.133 | "Fixed subagents not discovering project, user, or plugin skills via the Skill tool." Sub-agents can now reach skills again. |
| 16 | **`/loop` improvements** | v2.1.113, v2.1.140 | Esc cancels pending wakeups, redundant wakeups suppressed when background tasks notify on completion. |
| 17 | **`--from-pr` accepts GitLab and Bitbucket** | v2.1.119 | "GitLab merge-request, Bitbucket pull-request, and GitHub Enterprise PR URLs." `/ultrareview` and related flows widen beyond GitHub. |
| 18 | **`autoMode.hard_deny` rules** | v2.1.136 | "Auto mode classifier rules that block unconditionally regardless of user intent or allow exceptions." Tighter unattended-mode safety. |
| 19 | **PostToolUseFailure hook event** | v2.1.119 | Distinct from PostToolUse; fires only on tool failure. Cleaner separation. |
| 20 | **Hooks: `effort.level` in JSON input + `$CLAUDE_EFFORT` env** | v2.1.133 | Hooks now see and propagate effort level. |
| 21 | **Plugin dependency enforcement** | v2.1.143 | "`claude plugin disable` now refuses when another enabled plugin depends on the target." Affects any future plugin packaging of Serious Sidekick. |
| 22 | **`worktree.baseRef` setting** | v2.1.133 | Choose `fresh` (origin/default) or `head` (local HEAD) for `--worktree`, `EnterWorktree`, agent isolation. Affects `/serious-code` worktree behavior. |

### Notable smaller items

- **Plugin ecosystem matured** (v2.1.117–v2.1.143): dependency resolution, projected context cost in marketplace browser, `claude plugin prune`, `--plugin-url`, `.zip` plugin archives, themes/monitors moved to `experimental`. Plugin distribution of Serious Sidekick now plausible.
- **Background sessions** (`/bg`, `claude --bg`, `←`-detach): persisted flags across retire/wake for `--dangerously-skip-permissions`, `--allow-dangerously-skip-permissions`, `--fallback-model`, `--mcp-config`, `--settings`, `--add-dir`, `--plugin-dir`, `--strict-mcp-config`. Empty idle background sessions auto-retire after 5 min.
- **`CLAUDE_CODE_SESSION_ID` env var** (v2.1.132): Bash tool subprocesses get the session ID. Useful for skill-internal logging tied to the parent session.
- **`Bash(touch *)`, `Bash(mkdir *)` allow rules honored** (v2.1.126): regression fix; relevant to TDD-gate hook permissioning.
- **`autoAllowBashIfSandboxed` honors shell expansions** (v2.1.139).
- **PreToolUse hook `additionalContext` no longer dropped on tool failure** (v2.1.110).
- **`/ultrareview` parallelized + diffstat** (v2.1.113).
- **Stop hooks: 8-block infinite-loop cap with `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` override** (v2.1.143). Material for our voice-validator hook design.
- **Memory leaks**: multiple fixed (v2.1.121: many images, `/usage` 2GB leak, long-running tools failing to emit progress; v2.1.117: idle re-render loop). No Serious Sidekick action.
- **Security**: bash deny rules now match `env`/`sudo`/`watch`/`ionice`/`setsid` wrappers (v2.1.113); `Bash(find:*)` no longer auto-approves `-exec`/`-delete` (v2.1.113); macOS `/private/{etc,var,tmp,home}` treated as dangerous removal targets under `Bash(rm:*)` (v2.1.113).
- **Spinner / UX**: thinking spinner shows progress inline (v2.1.116); long-thinking spinner turns amber after 10s (v2.1.141).
- **OpenTelemetry**: agent_id / parent_agent_id headers and OTEL attributes (v2.1.139); `claude_code.skill_activated` carries `invocation_trigger` (v2.1.126); `claude_code.at_mention` event (v2.1.122).

### Items that did NOT ship (still pending from current ROADMAP)

- **`paths:` globs for skill auto-loading (ROADMAP #5)** — Not in any v2.1.109–v2.1.143 changelog entry. Still researched-only.
- **`FileChanged` hooks for drift detection (ROADMAP #6)** — Not in any changelog entry. Still researched-only.
- **`defer` + `PermissionDenied` hooks (ROADMAP #4)** — Not in any changelog entry. Still pending. (Related: `PermissionRequest` hook bugs around `updatedInput` and `setMode:'bypassPermissions'` were fixed in v2.1.110.)

### Impact on Serious Sidekick (cross-cutting)

1. **ROADMAP #3 (compound quick skills)** drops from M to S effort because fork-subagents are now generally available externally without env-var gating (v2.1.117 → v2.1.118).
2. **ROADMAP #8 (auto-detection skill invocation)** is now broadly enabled — `claude agents` view + `/goal` together cover most of what the original roadmap item was asking for. Reassess whether it remains its own item or merges with new `claude agents` integration work.
3. **`claude agents` view is a NEW potential roadmap item**: integrate `/serious-status` with it, or build on top of it instead of competing.
4. **`/goal` is a NEW potential roadmap item**: use it to drive `/serious-code` unattended execution; replaces some of the per-phase approval ceremony.
5. **Voice-retrofit research's Issue #54196 dependency** (PostToolUse `updatedToolOutput` broken at runtime) is now confirmed via the v2.1.121 changelog entry. When fixed, the retrofit's Phase 3 sub-agent translation simplifies considerably.
6. **ROADMAP #1 (Monitor tool)** — still REASSESS. No new info in this window beyond the v2.1.105 `monitors` manifest key already noted.

---

## v2.1.108 — April 14, 2026

### Added
- `ENABLE_PROMPT_CACHING_1H` env var to opt into 1-hour prompt cache TTL on API key, Bedrock, Vertex, and Foundry (`ENABLE_PROMPT_CACHING_1H_BEDROCK` is deprecated but still honored); `FORCE_PROMPT_CACHING_5M` to force 5-minute TTL
- Recap feature to provide context when returning to a session, configurable in `/config` and manually invocable with `/recap`; force with `CLAUDE_CODE_ENABLE_AWAY_SUMMARY` if telemetry disabled
- **The model can now discover and invoke built-in slash commands like `/init`, `/review`, and `/security-review` via the Skill tool**
- `/undo` is now an alias for `/rewind`

### Improved
- `/model` warns before switching models mid-conversation, since the next response re-reads the full history uncached
- `/resume` picker defaults to sessions from the current directory; press `Ctrl+A` to show all projects
- Error messages: server rate limits distinguished from plan usage limits; 5xx/529 errors show a link to status.claude.com; unknown slash commands suggest the closest match
- Reduced memory footprint for file reads, edits, and syntax highlighting by loading language grammars on demand
- Added "verbose" indicator when viewing the detailed transcript (`Ctrl+O`)
- Warning at startup when prompt caching is disabled via `DISABLE_PROMPT_CACHING*` env vars

### Fixed (selected highlights — 12 fixes total)
- Paste not working in the `/login` code prompt (regression in 2.1.105)
- Subscribers who set `DISABLE_TELEMETRY` falling back to 5-min prompt cache TTL instead of 1 hour
- Agent tool prompting for permission in auto mode when the safety classifier's transcript exceeded its context window
- `claude --resume <session-id>` losing the session's custom name and color set via `/rename`
- Transcript write failures (e.g., disk full) being silently dropped instead of logged
- Policy-managed plugins never auto-updating when running from a different project than where they were first installed

### Impact on Serious Sidekick

- **Built-in slash commands via Skill tool is a big deal for ROADMAP #8.** Auto-detection skill invocation ("bug in auth" → `/serious-research` without typing the slash command) was XL effort blocked on infrastructure. v2.1.108 ships that infrastructure for BUILT-IN commands. User-defined slash commands (our `/serious-*` family) are likely the next expansion. Status: **BACKLOG → RESEARCH**.
- **`/recap` overlaps with our `context.md`.** Not a replacement — our `context.md` is persistent cross-session, `/recap` is session-return oriented. But the feature suggests upstream is thinking about the same problem. Worth checking if `/recap` telemetry can feed into our next-session context load.
- **1-hour prompt caching (`ENABLE_PROMPT_CACHING_1H`)** — long `/serious-code` runs can benefit from 1-hour TTL on the prompt cache. Cost savings + speed. Consider adding to `/serious-init` environment setup.
- **Transcript write failures now logged** — closes a silent-failure class; no action needed on our side.

---

## v2.1.107 — April 14, 2026

- Show thinking hints sooner during long operations

---

## v2.1.105 — April 12-13, 2026

### Added
- `path` parameter to the `EnterWorktree` tool to switch into an existing worktree of the current repository
- PreCompact hook support: hooks can now block compaction by exiting with code 2 or returning `{"decision":"block"}`
- Background monitor support for plugins via a top-level `monitors` manifest key that auto-arms at session start or on skill invoke
- `/proactive` is now an alias for `/loop`

### Improved
- Stalled API stream handling: streams now abort after 5 minutes of no data and retry non-streaming instead of hanging indefinitely
- Network error messages: connection errors now show a retry message immediately instead of a silent spinner
- File write display: long single-line writes (e.g. minified JSON) are now truncated in the UI instead of paginating across many screens
- `/doctor` layout with status icons; press `f` to have Claude fix reported issues
- `/config` labels and descriptions for clarity
- Skill description handling: raised the listing cap from 250 to 1,536 characters and added a startup warning when descriptions are truncated
- `WebFetch` to strip `<style>` and `<script>` contents from fetched pages so CSS-heavy pages no longer exhaust the content budget before reaching actual text
- Stale agent worktree cleanup to remove worktrees whose PR was squash-merged instead of keeping them indefinitely
- MCP large-output truncation prompt to give format-specific recipes (e.g. `jq` for JSON, computed Read chunk sizes for text)

### Fixed (selected highlights — 22 fixes total)
- Images attached to queued messages (sent while Claude is working) being dropped
- Screen going blank when the prompt input wraps to a second line in long conversations
- Leading whitespace being trimmed from assistant messages, breaking ASCII art and indented diagrams
- Garbled bash output when commands print clickable file links
- `alt+enter` not inserting a newline in terminals using ESC-prefix alt encoding (regression in 2.1.100)
- MCP tools missing on the first turn of headless/remote-trigger sessions when MCP servers connect asynchronously
- 429 rate-limit errors showing a raw JSON dump instead of a clean message
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` in one project's settings permanently disabling usage metrics for all projects on the machine
- Marketplace auto-update leaving the official marketplace in a broken state when a plugin process holds files open during the update

### Impact on Serious Sidekick

- **PreCompact hook** — new event we weren't tracking. Useful for `/serious-code` long runs that approach context limits — block compaction until evidence files are written. Consider adding to roadmap.
- **`monitors` manifest key** — upstream first-class support for what our ROADMAP item #1 (Monitor tool integration) was going to build. May obsolete our approach or reshape it to use the manifest key instead of custom polling.
- **Skill description cap raised 250 → 1536** — our 18 auto-loader skills can now have richer descriptions. May improve auto-load accuracy without needing `paths:` globs (ROADMAP #5).
- **`/proactive` alias for `/loop`** — cosmetic; no action.

---

## v2.1.101 — April 10, 2026

- Added `/team-onboarding` command to generate a teammate ramp-up guide from your local Claude Code usage
- Added OS CA certificate store trust by default, so enterprise TLS proxies work without extra setup (set `CLAUDE_CODE_CERT_STORE=bundled` to use only bundled CAs)
- `/ultraplan` and other remote-session features now auto-create a default cloud environment instead of requiring web setup first
- Improved brief mode to retry once when Claude responds with plain text instead of a structured message
- Improved focus mode: Claude now writes more self-contained summaries since it knows you only see its final message
- Improved tool-not-available errors to explain why and how to proceed when the model calls a tool that exists but isn't available in the current context
- Improved rate-limit retry messages to show which limit was hit and when it resets instead of an opaque seconds countdown
- Improved refusal error messages to include the API-provided explanation when available
- Improved `claude -p --resume <name>` to accept session titles set via `/rename` or `--name`
- Improved settings resilience: an unrecognized hook event name in `settings.json` no longer causes the entire file to be ignored
- Improved plugin hooks from plugins force-enabled by managed settings to run when `allowManagedHooksOnly` is set
- Improved `/plugin` and `claude plugin update` to show a warning when the marketplace could not be refreshed, instead of silently reporting a stale version
- Improved plan mode to hide the "Refine with Ultraplan" option when the user's org or auth setup can't reach Claude Code on the web
- Improved beta tracing to honor `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_DETAILS`, and `OTEL_LOG_TOOL_CONTENT`; sensitive span attributes are no longer emitted unless opted in
- Improved SDK `query()` to clean up subprocess and temp files when consumers `break` from `for await` or use `await using`
- Fixed a command injection vulnerability in the POSIX `which` fallback used by LSP binary detection
- Fixed a memory leak where long sessions retained dozens of historical copies of the message list in the virtual scroller
- Fixed `--resume`/`--continue` losing conversation context on large sessions when the loader anchored on a dead-end branch instead of the live conversation
- Fixed `--resume` chain recovery bridging into an unrelated subagent conversation when a subagent message landed near a main-chain write gap
- Fixed a crash on `--resume` when a persisted Edit/Write tool result was missing its `file_path`
- Fixed a hardcoded 5-minute request timeout that aborted slow backends (local LLMs, extended thinking, slow gateways) regardless of `API_TIMEOUT_MS`
- Fixed `permissions.deny` rules not overriding a PreToolUse hook's `permissionDecision: "ask"` — previously the hook could downgrade a deny into a prompt
- Fixed `--setting-sources` without `user` causing background cleanup to ignore `cleanupPeriodDays` and delete conversation history older than 30 days
- Fixed Bedrock SigV4 authentication failing with 403 when `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper`, or `ANTHROPIC_CUSTOM_HEADERS` set an Authorization header
- Fixed `claude -w <name>` failing with "already exists" after a previous session's worktree cleanup left a stale directory
- Fixed subagents not inheriting MCP tools from dynamically-injected servers
- Fixed sub-agents running in isolated worktrees being denied Read/Edit access to files inside their own worktree
- Fixed sandboxed Bash commands failing with `mktemp: No such file or directory` after a fresh boot
- Fixed `claude mcp serve` tool calls failing with "Tool execution failed" in MCP clients that validate `outputSchema`
- Fixed `RemoteTrigger` tool's `run` action sending an empty body and being rejected by the server
- Fixed several `/resume` picker issues: narrow default view hiding sessions from other projects, unreachable preview on Windows Terminal, incorrect cwd in worktrees, session-not-found errors not surfacing in stderr, terminal title not being set, and resume hint overlapping the prompt input
- Fixed Grep tool ENOENT when the embedded ripgrep binary path becomes stale (VS Code extension auto-update, macOS App Translocation); now falls back to system `rg` and self-heals mid-session
- Fixed `/btw` writing a copy of the entire conversation to disk on every use
- Fixed `/context` Free space and Messages breakdown disagreeing with the header percentage
- Fixed several plugin issues: slash commands resolving to the wrong plugin with duplicate `name:` frontmatter, `/plugin update` failing with `ENAMETOOLONG`, Discover showing already-installed plugins, directory-source plugins loading from a stale version cache, and skills not honoring `context: fork` and `agent` frontmatter fields
- Fixed the `/mcp` menu offering OAuth-specific actions for MCP servers configured with `headersHelper`; Reconnect is now offered instead to re-invoke the helper script
- Fixed `ctrl+]`, `ctrl+\`, and `ctrl+^` keybindings not firing in terminals that send raw C0 control bytes (Terminal.app, default iTerm2, xterm)
- Fixed `/login` OAuth URL rendering with padding that prevented clean mouse selection
- Fixed rendering issues: flicker in non-fullscreen mode when content above the visible area changed, terminal scrollback being wiped during long sessions in non-fullscreen mode, and mouse-scroll escape sequences occasionally leaking into the prompt as text
- Fixed crash when `settings.json` env values are numbers instead of strings
- Fixed in-app settings writes (e.g. `/add-dir --remember`, `/config`) not refreshing the in-memory snapshot, preventing removed directories from being revoked mid-session
- Fixed custom keybindings (`~/.claude/keybindings.json`) not loading on Bedrock, Vertex, and other third-party providers
- Fixed `claude --continue -p` not correctly continuing sessions created by `-p` or the SDK
- Fixed several Remote Control issues: worktrees removed on session crash, connection failures not persisting in the transcript, spurious "Disconnected" indicator in brief mode for local sessions, and `/remote-control` failing over SSH when only `CLAUDE_CODE_ORGANIZATION_UUID` is set
- Fixed `/insights` sometimes omitting the report file link from its response
- [VSCode] Fixed the file attachment below the chat input not clearing when the last editor tab is closed

---

## v2.1.100 — April 10, 2026

**Republish only — no behavioral changes.** The `v2.1.100` git tag points to the exact same commit SHA as `v2.1.98` (`c5600e0b1e9bb6ddf750cf7441c4d4fffbb7c917`). The GitHub release body is empty and `CHANGELOG.md` has no entry for this version. Most likely a packaging, signing, or registry republish after v2.1.99 was skipped. **Treat v2.1.100 as functionally equivalent to v2.1.98.** Anthropic did not backfill release notes for this version — instead they cut v2.1.101 the same day with the actual changes.

---

## v2.1.98 — April 9, 2026

- Added interactive Google Vertex AI setup wizard accessible from the login screen when selecting "3rd-party platform", guiding you through GCP authentication, project and region configuration, credential verification, and model pinning
- Added `CLAUDE_CODE_PERFORCE_MODE` env var: when set, Edit/Write/NotebookEdit fail on read-only files with a `p4 edit` hint instead of silently overwriting them
- Added Monitor tool for streaming events from background scripts
- Added subprocess sandboxing with PID namespace isolation on Linux when `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` is set, and `CLAUDE_CODE_SCRIPT_CAPS` env var to limit per-session script invocations
- Added `--exclude-dynamic-system-prompt-sections` flag to print mode for improved cross-user prompt caching
- Added `workspace.git_worktree` to the status line JSON input, set whenever the current directory is inside a linked git worktree
- Added W3C `TRACEPARENT` env var to Bash tool subprocesses when OTEL tracing is enabled, so child-process spans correctly parent to Claude Code's trace tree
- LSP: Claude Code now identifies itself to language servers via `clientInfo` in the initialize request
- Fixed a Bash tool permission bypass where a backslash-escaped flag could be auto-allowed as read-only and lead to arbitrary code execution
- Fixed compound Bash commands bypassing forced permission prompts for safety checks and explicit ask rules in auto and bypass-permissions modes
- Fixed read-only commands with env-var prefixes not prompting unless the var is known-safe (`LANG`, `TZ`, `NO_COLOR`, etc.)
- Fixed redirects to `/dev/tcp/...` or `/dev/udp/...` not prompting instead of auto-allowing
- Fixed stalled streaming responses timing out instead of falling back to non-streaming mode
- Fixed 429 retries burning all attempts in ~13s when the server returns a small `Retry-After` — exponential backoff now applies as a minimum
- Fixed MCP OAuth `oauth.authServerMetadataUrl` config override not being honored on token refresh after restart, affecting ADFS and similar IdPs
- Fixed capital letters being dropped to lowercase on xterm and VS Code integrated terminal when the kitty keyboard protocol is active
- Fixed macOS text replacements deleting the trigger word instead of inserting the substitution
- Fixed `--dangerously-skip-permissions` being silently downgraded to accept-edits mode after approving a write to a protected path via Bash
- Fixed managed-settings allow rules remaining active after an admin removed them, until process restart
- Fixed `permissions.additionalDirectories` changes not applying mid-session — removed directories lose access immediately and added ones work without restart
- Fixed removing a directory from `additionalDirectories` revoking access to the same directory passed via `--add-dir`
- Fixed `Bash(cmd:*)` and `Bash(git commit *)` wildcard permission rules failing to match commands with extra spaces or tabs
- Fixed `Bash(...)` deny rules being downgraded to a prompt for piped commands that mix `cd` with other segments
- Fixed false Bash permission prompts for `cut -d /`, `paste -d /`, `column -s /`, `awk '{print $1}' file`, and filenames containing `%`
- Fixed permission rules with names matching JavaScript prototype properties (e.g. `toString`) causing `settings.json` to be silently ignored
- Fixed agent team members not inheriting the leader's permission mode when using `--dangerously-skip-permissions`
- Fixed a crash in fullscreen mode when hovering over MCP tool results
- Fixed copying wrapped URLs in fullscreen mode inserting spaces at line breaks
- Fixed file-edit diffs disappearing from the UI on `--resume` when the edited file was larger than 10KB
- Fixed several `/resume` picker issues: `--resume <name>` opening uneditable, filter reload wiping search state, empty list swallowing arrow keys, cross-project staleness, and transient task-status text replacing conversation summaries
- Fixed `/export` not honoring absolute paths and `~`, and silently rewriting user-supplied extensions to `.txt`
- Fixed `/effort max` being denied for unknown or future model IDs
- Fixed slash command picker breaking when a plugin's frontmatter `name` is a YAML boolean keyword
- Fixed rate-limit upsell text being hidden after message remounts
- Fixed MCP tools with `_meta["anthropic/maxResultSizeChars"]` not bypassing the token-based persist layer
- Fixed voice mode leaking dozens of space characters into the input when re-holding the push-to-talk key while the previous transcript is still processing
- Fixed `DISABLE_AUTOUPDATER` not fully suppressing the npm registry version check and symlink modification on npm-based installs
- Fixed a memory leak where Remote Control permission handler entries were retained for the lifetime of the session
- Fixed background subagents that fail with an error not reporting partial progress to the parent agent
- Fixed prompt-type Stop/SubagentStop hooks failing on long sessions, and hook evaluator API errors showing "JSON validation failed" instead of the real message
- Fixed feedback survey rendering when dismissed
- Fixed Bash `grep -f FILE` / `rg -f FILE` not prompting when reading a pattern file outside the working directory
- Fixed stale subagent worktree cleanup removing worktrees that contain untracked files
- Fixed `sandbox.network.allowMachLookup` not taking effect on macOS
- Improved `/resume` filter hint labels and added project/worktree/branch names in the filter indicator
- Improved footer indicators (Focus, notifications) to stay on the mode-indicator row instead of wrapping at narrow terminal widths
- Improved `/agents` with a tabbed layout: a Running tab shows live subagents, and the Library tab adds Run agent and View running instance actions
- Improved `/reload-plugins` to pick up plugin-provided skills without requiring a restart
- Improved Accept Edits mode to auto-approve filesystem commands prefixed with safe env vars or process wrappers
- Improved Vim mode: `j`/`k` in NORMAL mode now navigate history and select the footer pill at the input boundary
- Improved hook errors in the transcript to include the first line of stderr for self-diagnosis without `--debug`
- Improved OTEL tracing: interaction spans now correctly wrap full turns under concurrent SDK calls, and headless turns end spans per-turn
- Improved transcript entries to carry final token usage instead of streaming placeholders
- Updated the `/claude-api` skill to cover Managed Agents alongside Claude API
- [VSCode] Fixed false-positive "requires git-bash" error on Windows when `CLAUDE_CODE_GIT_BASH_PATH` is set or Git is installed at a default location
- Fixed `CLAUDE_CODE_MAX_CONTEXT_TOKENS` to honor `DISABLE_COMPACT` when it is set
- Dropped `/compact` hints when `DISABLE_COMPACT` is set

---

## v2.1.97 — April 8, 2026

- Added focus view toggle (`Ctrl+O`) in `NO_FLICKER` mode showing prompt, one-line tool summary with edit diffstats, and final response
- Added `refreshInterval` status line setting to re-run the status line command every N seconds
- Added `workspace.git_worktree` to the status line JSON input, set when the current directory is inside a linked git worktree
- Added `● N running` indicator in `/agents` next to agent types with live subagent instances
- Added syntax highlighting for Cedar policy files (`.cedar`, `.cedarpolicy`)
- Fixed `--dangerously-skip-permissions` being silently downgraded to accept-edits mode after approving a write to a protected path
- Fixed and hardened Bash tool permissions, tightening checks around env-var prefixes and network redirects, and reducing false prompts on common commands
- Fixed permission rules with names matching JavaScript prototype properties (e.g. `toString`) causing `settings.json` to be silently ignored
- Fixed managed-settings allow rules remaining active after an admin removed them until process restart
- Fixed `permissions.additionalDirectories` changes in settings not applying mid-session
- Fixed removing a directory from `settings.permissions.additionalDirectories` revoking access to the same directory passed via `--add-dir`
- Fixed MCP HTTP/SSE connections accumulating ~50 MB/hr of unreleased buffers when servers reconnect
- Fixed MCP OAuth `oauth.authServerMetadataUrl` not being honored on token refresh after restart, fixing ADFS and similar IdPs
- Fixed 429 retries burning all attempts in ~13 seconds when the server returns a small `Retry-After` — exponential backoff now applies as a minimum
- Fixed rate-limit upgrade options disappearing after context compaction
- Fixed several `/resume` picker issues: `--resume <name>` opening uneditable, Ctrl+A reload wiping search, empty list swallowing navigation, task-status text replacing conversation summary, and cross-project staleness
- Fixed file-edit diffs disappearing on `--resume` when the edited file was larger than 10KB
- Fixed `--resume` cache misses and lost mid-turn input from attachment messages not being saved to the transcript
- Fixed messages typed while Claude is working not being persisted to the transcript
- Fixed prompt-type `Stop`/`SubagentStop` hooks failing on long sessions, and hook evaluator API errors displaying "JSON validation failed" instead of the actual message
- Fixed subagents with worktree isolation or `cwd:` override leaking their working directory back to the parent session's Bash tool
- Fixed compaction writing duplicate multi-MB subagent transcript files on prompt-too-long retries
- Fixed `claude plugin update` reporting "already at the latest version" for git-based marketplace plugins when the remote had newer commits
- Fixed slash command picker breaking when a plugin's frontmatter `name` is a YAML boolean keyword
- Fixed copying wrapped URLs in `NO_FLICKER` mode inserting spaces at line breaks
- Fixed scroll rendering artifacts in `NO_FLICKER` mode when running inside zellij
- Fixed a crash in `NO_FLICKER` mode when hovering over MCP tool results
- Fixed a `NO_FLICKER` mode memory leak where API retries left stale streaming state
- Fixed slow mouse-wheel scrolling in `NO_FLICKER` mode on Windows Terminal
- Fixed custom status line not displaying in `NO_FLICKER` mode on terminals shorter than 24 rows
- Fixed Shift+Enter and Alt/Cmd+arrow shortcuts not working in Warp with `NO_FLICKER` mode
- Fixed Korean/Japanese/Unicode text becoming garbled when copied in no-flicker mode on Windows
- Fixed Bedrock SigV4 authentication failing when `AWS_BEARER_TOKEN_BEDROCK` or `ANTHROPIC_BEDROCK_BASE_URL` are set to empty strings (as GitHub Actions does for unset inputs)
- Improved Accept Edits mode to auto-approve filesystem commands prefixed with safe env vars or process wrappers (e.g. `LANG=C rm foo`, `timeout 5 mkdir out`)
- Improved auto mode and bypass-permissions mode to auto-approve sandbox network access prompts
- Improved sandbox: `sandbox.network.allowMachLookup` now takes effect on macOS
- Improved image handling: pasted and attached images are now compressed to the same token budget as images read via the Read tool
- Improved slash command and `@`-mention completion to trigger after CJK sentence punctuation, so Japanese/Chinese input no longer requires a space before `/` or `@`
- Improved Bridge sessions to show the local git repo, branch, and working directory on the claude.ai session card
- Improved footer layout: indicators (Focus, notifications) now stay on the mode-indicator row instead of wrapping below
- Improved context-low warning to show as a transient footer notification instead of a persistent row
- Improved markdown blockquotes to show a continuous left bar across wrapped lines
- Improved session transcript size by skipping empty hook entries and capping stored pre-edit file copies
- Improved transcript accuracy: per-block entries now carry the final token usage instead of the streaming placeholder
- Improved Bash tool OTEL tracing: subprocesses now inherit a W3C `TRACEPARENT` env var when tracing is enabled
- Updated `/claude-api` skill to cover Managed Agents alongside the Claude API

---

## v2.1.96 — April 8, 2026

- Fixed Bedrock requests failing with `403 "Authorization header is missing"` when using `AWS_BEARER_TOKEN_BEDROCK` or `CLAUDE_CODE_SKIP_BEDROCK_AUTH` (regression in 2.1.94)

---

## v2.1.94 — April 7, 2026

- Added support for Amazon Bedrock powered by Mantle, set `CLAUDE_CODE_USE_MANTLE=1`
- Changed default effort level from medium to high for API-key, Bedrock/Vertex/Foundry, Team, and Enterprise users (control this with `/effort`)
- Added compact `Slacked #channel` header with a clickable channel link for Slack MCP send-message tool calls
- Added `keep-coding-instructions` frontmatter field support for plugin output styles
- Added `hookSpecificOutput.sessionTitle` to `UserPromptSubmit` hooks for setting the session title
- Plugin skills declared via `"skills": ["./"]` now use the skill's frontmatter `name` for the invocation name instead of the directory basename, giving a stable name across install methods
- Fixed agents appearing stuck after a 429 rate-limit response with a long Retry-After header — the error now surfaces immediately instead of silently waiting
- Fixed Console login on macOS silently failing with "Not logged in" when the login keychain is locked or its password is out of sync — the error is now surfaced and `claude doctor` diagnoses the fix
- Fixed plugin skill hooks defined in YAML frontmatter being silently ignored
- Fixed plugin hooks failing with "No such file or directory" when `CLAUDE_PLUGIN_ROOT` was not set
- Fixed `${CLAUDE_PLUGIN_ROOT}` resolving to the marketplace source directory instead of the installed cache for local-marketplace plugins on startup
- Fixed scrollback showing the same diff repeated and blank pages in long-running sessions
- Fixed multiline user prompts in the transcript indenting wrapped lines under the `>` caret instead of under the text
- Fixed Shift+Space inserting the literal word "space" instead of a space character in search inputs
- Fixed hyperlinks opening two browser tabs when clicked inside tmux running in an xterm.js-based terminal (VS Code, Hyper, Tabby)
- Fixed an alt-screen rendering bug where content height changes mid-scroll could leave compounding ghost lines
- Fixed `FORCE_HYPERLINK` environment variable being ignored when set via `settings.json` `env`
- Fixed native terminal cursor not tracking the selected tab in dialogs, so screen readers and magnifiers can follow tab navigation
- Fixed Bedrock invocation of Sonnet 3.5 v2 by using the `us.` inference profile ID
- Fixed SDK/print mode not preserving the partial assistant response in conversation history when interrupted mid-stream
- Improved `--resume` to resume sessions from other worktrees of the same repo directly instead of printing a `cd` command
- Fixed CJK and other multibyte text being corrupted with U+FFFD in stream-json input/output when chunk boundaries split a UTF-8 sequence
- [VSCode] Reduced cold-open subprocess work on starting a session
- [VSCode] Fixed dropdown menus selecting the wrong item when the mouse was over the list while typing or using arrow keys
- [VSCode] Added a warning banner when `settings.json` files fail to parse, so users know their permission rules are not being applied

---

## v2.1.92 — April 4, 2026

- Added `forceRemoteSettingsRefresh` policy setting: when set, the CLI blocks startup until remote managed settings are freshly fetched, and exits if the fetch fails (fail-closed)
- Added interactive Bedrock setup wizard accessible from the login screen when selecting "3rd-party platform" — guides you through AWS authentication, region configuration, credential verification, and model pinning
- Added per-model and cache-hit breakdown to `/cost` for subscription users
- `/release-notes` is now an interactive version picker
- Remote Control session names now use your hostname as the default prefix (e.g. `myhost-graceful-unicorn`), overridable with `--remote-control-session-name-prefix`
- Pro users now see a footer hint when returning to a session after the prompt cache has expired, showing roughly how many tokens the next turn will send uncached
- Fixed subagent spawning permanently failing with "Could not determine pane count" after tmux windows are killed or renumbered during a long-running session
- Fixed prompt-type Stop hooks incorrectly failing when the small fast model returns `ok:false`, and restored `preventContinuation:true` semantics for non-Stop prompt-type hooks
- Fixed tool input validation failures when streaming emits array/object fields as JSON-encoded strings
- Fixed an API 400 error that could occur when extended thinking produced a whitespace-only text block alongside real content
- Fixed accidental feedback survey submissions from auto-pilot keypresses and consecutive-prompt digit collisions
- Fixed misleading "esc to interrupt" hint appearing alongside "esc to clear" when a text selection exists in fullscreen mode during processing
- Fixed Homebrew install update prompts to use the cask's release channel (`claude-code` -> stable, `claude-code@latest` -> latest)
- Fixed `ctrl+e` jumping to the end of the next line when already at end of line in multiline prompts
- Fixed an issue where the same message could appear at two positions when scrolling up in fullscreen mode (iTerm2, Ghostty, and other terminals with DEC 2026 support)
- Fixed idle-return "/clear to save X tokens" hint showing cumulative session tokens instead of current context size
- Fixed plugin MCP servers stuck "connecting" on session start when they duplicate a claude.ai connector that is unauthenticated
- Improved Write tool diff computation speed for large files (60% faster on files with tabs/`&`/`$`)
- Removed `/tag` command
- Removed `/vim` command (toggle vim mode via `/config` -> Editor mode)
- Linux sandbox now ships the `apply-seccomp` helper in both npm and native builds, restoring unix-socket blocking for sandboxed commands

---

## v2.1.91 — April 2, 2026

- Added MCP tool result persistence override via `_meta["anthropic/maxResultSizeChars"]` annotation (up to 500K), allowing larger results like DB schemas to pass through without truncation
- Added `disableSkillShellExecution` setting to disable inline shell execution in skills, custom slash commands, and plugin commands
- Added support for multi-line prompts in `claude-cli://open?q=` deep links (encoded newlines `%0A` no longer rejected)
- Plugins can now ship executables under `bin/` and invoke them as bare commands from the Bash tool
- Fixed transcript chain breaks on `--resume` that could lose conversation history when async transcript writes fail silently
- Fixed `cmd+delete` not deleting to start of line on iTerm2, kitty, WezTerm, Ghostty, and Windows Terminal
- Fixed plan mode in remote sessions losing track of the plan file after a container restart, which caused permission prompts on plan edits and an empty plan-approval modal
- Fixed JSON schema validation for `permissions.defaultMode = "auto"` in settings.json
- Fixed Windows version cleanup not protecting the active version's rollback copy
- `/feedback` now explains why it's unavailable instead of disappearing from the slash menu
- Improved `/claude-api` skill guidance for agent design patterns including tool surface decisions, context management, and caching strategy
- Improved performance: faster `stripAnsi` on Bun by routing through `Bun.stripANSI`
- Edit tool now uses shorter `old_string` anchors, reducing output tokens

---

## v2.1.90 — April 1, 2026

- Added `/powerup` — interactive lessons teaching Claude Code features with animated demos
- Added `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE` env var to keep the existing marketplace cache when `git pull` fails, useful in offline environments
- Added `.husky` to protected directories (acceptEdits mode)
- Fixed an infinite loop where the rate-limit options dialog would repeatedly auto-open after hitting your usage limit, eventually crashing the session
- Fixed `--resume` causing a full prompt-cache miss on the first request for users with deferred tools, MCP servers, or custom agents (regression since v2.1.69)
- Fixed `Edit`/`Write` failing with "File content has changed" when a PostToolUse format-on-save hook rewrites the file between consecutive edits
- Fixed `PreToolUse` hooks that emit JSON to stdout and exit with code 2 not correctly blocking the tool call
- Fixed collapsed search/read summary badge appearing multiple times in fullscreen scrollback when a CLAUDE.md file auto-loads during a tool call
- Fixed auto mode not respecting explicit user boundaries ("don't push", "wait for X before Y") even when the action would otherwise be allowed
- Fixed click-to-expand hover text being nearly invisible on light terminal themes
- Fixed UI crash when malformed tool input reached the permission dialog
- Fixed headers disappearing when scrolling `/model`, `/config`, and other selection screens
- Hardened PowerShell tool permission checks: fixed trailing `&` background job bypass, `-ErrorAction Break` debugger hang, archive-extraction TOCTOU, and parse-fail fallback deny-rule degradation
- Improved performance: eliminated per-turn JSON.stringify of MCP tool schemas on cache-key lookup
- Improved performance: SSE transport now handles large streamed frames in linear time (was quadratic)
- Improved performance: SDK sessions with long conversations no longer slow down quadratically on transcript writes
- Improved `/resume` all-projects view to load project sessions in parallel, improving load times for users with many projects
- Changed `--resume` picker to no longer show sessions created by `claude -p` or SDK invocations
- Removed `Get-DnsClientCache` and `ipconfig /displaydns` from auto-allow (DNS cache privacy)

---

## v2.1.89 — April 1, 2026

- Added `"defer"` permission decision to `PreToolUse` hooks — headless sessions can pause at a tool call and resume with `-p --resume` to have the hook re-evaluate
- Added `CLAUDE_CODE_NO_FLICKER=1` environment variable to opt into flicker-free alt-screen rendering with virtualized scrollback
- Added `PermissionDenied` hook that fires after auto mode classifier denials — return `{retry: true}` to tell the model it can retry
- Added named subagents to `@` mention typeahead suggestions
- Added `MCP_CONNECTION_NONBLOCKING=true` for `-p` mode to skip the MCP connection wait entirely, and bounded `--mcp-config` server connections at 5s instead of blocking on the slowest server
- Auto mode: denied commands now show a notification and appear in `/permissions` -> Recent tab where you can retry with `r`
- Fixed `Edit(//path/**)` and `Read(//path/**)` allow rules to check the resolved symlink target, not just the requested path
- Fixed voice push-to-talk not activating for some modifier-combo bindings, and voice mode on Windows failing with "WebSocket upgrade rejected with HTTP 101"
- Fixed Edit/Write tools doubling CRLF on Windows and stripping Markdown hard line breaks (two trailing spaces)
- Fixed `StructuredOutput` schema cache bug causing ~50% failure rate when using multiple schemas
- Fixed memory leak where large JSON inputs were retained as LRU cache keys in long-running sessions
- Fixed a crash when removing a message from very large session files (over 50MB)
- Fixed LSP server zombie state after crash — server now restarts on next request instead of failing until session restart
- Fixed prompt history entries containing CJK or emoji being silently dropped when they fall on a 4KB boundary in `~/.claude/history.jsonl`
- Fixed `/stats` undercounting tokens by excluding subagent usage, and losing historical data beyond 30 days when the stats cache format changes
- Fixed `-p --resume` hangs when the deferred tool input exceeds 64KB or no deferred marker exists, and `-p --continue` not resuming deferred tools
- Fixed `claude-cli://` deep links not opening on macOS
- Fixed MCP tool errors truncating to only the first content block when the server returns multi-element error content
- Fixed skill reminders and other system context being dropped when sending messages with images via the SDK
- Fixed PreToolUse/PostToolUse hooks to receive `file_path` as an absolute path for Write/Edit/Read tools, matching the documented behavior
- Fixed autocompact thrash loop — now detects when context refills to the limit immediately after compacting three times in a row and stops with an actionable error instead of burning API calls
- Fixed prompt cache misses in long sessions caused by tool schema bytes changing mid-session
- Fixed nested CLAUDE.md files being re-injected dozens of times in long sessions that read many files
- Fixed `--resume` crash when transcript contains a tool result from an older CLI version or interrupted write
- Fixed misleading "Rate limit reached" message when the API returned an entitlement error — now shows the actual error with actionable hints
- Fixed hooks `if` condition filtering not matching compound commands (`ls && git push`) or commands with env-var prefixes (`FOO=bar git push`)
- Fixed collapsed search/read group badges duplicating in terminal scrollback during heavy parallel tool use
- Fixed notification `invalidates` not clearing the currently-displayed notification immediately
- Fixed prompt briefly disappearing after submit when background messages arrived during processing
- Fixed Devanagari and other combining-mark text being truncated in assistant output
- Fixed rendering artifacts on main-screen terminals after layout shifts
- Fixed voice mode failing to request microphone permission on macOS Apple Silicon
- Fixed Shift+Enter submitting instead of inserting a newline on Windows Terminal Preview 1.25
- Fixed periodic UI jitter during streaming in iTerm2 when running inside tmux
- Fixed PowerShell tool incorrectly reporting failures when commands like `git push` wrote progress to stderr on Windows PowerShell 5.1
- Fixed a potential out-of-memory crash when the Edit tool was used on very large files (>1 GiB)
- Improved collapsed tool summary to show "Listed N directories" for `ls`/`tree`/`du` instead of "Read N files"
- Improved Bash tool to warn when a formatter/linter command modifies files you have previously read, preventing stale-edit errors
- Improved `@`-mention typeahead to rank source files above MCP resources with similar names
- Improved PowerShell tool prompt with version-appropriate syntax guidance (5.1 vs 7+)
- Changed `Edit` to work on files viewed via `Bash` with `sed -n` or `cat`, without requiring a separate `Read` call first
- Changed hook output over 50K characters to be saved to disk with a file path + preview instead of being injected directly into context
- Changed `cleanupPeriodDays: 0` in settings.json to be rejected with a validation error — it previously silently disabled transcript persistence
- Changed thinking summaries to no longer be generated by default in interactive sessions — set `showThinkingSummaries: true` in settings.json to restore
- Documented `TaskCreated` hook event and its blocking behavior
- Preserved task notifications when backgrounding a running command with Ctrl+B
- PowerShell tool on Windows: external-command arguments containing both a double-quote and whitespace now prompt instead of auto-allowing (PS 5.1 argument-splitting hardening)
- `/env` now applies to PowerShell tool commands (previously only affected Bash)
- `/usage` now hides redundant "Current week (Sonnet only)" bar for Pro and Enterprise plans
- Image paste no longer inserts a trailing space
- Pasting `!command` into an empty prompt now enters bash mode, matching typed `!` behavior
- `/buddy` is here for April 1st — hatch a small creature that watches you code

---

## v2.1.87 — March 29, 2026

- Fixed messages in Cowork Dispatch not getting delivered
