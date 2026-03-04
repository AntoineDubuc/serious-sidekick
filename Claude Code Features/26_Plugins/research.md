# Plugins

## Overview

The Claude Code plugin system allows developers to package and distribute custom functionality as reusable, shareable units. Plugins bundle slash commands (skills), specialized agents, hooks, MCP servers, LSP servers, and settings into single installable packages with a standardized manifest format. They use namespacing to prevent conflicts between plugins and can be distributed through plugin marketplaces hosted on GitHub, GitLab, npm, pip, or other sources. The system supports everything from personal workflow extensions to enterprise-managed plugin ecosystems.

## Key Capabilities

- **Bundled components**: A single plugin can include slash commands, agent skills, custom agents, hooks, MCP server configurations, LSP server configurations, and default settings
- **Namespaced skills**: Plugin skills are automatically prefixed with the plugin name (e.g., `/my-plugin:hello`) to prevent naming conflicts
- **Marketplace distribution**: Plugins are distributed through marketplace catalogs defined in `marketplace.json` files, supporting centralized discovery, version tracking, and automatic updates
- **Multiple source types**: Plugins can be sourced from local directories, GitHub repos, git URLs, npm packages, or pip packages
- **Enterprise management**: Organizations can restrict allowed marketplaces using `strictKnownMarketplaces` in managed settings, control which plugins are enabled by default, and manage release channels
- **Local testing**: The `--plugin-dir` flag loads plugins directly for development without installation
- **Plugin validation**: `claude plugin validate .` checks manifest structure and component configuration
- **LSP integration**: Plugins can ship Language Server Protocol servers for real-time code intelligence

## Configuration / Setup

### Plugin Structure

Every plugin contains a `.claude-plugin/` directory with a `plugin.json` manifest:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Required: plugin manifest
├── commands/                 # Optional: slash command files
├── agents/                   # Optional: agent definitions
├── skills/                   # Optional: agent skills with SKILL.md files
├── hooks/
│   └── hooks.json            # Optional: event handlers
├── .mcp.json                 # Optional: MCP server configurations
├── .lsp.json                 # Optional: LSP server configurations
├── settings.json             # Optional: default settings (currently only "agent" key)
└── README.md                 # Optional: documentation
```

Important: Do NOT put `commands/`, `agents/`, `skills/`, or `hooks/` inside the `.claude-plugin/` directory. Only `plugin.json` goes inside `.claude-plugin/`. All other directories must be at the plugin root level.

### Plugin Manifest (plugin.json)

```json
{
  "name": "my-plugin",
  "description": "A description of what this plugin does",
  "version": "1.0.0",
  "author": {
    "name": "Your Name"
  },
  "homepage": "https://example.com",
  "repository": "https://github.com/user/repo",
  "license": "MIT",
  "keywords": ["utility", "productivity"]
}
```

| Field         | Required | Purpose                                                                    |
|:--------------|:---------|:---------------------------------------------------------------------------|
| `name`        | Yes      | Unique identifier and skill namespace (e.g., `/my-plugin:hello`)           |
| `description` | No       | Shown in the plugin manager when browsing or installing                    |
| `version`     | No       | Track releases using semantic versioning                                   |
| `author`      | No       | Attribution information                                                    |
| `homepage`    | No       | Plugin homepage or documentation URL                                       |
| `repository`  | No       | Source code repository URL                                                 |
| `license`     | No       | SPDX license identifier                                                    |
| `keywords`    | No       | Tags for plugin discovery                                                  |

### Creating a Skill in a Plugin

Create `skills/hello/SKILL.md`:

```markdown
---
description: Greet the user with a friendly message
disable-model-invocation: true
---

Greet the user warmly and ask how you can help them today.
```

Skills support the `$ARGUMENTS` placeholder for dynamic user input.

### Testing Locally

Load a plugin during development with the `--plugin-dir` flag:

```bash
claude --plugin-dir ./my-plugin
```

Multiple plugins can be loaded:

```bash
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two
```

### Installing Plugins

```
/plugin install review-plugin@my-marketplace
```

### Managing Plugins

Use the `/plugin` command to manage plugins (browse, discover, install, manage).

## Usage Examples

### Marketplace Distribution

A marketplace is a catalog defined in `.claude-plugin/marketplace.json`:

```json
{
  "name": "company-tools",
  "owner": {
    "name": "DevTools Team",
    "email": "devtools@example.com"
  },
  "plugins": [
    {
      "name": "code-formatter",
      "source": "./plugins/formatter",
      "description": "Automatic code formatting on save",
      "version": "2.1.0"
    },
    {
      "name": "deployment-tools",
      "source": {
        "source": "github",
        "repo": "company/deploy-plugin"
      },
      "description": "Deployment automation tools"
    }
  ]
}
```

### Plugin Sources

| Source        | Format                                          | Notes                              |
|:--------------|:------------------------------------------------|:-----------------------------------|
| Relative path | `"./plugins/my-plugin"`                         | Local directory within marketplace |
| GitHub        | `{"source": "github", "repo": "owner/repo"}`   | Supports `ref` and `sha` pinning  |
| Git URL       | `{"source": "url", "url": "https://.../.git"}`  | Any git hosting service            |
| npm           | `{"source": "npm", "package": "@org/plugin"}`   | Supports `version` and `registry`  |
| pip           | `{"source": "pip", "package": "plugin-name"}`   | Python package distribution        |

### Adding a Marketplace

```
/plugin marketplace add owner/repo
```

Or with a full URL:

```
/plugin marketplace add https://gitlab.com/company/plugins.git
```

### Team Configuration

Require marketplaces for your team in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "code-formatter@company-tools": true,
    "deployment-tools@company-tools": true
  }
}
```

### LSP Server Plugin

Add `.lsp.json` to your plugin:

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": {
      ".go": "go"
    }
  }
}
```

### Hooks in Plugins

Create `hooks/hooks.json`:

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

Use `${CLAUDE_PLUGIN_ROOT}` in hook commands and MCP server configs to reference files within the plugin's installation directory.

### Default Settings in Plugins

A `settings.json` file at the plugin root can set default configuration:

```json
{
  "agent": "security-reviewer"
}
```

This activates the named agent from the plugin's `agents/` directory as the main thread agent.

## Important Details

### Standalone vs Plugin Configuration

| Approach                        | Skill Names          | Best For                                                    |
|:--------------------------------|:---------------------|:------------------------------------------------------------|
| Standalone (`.claude/` dir)     | `/hello`             | Personal workflows, project-specific, quick experiments     |
| Plugins (`.claude-plugin/`)     | `/plugin-name:hello` | Sharing with teams, community distribution, versioned       |

### Plugin Caching

When users install a plugin, Claude Code copies the plugin directory to a cache location at `~/.claude/plugins/cache`. This means:
- Plugins cannot reference files outside their directory using paths like `../shared-utils`
- If you need to share files across plugins, use symlinks (which are followed during copying)

### Strict Mode

The `strict` field in marketplace entries controls component authority:
- `true` (default): `plugin.json` is the authority; marketplace can supplement with additional components
- `false`: The marketplace entry is the entire definition; conflicts with `plugin.json` component declarations cause load failure

### Enterprise Marketplace Restrictions

Administrators can restrict marketplaces using `strictKnownMarketplaces` in managed settings:

```json
{
  "strictKnownMarketplaces": [
    {
      "source": "github",
      "repo": "acme-corp/approved-plugins"
    }
  ]
}
```

An empty array `[]` completely locks down marketplace additions.

### Release Channels

Support stable and latest channels by setting up two marketplaces pointing to different refs/SHAs of the same repo. The plugin's `plugin.json` must declare a different `version` at each ref.

### Version Resolution

Plugin versions determine cache paths and update detection. Avoid setting the version in both `plugin.json` and `marketplace.json` -- the plugin manifest always wins silently, which can cause the marketplace version to be ignored.

### Reserved Marketplace Names

The following names are reserved for official Anthropic use: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `life-sciences`.

### Submitting to Official Marketplace

Submit plugins through in-app forms:
- Claude.ai: [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit)
- Console: [platform.claude.com/plugins/submit](https://platform.claude.com/plugins/submit)

### Private Repository Support

Claude Code supports installing from private repositories using existing git credential helpers. For background auto-updates, set environment tokens:
- GitHub: `GITHUB_TOKEN` or `GH_TOKEN`
- GitLab: `GITLAB_TOKEN` or `GL_TOKEN`
- Bitbucket: `BITBUCKET_TOKEN`

### Git Operation Timeout

Default timeout for git operations is 120 seconds. Increase with:
```bash
export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000  # 5 minutes
```

## References

- [Create Plugins - Claude Code Docs](https://code.claude.com/docs/en/plugins) -- Official documentation on creating plugins with skills, agents, hooks, MCP servers, and LSP servers
- [Create and Distribute a Plugin Marketplace - Claude Code Docs](https://code.claude.com/docs/en/plugin-marketplaces) -- Official documentation on marketplace creation, hosting, and distribution
- [Discover and Install Plugins - Claude Code Docs](https://code.claude.com/docs/en/discover-plugins) -- Documentation on browsing and installing plugins
- [Plugins Reference - Claude Code Docs](https://code.claude.com/docs/en/plugins-reference) -- Complete technical specifications and schemas
- [Official Anthropic Plugin Directory](https://github.com/anthropics/claude-plugins-official) -- GitHub repository of official, Anthropic-managed Claude Code plugins
- [Plugin Settings - Claude Code Docs](https://code.claude.com/docs/en/settings#plugin-settings) -- Plugin configuration options in settings
