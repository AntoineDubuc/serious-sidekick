# IDE Extensions

## Overview

Claude Code integrates with both VS Code and JetBrains IDEs through dedicated extensions/plugins. These integrations provide a native graphical interface for Claude Code directly within the IDE, enabling features like inline diff viewing, selection context sharing, diagnostics integration, and keyboard shortcuts. The VS Code extension is the most feature-rich and is the recommended way to use Claude Code in VS Code.

## Key Capabilities

### VS Code Extension
- **Graphical chat panel** integrated directly into the editor, positionable in sidebar, panel, or editor area
- **Inline diff viewing**: side-by-side comparison of original and proposed changes with accept/reject workflow
- **@-mention file references**: type `@` followed by a file or folder name with fuzzy matching support
- **Selection context**: Claude automatically sees highlighted text in the editor; line count shown in prompt box footer
- **Plan review mode**: review and edit Claude's plans before accepting them
- **Auto-accept edits mode**: Claude makes edits without asking for permission
- **Multiple conversation tabs**: run parallel conversations in separate tabs or windows
- **Conversation history**: search and resume past conversations by keyword or time
- **Resume remote sessions**: resume Claude Code web sessions from claude.ai directly in VS Code (Remote tab)
- **Permission modes**: switch between default, plan, auto-accept, and bypass permissions from the prompt box
- **Context indicator**: shows how much of Claude's context window is being used
- **Extended thinking toggle**: enable deeper reasoning for complex problems via the command menu
- **Multi-line input**: `Shift+Enter` to add new lines without sending
- **Checkpoints**: track file edits and rewind to a previous state (fork, rewind code, or both)
- **Plugin management**: install and manage plugins via `/plugins` command with graphical interface
- **Chrome browser integration**: connect to Chrome for browser automation via `@browser`
- **Git integration**: commit, create PRs, and work across branches; support for git worktrees

### JetBrains Plugin
- **Supported IDEs**: IntelliJ IDEA, PyCharm, Android Studio, WebStorm, PhpStorm, GoLand
- **Diff viewing**: code changes displayed directly in the IDE diff viewer
- **Selection context**: current selection/tab automatically shared with Claude Code
- **File reference shortcuts**: insert file references with line ranges
- **Diagnostic sharing**: lint, syntax, and other diagnostic errors automatically shared with Claude

## Configuration / Setup

### VS Code Extension Installation

**Prerequisites:**
- VS Code 1.98.0 or higher
- An Anthropic account (or third-party provider credentials)

**Installation methods:**
1. Direct links: use `vscode:extension/anthropic.claude-code` or `cursor:extension/anthropic.claude-code`
2. Extensions view: press `Cmd+Shift+X` (Mac) / `Ctrl+Shift+X` (Windows/Linux), search "Claude Code", click Install
3. VS Code Marketplace: install from marketplace.visualstudio.com

**Opening the panel:**
- Click the Spark icon in the Editor Toolbar (top-right corner, requires a file to be open)
- Command Palette: `Cmd+Shift+P` / `Ctrl+Shift+P`, type "Claude Code"
- Status Bar: click "Claude Code" in the bottom-right corner

### VS Code Extension Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `selectedModel` | `default` | Model for new conversations |
| `useTerminal` | `false` | Launch in terminal mode instead of graphical panel |
| `initialPermissionMode` | `default` | Controls approval prompts: `default`, `plan`, `acceptEdits`, or `bypassPermissions` |
| `preferredLocation` | `panel` | Where Claude opens: `sidebar` or `panel` |
| `autosave` | `true` | Auto-save files before Claude reads or writes them |
| `useCtrlEnterToSend` | `false` | Use Ctrl/Cmd+Enter instead of Enter to send |
| `enableNewConversationShortcut` | `true` | Enable Cmd/Ctrl+N for new conversations |
| `respectGitIgnore` | `true` | Exclude .gitignore patterns from file searches |
| `disableLoginPrompt` | `false` | Skip auth prompts (for third-party providers) |
| `allowDangerouslySkipPermissions` | `false` | Bypass all permission prompts (use with extreme caution) |

### JetBrains Plugin Installation

1. Install the [Claude Code plugin](https://plugins.jetbrains.com/plugin/27310-claude-code-beta-) from the JetBrains Marketplace
2. Restart the IDE completely
3. Run `claude` from the IDE's integrated terminal to activate integration features
4. For external terminals, use the `/ide` command inside Claude Code to connect

**Plugin Settings** (Settings -> Tools -> Claude Code [Beta]):
- **Claude command**: specify a custom command path (e.g., `claude`, `/usr/local/bin/claude`, or `npx @anthropic/claude`)
- **Enable Option+Enter for multi-line prompts** (macOS only)
- **Enable automatic updates**: auto-check and install plugin updates

**Special configurations:**
- **Remote Development**: plugin must be installed on the remote host via Settings -> Plugin (Host)
- **WSL**: may need additional configuration; set `wsl -d Ubuntu -- bash -lic "claude"` as the Claude command

## Usage Examples

### VS Code Keyboard Shortcuts

| Command | Shortcut | Description |
|---------|----------|-------------|
| Focus Input | `Cmd+Esc` / `Ctrl+Esc` | Toggle focus between editor and Claude |
| Open in New Tab | `Cmd+Shift+Esc` / `Ctrl+Shift+Esc` | Open new conversation as editor tab |
| New Conversation | `Cmd+N` / `Ctrl+N` | Start a new conversation (Claude focused) |
| Insert @-Mention | `Option+K` / `Alt+K` | Insert reference to current file and selection (editor focused) |

### JetBrains Keyboard Shortcuts

| Command | Shortcut | Description |
|---------|----------|-------------|
| Open Claude Code | `Cmd+Esc` / `Ctrl+Esc` | Open Claude Code from the editor |
| Insert File Reference | `Cmd+Option+K` / `Alt+Ctrl+K` | Insert file reference with line range (e.g., @File#L1-99) |

### Using @-mentions for File Context

```text
> Explain the logic in @auth (fuzzy matches auth.js, AuthService.ts, etc.)
> What's in @src/components/ (include a trailing slash for folders)
```

### Referencing Terminal Output

```text
> @terminal:name  (where "name" is the terminal's title)
```

### Connecting to MCP Servers (from VS Code terminal)

```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp/
```

### Browser Automation

```text
@browser go to localhost:3000 and check the console for errors
```

## Important Details

- **VS Code extension includes the CLI**: the extension bundles the command-line interface, accessible from the integrated terminal
- **Shared conversation history**: the extension and CLI share conversation history; continue an extension conversation in CLI with `claude --resume`
- **Settings are shared**: Claude Code settings in `~/.claude/settings.json` are shared between the extension and CLI
- **Schema validation**: add `"$schema": "https://json.schemastore.org/claude-code-settings.json"` to settings.json for autocomplete and validation
- **MCP config via CLI only**: MCP servers must be configured via CLI, but once configured they work in both extension and CLI
- **Tab status indicators**: colored dots on spark icons indicate status (blue = permission pending, orange = finished while hidden)
- **Terminal mode**: check "Use Terminal" in VS Code settings to use CLI-style interface instead of graphical panel
- **JetBrains security note**: with auto-edit permissions, Claude may modify IDE config files that can be auto-executed; use manual approval for edits in untrusted environments
- **JetBrains ESC key**: if ESC doesn't interrupt Claude in JetBrains terminals, go to Settings -> Tools -> Terminal and uncheck "Move focus to the editor with Escape"
- **Features only in CLI** (not in VS Code extension): full command set, MCP server configuration, `!` bash shortcut, tab completion

## References

- [Use Claude Code in VS Code](https://code.claude.com/docs/en/ide-integrations) -- Full VS Code extension documentation including setup, features, and configuration
- [JetBrains IDEs](https://code.claude.com/docs/en/jetbrains) -- JetBrains plugin documentation for IntelliJ, PyCharm, WebStorm, and others
- [VS Code Marketplace - Claude Code](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code) -- Direct install link for the VS Code extension
- [JetBrains Marketplace - Claude Code](https://plugins.jetbrains.com/plugin/27310-claude-code-beta-) -- Direct install link for the JetBrains plugin
