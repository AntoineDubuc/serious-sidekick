# MCP Integration

## Overview

Claude Code connects to external tools and data sources through the Model Context Protocol (MCP), an open source standard for AI-tool integrations. MCP servers give Claude Code access to your tools, databases, and APIs. With MCP, Claude Code can implement features from issue trackers, analyze monitoring data, query databases, integrate designs, and automate multi-system workflows. MCP servers can be configured at local, project, or user scope, and support stdio, HTTP, and SSE transports.

## Key Capabilities

- **Connect to hundreds of external tools**: Issue trackers (JIRA, GitHub), monitoring (Sentry, Statsig), databases (PostgreSQL), design tools (Figma), communication (Slack, Gmail), and more.
- **Three transport types**: HTTP (recommended for remote), SSE (deprecated, use HTTP), and stdio (for local processes).
- **Three configuration scopes**: Local (default, private per-project), Project (shared via `.mcp.json` in version control), and User (available across all projects).
- **OAuth 2.0 authentication**: Secure connections to cloud-based MCP servers with automatic token refresh.
- **MCP resources**: Reference MCP resources using `@server:protocol://resource/path` mentions.
- **MCP prompts as commands**: MCP server prompts become available as `/mcp__servername__promptname` commands.
- **Dynamic tool updates**: Supports `list_changed` notifications for live tool/prompt/resource updates.
- **Tool Search**: Automatically manages large numbers of MCP tools by loading them on-demand.
- **Claude Code as MCP server**: Claude Code itself can serve as an MCP server for other applications via `claude mcp serve`.
- **Plugin-provided MCP servers**: Plugins can bundle MCP servers that start automatically.
- **Managed MCP**: Organizations can deploy centrally controlled MCP servers and restrict which servers employees can use.

## Configuration / Setup

### Adding MCP Servers

**Option 1: Remote HTTP server (recommended)**:
```bash
claude mcp add --transport http <name> <url>

# Example: Connect to Notion
claude mcp add --transport http notion https://mcp.notion.com/mcp

# With Bearer token
claude mcp add --transport http secure-api https://api.example.com/mcp \
  --header "Authorization: Bearer your-token"
```

**Option 2: Remote SSE server (deprecated)**:
```bash
claude mcp add --transport sse <name> <url>

# Example: Connect to Asana
claude mcp add --transport sse asana https://mcp.asana.com/sse
```

**Option 3: Local stdio server**:
```bash
claude mcp add [options] <name> -- <command> [args...]

# Example: Add Airtable server
claude mcp add --transport stdio --env AIRTABLE_API_KEY=YOUR_KEY airtable \
  -- npx -y airtable-mcp-server
```

**Important option ordering**: All options (`--transport`, `--env`, `--scope`, `--header`) must come before the server name. The `--` separates the server name from the command.

**Add from JSON configuration**:
```bash
claude mcp add-json weather-api '{"type":"http","url":"https://api.weather.com/mcp","headers":{"Authorization":"Bearer token"}}'
```

**Import from Claude Desktop**:
```bash
claude mcp add-from-claude-desktop
```

### Managing Servers

```bash
claude mcp list           # List all configured servers
claude mcp get github     # Get details for a specific server
claude mcp remove github  # Remove a server
```

Within Claude Code:
```
/mcp                      # Check server status, authenticate
```

### Configuration Scopes

| Scope | Description | Storage |
|-------|-------------|---------|
| `local` (default) | Private to you, current project only | `~/.claude.json` under project path |
| `project` | Shared with team via version control | `.mcp.json` in project root |
| `user` | Available across all your projects | `~/.claude.json` |

```bash
# Add to specific scope
claude mcp add --transport http stripe --scope local https://mcp.stripe.com
claude mcp add --transport http paypal --scope project https://mcp.paypal.com/mcp
claude mcp add --transport http hubspot --scope user https://mcp.hubspot.com/anthropic
```

### Project-scoped `.mcp.json` Format
```json
{
  "mcpServers": {
    "shared-server": {
      "command": "/path/to/server",
      "args": [],
      "env": {}
    }
  }
}
```

Supports environment variable expansion:
```json
{
  "mcpServers": {
    "api-server": {
      "type": "http",
      "url": "${API_BASE_URL:-https://api.example.com}/mcp",
      "headers": {
        "Authorization": "Bearer ${API_KEY}"
      }
    }
  }
}
```

Supported syntax: `${VAR}` and `${VAR:-default}`. Variables can be expanded in `command`, `args`, `env`, `url`, and `headers`.

### OAuth Authentication

```bash
# 1. Add the server
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# 2. Authenticate via /mcp in Claude Code
> /mcp
```

For servers requiring pre-configured OAuth credentials:
```bash
claude mcp add --transport http \
  --client-id your-client-id --client-secret --callback-port 8080 \
  my-server https://mcp.example.com/mcp
```

## Usage Examples

### Monitor errors with Sentry
```bash
# Add the Sentry MCP server
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# Authenticate
> /mcp

# Use it
> "What are the most common errors in the last 24 hours?"
> "Show me the stack trace for error ID abc123"
```

### Connect to GitHub
```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp/

> /mcp  # Authenticate
> "Review PR #456 and suggest improvements"
> "Create a new issue for the bug we just found"
```

### Query PostgreSQL database
```bash
claude mcp add --transport stdio db -- npx -y @bytebase/dbhub \
  --dsn "postgresql://readonly:pass@prod.db.com:5432/analytics"

> "What's our total revenue this month?"
> "Show me the schema for the orders table"
```

### Use Claude Code as an MCP server (in Claude Desktop)
```json
{
  "mcpServers": {
    "claude-code": {
      "type": "stdio",
      "command": "claude",
      "args": ["mcp", "serve"],
      "env": {}
    }
  }
}
```

### Reference MCP resources
```
> Can you analyze @github:issue://123 and suggest a fix?
> Compare @postgres:schema://users with @docs:file://database/user-model
```

### Execute MCP prompts as commands
```
> /mcp__github__list_prs
> /mcp__github__pr_review 456
> /mcp__jira__create_issue "Bug in login flow" high
```

### Plugin MCP configuration
In `.mcp.json` at plugin root:
```json
{
  "database-tools": {
    "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
    "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
    "env": {
      "DB_URL": "${DB_URL}"
    }
  }
}
```

## Important Details

### Scope Precedence
When servers with the same name exist at multiple scopes: local > project > user.

### Output Limits
- Warning threshold: 10,000 tokens per MCP tool output.
- Default maximum: 25,000 tokens.
- Configurable via `MAX_MCP_OUTPUT_TOKENS` environment variable.
```bash
export MAX_MCP_OUTPUT_TOKENS=50000
claude
```

### MCP Tool Search
- Automatically enabled when MCP tool descriptions exceed 10% of context window.
- MCP tools are deferred and loaded on-demand via search.
- Requires Sonnet 4+ or Opus 4+ (Haiku does not support tool search).
- Configure via `ENABLE_TOOL_SEARCH` env var: `auto` (default), `auto:<N>` (custom threshold), `true`, `false`.

### Windows Notes
On native Windows (not WSL), local MCP servers using `npx` require the `cmd /c` wrapper:
```bash
claude mcp add --transport stdio my-server -- cmd /c npx -y @some/package
```

### MCP Timeout
Configure startup timeout via `MCP_TIMEOUT` environment variable:
```bash
MCP_TIMEOUT=10000 claude  # 10-second timeout
```

### Managed MCP Configuration

**Option 1: Exclusive control with `managed-mcp.json`**:
Deploy to system-wide directories (requires admin privileges):
- macOS: `/Library/Application Support/ClaudeCode/managed-mcp.json`
- Linux/WSL: `/etc/claude-code/managed-mcp.json`
- Windows: `C:\Program Files\ClaudeCode\managed-mcp.json`

Users cannot add, modify, or use any servers other than those in this file.

**Option 2: Policy-based with allowlists/denylists**:
Use `allowedMcpServers` and `deniedMcpServers` in managed settings. Supports restriction by `serverName`, `serverCommand` (exact array match), or `serverUrl` (with wildcard patterns).

Key rules:
- Denylist takes absolute precedence over allowlist.
- `allowedMcpServers: []` (empty array) = complete lockdown.
- `allowedMcpServers: undefined` (default) = no restrictions.
- Options 1 and 2 can be combined.

### Claude.ai MCP Servers
If logged in with a Claude.ai account, MCP servers configured at `claude.ai/settings/connectors` are automatically available. Disable with `ENABLE_CLAUDEAI_MCP_SERVERS=false`.

### Security
- Claude Code prompts for approval before using project-scoped servers from `.mcp.json`.
- Use `claude mcp reset-project-choices` to reset approval choices.
- Authentication tokens are stored securely and refreshed automatically.
- Use "Clear authentication" in `/mcp` menu to revoke access.

## References

- [Connect Claude Code to Tools via MCP](https://docs.anthropic.com/en/docs/claude-code/mcp) -- Full documentation on MCP integration, installation, scopes, and managed configuration
- [Model Context Protocol Introduction](https://modelcontextprotocol.io/introduction) -- The open source MCP standard
- [MCP SDK Quickstart](https://modelcontextprotocol.io/quickstart/server) -- Build your own MCP server
- [MCP Servers on GitHub](https://github.com/modelcontextprotocol/servers) -- Hundreds of community MCP servers
- [Plugins Reference: MCP Servers](https://code.claude.com/docs/en/plugins-reference#mcp-servers) -- Bundling MCP servers with plugins
- [Settings](https://code.claude.com/docs/en/settings) -- Configuration and managed settings
