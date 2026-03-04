# Fast Mode

## Overview

Fast mode is a high-speed configuration for Claude Opus 4.6 within Claude Code, making the model approximately 2.5x faster at a higher cost per token. It is not a different model -- it uses the same Opus 4.6 with a different API configuration that prioritizes speed over cost efficiency. Quality and capabilities remain identical; only latency and pricing change. Fast mode is currently in research preview.

## Key Capabilities

- **2.5x faster responses**: Same Opus 4.6 model with a speed-optimized API configuration.
- **Identical quality**: No change in reasoning, code generation, or tool use capabilities.
- **Simple toggle**: Enable or disable with `/fast` in CLI or VS Code extension.
- **Visual indicator**: A `lightning bolt` icon appears next to the prompt when fast mode is active.
- **Automatic rate limit fallback**: When fast mode rate limits are hit, it falls back to standard Opus 4.6 automatically and re-enables when cooldown expires.
- **Persistent across sessions**: Once toggled on, fast mode stays on in future sessions until explicitly toggled off.
- **Compatible with 1M token extended context window**.
- **Combinable with effort level**: Use fast mode with a lower effort level for maximum speed on straightforward tasks.

## Configuration / Setup

### Toggling Fast Mode

- **CLI/VS Code**: Type `/fast` and press Tab to toggle on or off.
- **Settings file**: Set `"fastMode": true` in your user settings file.

When enabled:
- If you are on a different model, Claude Code automatically switches to Opus 4.6.
- A confirmation message "Fast mode ON" is displayed.
- A small `lightning bolt` icon appears next to the prompt.
- Run `/fast` again to check whether fast mode is currently on or off.

When disabled:
- You remain on Opus 4.6 (the model does not revert to your previous model).
- Use `/model` to switch to a different model if desired.

### Requirements

- **Not available on third-party cloud providers**: Fast mode is not available on Amazon Bedrock, Google Vertex AI, or Microsoft Azure Foundry. Only available through the Anthropic Console API and Claude subscription plans.
- **Extra usage must be enabled**: Fast mode tokens are billed directly to extra usage, even if you have remaining plan usage. For individual accounts, enable in Console billing settings. For Teams/Enterprise, an admin must enable extra usage for the organization.
- **Admin enablement for Teams/Enterprise**: Fast mode is disabled by default for Teams and Enterprise orgs. An admin must explicitly enable it in Console or Claude AI admin settings.
- **To disable entirely**: Set `CLAUDE_CODE_DISABLE_FAST_MODE=1` as an environment variable.

### Per-Session Opt-In (Admin Setting)

Administrators on Teams or Enterprise plans can require fast mode to reset each session:

```json
{
  "fastModePerSessionOptIn": true
}
```

This prevents fast mode from persisting, requiring users to explicitly enable it with `/fast` each session. Useful for controlling costs when users run multiple concurrent sessions.

### Enabling for an Organization

Admins can enable fast mode in:
- **Console** (API customers): Claude Code preferences at `platform.claude.com/claude-code/preferences`
- **Claude AI** (Teams/Enterprise): Admin Settings > Claude Code at `claude.ai/admin-settings/claude-code`

## Pricing

Fast mode is priced at approximately 6x standard Opus rates:

| Mode                           | Input (per MTok) | Output (per MTok) |
|:-------------------------------|:-----------------|:------------------|
| Fast mode on Opus 4.6 (<200K)  | $30              | $150              |
| Fast mode on Opus 4.6 (>200K)  | $60              | $225              |

Important: Switching into fast mode mid-conversation charges the full fast mode uncached input token price for the entire conversation context. Enabling fast mode at the start of a session is more cost-efficient.

Fast mode usage is billed directly to extra usage and does not count against your plan's included usage.

## Usage Examples

**Toggle fast mode on for a rapid debugging session:**
```
/fast
> Fast mode ON
```

**Quick iteration cycle:**
```
/fast
Fix the null pointer exception in src/auth/handler.ts
[Fast response in ~10 seconds instead of ~25 seconds]
```

**Toggle off when done with interactive work:**
```
/fast
> Fast mode OFF
```

**Check current status:**
```
/fast
> Fast mode is currently: ON
```

## Important Details

### When to Use Fast Mode

**Best for:**
- Rapid iteration on code changes
- Live debugging sessions
- Time-sensitive work with tight deadlines
- Interactive work where response latency directly impacts productivity

**Better to use standard mode for:**
- Long autonomous tasks where speed matters less
- Batch processing or CI/CD pipelines
- Cost-sensitive workloads

### Fast Mode vs. Effort Level

| Setting            | Effect                                                                           |
|:-------------------|:---------------------------------------------------------------------------------|
| **Fast mode**      | Same model quality, lower latency, higher cost                                   |
| **Lower effort**   | Less thinking time, faster responses, potentially lower quality on complex tasks |

You can combine both for maximum speed on straightforward tasks.

### Rate Limit Behavior

When you hit the fast mode rate limit or run out of extra usage credits:
1. Fast mode automatically falls back to standard Opus 4.6.
2. The lightning bolt icon turns gray to indicate cooldown.
3. You continue working at standard speed and pricing.
4. When the cooldown expires, fast mode automatically re-enables.

To disable fast mode manually during cooldown, run `/fast` again.

### Research Preview Status

Fast mode is a research preview feature. The feature, pricing, and availability may change based on feedback.

## References

- [Speed up responses with fast mode - Claude Code Docs](https://code.claude.com/docs/en/fast-mode) -- Official documentation covering toggle, pricing, requirements, and rate limit behavior
- [Fast mode (research preview) - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/fast-mode) -- API-level documentation for fast mode
- [Fast mode for Claude Opus 4.6 - GitHub Copilot](https://github.blog/changelog/2026-02-07-claude-opus-4-6-fast-is-now-in-public-preview-for-github-copilot/) -- GitHub Copilot integration announcement
