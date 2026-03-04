# Multi-Model Support

## Overview

Claude Code supports multiple Claude models with different tradeoffs for capability, speed, and cost. You can switch models mid-session, set defaults via configuration or environment variables, and use special model aliases like `opusplan` for hybrid workflows. Model selection is one of the primary levers for optimizing your Claude Code experience across different types of tasks.

## Key Capabilities

- **Multiple model tiers**: Opus (most capable), Sonnet (balanced), and Haiku (fast and efficient) are all available.
- **Model aliases**: Convenient shortcuts (`opus`, `sonnet`, `haiku`, `default`, `opusplan`, `sonnet[1m]`) that always resolve to the latest version.
- **Mid-session switching**: Use `/model` to change models without restarting.
- **Hybrid `opusplan` mode**: Automatically uses Opus during plan mode and Sonnet during execution.
- **Effort level control**: Adjust Opus 4.6's adaptive reasoning (low, medium, high) to balance depth vs. speed/cost.
- **Extended context**: Opus 4.6 and Sonnet 4.6 support 1 million token context windows for long sessions.
- **Enterprise model restrictions**: Administrators can restrict available models with `availableModels`.
- **Third-party provider support**: Pin model versions for Bedrock, Vertex AI, and Foundry deployments.

## Configuration / Setup

### Setting Your Model

Models can be configured in several ways, listed in order of priority (highest first):

1. **During session**: `/model <alias|name>` to switch mid-session.
2. **At startup**: `claude --model <alias|name>`.
3. **Environment variable**: `ANTHROPIC_MODEL=<alias|name>`.
4. **Settings file**: Set `"model"` field in settings.json.

### Model Aliases

| Alias | Behavior |
|-------|----------|
| `default` | Recommended model based on account type |
| `sonnet` | Latest Sonnet model (currently Sonnet 4.6) for daily coding tasks |
| `opus` | Latest Opus model (currently Opus 4.6) for complex reasoning tasks |
| `haiku` | Fast and efficient Haiku model for simple tasks |
| `sonnet[1m]` | Sonnet with 1 million token context window for long sessions |
| `opusplan` | Uses Opus during plan mode, switches to Sonnet for execution |

Aliases always point to the latest version. To pin to a specific version, use the full model name (e.g., `claude-opus-4-6`) or the corresponding environment variable.

### Current Model Names

- Opus 4.6: `claude-opus-4-6`
- Sonnet 4.6: `claude-sonnet-4-6`
- Opus 4.5: `claude-opus-4-5-20251101`
- Sonnet 4.5: `claude-sonnet-4-5-20250929`
- Haiku 4.5: `claude-haiku-4-5-20251001`

### Default Model Behavior by Account Type

| Account Type | Default Model |
|-------------|--------------|
| Max and Team Premium | Opus 4.6 |
| Pro and Team Standard | Sonnet 4.6 |
| Enterprise | Opus 4.6 available but not the default |

Claude Code may automatically fall back to Sonnet if you hit a usage threshold with Opus.

### Environment Variables for Model Configuration

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_MODEL` | Override the default model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Model for `opus` alias (or `opusplan` in plan mode) |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Model for `sonnet` alias (or `opusplan` in execution mode) |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Model for `haiku` alias and background functionality |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Model for subagents |

Note: `ANTHROPIC_SMALL_FAST_MODEL` is deprecated in favor of `ANTHROPIC_DEFAULT_HAIKU_MODEL`.

### Settings File Configuration

```json
{
  "model": "opus",
  "availableModels": ["sonnet", "haiku"]
}
```

## Usage Examples

### Starting with a Specific Model

```bash
# Start with Opus
claude --model opus

# Start with Sonnet
claude --model sonnet

# Start with a specific version
claude --model claude-opus-4-6
```

### Switching Models Mid-Session

```
/model sonnet     # Switch to Sonnet
/model opus       # Switch to Opus
/model haiku      # Switch to Haiku
/model opusplan   # Switch to hybrid Opus/Sonnet mode
```

### Using the OpusPlan Hybrid Mode

The `opusplan` alias provides an automated hybrid approach:
- **In plan mode**: Uses Opus for complex reasoning and architecture decisions.
- **In execution mode**: Automatically switches to Sonnet for code generation and implementation.

```
/model opusplan
```

### Adjusting Effort Level

Effort levels control Opus 4.6's adaptive reasoning:

- **In `/model`**: Use left/right arrow keys to adjust the effort slider.
- **Environment variable**: `CLAUDE_CODE_EFFORT_LEVEL=low|medium|high`
- **Settings**: Set `"effortLevel"` in settings file.

Three levels: **low** (faster, cheaper), **medium**, **high** (default, deeper reasoning).

### Using Extended Context (1M Tokens)

```bash
# Use the 1M alias
/model sonnet[1m]

# Or append [1m] to a full model name
/model claude-sonnet-4-6[1m]
```

Extended context is available for:
- API and pay-as-you-go users: full access.
- Pro, Max, Teams, and Enterprise subscribers: available with extra usage enabled.

Standard rates apply until 200K tokens; beyond that, long-context pricing applies.

To disable 1M context: `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`.

### Restricting Models for Enterprise Teams

```json
{
  "model": "sonnet",
  "availableModels": ["sonnet", "haiku"]
}
```

When `availableModels` is set, users cannot switch to models not in the list. The "Default" option always remains available.

### Pinning Models for Third-Party Providers

For Bedrock, Vertex AI, or Foundry deployments, pin model versions to prevent breakage when Anthropic releases new models:

```bash
# Bedrock example
export ANTHROPIC_DEFAULT_OPUS_MODEL='us.anthropic.claude-opus-4-6-v1'
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6-v1'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1'

# Vertex AI example
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='claude-haiku-4-5-20251001'
```

### Configuring Subagent Models

For subagents that handle simpler tasks, specify a cheaper model:

```bash
export CLAUDE_CODE_SUBAGENT_MODEL='claude-haiku-4-5-20251001'
```

Or configure in subagent definition files:
```markdown
---
model: haiku
---
```

## Important Details

### When to Use Each Model

| Model | Best For | Tradeoffs |
|-------|----------|-----------|
| **Opus** | Complex architectural decisions, multi-step reasoning, difficult debugging, large refactors | Most capable but most expensive and slower |
| **Sonnet** | Daily coding tasks, most development work, code generation, implementation | Good balance of capability, speed, and cost |
| **Haiku** | Simple tasks, quick answers, background operations, subagent tasks | Fastest and cheapest, less capable for complex reasoning |
| **OpusPlan** | Complex features requiring both deep planning and efficient implementation | Combines Opus reasoning with Sonnet efficiency |

### Adaptive Reasoning (Opus 4.6)

Opus 4.6 supports adaptive reasoning (also called extended thinking) which dynamically allocates thinking based on task complexity. The effort level slider controls this:

- **Low**: Faster and cheaper for straightforward tasks.
- **Medium**: Balanced.
- **High** (default): Deeper reasoning for complex problems.

Extended thinking is enabled by default with a budget of 31,999 tokens. Thinking tokens are billed as output tokens.

To disable adaptive reasoning and revert to fixed thinking budget: `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`. When disabled, models use the budget controlled by `MAX_THINKING_TOKENS`.

### Prompt Caching Configuration

Prompt caching is automatic but can be disabled per model:

| Variable | Effect |
|----------|--------|
| `DISABLE_PROMPT_CACHING` | Disable for all models (takes precedence) |
| `DISABLE_PROMPT_CACHING_HAIKU` | Disable for Haiku only |
| `DISABLE_PROMPT_CACHING_SONNET` | Disable for Sonnet only |
| `DISABLE_PROMPT_CACHING_OPUS` | Disable for Opus only |

### Checking Your Current Model

- View in the status line (if configured).
- Run `/status` to see your current model and account information.

### Model Restriction Merge Behavior

When `availableModels` is set at multiple levels (user and project settings), arrays are merged and deduplicated. To enforce a strict allowlist, set `availableModels` in managed or policy settings which take highest priority.

### Fast Mode

For Opus 4.6, fast mode (research preview) can provide up to 2.5x higher output speed at premium pricing. It uses the same model with faster output, not a different model. Toggle fast mode with `/fast`.

Settings: `fastModePerSessionOptIn` requires per-session opt-in. Environment variable: `CLAUDE_CODE_DISABLE_FAST_MODE=1` to disable.

## References

- [Model Configuration](https://code.claude.com/docs/en/model-config) -- Official documentation on model aliases, settings, effort levels, and extended context
- [Claude Code Model Configuration (Help Center)](https://support.claude.com/en/articles/11940350-claude-code-model-configuration) -- Model configuration help article
- [Choosing the Right Model](https://platform.claude.com/docs/en/about-claude/models/choosing-a-model) -- Anthropic's guide to choosing between Claude models
- [Claude Code Settings](https://code.claude.com/docs/en/settings) -- Settings reference including model-related options
- [Manage Costs](https://code.claude.com/docs/en/costs) -- Cost implications of model selection
