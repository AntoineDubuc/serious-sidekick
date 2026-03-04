# Desktop App

## Overview

Claude Code Desktop is the Code tab within the Claude Desktop application, providing a graphical interface for Claude Code instead of the terminal. It runs the same underlying engine as the CLI but adds visual capabilities like diff review, app preview, parallel sessions with Git worktree isolation, PR monitoring, and connectors for external services. The desktop app is available on macOS and Windows, with Linux users limited to the CLI or community alternatives.

## Key Capabilities

- **Visual diff review with inline comments**: After Claude makes changes, a diff stats indicator (e.g., `+12 -1`) appears. Click to open a file-by-file diff viewer. Click any line to add a comment, then submit all comments at once (Cmd+Enter on macOS, Ctrl+Enter on Windows). Claude reads comments and revises accordingly.
- **Live app preview**: Claude can start a dev server and open an embedded browser to verify changes. Supports frontend web apps and backend servers. Auto-verify is enabled by default — Claude takes screenshots, inspects the DOM, clicks elements, fills forms, and fixes issues it finds.
- **GitHub PR monitoring with auto-fix and auto-merge**: After opening a PR, a CI status bar appears. Enable auto-fix to have Claude automatically attempt to fix failing CI checks. Enable auto-merge to squash-merge once all checks pass.
- **Parallel sessions with Git worktree isolation**: Click "+ New session" in the sidebar. Each session in a Git repository gets its own isolated copy via Git worktrees stored in `<project-root>/.claude/worktrees/` by default.
- **Connectors for external tools**: Integrations with GitHub, Slack, Linear, Google Calendar, Notion, and more via the "+" button next to the prompt box.
- **Multiple environments**: Local (your machine), Remote (Anthropic cloud), or SSH (your own remote machines).
- **Cloud/remote sessions**: Select "Remote" to run on Anthropic's cloud infrastructure. Sessions continue even when you close the app. Monitor from claude.ai/code or the Claude iOS app. Remote sessions also support multiple repositories.
- **SSH sessions**: Connect to remote machines, cloud VMs, or dev containers over SSH.
- **Permission modes**: Ask permissions (default, manual approval), Auto accept edits (auto-approves file edits), Plan mode (analysis only), Bypass permissions (no prompts, requires explicit enable in Settings).
- **Session management**: Filter by status (Active, Archived) and environment (Local, Cloud). Rename sessions, check context usage, and use `/compact` to free context space.
- **Continue in another surface**: Move sessions to Claude Code on the Web or open in your IDE via the "Continue in" menu.
- **Plugins**: Install, enable, disable, or uninstall plugins from a built-in plugin manager UI.
- **Skills**: Type `/` in the prompt box to browse built-in commands, custom skills, project skills, and plugin skills.
- **Code review**: Click "Review code" in the diff view toolbar for Claude to evaluate changes, focusing on compile errors, logic errors, security vulnerabilities, and bugs.

## Configuration / Setup

### Installation
- **macOS**: Download from [claude.com/download](https://claude.com/download). Distribute via MDM (Jamf, Kandji) using the `.dmg` installer.
- **Windows**: Download from [claude.com/download](https://claude.com/download). Deploy via MSIX package or `.exe` installer. ARM64 is supported.
- **Linux**: Not available. Use the CLI instead.
- Requires an active paid subscription: Pro, Max, Teams, or Enterprise.

### Before First Session
Configure four things in the prompt area:
1. **Environment**: Local, Remote, or SSH connection
2. **Project folder**: The folder or repository Claude works in
3. **Model**: Pick from the dropdown (locked once session starts)
4. **Permission mode**: Choose autonomy level

### Preview Server Configuration
Claude auto-detects dev server setup and stores config in `.claude/launch.json`. Example:
```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "my-app",
      "runtimeExecutable": "npm",
      "runtimeArgs": ["run", "dev"],
      "port": 3000
    }
  ]
}
```
Supports multiple configurations, custom ports, `autoPort` conflict handling, environment variables, and `autoVerify` toggle.

### SSH Configuration
Add via the environment dropdown: provide a name, SSH host (`user@hostname`), optional SSH port, and optional identity file path. Claude Code must be installed on the remote machine.

### Environment Variables
Local sessions inherit variables from your shell profile (`~/.zshrc` or `~/.bashrc`). Set `MAX_THINKING_TOKENS=0` to disable extended thinking.

## Usage Examples

**Starting a session**: Select your environment and project folder, choose a model, pick a permission mode, type your task, and press Enter.

**Visual diff review**: After Claude edits files, click the diff stats indicator to review changes file by file. Add inline comments on specific lines, then submit all comments at once.

**Parallel work**: Open multiple sessions via "+ New session." Each gets its own Git worktree for isolation.

**Remote long-running tasks**: Select "Remote" environment, add one or more repositories, submit a task, and close the app. Check back later from any device.

**Moving from CLI to Desktop**: Run `/desktop` in the terminal to save your CLI session and open it in the desktop app.

**Attaching context**: Use `@` mentions for files with autocomplete, or attach images, PDFs, and other files via the attachment button or drag-and-drop.

## Important Details

- **Shared configuration**: Desktop and CLI share CLAUDE.md files, MCP servers, hooks, skills, settings, and model configurations.
- **MCP server note**: MCP servers configured for the Claude Desktop chat app in `claude_desktop_config.json` are separate from Claude Code. Use `~/.claude.json` or `.mcp.json` for Claude Code MCP servers.
- **Not available in Desktop**: Third-party providers (Bedrock, Vertex, Foundry), Linux support, inline code suggestions, agent teams, scripting/automation (`--print`), `dontAsk` permission mode, `--verbose` flag.
- **Cowork tab**: Requires Apple Silicon (M1 or later) on macOS. Available on all supported Windows hardware.
- **Enterprise features**: Admin console controls for enabling/disabling the Code tab, disabling Bypass permissions mode, disabling remote sessions. MDM policies via `com.anthropic.Claude` on macOS or `SOFTWARE\Policies\Claude` registry on Windows.
- **Worktree location**: Configurable in Settings under "Worktree location." Optional branch prefix for organizing Claude-created branches.
- **Git requirement**: Git is required for local sessions on Windows. Git LFS must be installed if the repository uses it.

## References

- [Use Claude Code Desktop](https://code.claude.com/docs/en/desktop) — Official documentation for the Desktop app
- [Desktop Quickstart](https://code.claude.com/docs/en/desktop-quickstart) — Getting started guide
- [Claude Code for Desktop (ClaudeLog)](https://claudelog.com/faqs/claude-code-desktop-app/) — Community FAQ
- [Download Claude](https://claude.com/download) — Official download page
