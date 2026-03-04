# Interactive Features

## Overview

Claude Code's interactive mode provides a rich set of terminal-based features for everyday development work. This includes auto-generated prompt suggestions, direct bash execution, an external editor integration, a diff viewer, task lists, context visualization, usage statistics, session management commands, file references, image/PDF support, and many more. These features make the CLI experience more productive and intuitive beyond the core AI coding capabilities.

## Key Capabilities

### Prompt Suggestions
- Auto-generated suggestions appear as grayed-out text in the prompt input.
- On first open, suggestions are drawn from your project's git history to reflect files you have been working on recently.
- After Claude responds, suggestions continue to appear based on conversation history (follow-up steps, natural workflow continuations).
- Press **Tab** to accept the suggestion, or press **Enter** to accept and submit immediately.
- Start typing to dismiss the suggestion.
- Suggestions reuse the parent conversation's prompt cache, so additional cost is minimal.
- Automatically skipped after the first turn, in non-interactive mode, and in plan mode.
- Disable with: `export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` or toggle in `/config`.

### Bash Mode (! prefix)
- Prefix any input with `!` to run bash commands directly without Claude interpreting or approving the command.
- Command output is added to the conversation context, so Claude can reference it.
- Shows real-time progress and output.
- Supports `Ctrl+B` backgrounding for long-running commands.
- Supports history-based autocomplete: type a partial command and press **Tab** to complete from previous `!` commands in the current project.

### External Editor (Ctrl+G)
- Press `Ctrl+G` to open the current prompt text in your default text editor (`$EDITOR`).
- Useful for composing complex, multi-line prompts or editing custom responses outside the terminal.

### Diff Viewer (/diff)
- Run `/diff` to open an interactive diff viewer showing uncommitted changes and per-turn diffs.
- Use left/right arrows to switch between the current git diff and individual Claude turns.
- Use up/down arrows to browse files.
- Provides a visual way to review what Claude has changed without leaving the session.

### Task List (Ctrl+T)
- Claude creates task lists to track progress on complex, multi-step work.
- Tasks appear in the terminal status area with indicators for pending, in progress, or complete.
- Press `Ctrl+T` to toggle the task list view (shows up to 10 tasks at a time).
- Ask Claude "show me all tasks" or "clear all tasks" for full management.
- Tasks persist across context compactions.
- Share task lists across sessions with `CLAUDE_CODE_TASK_LIST_ID=my-project claude`.
- Revert to previous TODO list with `CLAUDE_CODE_ENABLE_TASKS=false`.

### Context Visualization (/context)
- Run `/context` to visualize current context usage as a colored grid.
- Helps you understand how much of the context window is being used.

### /insights Command
- Run `/insights` to generate a report analyzing your Claude Code sessions.
- Includes project areas, interaction patterns, and friction points.

### /stats and /cost Commands
- `/stats`: Visualize daily usage, session history, streaks, and model preferences.
- `/cost`: Show token usage statistics with subscription-specific details.
- `/usage`: Show plan usage limits and rate limit status.

### Session Naming (/rename)
- `/rename [name]`: Rename the current session. Without a name, auto-generates one from conversation history.

### Session Forking (/fork)
- `/fork [name]`: Create a fork of the current conversation at the current point.
- Useful for exploring alternative approaches without losing your current work.

### @ File References
- Type `@` followed by a filename to trigger file path autocomplete.
- Adds the referenced file to the conversation context so Claude can read and reference it.

### Image and PDF Support
- Paste images from clipboard with `Ctrl+V` (or `Cmd+V` in iTerm2, `Alt+V` on Windows).
- Supports pasting image files or paths to image files.
- In the Desktop app, attach images, PDFs, and other files via drag-and-drop or the attachment button.

### Background Bash Commands
- Press `Ctrl+B` to move a running bash command to the background (tmux users press twice).
- Or prompt Claude to run a command in the background.
- Output is buffered and retrievable via the TaskOutput tool.
- Background tasks have unique IDs for tracking.
- Disable with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.

### PR Review Status
- When working on a branch with an open PR, a clickable PR link appears in the footer (e.g., "PR #446").
- Colored underline indicates review state: green (approved), yellow (pending), red (changes requested), gray (draft), purple (merged).
- Cmd+click (Mac) or Ctrl+click (Windows/Linux) to open the PR in your browser.
- Auto-updates every 60 seconds. Requires the `gh` CLI.

### Other Notable Commands
- `/clear` (aliases: `/reset`, `/new`): Clear conversation history and free context.
- `/compact [instructions]`: Compact conversation with optional focus instructions.
- `/copy`: Copy last assistant response to clipboard, with interactive picker for code blocks.
- `/export [filename]`: Export conversation as plain text.
- `/fast [on|off]`: Toggle fast mode.
- `/model [model]`: Switch AI model immediately, with effort level adjustment via arrow keys.
- `/plan`: Enter plan mode directly from the prompt.
- `/pr-comments [PR]`: Fetch and display comments from a GitHub pull request.
- `/review`: Review a pull request for code quality, correctness, security, and test coverage.
- `/rewind` (alias: `/checkpoint`): Rewind conversation and/or code to a previous point.
- `/sandbox`: Toggle sandbox mode.
- `/security-review`: Analyze pending changes for security vulnerabilities.
- `/vim`: Toggle between Vim and Normal editing modes.
- `/desktop` (alias: `/app`): Continue the current session in the Desktop app (macOS/Windows).
- `/release-notes`: View the full changelog.
- `/doctor`: Diagnose and verify your installation and settings.

## Configuration / Setup

Most interactive features work out of the box. Configuration options include:

- **Disable prompt suggestions**: `export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` or toggle in `/config`.
- **Disable background tasks**: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
- **Share task lists**: `CLAUDE_CODE_TASK_LIST_ID=my-project claude`.
- **Terminal keybindings**: Run `/terminal-setup` for Shift+Enter and other shortcuts in VS Code, Alacritty, Zed, or Warp terminals.
- **Vim mode**: Toggle with `/vim` or configure permanently via `/config`.
- **Option as Meta (macOS)**: Configure in terminal settings for Alt-key shortcuts (Alt+B, Alt+F, Alt+Y, Alt+M, Alt+P).

## Usage Examples

**Use prompt suggestions**:
```
# Open a session and see a grayed-out suggestion
# Press Tab to accept, Enter to accept and submit, or just start typing to dismiss
```

**Direct bash execution**:
```
! npm test
! git status
! ls -la
```

**Open diff viewer**:
```
/diff
# Use arrow keys: left/right for diff type, up/down for files
```

**Fork a conversation**:
```
/fork exploring-alternative-approach
```

**Reference a file**:
```
@src/auth/login.ts can you explain how the authentication flow works?
```

**Background a long command**:
Press `Ctrl+B` while a command is running, or:
```
Can you run npm test in the background?
```

**Rewind to a checkpoint**:
Press `Esc` twice, or:
```
/rewind
```

## Important Details

- **Multiline input methods**: `\` + Enter (all terminals), Option+Enter (macOS default), Shift+Enter (iTerm2, WezTerm, Ghostty, Kitty natively; others need `/terminal-setup`), Ctrl+J (line feed), or paste directly for code blocks.
- **Command history**: Input history is stored per working directory. History resets with `/clear` but previous sessions can be resumed. History expansion (`!`) is disabled by default.
- **Reverse search**: Press `Ctrl+R` for interactive reverse history search. Ctrl+R again cycles matches, Tab/Esc accepts, Enter executes, Ctrl+C cancels.
- **MCP prompts as commands**: MCP servers can expose prompts as slash commands with the format `/mcp__<server>__<prompt>`.
- **Esc+Esc**: Double-press Escape to rewind or summarize — restores code and/or conversation to a previous point.
- **Shift+Tab or Alt+M**: Toggle between permission modes (Auto-Accept, Plan, Normal).
- **Alt+P**: Switch models without clearing your prompt.
- **Alt+T**: Toggle extended thinking (run `/terminal-setup` first).

## References

- [Interactive Mode](https://code.claude.com/docs/en/interactive-mode) — Official documentation for all interactive features, keyboard shortcuts, and built-in commands
- [Skills](https://code.claude.com/docs/en/skills) — Custom prompts and workflows that extend interactive commands
- [Checkpointing](https://code.claude.com/docs/en/checkpointing) — Rewind and restore previous states
- [CLI Reference](https://code.claude.com/docs/en/cli-reference) — Full command-line flags and options
