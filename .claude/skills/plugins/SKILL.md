---
name: plugins
description: "Auto-load when user asks about plugins, plugin marketplace, creating plugins, distributing plugins, or plugin.json manifest"
---

# Plugins

## Quick Reference
- Plugins bundle slash commands, agents, skills, hooks, MCP servers, LSP servers, and settings into a single installable package.
- Every plugin has a `.claude-plugin/plugin.json` manifest -- this is the only file inside `.claude-plugin/`.
- Plugin skills are namespaced: `/plugin-name:skill-name` (vs standalone `/skill-name`).
- Distributed through marketplace catalogs (`marketplace.json`) hosted on GitHub, GitLab, npm, pip, or local paths.
- Install: `/plugin install plugin-name@marketplace-name`. Manage: `/plugin` command.
- Local testing: `claude --plugin-dir ./my-plugin` (no installation needed).
- Validate: `claude plugin validate .`
- Plugin cache lives at `~/.claude/plugins/cache` -- plugins cannot reference files outside their directory.
- Enterprise control: `strictKnownMarketplaces` in managed settings restricts allowed marketplaces.

## Configuration

**Plugin directory structure:**
```
my-plugin/
  .claude-plugin/
    plugin.json          # Required: manifest (ONLY file in .claude-plugin/)
  commands/              # Optional: slash command files
  agents/                # Optional: agent definitions
  skills/                # Optional: SKILL.md files
  hooks/
    hooks.json           # Optional: event handlers
  .mcp.json              # Optional: MCP server configs
  .lsp.json              # Optional: LSP server configs
  settings.json          # Optional: default settings
```

**plugin.json manifest:**
```json
{
  "name": "my-plugin",
  "description": "What this plugin does",
  "version": "1.0.0",
  "author": { "name": "Your Name" },
  "repository": "https://github.com/user/repo",
  "license": "MIT",
  "keywords": ["utility"]
}
```

**marketplace.json (for distribution):**
```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "devtools@example.com" },
  "plugins": [
    {
      "name": "code-formatter",
      "source": "./plugins/formatter",
      "description": "Auto code formatting",
      "version": "2.1.0"
    },
    {
      "name": "deploy-tools",
      "source": { "source": "github", "repo": "company/deploy-plugin" },
      "description": "Deployment automation"
    }
  ]
}
```

**Plugin sources in marketplace entries:**

| Source | Format |
|--------|--------|
| Relative path | `"./plugins/my-plugin"` |
| GitHub | `{"source": "github", "repo": "owner/repo"}` (supports `ref`, `sha` pinning) |
| Git URL | `{"source": "url", "url": "https://.../.git"}` |
| npm | `{"source": "npm", "package": "@org/plugin"}` (supports `version`, `registry`) |
| pip | `{"source": "pip", "package": "plugin-name"}` |

## Common Patterns

1. **Create a skill inside a plugin** (`skills/hello/SKILL.md`):
   ```markdown
   ---
   description: Greet the user with a friendly message
   disable-model-invocation: true
   ---
   Greet the user warmly and ask how you can help them today.
   ```
   Use `$ARGUMENTS` placeholder for dynamic user input.

2. **Add hooks to a plugin** (`hooks/hooks.json`):
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [{ "type": "command", "command": "jq -r '.tool_input.file_path' | xargs npm run lint:fix" }]
         }
       ]
     }
   }
   ```
   Use `${CLAUDE_PLUGIN_ROOT}` to reference files within the plugin's install directory.

3. **Team-wide plugin configuration** (`.claude/settings.json`):
   ```json
   {
     "extraKnownMarketplaces": {
       "company-tools": {
         "source": { "source": "github", "repo": "your-org/claude-plugins" }
       }
     },
     "enabledPlugins": {
       "code-formatter@company-tools": true,
       "deploy-tools@company-tools": true
     }
   }
   ```

## Gotchas
- **Do NOT put `commands/`, `agents/`, `skills/`, or `hooks/` inside `.claude-plugin/`** -- only `plugin.json` goes there. All other dirs must be at the plugin root.
- **Plugin caching**: plugins are copied to `~/.claude/plugins/cache`, so they cannot reference `../shared-utils`. Use symlinks if you need shared files.
- **Version conflicts**: avoid setting version in both `plugin.json` and `marketplace.json` -- the plugin manifest always wins silently.
- **`strict` field** (default `true`): `plugin.json` is the authority. Set `false` to let the marketplace entry be the entire definition.
- **Reserved marketplace names**: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `life-sciences`.
- **Private repos**: use existing git credential helpers. For background auto-updates, set `GITHUB_TOKEN`, `GITLAB_TOKEN`, or `BITBUCKET_TOKEN`.
- **Git timeout**: default 120s. Increase with `CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000`.
- **Submit to official marketplace**: via [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit) or [platform.claude.com/plugins/submit](https://platform.claude.com/plugins/submit).

@./Claude Code Features/26_Plugins/research.md
