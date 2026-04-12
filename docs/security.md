# Security Model: Serious Sidekick Update Pipeline

## Manifest Integrity Model

### What SHA-256 hashes protect against

The `manifest.json` file contains SHA-256 hashes for template-tier files. `bin/serious-update` verifies these hashes before copying files to user machines. This protects against:

- **Accidental file corruption** during transfer or disk errors
- **Build race conditions** where a file is modified between manifest generation and the update copy
- **Incomplete updates** where only some files were written before an interruption

### What SHA-256 hashes do NOT protect against

The manifest hashes live in the same repository as the files they protect. This means they **do not protect against repo-level tampering**. An attacker who can modify files in the repo can also modify the manifest to match.

Specifically, in-repo hashes **cannot defend** against:

- A malicious commit that modifies both a source file and its manifest hash
- A compromised CI pipeline that regenerates the manifest after injecting code
- A maintainer account compromise that pushes tampered files with correct hashes

### Future work: out-of-band trust anchor

A full supply-chain mitigation requires an **out-of-band trust anchor** that is not stored in the same repository:

- **Signed release tags** using GPG keys stored outside the repo
- **Pinned commit SHAs** published via a separate, independently-verified channel
- **Reproducible builds** where users can verify the build output matches a known-good state

This is acknowledged future work and is not implemented in the current version.

## Template Key Allowlist

The `merge_settings` function in `lib/serious-common.sh` enforces a top-level key allowlist for template `settings.json` files. Only these keys are permitted:

| Key | Purpose |
|-----|---------|
| `hooks` | Claude Code lifecycle hooks (PreToolUse, PostToolUse, Stop) |
| `permissions` | File and command permission rules |
| `env` | Environment variable configuration |
| `statusLine` | Status bar command configuration |

Templates containing any key not in this allowlist are rejected with an error. This prevents an attacker from injecting arbitrary configuration keys (e.g., malicious plugins, backdoor settings) via a tampered template.

### Why each key is allowed

- **`hooks`**: Core functionality -- all serious-owned quality gates are hooks.
- **`permissions`**: Needed for security policy enforcement (allow/deny rules).
- **`env`**: Standard Claude Code configuration for environment variables.
- **`statusLine`**: Required for the live status line feature (Plan 4b cross-plan coordination).

### Allowlist governance

The allowlist is defined as `ALLOWED_TOP_LEVEL_KEYS` in `lib/serious-common.sh`. Adding a new key requires:

1. A justified use case
2. Updating the allowlist constant
3. Updating the governance test in `tests/test_supply_chain.sh` (which asserts the exact set)
4. Updating this documentation

## Ownership Pinning

The `parse_manifest` function enforces that `.claude/settings.json` must always be `merge`-tier with `merge_key=hooks`. A manifest that attempts to change this to `template` tier (which would overwrite user settings wholesale) is rejected.

## Hook Command Validation

The `is_serious()` function validates hook commands against a strict regex pattern:
```
^bash "$CLAUDE_PROJECT_DIR/.claude/skills/serious-[a-z-]+/hooks/[a-z0-9._-]+\.sh"$
```

This prevents:
- Rogue skill directories (e.g., `serious-evil`)
- Path traversal after `/hooks/` (e.g., `../../../../tmp/evil.sh`)
- Command chaining after the closing quote (e.g., `legit.sh" && curl evil`)
