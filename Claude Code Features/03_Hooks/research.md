# Hooks

## Overview

Hooks are user-defined shell commands, HTTP endpoints, or LLM prompts that execute automatically at specific points in Claude Code's lifecycle. They allow you to automate workflows, enforce policies, validate tool usage, and integrate with external systems. Hooks fire at defined lifecycle events; when a matcher matches, Claude Code passes JSON context about the event to the hook handler, which can inspect the input, take action, and optionally return a decision.

## Key Capabilities

- **Lifecycle automation**: Run custom logic before/after tool calls, on session start/end, on prompt submission, on notifications, and more.
- **Policy enforcement**: Block dangerous commands (e.g., `rm -rf`), deny specific tool usage, validate prompts before processing.
- **Four handler types**: Command (shell), HTTP (POST endpoint), Prompt (single-turn LLM evaluation), and Agent (subagent with tools).
- **Matcher-based filtering**: Use regex patterns to target specific tools, MCP servers, session types, or notification types.
- **Decision control**: Allow, deny, or escalate tool calls; block prompts; prevent Claude from stopping; modify tool inputs before execution.
- **Async support**: Run hooks in the background without blocking.
- **Scoped hooks**: Define hooks in settings files (user, project, local), plugins, skills, or subagent frontmatter.
- **MCP tool matching**: Match MCP tools using the pattern `mcp__<server>__<tool>`.

## Configuration / Setup

### Hook Locations

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All your projects | No, local to your machine |
| `.claude/settings.json` | Single project | Yes, committable to repo |
| `.claude/settings.local.json` | Single project | No, gitignored |
| Managed policy settings | Organization-wide | Yes, admin-controlled |
| Plugin `hooks/hooks.json` | When plugin is enabled | Yes, bundled with plugin |
| Skill or agent frontmatter | While the component is active | Yes, defined in the component file |

### Configuration Structure

The configuration has three levels of nesting:
1. Choose a **hook event** to respond to (e.g., `PreToolUse`, `Stop`)
2. Add a **matcher group** to filter when it fires (e.g., "only for the Bash tool")
3. Define one or more **hook handlers** to run when matched

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/block-rm.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook Events

| Event | When it fires |
|-------|---------------|
| `SessionStart` | When a session begins or resumes |
| `UserPromptSubmit` | When you submit a prompt, before Claude processes it |
| `PreToolUse` | Before a tool call executes. Can block it |
| `PermissionRequest` | When a permission dialog appears |
| `PostToolUse` | After a tool call succeeds |
| `PostToolUseFailure` | After a tool call fails |
| `Notification` | When Claude Code sends a notification |
| `SubagentStart` | When a subagent is spawned |
| `SubagentStop` | When a subagent finishes |
| `Stop` | When Claude finishes responding |
| `TeammateIdle` | When an agent team teammate is about to go idle |
| `TaskCompleted` | When a task is being marked as completed |
| `ConfigChange` | When a configuration file changes during a session |
| `WorktreeCreate` | When a worktree is being created |
| `WorktreeRemove` | When a worktree is being removed |
| `PreCompact` | Before context compaction |
| `SessionEnd` | When a session terminates |

### Matcher Patterns

The matcher is a regex string. Use `"*"`, `""`, or omit entirely to match all occurrences.

| Event | What the matcher filters | Example values |
|-------|--------------------------|----------------|
| `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest` | tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart` | how session started | `startup`, `resume`, `clear`, `compact` |
| `SessionEnd` | why session ended | `clear`, `logout`, `prompt_input_exit` |
| `Notification` | notification type | `permission_prompt`, `idle_prompt` |
| `SubagentStart` / `SubagentStop` | agent type | `Bash`, `Explore`, `Plan` |
| `PreCompact` | compaction trigger | `manual`, `auto` |
| `ConfigChange` | config source | `user_settings`, `project_settings`, `skills` |
| `UserPromptSubmit`, `Stop`, `TeammateIdle`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove` | no matcher support | always fires |

### Handler Types

**Command hooks** (`type: "command"`):
```json
{ "type": "command", "command": ".claude/hooks/check-style.sh", "timeout": 600 }
```

**HTTP hooks** (`type: "http"`):
```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": { "Authorization": "Bearer $MY_TOKEN" },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

**Prompt hooks** (`type: "prompt"`):
```json
{ "type": "prompt", "prompt": "Is this command safe? $ARGUMENTS", "model": "sonnet" }
```

**Agent hooks** (`type: "agent"`):
```json
{ "type": "agent", "prompt": "Verify the code follows conventions: $ARGUMENTS", "timeout": 60 }
```

### Common Handler Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `"command"`, `"http"`, `"prompt"`, or `"agent"` |
| `timeout` | no | Seconds before canceling. Defaults: 600 (command), 30 (prompt), 60 (agent) |
| `statusMessage` | no | Custom spinner message while hook runs |
| `once` | no | If `true`, runs only once per session then is removed (skills only) |

## Usage Examples

### Block destructive shell commands (PreToolUse)
```bash
#!/bin/bash
# .claude/hooks/block-rm.sh
COMMAND=$(jq -r '.tool_input.command')

if echo "$COMMAND" | grep -q 'rm -rf'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Destructive command blocked by hook"
    }
  }'
else
  exit 0
fi
```

### Run linting after file edits (PostToolUse)
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-style.sh"
          }
        ]
      }
    ]
  }
}
```

### Match MCP tools
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__memory__.*",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Memory operation initiated' >> ~/mcp-operations.log"
          }
        ]
      }
    ]
  }
}
```

### HTTP hook with authentication
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:8080/hooks/pre-tool-use",
            "timeout": 30,
            "headers": {
              "Authorization": "Bearer $MY_TOKEN"
            },
            "allowedEnvVars": ["MY_TOKEN"]
          }
        ]
      }
    ]
  }
}
```

### Hooks in skills (via frontmatter)
```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

### SessionStart hook to persist environment variables
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
  echo 'export DEBUG_LOG=true' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

## Important Details

### Exit Code Semantics
- **Exit 0**: Success. Claude Code parses stdout for JSON output. For most events, stdout is only shown in verbose mode. Exceptions: `UserPromptSubmit` and `SessionStart` add stdout as context for Claude.
- **Exit 2**: Blocking error. stderr is fed back to Claude as an error message. The effect depends on the event (e.g., `PreToolUse` blocks the tool call, `UserPromptSubmit` rejects the prompt).
- **Any other exit code**: Non-blocking error. stderr shown in verbose mode only, execution continues.

### Exit Code 2 Behavior by Event
| Event | Can Block? | Effect |
|-------|-----------|--------|
| `PreToolUse` | Yes | Blocks the tool call |
| `PermissionRequest` | Yes | Denies the permission |
| `UserPromptSubmit` | Yes | Blocks prompt processing and erases the prompt |
| `Stop` | Yes | Prevents Claude from stopping, continues conversation |
| `SubagentStop` | Yes | Prevents the subagent from stopping |
| `TeammateIdle` | Yes | Prevents teammate from going idle |
| `TaskCompleted` | Yes | Prevents task from being marked completed |
| `ConfigChange` | Yes | Blocks config change (except `policy_settings`) |
| `PostToolUse` | No | Shows stderr to Claude (tool already ran) |
| `PostToolUseFailure` | No | Shows stderr to Claude (tool already failed) |
| `Notification`, `SubagentStart`, `SessionStart`, `SessionEnd`, `PreCompact` | No | Shows stderr to user only |
| `WorktreeCreate` | Yes | Any non-zero exit code fails creation |
| `WorktreeRemove` | No | Failures logged in debug mode only |

### PreToolUse Decision Control
The `hookSpecificOutput` object supports:
- `permissionDecision`: `"allow"` (bypass permission system), `"deny"` (prevent tool call), `"ask"` (prompt user to confirm)
- `permissionDecisionReason`: Reason string shown to user (allow/ask) or Claude (deny)
- `updatedInput`: Modify tool input parameters before execution
- `additionalContext`: String added to Claude's context before tool executes

### Common Input Fields (all events)
| Field | Description |
|-------|-------------|
| `session_id` | Current session identifier |
| `transcript_path` | Path to conversation JSON |
| `cwd` | Current working directory |
| `permission_mode` | Current permission mode |
| `hook_event_name` | Name of the event that fired |

### JSON Output Fields (all events)
| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | If `false`, Claude stops processing entirely |
| `stopReason` | none | Message shown to user when `continue` is false |
| `suppressOutput` | `false` | If `true`, hides stdout from verbose output |
| `systemMessage` | none | Warning message shown to the user |

### Key Rules
- All matching hooks run in parallel; identical handlers are deduplicated.
- Command hooks are deduplicated by command string; HTTP hooks by URL.
- Hooks run in the current directory with Claude Code's environment.
- `$CLAUDE_PROJECT_DIR` references the project root; `${CLAUDE_PLUGIN_ROOT}` references the plugin root.
- `$CLAUDE_CODE_REMOTE` is set to `"true"` in remote web environments.
- `CLAUDE_ENV_FILE` is available only for `SessionStart` hooks.
- Hook changes in settings files require review via `/hooks` menu; Claude Code captures a snapshot at startup.
- `disableAllHooks: true` in settings disables all hooks (managed hooks can only be disabled at the managed settings level).
- Enterprise administrators can use `allowManagedHooksOnly` to block user, project, and plugin hooks.
- HTTP hooks: non-2xx responses and connection failures produce non-blocking errors. To block, return 2xx with appropriate JSON.

## References

- [Hooks Reference](https://docs.anthropic.com/en/docs/claude-code/hooks) -- Complete reference for hook events, configuration, input/output formats, and decision control
- [Automate Workflows with Hooks (Guide)](https://code.claude.com/docs/en/hooks-guide) -- Quickstart guide with practical examples
- [Bash Command Validator Example](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py) -- Reference implementation for Bash command validation
- [Settings](https://code.claude.com/docs/en/settings) -- Settings file locations and hook configuration options
