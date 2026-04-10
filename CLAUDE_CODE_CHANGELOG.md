# Claude Code Changelog (v2.1.87 — v2.1.98)

> Covers 9 releases over 12 days (March 29 — April 9, 2026).
> Versions v2.1.88, v2.1.93, and v2.1.95 were internal/skipped builds.

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
