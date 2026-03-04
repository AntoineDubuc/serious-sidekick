---
name: subagents
description: "Auto-load when user asks about subagents, multi-agent workflows, parallel agents, agent orchestration, delegating tasks, or the Agent tool."
---

# Claude Code Subagents

## Quick Reference
- Subagents are specialized AI assistants that run in their own context with custom prompts, tools, and permissions
- Built-in subagents: **Explore** (Haiku, read-only), **Plan** (read-only for plan mode), **General-purpose** (all tools), **Bash** (terminal), **Claude Code Guide** (Haiku, help)
- Create custom subagents as markdown files with YAML frontmatter in `.claude/agents/` (project) or `~/.claude/agents/` (user)
- Priority: `--agents` CLI flag > `.claude/agents/` > `~/.claude/agents/` > plugin agents
- Subagents CANNOT spawn other subagents; chain them from the main conversation instead
- Foreground subagents block and pass permission prompts through; background subagents run concurrently with auto-denied permissions
- Press `Ctrl+B` to background a running task
- Each subagent starts fresh with only its own system prompt (not the full Claude Code system prompt)
- Subagent results return to main context and consume tokens; keep results concise

## Configuration

### Agent file format (.claude/agents/my-agent.md)
```yaml
---
name: code-reviewer
description: "Reviews code for quality and best practices. Use after code changes."
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
maxTurns: 20
permissionMode: default
memory: user
background: false
isolation: worktree
skills: my-skill-name
mcpServers: github, sentry
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---

You are a code reviewer. Analyze code for quality, security, and best practices.
```

### Frontmatter Fields

| Field | Description |
|-------|-------------|
| `name` | Unique ID (lowercase, hyphens) |
| `description` | When Claude should delegate to this agent |
| `tools` | Allowed tools (inherits all if omitted) |
| `disallowedTools` | Tools to deny (removed from inherited list) |
| `model` | `sonnet`, `opus`, `haiku`, or `inherit` (default) |
| `maxTurns` | Maximum agentic turns |
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `memory` | Persistent memory: `user`, `project`, or `local` |
| `background` | `true` = always run as background task |
| `isolation` | `worktree` for git worktree isolation |
| `skills` | Skills to preload into context at startup |
| `mcpServers` | MCP servers available to this agent |
| `hooks` | Lifecycle hooks scoped to this agent |

### CLI-defined subagents
```bash
claude --agents '{
  "reviewer": {
    "description": "Expert code reviewer",
    "prompt": "Review code for quality and security.",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}'
```

## Common Patterns

### Read-only code reviewer
```yaml
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews after changes.
tools: Read, Grep, Glob, Bash
model: inherit
---
You are a senior code reviewer. Run git diff, review modified files, and provide feedback organized by priority (critical, warnings, suggestions).
```

### Parallel research
```
Research the authentication, database, and API modules in parallel using separate subagents
```

### Restrict which subagents an agent can spawn
```yaml
---
name: coordinator
description: Coordinates work across agents
tools: Agent(worker, researcher), Read, Bash
---
```

## Gotchas
- Subagents CANNOT spawn other subagents. For nested delegation, use skills or chain from the main conversation.
- Background subagents auto-deny any permission not pre-approved; Claude pre-prompts before launching.
- Results returning from many subagents can fill the context window. Keep subagent output concise.
- Persistent memory (`memory: user`) stores at `~/.claude/agent-memory/<name>/`; the subagent sees the first 200 lines of `MEMORY.md`.
- Auto-compaction triggers at ~95% capacity. Override with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env var.
- The `Task` tool was renamed to `Agent` in v2.1.63. Existing `Task(...)` references still work as aliases.
- Disable background tasks with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
- Disable specific agents: add `Agent(agent-name)` to `permissions.deny` in settings.

@./Claude Code Features/09_Subagents/research.md
