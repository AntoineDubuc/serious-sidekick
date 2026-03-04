# Permissions and Security

## Overview

Claude Code uses a layered security architecture combining fine-grained permissions, sandboxing, and built-in protections. The permission system controls what Claude Code can access and do, with rules that can be checked into version control and distributed organization-wide. Security features include prompt injection protections, command blocklists, isolated context windows, and credential management.

## Key Capabilities

### Permission System
- **Tiered tool permissions**: read-only tools require no approval; bash commands and file modifications require explicit approval
- **Three rule types**: Allow (auto-approve), Ask (prompt for confirmation), Deny (block completely)
- **Rule evaluation order**: deny -> ask -> allow (deny rules always take precedence)
- **Five permission modes**: default, acceptEdits, plan, dontAsk, bypassPermissions
- **Fine-grained specifiers**: match specific commands, file paths, domains, MCP tools, and subagents
- **Wildcard patterns**: glob-style `*` matching for Bash commands
- **Gitignore-style path rules**: for Read and Edit tools with absolute, home-relative, project-relative, and cwd-relative patterns
- **Managed settings**: organizational policies that cannot be overridden by users or projects
- **Hook-based extension**: PreToolUse hooks can approve or deny tool calls at runtime

### Security
- **Sandboxed bash tool**: filesystem and network isolation for bash commands
- **Write access restriction**: Claude can only write to the folder where it was started and subfolders
- **Prompt injection protections**: context-aware analysis, input sanitization, command blocklist
- **Isolated context windows**: web fetch uses separate context to avoid malicious prompt injection
- **Trust verification**: first-time codebase runs and new MCP servers require verification
- **Command injection detection**: suspicious bash commands require manual approval even if allowlisted
- **Fail-closed matching**: unmatched commands default to requiring manual approval
- **Secure credential storage**: API keys and tokens are encrypted

## Configuration / Setup

### Permission Modes

Set `defaultMode` in settings files:

| Mode | Description |
|------|-------------|
| `default` | Standard behavior: prompts for permission on first use of each tool |
| `acceptEdits` | Automatically accepts file edit permissions for the session |
| `plan` | Plan Mode: Claude can analyze but not modify files or execute commands |
| `dontAsk` | Auto-denies tools unless pre-approved via `/permissions` or `permissions.allow` rules |
| `bypassPermissions` | Skips all permission prompts (only use in isolated environments like containers/VMs) |

### Permission Rule Syntax

Rules follow the format `Tool` or `Tool(specifier)`:

**Match all uses:**
| Rule | Effect |
|------|--------|
| `Bash` | Matches all Bash commands |
| `WebFetch` | Matches all web fetch requests |
| `Read` | Matches all file reads |

**Fine-grained specifiers:**
| Rule | Effect |
|------|--------|
| `Bash(npm run build)` | Matches exact command |
| `Bash(npm run *)` | Matches commands starting with `npm run` |
| `Bash(* --version)` | Matches commands ending with `--version` |
| `Read(./.env)` | Matches reading .env in current directory |
| `WebFetch(domain:example.com)` | Matches fetch requests to example.com |
| `mcp__puppeteer__puppeteer_navigate` | Matches specific MCP tool |
| `Agent(Explore)` | Matches the Explore subagent |

### Read/Edit Path Pattern Types

| Pattern | Meaning | Example |
|---------|---------|---------|
| `//path` | Absolute path from filesystem root | `Read(//Users/alice/secrets/**)` |
| `~/path` | Path from home directory | `Read(~/Documents/*.pdf)` |
| `/path` | Path relative to project root | `Edit(/src/**/*.ts)` |
| `path` or `./path` | Path relative to current directory | `Read(*.env)` |

Note: `*` matches files in a single directory; `**` matches recursively across directories.

### Example Settings Configuration

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git commit *)",
      "Bash(git * main)",
      "Bash(* --version)",
      "Bash(* --help *)"
    ],
    "deny": [
      "Bash(git push *)"
    ]
  }
}
```

### Working Directories

Extend Claude's file access:
- **During startup**: `--add-dir <path>` CLI argument
- **During session**: `/add-dir` command
- **Persistent**: add to `additionalDirectories` in settings files

### Managed Settings (Organizational Policies)

Settings that cannot be overridden by user or project settings:

| Setting | Description |
|---------|-------------|
| `disableBypassPermissionsMode` | Set to `"disable"` to prevent `bypassPermissions` mode |
| `allowManagedPermissionRulesOnly` | Only rules in managed settings apply |
| `allowManagedHooksOnly` | Only managed and SDK hooks are allowed |
| `allowManagedMcpServersOnly` | Only managed MCP servers are respected |
| `blockedMarketplaces` | Blocklist of plugin marketplace sources |
| `sandbox.network.allowManagedDomainsOnly` | Only managed domain allowlists apply |
| `strictKnownMarketplaces` | Controls which plugin marketplaces users can add |
| `allow_remote_sessions` | Control whether users can start remote/web sessions |

### Settings Precedence

From highest to lowest priority:
1. Managed settings
2. Command line arguments
3. Local project settings
4. Shared project settings
5. User settings

## Usage Examples

### Viewing and Managing Permissions

```text
/permissions
```
Lists all permission rules and the settings.json file they are sourced from.

### Configuring a Read-Only Agent

```json
{
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Edit", "Write", "Bash"]
  }
}
```

### Restricting Network Access

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:github.com)",
      "WebFetch(domain:docs.example.com)"
    ],
    "deny": [
      "Bash(curl *)",
      "Bash(wget *)"
    ]
  }
}
```

### Disabling Specific Subagents

```json
{
  "permissions": {
    "deny": ["Agent(Explore)", "Agent(my-custom-agent)"]
  }
}
```

### CLI with Bypass Permissions (for Containers/CI)

```bash
claude -p "Run all tests and fix failures" \
  --allowedTools "Bash,Read,Edit" \
  --dangerously-skip-permissions
```

### Extending Permissions with Hooks

PreToolUse hooks can evaluate permissions at runtime:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "./scripts/validate-command.sh" }
        ]
      }
    ]
  }
}
```
Hook exit code 2 blocks the operation; exit code 0 allows it.

## Important Details

### Security Best Practices

- **Review all suggested changes** before approval
- **Use project-specific permission settings** for sensitive repositories
- **Consider using devcontainers** for additional isolation
- **Regularly audit permissions** with `/permissions`
- **Use managed settings** to enforce organizational standards
- **Share approved permission configurations** through version control
- **Never commit API keys** directly to repositories
- **Avoid piping untrusted content** directly to Claude
- **Use VMs** for scripts interacting with external web services

### Permissions and Sandboxing Are Complementary

- **Permissions** control which tools Claude Code can use and which files/domains it can access (applies to all tools)
- **Sandboxing** provides OS-level enforcement that restricts bash tool's filesystem and network access (applies only to Bash commands)
- Use both for defense-in-depth: permissions block attempts, sandboxing prevents bypasses

### Bash Permission Pattern Limitations

Patterns constraining command arguments are fragile. For example, `Bash(curl http://github.com/ *)` won't match:
- Options before URL: `curl -X GET http://github.com/...`
- Different protocol: `curl https://github.com/...`
- Redirects, variables, extra spaces

For reliable URL filtering, use deny rules to block `curl`/`wget` and use `WebFetch(domain:...)` for allowed domains.

### Bash Wildcard Behavior

The space before `*` matters:
- `Bash(ls *)` matches `ls -la` but NOT `lsof` (enforces word boundary)
- `Bash(ls*)` matches both `ls -la` AND `lsof` (no word boundary)

Claude Code is aware of shell operators (like `&&`), so `Bash(safe-cmd *)` won't permit `safe-cmd && other-cmd`.

### Prompt Injection Protections

- **Permission system**: sensitive operations require explicit approval
- **Context-aware analysis**: detects harmful instructions
- **Input sanitization**: prevents command injection
- **Command blocklist**: blocks risky commands like `curl` and `wget` by default
- **Network request approval**: tools making network requests require approval
- **Isolated context windows**: web fetch uses separate context
- **Trust verification**: first-time codebases and new MCP servers require verification
- **Command injection detection**: suspicious commands require manual approval
- **Fail-closed matching**: unmatched commands default to requiring approval
- **Natural language descriptions**: complex bash commands include explanations

### MCP Security

- The list of allowed MCP servers is configured in source code as part of Claude Code settings
- Write your own MCP servers or use servers from trusted providers
- Anthropic does not manage or audit any MCP servers
- You can configure Claude Code permissions for MCP servers

### Cloud Execution Security

When using Claude Code on the web:
- Isolated VMs for each session
- Network access limited/configurable
- Credential protection through secure proxy
- Git push restricted to current working branch
- Audit logging for all operations
- Automatic cleanup after session completion

### Reporting Security Issues

Report vulnerabilities through Anthropic's [HackerOne program](https://hackerone.com/anthropic-vdp/reports/new?type=team&report_type=vulnerability). Include detailed reproduction steps and allow time for remediation before disclosure.

## References

- [Configure Permissions](https://code.claude.com/docs/en/permissions) -- Full permissions documentation including rule syntax, modes, managed settings, and examples
- [Security](https://code.claude.com/docs/en/security) -- Security safeguards, prompt injection protections, and best practices
- [Sandboxing](https://code.claude.com/docs/en/sandboxing) -- Filesystem and network isolation for bash commands
- [Settings](https://code.claude.com/docs/en/settings) -- Complete configuration reference including permission settings
- [Hooks](https://code.claude.com/docs/en/hooks) -- Automate workflows and extend permission evaluation with hooks
- [Anthropic Trust Center](https://trust.anthropic.com) -- SOC 2 Type 2 report, ISO 27001 certificate, and other security resources
