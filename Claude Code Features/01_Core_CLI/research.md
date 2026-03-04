# Core CLI

## Overview

Claude Code is an agentic coding tool that reads your codebase, edits files, runs commands, and integrates with your development tools. It operates as a terminal-native AI agent available in your terminal, IDE (VS Code, JetBrains), desktop app, and browser. It understands your entire codebase and can work across multiple files and tools to build features, fix bugs, and automate development tasks.

## Key Capabilities

- **Build features and fix bugs**: Describe what you want in plain language; Claude plans the approach, writes code across multiple files, and verifies it works.
- **Automate tedious tasks**: Write tests for untested code, fix lint errors, resolve merge conflicts, update dependencies, write release notes.
- **Create commits and pull requests**: Works directly with git to stage changes, write commit messages, create branches, and open PRs.
- **Connect external tools via MCP**: Model Context Protocol lets Claude read design docs, update tickets, pull data from Slack, etc.
- **Customize with CLAUDE.md, skills, and hooks**: Persistent project instructions, custom slash commands, lifecycle hooks for automation.
- **Run agent teams and subagents**: Spawn multiple agents working on different parts of a task simultaneously.
- **Pipe, script, and automate**: Composable and follows Unix philosophy. Pipe logs into it, run in CI, chain with other tools.
- **Work from anywhere**: Sessions are not tied to a single surface. Move between terminal, desktop, web, and mobile via Remote Control and Teleport.

## Configuration / Setup

### Installation Methods

**Native Install (Recommended)**:
```bash
# macOS, Linux, WSL
curl -fsSL https://claude.ai/install.sh | bash

# Windows PowerShell
irm https://claude.ai/install.ps1 | iex

# Windows CMD
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```
Native installations auto-update in the background.

**Homebrew** (does not auto-update):
```bash
brew install --cask claude-code
```

**WinGet** (does not auto-update):
```powershell
winget install Anthropic.ClaudeCode
```

### Starting Claude Code
```bash
cd your-project
claude
```
You will be prompted to log in on first use. Requires a Claude subscription or Anthropic Console account.

### Other Surfaces
- **VS Code / Cursor**: Install the "Claude Code" extension from the Extensions view.
- **JetBrains**: Install the Claude Code plugin from JetBrains Marketplace.
- **Desktop App**: Download from claude.ai for macOS (universal) or Windows (x64 / ARM64).
- **Web**: Start coding at claude.ai/code with no local setup required.

## Usage Examples

### Interactive session
```bash
claude                        # Start interactive session
claude "explain this project" # Start with initial prompt
```

### Non-interactive (print mode)
```bash
claude -p "explain this function"           # Query via SDK, then exit
cat logs.txt | claude -p "explain"          # Process piped content
```

### Session management
```bash
claude -c                                    # Continue most recent conversation
claude -c -p "Check for type errors"        # Continue in print mode
claude -r "auth-refactor" "Finish this PR"  # Resume session by name or ID
```

### Scripting and automation
```bash
# Monitor logs and get alerted
tail -f app.log | claude -p "Slack me if you see any anomalies"

# Automate translations in CI
claude -p "translate new strings into French and raise a PR for review"

# Bulk operations across files
git diff main --name-only | claude -p "review these changed files for security issues"
```

### Other commands
```bash
claude update                                    # Update to latest version
claude auth login --email user@example.com --sso # Sign in with SSO
claude auth status                               # Check auth status (JSON)
claude agents                                    # List configured subagents
claude mcp                                       # Configure MCP servers
claude remote-control                            # Start Remote Control session
```

## CLI Flags Reference

### Session and output
| Flag | Description |
|------|-------------|
| `--print`, `-p` | Print response without interactive mode |
| `--continue`, `-c` | Load the most recent conversation in the current directory |
| `--resume`, `-r` | Resume a specific session by ID or name |
| `--session-id` | Use a specific session UUID |
| `--fork-session` | When resuming, create a new session ID instead of reusing the original |
| `--from-pr` | Resume sessions linked to a specific GitHub PR |
| `--output-format` | Output format for print mode: `text`, `json`, `stream-json` |
| `--input-format` | Input format for print mode: `text`, `stream-json` |
| `--json-schema` | Get validated JSON output matching a JSON Schema (print mode) |
| `--verbose` | Enable verbose logging with full turn-by-turn output |
| `--version`, `-v` | Output the version number |
| `--no-session-persistence` | Disable session persistence (print mode only) |

### Model and behavior
| Flag | Description |
|------|-------------|
| `--model` | Set model: alias (`sonnet`, `opus`) or full name (`claude-sonnet-4-6`) |
| `--fallback-model` | Automatic fallback model when default is overloaded (print mode) |
| `--max-turns` | Limit agentic turns (print mode). Exits with error at limit |
| `--max-budget-usd` | Maximum dollar amount for API calls before stopping (print mode) |
| `--agent` | Specify an agent for the current session |
| `--agents` | Define custom subagents dynamically via JSON |
| `--permission-mode` | Begin in a specified permission mode (e.g., `plan`) |

### System prompt customization
| Flag | Description |
|------|-------------|
| `--system-prompt` | Replace the entire system prompt (interactive + print) |
| `--system-prompt-file` | Replace from file (print only) |
| `--append-system-prompt` | Append to default prompt (interactive + print) |
| `--append-system-prompt-file` | Append from file (print only) |

### Tools and permissions
| Flag | Description |
|------|-------------|
| `--allowedTools` | Tools that execute without prompting for permission |
| `--disallowedTools` | Tools removed from the model's context entirely |
| `--tools` | Restrict which built-in tools Claude can use |
| `--dangerously-skip-permissions` | Skip all permission prompts (use with caution) |
| `--allow-dangerously-skip-permissions` | Enable permission bypassing as an option |

### Working directories and environment
| Flag | Description |
|------|-------------|
| `--add-dir` | Add additional working directories |
| `--worktree`, `-w` | Start in an isolated git worktree |
| `--mcp-config` | Load MCP servers from JSON files or strings |
| `--strict-mcp-config` | Only use MCP servers from `--mcp-config` |
| `--chrome` / `--no-chrome` | Enable/disable Chrome browser integration |
| `--ide` | Automatically connect to IDE on startup |
| `--settings` | Path to a settings JSON file or JSON string |
| `--setting-sources` | Comma-separated list of setting sources to load |

### Advanced
| Flag | Description |
|------|-------------|
| `--debug` | Enable debug mode with optional category filtering |
| `--disable-slash-commands` | Disable all skills and commands for this session |
| `--init` | Run initialization hooks and start interactive mode |
| `--init-only` | Run initialization hooks and exit |
| `--maintenance` | Run maintenance hooks and exit |
| `--remote` | Create a new web session on claude.ai |
| `--teleport` | Resume a web session in your local terminal |
| `--teammate-mode` | Set agent team teammate display: `auto`, `in-process`, `tmux` |
| `--plugin-dir` | Load plugins from directories (repeatable) |
| `--betas` | Beta headers to include in API requests (API key users only) |
| `--include-partial-messages` | Include partial streaming events (requires `--print` and `stream-json`) |

## Important Details

- **Supported platforms**: macOS, Linux, WSL, and native Windows (Windows requires Git for Windows).
- **Authentication**: Requires a Claude subscription (claude.com/pricing) or Anthropic Console account. Terminal CLI and VS Code also support third-party providers.
- **Auto-update**: Native installations auto-update in the background. Homebrew and WinGet require manual updates (`brew upgrade claude-code` / `winget upgrade Anthropic.ClaudeCode`).
- **Unix philosophy**: Claude Code is composable. You can pipe content to it, use it in CI pipelines, and chain it with other CLI tools.
- **Cross-surface consistency**: CLAUDE.md files, settings, and MCP servers work across all surfaces (terminal, IDE, desktop, web).
- **Session portability**: You can move work between environments using Remote Control, Teleport (`/teleport`), and the `/desktop` command.
- The `--system-prompt` and `--system-prompt-file` flags are mutually exclusive. The append flags can be combined with either replacement flag.
- The `--output-format json` flag is particularly useful for scripting and automation.

## References

- [Claude Code Overview](https://docs.anthropic.com/en/docs/claude-code/overview) -- What Claude Code is, installation, and capabilities overview
- [CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-reference) -- Complete reference for all CLI commands and flags
- [Quickstart](https://code.claude.com/docs/en/quickstart) -- Walk through your first real task
- [Common Workflows](https://code.claude.com/docs/en/common-workflows) -- Patterns for getting the most out of Claude Code
- [Settings](https://code.claude.com/docs/en/settings) -- Configuration options
