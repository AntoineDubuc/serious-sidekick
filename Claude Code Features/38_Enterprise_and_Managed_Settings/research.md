# Enterprise and Managed Settings

## Overview

Claude Code provides enterprise-grade configuration management through managed settings files, server-managed settings, and MDM/OS-level policies. These allow organizations to enforce security policies, control permissions, restrict tools and plugins, and standardize Claude Code behavior across all users. Managed settings have the highest precedence in the settings hierarchy and cannot be overridden by individual users or project settings.

## Key Capabilities

- **Organization-wide policy enforcement**: Deploy settings that apply to all Claude Code users in the organization. Users cannot override managed settings.
- **Multiple delivery mechanisms**: Managed settings files at system paths, server-managed settings via Claude.ai admin console, and MDM/OS-level policies (macOS plist, Windows registry).
- **Server-managed settings (public beta)**: Configure Claude Code through a web-based interface on Claude.ai. Claude Code clients automatically receive settings when users authenticate. Available for Teams and Enterprise plans.
- **Permission control**: Define allow, ask, and deny rules for tools, files, and network access. Restrict which permission modes are available.
- **Plugin marketplace controls**: Allowlist and blocklist plugin marketplaces, enforce strict marketplace restrictions.
- **MCP server restrictions**: Control which MCP servers users can configure with allowlists and denylists.
- **Hook restrictions**: Prevent loading of user/project/plugin hooks; only allow managed and SDK hooks.
- **Company announcements**: Display organizational messages to all users via the `companyAnnouncements` field.
- **Managed CLAUDE.md**: Place a CLAUDE.md file at system-level managed paths to apply unified guidelines across the organization with highest precedence.
- **Forced login methods**: Lock the CLI to specific authentication credentials or organizations with `forceLoginMethod` and `forceLoginOrgUUID`.
- **Audit logging**: Audit log events for settings changes are available through the compliance API or audit log export.

## Configuration / Setup

### Managed Settings File Paths

| OS | Path |
|----|------|
| **macOS** | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| **Linux & WSL** | `/etc/claude-code/managed-settings.json` |
| **Windows** | `C:\Program Files\ClaudeCode\managed-settings.json` |

### MDM / OS-Level Policies

| Platform | Mechanism | Location |
|----------|-----------|----------|
| **macOS** | Managed preferences | `com.anthropic.claudecode` domain (Jamf, Kandji, etc.) |
| **Windows (machine)** | Registry | `HKLM\SOFTWARE\Policies\ClaudeCode` |
| **Windows (user)** | Registry | `HKCU\SOFTWARE\Policies\ClaudeCode` |

### Server-Managed Settings (Public Beta)
1. Navigate to **Claude.ai > Admin Settings > Claude Code > Managed settings**
2. Add configuration as JSON
3. Save and deploy — clients receive updates on next startup or hourly polling cycle

**Requirements**:
- Claude for Teams or Claude for Enterprise plan
- Claude Code v2.1.38+ (Teams) or v2.1.30+ (Enterprise)
- Network access to `api.anthropic.com`

**Access control**: Only Primary Owner and Owner roles can manage these settings.

### Settings Precedence (Highest to Lowest)
1. **Managed settings** (cannot be overridden)
   - Server-managed (Anthropic servers) — highest within managed tier
   - MDM/OS-level policies
   - `managed-settings.json` file
   - Windows user-level registry `HKCU` — lowest in managed tier
2. **Command line arguments** (temporary session overrides)
3. **Local project settings** (`.claude/settings.local.json`)
4. **Shared project settings** (`.claude/settings.json`)
5. **User settings** (`~/.claude/settings.json`)

Array-valued settings (like `permissions.allow`, `sandbox.filesystem.allowWrite`) are **concatenated and deduplicated** across scopes, not replaced.

### Managed-Only Settings

These settings can **only** be configured in managed settings:

| Setting | Description |
|---------|-------------|
| `disableBypassPermissionsMode` | Set to `"disable"` to prevent `bypassPermissions` mode and the `--dangerously-skip-permissions` flag |
| `allowManagedPermissionRulesOnly` | When `true`, prevents user and project settings from defining `allow`, `ask`, or `deny` permission rules. Only rules in managed settings apply |
| `allowManagedHooksOnly` | When `true`, prevents loading of user, project, and plugin hooks. Only managed and SDK hooks allowed |
| `allowManagedMcpServersOnly` | When `true`, only `allowedMcpServers` from managed settings are respected. `deniedMcpServers` still merges from all sources |
| `allowedMcpServers` | Allowlist of MCP servers users can configure (e.g., `[{ "serverName": "github" }]`) |
| `deniedMcpServers` | Denylist of explicitly blocked MCP servers |
| `strictKnownMarketplaces` | Allowlist of plugin marketplaces users can add (e.g., `[{ "source": "github", "repo": "acme-corp/plugins" }]`) |
| `blockedMarketplaces` | Blocklist of marketplace sources; checked before download so blocked sources never touch the filesystem |
| `sandbox.network.allowManagedDomainsOnly` | When `true`, only `allowedDomains` and `WebFetch(domain:...)` allow rules from managed settings are respected |
| `allow_remote_sessions` | When `true`, allows remote sessions. Set to `false` to prevent Remote Control and web session access |

## Usage Examples

**Enforce permission deny list and prevent bypass**:
```json
{
  "permissions": {
    "deny": [
      "Bash(curl *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ]
  },
  "disableBypassPermissionsMode": "disable"
}
```

**Lock down to managed permissions only**:
```json
{
  "allowManagedPermissionRulesOnly": true,
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git commit *)"
    ],
    "deny": [
      "Bash(git push *)",
      "Bash(rm -rf *)"
    ]
  }
}
```

**Restrict MCP servers to an allowlist**:
```json
{
  "allowManagedMcpServersOnly": true,
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverName": "linear" }
  ],
  "deniedMcpServers": [
    { "serverName": "filesystem" }
  ]
}
```

**Control plugin marketplaces**:
```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" }
  ],
  "blockedMarketplaces": [
    { "source": "github", "repo": "untrusted/plugins" }
  ]
}
```

**Restrict hooks to managed only**:
```json
{
  "allowManagedHooksOnly": true,
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/opt/company-tools/validate-command.sh"
          }
        ]
      }
    ]
  }
}
```

**Company announcements**:
```json
{
  "companyAnnouncements": "Please use only approved MCP servers per security policy. Contact #dev-tools on Slack for questions."
}
```

## Important Details

- **Server-managed vs endpoint-managed**: Server-managed settings are best for organizations without MDM or users on unmanaged devices (settings delivered from Anthropic servers). Endpoint-managed settings are best for organizations with MDM (stronger security because settings are protected at the OS level). When both are present, server-managed settings take precedence.
- **Security approval dialogs**: Certain settings (shell commands, custom environment variables, hook configurations) require explicit user approval before being applied. Users must approve to proceed; rejecting causes Claude Code to exit. In non-interactive mode (`-p` flag), dialogs are skipped.
- **Fetch and caching behavior**: Server-managed settings are fetched at startup and polled hourly. Cached settings apply immediately on subsequent launches. Settings updates apply automatically without restart (except advanced settings like OpenTelemetry).
- **Security considerations**: Server-managed settings are a client-side control. On unmanaged devices, users with admin/sudo access could modify the Claude Code binary or cached settings. For stronger guarantees, use endpoint-managed settings with MDM.
- **Current limitations**: Server-managed settings apply uniformly to all users (no per-group configurations yet). MCP server configurations cannot be distributed through server-managed settings. Settings are not available when using third-party providers (Bedrock, Vertex, Foundry, custom API endpoints).
- **Desktop app admin controls**: Admin console at `claude.ai/admin-settings/claude-code` for enabling/disabling the Code tab, Bypass permissions mode, and remote sessions. MDM policies available for macOS (`com.anthropic.Claude` domain) and Windows (`SOFTWARE\Policies\Claude` registry).
- **ConfigChange hooks**: Use `ConfigChange` hooks to log modifications or block unauthorized settings changes at runtime.
- **Authentication and SSO**: Enterprise organizations can require SSO for all users via SAML or OIDC configuration.

## References

- [Server-Managed Settings](https://code.claude.com/docs/en/server-managed-settings) — Official documentation for server-managed settings (public beta)
- [Settings Reference](https://code.claude.com/docs/en/settings) — Complete configuration reference including managed settings file paths and precedence
- [Permissions](https://code.claude.com/docs/en/permissions) — Permission configuration, managed-only settings, and access control
- [Claude Code on Team and Enterprise](https://www.anthropic.com/news/claude-code-on-team-and-enterprise) — Anthropic announcement on enterprise features
- [Admin Controls for Claude Code](https://www.eesel.ai/blog/admin-controls-claude-code) — Practical guide to enterprise admin controls
