# Sandboxing

## Overview

Claude Code features native OS-level sandboxing that provides filesystem and network isolation for bash commands, reducing the need for constant permission prompts while maintaining security. The sandbox uses Seatbelt on macOS and bubblewrap on Linux/WSL2, enforcing restrictions not just on Claude Code's direct interactions but also on all scripts, programs, and subprocesses spawned by commands. Sandboxing reduced permission prompts by 84% while maintaining security boundaries.

## Key Capabilities

- **Filesystem isolation**: By default, read and write access to the current working directory and its subdirectories. Read access to the entire computer except certain denied directories. Cannot modify files outside the current working directory without explicit permission.
- **Network isolation**: Only approved domains can be accessed. Network traffic passes through a proxy server running outside the sandbox via a unix domain socket. New domain requests trigger permission prompts.
- **OS-level enforcement**: Uses macOS Seatbelt and Linux bubblewrap — kernel-level enforcement that applies to all child processes.
- **Two sandbox modes**: Auto-allow mode (sandboxed commands run automatically without permission) and Regular permissions mode (all commands go through standard permission flow even when sandboxed).
- **Configurable boundaries**: Define custom allowed/denied paths and domains through settings.
- **Protection against prompt injection**: Even if an attacker manipulates Claude's behavior, the sandbox prevents modification of critical config files, data exfiltration, malicious downloads, and unauthorized API calls.
- **Open source runtime**: The sandbox runtime is available as an open source npm package (`@anthropic-ai/sandbox-runtime`) for use in other agent projects.

## Configuration / Setup

### Prerequisites

**macOS**: Works out of the box using the built-in Seatbelt framework. Enabled by default since Claude Code v1.0.20.

**Linux/WSL2**: Install required packages:
```bash
# Ubuntu/Debian
sudo apt-get install bubblewrap socat

# Fedora
sudo dnf install bubblewrap socat
```

**WSL1**: Not supported (bubblewrap requires kernel features only available in WSL2).

### Enable Sandboxing
Run `/sandbox` in Claude Code to open the mode selection menu.

### Sandbox Modes

| Mode | Behavior |
|------|----------|
| **Auto-allow** | Sandboxed bash commands run automatically without permission. Commands that cannot be sandboxed (e.g., needing non-allowed network hosts) fall back to regular permission flow. Explicit ask/deny rules are always respected. |
| **Regular permissions** | All bash commands go through standard permission flow, even when sandboxed. More control but more approvals needed. |

In both modes, the sandbox enforces the same filesystem and network restrictions. Auto-allow works independently of your permission mode setting.

### Filesystem Configuration
```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.kube", "//tmp/build"],
      "denyWrite": ["//etc"],
      "denyRead": ["~/.aws/credentials"]
    }
  }
}
```

**Path prefix conventions**:
| Prefix | Meaning | Example |
|--------|---------|---------|
| `//` | Absolute path from filesystem root | `//tmp/build` becomes `/tmp/build` |
| `~/` | Relative to home directory | `~/.kube` becomes `$HOME/.kube` |
| `/` | Relative to settings file directory | `/build` becomes `$SETTINGS_DIR/build` |
| `./` or no prefix | Relative path | `./output` |

When `allowWrite`, `denyWrite`, or `denyRead` is defined in multiple settings scopes, arrays are **merged** (combined, not replaced).

### Network Configuration
```json
{
  "sandbox": {
    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org"],
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": true,
      "allowAllUnixSockets": false,
      "httpProxyPort": 8080,
      "socksProxyPort": 8081,
      "allowManagedDomainsOnly": false
    }
  }
}
```

### Additional Settings
```json
{
  "sandbox": {
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker"],
    "enableWeakerNestedSandbox": false,
    "allowUnsandboxedCommands": false
  }
}
```
- `excludedCommands`: Commands that always run outside the sandbox (e.g., `docker` which is incompatible).
- `allowUnsandboxedCommands`: Set to `false` to disable the escape hatch that allows commands to retry outside the sandbox.
- `enableWeakerNestedSandbox`: Enables sandbox in Docker environments without privileged namespaces — considerably weakens security.

## Usage Examples

**Basic sandbox enable**:
```
/sandbox
```

**Grant write access to kubectl config**:
```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.kube"]
    }
  }
}
```

**Enterprise: Custom proxy for HTTPS inspection**:
```json
{
  "sandbox": {
    "network": {
      "httpProxyPort": 8080,
      "socksProxyPort": 8081
    }
  }
}
```

**Sandbox other programs (open source runtime)**:
```bash
npx @anthropic-ai/sandbox-runtime <command-to-sandbox>
```

## Important Details

- **How sandboxing relates to permissions**: Permissions control which tools Claude can use (applies to all tools). Sandboxing provides OS-level enforcement for Bash commands and their child processes. Both are complementary security layers — use both for defense-in-depth.
- **Escape hatch**: When a command fails due to sandbox restrictions, Claude may retry with `dangerouslyDisableSandbox`, which then goes through the normal permission flow. Disable with `"allowUnsandboxedCommands": false`.
- **Incompatible tools**: `watchman` is incompatible (use `jest --no-watchman`). `docker` is incompatible (add to `excludedCommands`). Some CLI tools need specific domain access — they will request permission on first use.
- **Performance**: Minimal overhead, less than 15ms of added latency. Some filesystem operations may be slightly slower.
- **Security limitations**:
  - Network filtering operates at the domain level; it does not inspect traffic content.
  - Broad domains like `github.com` may allow data exfiltration. Domain fronting may bypass filtering.
  - `allowUnixSockets` can grant access to powerful system services (e.g., Docker socket).
  - Overly broad filesystem write permissions can enable privilege escalation.
  - `enableWeakerNestedSandbox` considerably weakens security.
- **Notification on violation**: When Claude attempts to access resources outside the sandbox, the operation is blocked at the OS level, you receive an immediate notification, and you can deny, allow once, or permanently update configuration.
- **Native Windows support**: Planned but not yet available (use WSL2 on Windows).

## References

- [Sandboxing](https://code.claude.com/docs/en/sandboxing) — Official documentation
- [Making Claude Code More Secure and Autonomous](https://www.anthropic.com/engineering/claude-code-sandboxing) — Anthropic engineering blog post on sandboxing architecture
- [Sandbox Runtime (GitHub)](https://github.com/anthropic-experimental/sandbox-runtime) — Open source sandbox runtime package
- [Sandboxing Claude Code on macOS](https://www.infralovers.com/blog/2026-02-15-sandboxing-claude-code-macos/) — Community guide on macOS sandboxing
