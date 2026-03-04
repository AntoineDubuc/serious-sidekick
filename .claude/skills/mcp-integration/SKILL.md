---
name: mcp-integration
description: "Auto-load when user asks about MCP servers, external tools, Model Context Protocol, connecting databases/APIs, or tool integrations."
---

# MCP Integration in Claude Code

## Quick Reference
- MCP (Model Context Protocol) connects Claude Code to external tools, databases, and APIs
- Three transports: `http` (recommended for remote), `sse` (deprecated), `stdio` (local processes)
- Three scopes: `local` (default, private per-project), `project` (shared via `.mcp.json`), `user` (all projects)
- Scope precedence: local > project > user
- Add servers via CLI: `claude mcp add --transport <type> <name> <url-or-command>`
- All CLI options (`--transport`, `--env`, `--scope`, `--header`) must come BEFORE the server name
- Use `/mcp` inside Claude Code to check status and authenticate OAuth servers
- MCP resources: `@server:protocol://resource/path`; MCP prompts: `/mcp__server__prompt`
- Output limit: 25,000 tokens default (warning at 10,000). Override with `MAX_MCP_OUTPUT_TOKENS`
- Tool Search auto-enables when MCP tools exceed 10% of context window (requires Sonnet 4+ or Opus 4+)

## Configuration

### Adding servers
```bash
# HTTP (recommended for remote)
claude mcp add --transport http notion https://mcp.notion.com/mcp

# HTTP with auth header
claude mcp add --transport http secure-api https://api.example.com/mcp \
  --header "Authorization: Bearer your-token"

# stdio (local process)
claude mcp add --transport stdio --env API_KEY=xxx my-server \
  -- npx -y @some/mcp-server

# From JSON
claude mcp add-json weather '{"type":"http","url":"https://api.weather.com/mcp"}'

# Import from Claude Desktop
claude mcp add-from-claude-desktop

# Manage
claude mcp list
claude mcp get <name>
claude mcp remove <name>
```

### Project-scoped .mcp.json
```json
{
  "mcpServers": {
    "api-server": {
      "type": "http",
      "url": "${API_BASE_URL:-https://api.example.com}/mcp",
      "headers": {
        "Authorization": "Bearer ${API_KEY}"
      }
    },
    "local-tool": {
      "command": "npx",
      "args": ["-y", "@some/mcp-package"],
      "env": { "TOKEN": "${MY_TOKEN}" }
    }
  }
}
```
Supports `${VAR}` and `${VAR:-default}` in command, args, env, url, and headers.

### OAuth authentication
```bash
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
# Then authenticate inside Claude Code:
> /mcp
```

## Common Patterns

### Connect to popular services
```bash
# GitHub
claude mcp add --transport http github https://api.githubcopilot.com/mcp/

# Sentry
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# PostgreSQL
claude mcp add --transport stdio db -- npx -y @bytebase/dbhub \
  --dsn "postgresql://user:pass@host:5432/db"
```

### Claude Code as MCP server (for Claude Desktop)
```json
{
  "mcpServers": {
    "claude-code": {
      "type": "stdio",
      "command": "claude",
      "args": ["mcp", "serve"]
    }
  }
}
```

### Using MCP resources and prompts
```
> Analyze @github:issue://123 and suggest a fix
> /mcp__github__list_prs
> /mcp__jira__create_issue "Bug report" high
```

## Gotchas
- Option ordering matters: `claude mcp add --transport http --scope project name url` (options before name)
- On Windows (not WSL), wrap with `cmd /c`: `claude mcp add --transport stdio my-server -- cmd /c npx -y @pkg`
- Configure startup timeout: `MCP_TIMEOUT=10000 claude` (milliseconds)
- Project-scoped servers from `.mcp.json` require user approval; reset with `claude mcp reset-project-choices`
- Tool Search requires Sonnet 4+ or Opus 4+; Haiku does not support it
- Claude.ai MCP servers are auto-available when logged in; disable with `ENABLE_CLAUDEAI_MCP_SERVERS=false`
- Managed MCP: `managed-mcp.json` at system paths locks users to only those servers. Policy-based allowlists/denylists also available.

@./Claude Code Features/05_MCP_Integration/research.md
