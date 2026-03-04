# Settings and Configuration

## Overview

Claude Code uses a layered configuration system with settings files (JSON), environment variables, and command-line arguments. Settings can be scoped from organization-wide managed policies down to personal local overrides, with a clear precedence hierarchy. The configuration system controls permissions, model selection, environment variables, tool behavior, hooks, MCP servers, plugins, sandboxing, and display preferences.

## Key Capabilities

- **Multi-scope settings files**: Managed, user, project, and local settings layers with defined precedence.
- **Permissions system**: Fine-grained allow/ask/deny rules for tools like Bash, Read, Edit, WebFetch, and MCP.
- **Environment variable configuration**: Extensive set of environment variables for authentication, model configuration, feature toggles, and behavior customization.
- **Sandbox configuration**: OS-level filesystem and network isolation settings for Bash commands.
- **MCP server management**: Configure, enable, and restrict Model Context Protocol servers.
- **Plugin management**: Enable plugins from marketplaces with configurable sources.
- **Attribution settings**: Customize commit and PR attribution messages.
- **Display and UI settings**: Control output style, spinner behavior, language, status line, and more.
- **Auto-backups**: Configuration files are automatically backed up (5 most recent kept).

## Configuration / Setup

### Settings File Locations

| Scope | Location | Applies To | Shared |
|-------|----------|-----------|--------|
| **Managed** | Server, plist/registry, `/managed-settings.json` | All machine users | Yes (IT-deployed) |
| **User** | `~/.claude/settings.json` | You across all projects | No |
| **Project** | `.claude/settings.json` (in repo) | All collaborators | Yes (git-committed) |
| **Local** | `.claude/settings.local.json` | You in this repo only | No (gitignored) |

Additional file locations:
```
~/.claude/settings.json                    # User settings
~/.claude/settings.local.json              # User local overrides
~/.claude/CLAUDE.md                        # User memory file
~/.claude/agents/                          # User subagents
~/.claude.json                             # Preferences, OAuth, MCP servers, caches
~/.claude/plans                            # Plan files (default location)

.claude/settings.json                      # Project settings
.claude/settings.local.json                # Project local overrides
.claude/CLAUDE.md                          # Project memory file
.claude/CLAUDE.local.md                    # Project local memory
.claude/agents/                            # Project subagents
.mcp.json                                  # Project MCP servers
```

Managed settings locations:
```
/Library/Application Support/ClaudeCode/   # macOS managed settings
/etc/claude-code/                          # Linux/WSL managed settings
C:\Program Files\ClaudeCode\               # Windows managed settings
HKLM\SOFTWARE\Policies\ClaudeCode          # Windows registry (admin)
HKCU\SOFTWARE\Policies\ClaudeCode          # Windows registry (user)
com.anthropic.claudecode                   # macOS managed preferences domain
```

### Settings Precedence (Highest to Lowest)

1. **Managed settings** (cannot be overridden)
2. **Command line arguments** (session temporary overrides)
3. **Local project settings** (`.claude/settings.local.json`)
4. **Shared project settings** (`.claude/settings.json`)
5. **User settings** (`~/.claude/settings.json`)

Array settings merge across scopes (concatenated and deduplicated).

### Schema Validation

Add a `$schema` reference for editor autocompletion:
```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

## Usage Examples

### Complete settings.json Example

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git diff *)",
      "Read(./src/**)",
      "Edit(./src/**)"
    ],
    "ask": [
      "Bash(git push *)"
    ],
    "deny": [
      "Bash(curl *)",
      "Read(./.env)",
      "Read(./secrets/**)"
    ],
    "additionalDirectories": ["../docs/"],
    "defaultMode": "default"
  },

  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "NODE_ENV": "development"
  },

  "attribution": {
    "commit": "Generated with Claude Code\n\nCo-Authored-By: Claude <noreply@anthropic.com>",
    "pr": "Generated with Claude Code"
  },

  "model": "claude-sonnet-4-6",
  "outputStyle": "Explanatory",
  "language": "english",
  "autoUpdatesChannel": "stable",
  "respectGitignore": true,
  "showTurnDuration": true,
  "cleanupPeriodDays": 30
}
```

### Permission Rules Syntax

Rules follow the format `Tool` or `Tool(specifier)` and are evaluated in order: deny -> ask -> allow (first match wins).

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "Bash(npm run *)",
      "Bash(git diff *)",
      "Read(./src/**)",
      "Edit(./src/**)",
      "WebFetch(domain:example.com)"
    ],
    "ask": [
      "Bash(git push *)",
      "WebFetch(*)"
    ],
    "deny": [
      "Bash(curl *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "WebFetch"
    ]
  }
}
```

### Sandbox Configuration

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "git"],
    "filesystem": {
      "allowWrite": ["//tmp/build", "~/.kube"],
      "denyWrite": ["//etc", "//usr/local/bin"],
      "denyRead": ["~/.aws/credentials"]
    },
    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org"],
      "allowLocalBinding": true
    }
  }
}
```

Sandbox path prefixes:
| Prefix | Meaning | Example |
|--------|---------|---------|
| `//` | Absolute from root | `//tmp/build` maps to `/tmp/build` |
| `~/` | From home directory | `~/.kube` maps to `$HOME/.kube` |
| `/` | Relative to settings directory | `/build` maps to `$SETTINGS_DIR/build` |
| `./` or none | Relative path | `./output` |

### Permission Modes

Set `defaultMode` in settings:

| Mode | Description |
|------|-------------|
| `default` | Prompts for permission on first use of each tool |
| `acceptEdits` | Automatically accepts file edit permissions for the session |
| `plan` | Read-only tools only; creates a plan for approval |
| `dontAsk` | Auto-denies tools unless pre-approved |
| `bypassPermissions` | Skips all permission prompts (isolated environments only) |

### Configuration Commands

```bash
/config              # Open settings interface
/status              # Show active settings sources and origins
/permissions         # View and manage tool permissions
```

## Important Details

### All Configurable Settings

**Core Settings:**
- `model` -- Default model (e.g., `"claude-sonnet-4-6"`, `"opus"`, `"sonnet"`)
- `availableModels` -- Restrict which models users can select (e.g., `["sonnet", "haiku"]`)
- `outputStyle` -- Output style (e.g., `"Explanatory"`)
- `language` -- UI language (e.g., `"japanese"`, `"english"`)
- `autoUpdatesChannel` -- Update channel (`"stable"`)
- `cleanupPeriodDays` -- Session cleanup period in days
- `respectGitignore` -- Whether to respect .gitignore patterns
- `plansDirectory` -- Directory for plan files
- `fastModePerSessionOptIn` -- Require per-session fast mode opt-in
- `alwaysThinkingEnabled` -- Always enable extended thinking
- `teammateMode` -- Teammate mode (`"in-process"`)
- `autoMemoryEnabled` -- Enable/disable auto memory

**Display Settings:**
- `showTurnDuration` -- Show turn duration
- `spinnerVerbs` -- Custom spinner verbs (mode: append/replace, verbs array)
- `spinnerTipsEnabled` -- Enable spinner tips
- `spinnerTipsOverride` -- Custom spinner tips
- `terminalProgressBarEnabled` -- Enable terminal progress bar
- `prefersReducedMotion` -- Reduce motion in UI

**Attribution:**
- `attribution.commit` -- Commit message attribution
- `attribution.pr` -- PR attribution
- `includeCoAuthoredBy` -- Deprecated; use `attribution`

**Hooks:**
- `hooks` -- Hook definitions
- `disableAllHooks` -- Disable all hooks
- `allowManagedHooksOnly` -- Only allow managed hooks

**MCP Servers:**
- `enableAllProjectMcpServers` -- Enable all project MCP servers
- `enabledMcpjsonServers` -- Enabled MCP server names
- `disabledMcpjsonServers` -- Disabled MCP server names
- `allowedMcpServers` -- Allowed MCP servers
- `deniedMcpServers` -- Denied MCP servers
- `allowManagedMcpServersOnly` -- Only allow managed MCP servers

**API and Authentication:**
- `apiKeyHelper` -- Script to generate API keys
- `forceLoginMethod` -- Force login method (`"claudeai"` or `"console"`)
- `forceLoginOrgUUID` -- Force login organization UUID
- `awsAuthRefresh` -- AWS auth refresh command
- `awsCredentialExport` -- AWS credential export script

**Plugins:**
- `enabledPlugins` -- Enabled plugin map
- `extraKnownMarketplaces` -- Additional plugin marketplaces
- `strictKnownMarketplaces` -- Strict marketplace sources
- `blockedMarketplaces` -- Blocked marketplace sources

**Status Line and File Suggestions:**
- `statusLine` -- Custom status line command
- `fileSuggestion` -- File suggestion command

**Managed-Only Settings (cannot be set by users):**
- `disableBypassPermissionsMode` -- Prevent bypass permissions mode
- `allowManagedPermissionRulesOnly` -- Only managed permission rules
- `allowManagedHooksOnly` -- Only managed hooks
- `allowManagedMcpServersOnly` -- Only managed MCP servers
- `sandbox.network.allowManagedDomainsOnly` -- Only managed domains
- `strictKnownMarketplaces` -- Controlled plugin marketplaces
- `blockedMarketplaces` -- Blocked plugin sources
- `allow_remote_sessions` -- Allow remote sessions

### Key Environment Variables

**Authentication and API:**
- `ANTHROPIC_API_KEY` -- API key
- `ANTHROPIC_AUTH_TOKEN` -- Custom Authorization header
- `ANTHROPIC_MODEL` -- Override default model
- `ANTHROPIC_SMALL_FAST_MODEL` -- Haiku-class model for background tasks (deprecated, use `ANTHROPIC_DEFAULT_HAIKU_MODEL`)

**Model Configuration:**
- `ANTHROPIC_DEFAULT_HAIKU_MODEL` -- Custom Haiku model
- `ANTHROPIC_DEFAULT_SONNET_MODEL` -- Custom Sonnet model
- `ANTHROPIC_DEFAULT_OPUS_MODEL` -- Custom Opus model
- `CLAUDE_CODE_SUBAGENT_MODEL` -- Subagent model override
- `CLAUDE_CODE_EFFORT_LEVEL` -- Effort level (low/medium/high)
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS` -- Max output tokens (default: 32000, max: 64000)

**Feature Toggles:**
- `CLAUDE_CODE_DISABLE_1M_CONTEXT` -- Disable 1M context
- `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` -- Disable adaptive reasoning
- `CLAUDE_CODE_DISABLE_AUTO_MEMORY` -- Disable auto memory
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` -- Disable background tasks
- `CLAUDE_CODE_DISABLE_FAST_MODE` -- Disable fast mode
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` -- Equivalent to multiple disable flags

**Shell and Execution:**
- `CLAUDE_CODE_SHELL` -- Override shell detection
- `CLAUDE_CODE_SHELL_PREFIX` -- Command prefix for all bash
- `BASH_DEFAULT_TIMEOUT_MS` -- Default bash timeout
- `BASH_MAX_TIMEOUT_MS` -- Maximum bash timeout
- `BASH_MAX_OUTPUT_LENGTH` -- Max bash output chars before truncation

**Files and Configuration:**
- `CLAUDE_CONFIG_DIR` -- Custom config directory
- `CLAUDE_CODE_TMPDIR` -- Custom temp directory
- `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` -- Load CLAUDE.md from additional dirs

**Telemetry and Reporting:**
- `CLAUDE_CODE_ENABLE_TELEMETRY` -- Enable OpenTelemetry
- `DISABLE_AUTOUPDATER` -- Disable auto updates
- `DISABLE_ERROR_REPORTING` -- Opt out of Sentry
- `DISABLE_TELEMETRY` -- Opt out of telemetry
- `DISABLE_COST_WARNINGS` -- Disable cost warnings

**Prompt Caching:**
- `DISABLE_PROMPT_CACHING` -- Disable all prompt caching
- `DISABLE_PROMPT_CACHING_HAIKU` -- Disable Haiku caching
- `DISABLE_PROMPT_CACHING_SONNET` -- Disable Sonnet caching
- `DISABLE_PROMPT_CACHING_OPUS` -- Disable Opus caching

**MCP and Extensions:**
- `ENABLE_TOOL_SEARCH` -- Tool search mode (auto/auto:N/true/false)
- `ENABLE_CLAUDEAI_MCP_SERVERS` -- Enable Claude.ai MCP servers

**Agent Teams:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -- Enable agent teams
- `CLAUDE_CODE_TEAM_NAME` -- Team name
- `CLAUDE_CODE_TASK_LIST_ID` -- Share task list across sessions

**UI and Display:**
- `CLAUDE_CODE_SIMPLE` -- Minimal mode (bash and file tools only)
- `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` -- Show prompt suggestions

**TLS/mTLS:**
- `CLAUDE_CODE_CLIENT_CERT` -- Client certificate path
- `CLAUDE_CODE_CLIENT_KEY` -- Client key path
- `CLAUDE_CODE_CLIENT_KEY_PASSPHRASE` -- Key passphrase

### Tool-Specific Permission Patterns

- **Bash**: `Bash(npm run *)` -- Command matching with glob wildcards. Space before `*` enforces word boundary.
- **Read**: `Read(./src/**)` -- File path patterns following gitignore specification.
- **Edit**: `Edit(/docs/**)` -- Same as Read, applies to all file-editing tools.
- **WebFetch**: `WebFetch(domain:example.com)` -- Domain matching.
- **MCP**: `mcp__puppeteer__puppeteer_navigate` -- Server and tool matching.
- **Agent**: `Agent(Explore)` -- Subagent matching.

Path prefixes for Read/Edit rules:
| Pattern | Meaning |
|---------|---------|
| `//path` | Absolute path from filesystem root |
| `~/path` | Path from home directory |
| `/path` | Path relative to project root |
| `path` or `./path` | Path relative to current directory |

## References

- [Claude Code Settings](https://code.claude.com/docs/en/settings) -- Official settings and configuration reference
- [Configure Permissions](https://code.claude.com/docs/en/permissions) -- Permission rules, modes, and managed policies
- [Sandboxing](https://code.claude.com/docs/en/sandboxing) -- OS-level filesystem and network isolation
- [Server-Managed Settings](https://code.claude.com/docs/en/server-managed-settings) -- Centralized settings management
- [Model Configuration](https://code.claude.com/docs/en/model-config) -- Model-related settings and environment variables
