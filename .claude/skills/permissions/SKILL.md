---
name: permissions
description: "Auto-load when user asks about permissions, security, allow/deny rules, sandboxing, or permission modes in Claude Code"
---

# Permissions and Security

## Quick Reference
- **Three rule types**: Allow (auto-approve), Ask (prompt), Deny (block). Evaluation order: deny -> ask -> allow (deny always wins).
- **Five permission modes**: `default`, `acceptEdits`, `plan`, `dontAsk`, `bypassPermissions` -- set via `defaultMode` in settings.
- **Rule syntax**: `Tool` or `Tool(specifier)` -- e.g., `Bash(npm run *)`, `Read(./.env)`, `WebFetch(domain:example.com)`.
- **Wildcard `*`**: space before `*` enforces word boundary (`Bash(ls *)` matches `ls -la` but NOT `lsof`).
- **Path patterns**: `//path` = absolute, `~/path` = home-relative, `/path` = project-relative, `./path` = cwd-relative. Use `**` for recursive matching.
- **Settings precedence** (highest to lowest): managed settings > CLI args > local project > shared project > user settings.
- **Sandboxing** is separate from permissions -- it provides OS-level filesystem/network isolation for Bash commands only.
- **Fail-closed**: unmatched commands default to requiring manual approval.
- **View current rules**: run `/permissions` in an interactive session.
- **Managed settings** (`disableBypassPermissionsMode`, `allowManagedPermissionRulesOnly`, etc.) let orgs enforce policies that users cannot override.

## Configuration

**Basic permission rules in settings.json:**
```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git commit *)",
      "Bash(* --version)",
      "Bash(* --help *)"
    ],
    "deny": [
      "Bash(git push *)"
    ]
  }
}
```

**Read-only agent:**
```json
{
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Edit", "Write", "Bash"]
  }
}
```

**Restrict network access (deny curl/wget, allow specific domains):**
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

**Deny specific subagents:**
```json
{
  "permissions": {
    "deny": ["Agent(Explore)", "Agent(my-custom-agent)"]
  }
}
```

**Extend file access with additional directories:**
- CLI: `--add-dir <path>`
- Session: `/add-dir`
- Persistent: `additionalDirectories` in settings

**Extend permissions with PreToolUse hooks** (exit code 0 = allow, exit code 2 = deny):
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

## Common Patterns

1. **CI/CD with bypass permissions** (containers/VMs only):
   ```bash
   claude -p "Run all tests and fix failures" \
     --allowedTools "Bash,Read,Edit" \
     --dangerously-skip-permissions
   ```

2. **Org-wide managed settings** that cannot be overridden:
   - `disableBypassPermissionsMode`: prevent users from using `bypassPermissions`
   - `allowManagedPermissionRulesOnly`: only managed permission rules apply
   - `allowManagedHooksOnly` / `allowManagedMcpServersOnly`: restrict hooks and MCP servers

3. **Fine-grained MCP tool permissions**: `mcp__puppeteer__puppeteer_navigate` matches a specific MCP tool by its fully qualified name.

## Gotchas
- **Bash pattern fragility**: `Bash(curl http://github.com/ *)` won't match options before URL, different protocols, or redirects. Use deny rules for curl/wget and `WebFetch(domain:...)` for reliable URL filtering.
- **Shell operator awareness**: Claude Code detects `&&`, so `Bash(safe-cmd *)` won't permit `safe-cmd && malicious-cmd`.
- **Write access restriction**: Claude can only write to the folder where it was started and subfolders.
- **`dontAsk` mode** auto-denies tools unless pre-approved via `/permissions` or `permissions.allow` rules -- not the same as `bypassPermissions`.
- **First-time codebase runs** and new MCP servers require manual trust verification regardless of permission rules.
- **`bypassPermissions`** should only be used in isolated environments (containers, VMs) -- never on a developer workstation with real data.

@./Claude Code Features/10_Permissions_and_Security/research.md
