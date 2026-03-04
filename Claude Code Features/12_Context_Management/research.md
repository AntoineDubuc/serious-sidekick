# Context Management

## Overview

Claude Code operates within a finite context window that holds conversation history, file contents, command outputs, CLAUDE.md instructions, loaded skills, and system instructions. As you work, context fills up. Claude Code manages this automatically through auto-compaction, but understanding how context works helps you write more effective prompts, keep sessions productive, and reduce token costs. Context management also intersects with extended thinking, CLAUDE.md persistence, and features like subagents and skills.

## Key Capabilities

- **Automatic context management**: Claude Code automatically compacts when approaching context limits, clearing older tool outputs first, then summarizing the conversation
- **Manual compaction**: Use the `/compact` command to manually trigger compaction, optionally with focus instructions
- **Custom compaction instructions**: Guide what gets preserved during compaction via CLAUDE.md or `/compact` arguments
- **Context visualization**: Use `/context` to see a colored grid showing what is consuming context space
- **Extended thinking**: Enabled by default, gives Claude reasoning space before responding; configurable via effort levels
- **1M token context window**: Available in beta for Opus 4.6 and Sonnet 4.6, extending beyond the standard 200K limit
- **CLAUDE.md survives compaction**: CLAUDE.md files are re-read from disk and re-injected fresh after compaction
- **Skills load on demand**: Skill descriptions are visible at session start, but full content only loads when used
- **Subagents get separate context**: Subagent work does not bloat the main conversation's context
- **Targeted summarization via checkpoints**: Use `/rewind` (or Esc+Esc) to summarize from a specific point rather than compacting the entire conversation

## Configuration / Setup

### Viewing context usage

Run `/context` during a session to see what is consuming space. This shows a colored grid of context utilization.

You can also configure your status line to display context usage continuously:

```bash
# See statusline documentation for configuration
```

### Controlling compaction behavior

**Manual compaction with focus:**

```
/compact Focus on code samples and API usage
```

**Custom compaction instructions in CLAUDE.md:**

```markdown
# Compact instructions

When you are using compact, please focus on test output and code changes
```

### Configuring extended thinking

| Scope | How to configure | Details |
|-------|-----------------|---------|
| **Effort level** | Adjust in `/model` or set `CLAUDE_CODE_EFFORT_LEVEL` | Controls thinking depth for Opus 4.6: low, medium, high (default) |
| **Toggle shortcut** | Press `Option+T` (macOS) or `Alt+T` (Windows/Linux) | Toggle thinking on/off for the current session |
| **Global default** | Use `/config` to toggle thinking mode | Saved as `alwaysThinkingEnabled` in `~/.claude/settings.json` |
| **Limit token budget** | Set `MAX_THINKING_TOKENS` environment variable | Limit thinking budget to a specific number of tokens (e.g., `export MAX_THINKING_TOKENS=10000`) |
| **Disable adaptive thinking** | Set `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` | Reverts Opus 4.6 and Sonnet 4.6 to fixed thinking budget |

Setting `MAX_THINKING_TOKENS=0` disables thinking entirely on any model.

### Enabling 1M context window

Available for API and pay-as-you-go users (full access) and Pro/Max/Teams/Enterprise subscribers (with extra usage enabled).

```bash
# Use the model alias with 1m suffix
/model sonnet[1m]

# Or append [1m] to a full model name
/model claude-sonnet-4-6[1m]

# Disable 1M context entirely
export CLAUDE_CODE_DISABLE_1M_CONTEXT=1
```

Standard rates apply until the session exceeds 200K tokens. Beyond 200K, long-context pricing applies.

## Usage Examples

### Check what is consuming context

```
/context
```

### Manually compact with focus

```
/compact Focus on the API changes and test results
```

### Clear context between tasks

```
/clear
```

Use `/clear` when switching to unrelated work. Stale context wastes tokens on every subsequent message. Use `/rename` before clearing so you can find the session later.

### Targeted summarization with rewind

Press `Esc` twice (or use `/rewind`) to open the rewind menu. Select a message and choose "Summarize from here" to compress only the messages from that point forward, keeping earlier context in full detail. You can type optional instructions to guide what the summary focuses on.

### Reduce MCP server overhead

```
/mcp
```

Each MCP server adds tool definitions to context, even when idle. Run `/mcp` to see configured servers and disable unused ones. Use CLI tools (`gh`, `aws`, `gcloud`) instead of MCP servers when possible, as they do not add persistent tool definitions.

To trigger automatic tool search at a lower threshold:

```bash
export ENABLE_TOOL_SEARCH=auto:5  # Triggers when tools exceed 5% of context
```

### Use subagents for context isolation

Delegate verbose operations (running tests, fetching documentation, processing logs) to subagents. The verbose output stays in the subagent's context, and only a summary returns to the main conversation.

### Move specialized instructions to skills

Keep CLAUDE.md under ~500 lines by moving workflow-specific instructions (PR review templates, migration procedures) into skills that load on demand.

## Important Details

### How auto-compaction works

When context approaches the limit, Claude Code:
1. Clears older tool outputs first
2. Summarizes the conversation if needed
3. Preserves your requests and key code snippets
4. May lose detailed instructions from early in the conversation

This is why persistent rules belong in CLAUDE.md rather than in conversation history.

### CLAUDE.md fully survives compaction

After `/compact` or auto-compaction, Claude re-reads CLAUDE.md files from disk and re-injects them fresh into the session. If an instruction disappeared after compaction, it was given only in conversation and was not written to CLAUDE.md. Instructions in CLAUDE.md persist across compactions.

### Auto memory and compaction

The first 200 lines of `MEMORY.md` (auto memory) are loaded at the start of every conversation. This 200-line limit applies only to `MEMORY.md`. CLAUDE.md files are loaded in full regardless of length, though shorter files produce better adherence.

### Extended thinking details

- Extended thinking is enabled by default with a budget of up to 31,999 tokens (for non-Opus 4.6 models)
- Opus 4.6 uses **adaptive reasoning**, dynamically allocating thinking tokens based on effort level (low/medium/high)
- You are charged for all thinking tokens used, even though Claude 4 models show summarized thinking
- Thinking tokens are billed as output tokens
- Phrases like "think", "think hard", "ultrathink" are treated as regular prompt instructions and do not allocate thinking tokens
- To view Claude's thinking process, press `Ctrl+O` to toggle verbose mode

### Context costs by feature

- **MCP servers**: add tool definitions to every request; a few servers can consume significant context before you start working
- **Skills**: only descriptions load at session start; full content loads on demand
- **Subagents**: get their own fresh context, separate from the main conversation
- **CLAUDE.md**: loaded in full at session start; keep under ~200 lines per file for best adherence
- **Auto memory**: first 200 lines of MEMORY.md loaded at session start

### Token usage tips

- Use `/cost` to check current token usage
- Specific prompts (referencing files, constraints) are cheaper than vague ones
- Use plan mode (`Shift+Tab`) before implementation to prevent expensive re-work
- Course-correct early with `Escape` to stop and `/rewind` to restore
- Lower the effort level in `/model` for simple tasks where deep reasoning is not needed
- Disable thinking for simple queries: `MAX_THINKING_TOKENS=0`

## References

- [How Claude Code Works](https://docs.anthropic.com/en/docs/claude-code/how-claude-code-works) -- Architecture, agentic loop, and context window details
- [Memory (CLAUDE.md and Auto Memory)](https://docs.anthropic.com/en/docs/claude-code/memory) -- How CLAUDE.md files load and survive compaction
- [Manage Costs](https://docs.anthropic.com/en/docs/claude-code/costs) -- Token usage tracking and cost reduction strategies
- [Model Configuration](https://docs.anthropic.com/en/docs/claude-code/model-config) -- Extended thinking, effort levels, and 1M context
- [Interactive Mode](https://docs.anthropic.com/en/docs/claude-code/interactive-mode) -- /compact, /context, /clear commands
- [Checkpointing](https://docs.anthropic.com/en/docs/claude-code/checkpointing) -- Rewind and targeted summarization
