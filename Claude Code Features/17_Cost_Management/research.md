# Cost Management

## Overview

Claude Code consumes tokens for each interaction. Costs vary based on codebase size, query complexity, and conversation length. According to Anthropic, the average cost is approximately $6 per developer per day, with daily costs remaining below $12 for 90% of users. For team usage with Sonnet 4.6, Claude Code costs approximately $100-200 per developer per month, though there is large variance depending on usage patterns and whether automation is involved.

## Key Capabilities

- **Real-time cost tracking**: Use the `/cost` command to see token usage statistics for the current session.
- **Automatic prompt caching**: Claude Code automatically caches repeated content like system prompts to reduce costs.
- **Auto-compaction**: Conversation history is automatically summarized when approaching context limits.
- **Model switching**: Switch between Opus (most capable, most expensive), Sonnet (balanced), and Haiku (cheapest) models mid-session.
- **Workspace spend limits**: Set organization-level spend limits through the Claude Console.
- **Per-user rate limiting**: Configure Token Per Minute (TPM) and Request Per Minute (RPM) limits by team size.
- **Context management**: Multiple strategies to keep context small and reduce per-message costs.
- **Extended thinking control**: Adjust or disable thinking tokens to reduce output token billing.

## Configuration / Setup

### Tracking Costs

Use `/cost` to view current session statistics (relevant for API users; Claude Max and Pro subscribers should use `/stats` instead):

```
Total cost:            $0.55
Total duration (API):  6m 19.7s
Total duration (wall): 6h 33m 10.2s
Total code changes:    0 lines added, 0 lines removed
```

You can also configure the status line to display context window usage continuously.

### Setting Workspace Spend Limits

When using the Claude API, set workspace spend limits through the Anthropic Console. A workspace called "Claude Code" is automatically created when you first authenticate. Admins can view cost and usage reporting in the Console.

### Rate Limit Recommendations by Team Size

| Team size | TPM per user | RPM per user |
|-----------|-------------|-------------|
| 1-5 users | 200k-300k | 5-7 |
| 5-20 users | 100k-150k | 2.5-3.5 |
| 20-50 users | 50k-75k | 1.25-1.75 |
| 50-100 users | 25k-35k | 0.62-0.87 |
| 100-500 users | 15k-20k | 0.37-0.47 |
| 500+ users | 10k-15k | 0.25-0.35 |

TPM per user decreases as team size grows because fewer users tend to use Claude Code concurrently in larger organizations. These rate limits apply at the organization level, not per individual user.

### Adjusting Extended Thinking

Extended thinking is enabled by default with a budget of 31,999 tokens. To reduce costs on simpler tasks:

- Lower the effort level in `/model` for Opus 4.6 (low, medium, high).
- Disable thinking in `/config`.
- Set a lower budget: `MAX_THINKING_TOKENS=8000`.
- Set effort via environment variable: `CLAUDE_CODE_EFFORT_LEVEL=low|medium|high`.

### Third-Party Cost Tracking

On Bedrock, Vertex, and Foundry, Claude Code does not send metrics from your cloud. Enterprises can use LiteLLM (open-source, unaffiliated with Anthropic) to track spend by key.

## Usage Examples

### Managing Context Proactively

```bash
# Check current token usage
/cost

# Clear context between unrelated tasks
/clear

# Compact with focus instructions
/compact Focus on code samples and API usage

# Rename sessions for easy resumption
/rename oauth-migration
```

### Customizing Compaction in CLAUDE.md

```markdown
# Compact instructions

When you are using compact, please focus on test output and code changes
```

### Choosing the Right Model

```bash
# Switch models mid-session
/model sonnet    # For most coding tasks (cheaper)
/model opus      # For complex architectural decisions
/model haiku     # For simple tasks (cheapest)
```

### Reducing MCP Server Overhead

```bash
# Check what's consuming context space
/context

# View and disable unused MCP servers
/mcp

# Set a lower tool search threshold
ENABLE_TOOL_SEARCH=auto:5  # Triggers when tools exceed 5% of context
```

### Using Hooks to Filter Output

A PreToolUse hook can preprocess data before Claude sees it, reducing context from tens of thousands of tokens to hundreds:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/filter-test-output.sh"
          }
        ]
      }
    ]
  }
}
```

### Delegating to Subagents

Delegate verbose operations (tests, documentation fetching, log processing) to subagents so verbose output stays in the subagent's context while only a summary returns to the main conversation.

```
Use subagents to investigate how our authentication system handles token
refresh, and whether we have any existing OAuth utilities I should reuse.
```

### Writing Specific Prompts

Vague requests trigger broad scanning and consume more tokens:
- Bad: "improve this codebase"
- Good: "add input validation to the login function in auth.ts"

## Important Details

### How Token Costs Scale

Token costs scale with context size: the more context Claude processes, the more tokens you use. Every message, file read, command output, and tool result adds to the context window.

### Background Token Usage

Claude Code uses tokens for some background functionality even when idle:
- **Conversation summarization**: Background jobs for the `claude --resume` feature.
- **Command processing**: Some commands like `/cost` may generate requests to check status.
- These background processes consume a small amount of tokens, typically under $0.04 per session.

### Agent Team Costs

Agent teams use approximately 7x more tokens than standard sessions when teammates run in plan mode, because each teammate maintains its own context window. To manage costs:
- Use Sonnet for teammates (balances capability and cost).
- Keep teams small (token usage is roughly proportional to team size).
- Keep spawn prompts focused.
- Clean up teams when work is done (active teammates continue consuming tokens even if idle).

### Cost Optimization Strategies Summary

1. **Clear between tasks**: Use `/clear` when switching to unrelated work.
2. **Choose the right model**: Sonnet for most tasks, Opus for complex reasoning, Haiku for simple tasks and subagents.
3. **Reduce MCP server overhead**: Disable unused servers, prefer CLI tools.
4. **Install code intelligence plugins**: Reduces unnecessary file reads for typed languages.
5. **Use hooks to preprocess data**: Filter large outputs before Claude sees them.
6. **Move specialized instructions to skills**: Keep CLAUDE.md under ~500 lines; skills load on demand.
7. **Delegate verbose operations to subagents**: Keep verbose output out of main context.
8. **Write specific prompts**: Avoid broad scanning.
9. **Use plan mode for complex tasks**: Press Shift+Tab before implementation to prevent expensive re-work.
10. **Course-correct early**: Press Escape to stop immediately if Claude goes in the wrong direction.
11. **Test incrementally**: Write one file, test it, then continue.

### Prompt Caching

Claude Code automatically uses prompt caching to optimize performance and reduce costs. You can disable it with environment variables:
- `DISABLE_PROMPT_CACHING=1` -- Disable for all models.
- `DISABLE_PROMPT_CACHING_HAIKU=1` -- Disable for Haiku only.
- `DISABLE_PROMPT_CACHING_SONNET=1` -- Disable for Sonnet only.
- `DISABLE_PROMPT_CACHING_OPUS=1` -- Disable for Opus only.

### 1M Context Window Pricing

Selecting a 1M model does not immediately change billing. Sessions use standard rates until they exceed 200K tokens of context. Beyond 200K tokens, requests are charged at long-context pricing with dedicated rate limits.

### Cost-Related Environment Variables

- `DISABLE_COST_WARNINGS` -- Disable cost warnings.
- `MAX_THINKING_TOKENS` -- Set maximum thinking token budget.
- `CLAUDE_CODE_EFFORT_LEVEL` -- Set effort level (low/medium/high).
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS` -- Max output tokens (default: 32000, max: 64000).

## References

- [Manage costs effectively](https://code.claude.com/docs/en/costs) -- Official Claude Code documentation on cost management
- [Model configuration](https://code.claude.com/docs/en/model-config) -- Model selection and configuration options
- [Claude Code Settings](https://code.claude.com/docs/en/settings) -- Settings reference including cost-related environment variables
- [Reduce token usage](https://code.claude.com/docs/en/costs#reduce-token-usage) -- Detailed strategies for reducing token consumption
