---
name: fast-mode
description: "Auto-load when user asks about fast mode, speed, /fast toggle, faster responses, or response latency in Claude Code"
---

# Fast Mode (Research Preview)

## Quick Reference
- **Same Opus 4.6 model**, ~2.5x faster, ~6x higher cost per token. Quality and capabilities are identical.
- Toggle with `/fast` in CLI or VS Code. Persistent across sessions until toggled off.
- Lightning bolt icon appears next to the prompt when active.
- **Auto-fallback**: when fast mode rate limits are hit, falls back to standard Opus 4.6 automatically, re-enables after cooldown.
- **Pricing**: $30/$150 per MTok input/output (<200K context), $60/$225 per MTok (>200K context).
- **Billed to extra usage** -- does NOT count against plan's included usage. Extra usage must be enabled.
- **Not available** on third-party providers (Bedrock, Vertex AI, Azure Foundry).
- Compatible with 1M token extended context window.
- Can combine with lower effort level for maximum speed on simple tasks.

## Configuration

**Toggle on/off:**
```
/fast
```

**Enable via settings:**
```json
{
  "fastMode": true
}
```

**Disable entirely (env var):**
```bash
export CLAUDE_CODE_DISABLE_FAST_MODE=1
```

**Per-session opt-in (admin setting for Teams/Enterprise):**
```json
{
  "fastModePerSessionOptIn": true
}
```
This prevents fast mode from persisting -- users must `/fast` each session.

**Admin enablement:**
- Console (API): `platform.claude.com/claude-code/preferences`
- Claude AI (Teams/Enterprise): `claude.ai/admin-settings/claude-code`

## Common Patterns

1. **Rapid debugging session:**
   ```
   /fast
   Fix the null pointer exception in src/auth/handler.ts
   ```

2. **Toggle off for long autonomous tasks:**
   ```
   /fast
   ```
   Standard mode is more cost-effective for batch processing, CI/CD, or tasks where latency does not matter.

3. **Maximum speed on simple tasks** -- combine fast mode with lower effort level.

## Gotchas
- **Switching mid-conversation charges full uncached input price** for the entire conversation context at fast mode rates. Enable at the start of a session for cost efficiency.
- **Toggling off does NOT revert to your previous model** -- you stay on Opus 4.6. Use `/model` to switch.
- **Extra usage must be enabled** or fast mode will not work. For Teams/Enterprise, an admin must enable it.
- **Fast mode is disabled by default for Teams/Enterprise orgs** -- an admin must explicitly enable it.
- **Rate limit behavior**: lightning bolt turns gray during cooldown, you continue at standard speed/pricing, fast mode re-enables automatically when cooldown expires.
- **Research preview**: feature, pricing, and availability may change.

### Fast Mode vs Effort Level

| Setting | Effect |
|---------|--------|
| Fast mode | Same quality, lower latency, higher cost |
| Lower effort | Less thinking, faster responses, potentially lower quality on complex tasks |

Combine both for maximum speed on straightforward tasks.

@./Claude Code Features/29_Fast_Mode/research.md
