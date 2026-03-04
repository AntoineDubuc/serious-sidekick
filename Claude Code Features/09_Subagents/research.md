# Subagents

## Overview

Subagents are specialized AI assistants within Claude Code that handle specific types of tasks. Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions. When Claude encounters a task matching a subagent's description, it delegates to that subagent, which works independently and returns results. Subagents help preserve context, enforce constraints, specialize behavior, and control costs by routing tasks to appropriate models.

## Key Capabilities

- **Context preservation**: keep exploration and implementation out of the main conversation context
- **Tool constraints**: limit which tools a subagent can use (e.g., read-only agents)
- **Model selection**: route tasks to different models (Haiku for fast lookups, Sonnet for analysis, Opus for complex reasoning)
- **Custom system prompts**: focused prompts for specific domains
- **Persistent memory**: subagents can build up knowledge across sessions
- **Background execution**: run subagents concurrently while continuing to work
- **Hooks support**: define lifecycle hooks scoped to specific subagents
- **Parallel research**: spawn multiple subagents to investigate independent areas simultaneously
- **Chained workflows**: use subagents in sequence, passing results between them
- **Git worktree isolation**: run subagents in isolated worktrees for independent file changes
- **Skills preloading**: inject skill content into subagent context at startup

## Configuration / Setup

### Built-in Subagents

Claude Code includes several built-in subagents:

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **Explore** | Haiku (fast) | Read-only (denied Write/Edit) | File discovery, code search, codebase exploration |
| **Plan** | Inherits | Read-only (denied Write/Edit) | Codebase research for planning mode |
| **General-purpose** | Inherits | All tools | Complex research, multi-step operations, code modifications |
| **Bash** | Inherits | Terminal commands | Running commands in separate context |
| **Claude Code Guide** | Haiku | -- | Answering questions about Claude Code features |

### Subagent Scope and Priority

| Location | Scope | Priority |
|----------|-------|----------|
| `--agents` CLI flag | Current session only | 1 (highest) |
| `.claude/agents/` | Current project | 2 |
| `~/.claude/agents/` | All your projects | 3 |
| Plugin's `agents/` directory | Where plugin is enabled | 4 (lowest) |

### Creating Subagents

**Interactive method** -- use the `/agents` command:
1. Run `/agents` in Claude Code
2. Select "Create new agent"
3. Choose scope (User-level or Project-level)
4. Optionally "Generate with Claude" by describing the subagent
5. Select tools, model, and color

**Manual method** -- create a Markdown file with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

**CLI-defined subagents** -- pass JSON when launching Claude Code:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer. Focus on code quality, security, and best practices.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

### Supported Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier using lowercase letters and hyphens |
| `description` | Yes | When Claude should delegate to this subagent |
| `tools` | No | Tools the subagent can use (inherits all if omitted) |
| `disallowedTools` | No | Tools to deny, removed from inherited or specified list |
| `model` | No | Model: `sonnet`, `opus`, `haiku`, or `inherit` (default: `inherit`) |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, or `plan` |
| `maxTurns` | No | Maximum number of agentic turns |
| `skills` | No | Skills to preload into subagent context at startup |
| `mcpServers` | No | MCP servers available to this subagent |
| `hooks` | No | Lifecycle hooks scoped to this subagent |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local` |
| `background` | No | Set to `true` to always run as a background task |
| `isolation` | No | Set to `worktree` for git worktree isolation |

## Usage Examples

### Code Reviewer (Read-Only)

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- No exposed secrets or API keys
- Proper error handling
- Good test coverage

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)
```

### Debugger (Read + Write)

```markdown
---
name: debugger
description: Debugging specialist for errors, test failures, and unexpected behavior.
tools: Read, Edit, Bash, Grep, Glob
---

You are an expert debugger specializing in root cause analysis.

When invoked:
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate the failure location
4. Implement minimal fix
5. Verify solution works
```

### Database Query Validator with Hooks

```markdown
---
name: db-reader
description: Execute read-only database queries.
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---

You are a database analyst with read-only access. Execute SELECT queries only.
```

### Data Scientist

```markdown
---
name: data-scientist
description: Data analysis expert for SQL queries, BigQuery operations, and data insights.
tools: Bash, Read, Write
model: sonnet
---

You are a data scientist specializing in SQL and BigQuery analysis.
```

### Subagent with Persistent Memory

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
memory: user
---

You are a code reviewer. As you review code, update your agent memory with
patterns, conventions, and recurring issues you discover.
```

### Using Subagents in Conversation

```text
Use the code-reviewer subagent to review the authentication module

Research the authentication, database, and API modules in parallel using separate subagents

Use the code-reviewer subagent to find performance issues, then use the optimizer subagent to fix them
```

### Restricting Which Subagents Can Be Spawned

```yaml
---
name: coordinator
description: Coordinates work across specialized agents
tools: Agent(worker, researcher), Read, Bash
---
```

### Disabling Specific Subagents via Settings

```json
{
  "permissions": {
    "deny": ["Agent(Explore)", "Agent(my-custom-agent)"]
  }
}
```

### Project-Level Hooks for Subagent Events

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/setup-db-connection.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          { "type": "command", "command": "./scripts/cleanup-db-connection.sh" }
        ]
      }
    ]
  }
}
```

## Important Details

### Foreground vs Background Execution

- **Foreground subagents**: block the main conversation; permission prompts and clarifying questions are passed through to the user
- **Background subagents**: run concurrently; Claude pre-prompts for permissions before launching; auto-deny anything not pre-approved; clarifying questions fail but the subagent continues
- Press `Ctrl+B` to background a running task
- Set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` to disable background functionality
- Failed background subagents can be resumed in foreground to retry with interactive prompts

### Subagent Limitations

- **Subagents cannot spawn other subagents**: if nested delegation is needed, use Skills or chain subagents from the main conversation
- **Subagents receive only their own system prompt**: not the full Claude Code system prompt (plus basic environment details)
- **When results return**: subagent results return to the main conversation and consume context; many subagents returning detailed results can fill the context window
- **Subagents start fresh**: each invocation creates a new instance with fresh context (unless explicitly resumed)

### Persistent Memory Scopes

| Scope | Location | Use Case |
|-------|----------|----------|
| `user` | `~/.claude/agent-memory/<name>/` | Learnings across all projects (recommended default) |
| `project` | `.claude/agent-memory/<name>/` | Project-specific, shareable via version control |
| `local` | `.claude/agent-memory-local/<name>/` | Project-specific, not checked into version control |

When memory is enabled, the subagent gets read/write access to its memory directory and sees the first 200 lines of `MEMORY.md`.

### Auto-Compaction

Subagents support automatic compaction at approximately 95% capacity. Override with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` environment variable (e.g., `50`).

### Subagent Transcript Persistence

- Transcripts stored at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`
- Unaffected by main conversation compaction
- Cleaned up based on `cleanupPeriodDays` setting (default: 30 days)

### When to Use Subagents vs Main Conversation

**Use main conversation when:**
- Task needs frequent back-and-forth or iterative refinement
- Multiple phases share significant context
- Making a quick, targeted change
- Latency matters

**Use subagents when:**
- Task produces verbose output you don't need in main context
- You want to enforce specific tool restrictions or permissions
- Work is self-contained and can return a summary

### Agent Tool Renamed

In version 2.1.63, the Task tool was renamed to Agent. Existing `Task(...)` references in settings and agent definitions still work as aliases.

## References

- [Create Custom Subagents](https://code.claude.com/docs/en/sub-agents) -- Full documentation on creating, configuring, and managing subagents
- [Agent Teams](https://code.claude.com/docs/en/agent-teams) -- For multi-agent parallel work with independent context windows
- [Plugins](https://code.claude.com/docs/en/plugins) -- Distribute subagents with plugins across teams and projects
- [Skills](https://code.claude.com/docs/en/skills) -- Reusable prompts that run in the main conversation context
- [Hooks](https://code.claude.com/docs/en/hooks) -- Lifecycle hooks for subagent events
