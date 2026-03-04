---
name: hooks
description: "Auto-load when user asks about hooks, lifecycle events, pre/post tool use, automating actions, blocking commands, or policy enforcement in Claude Code."
---

# Claude Code Hooks

## Quick Reference
- Hooks are user-defined actions that execute automatically at specific lifecycle events (PreToolUse, PostToolUse, Stop, SessionStart, etc.)
- Configuration lives in settings files: `~/.claude/settings.json` (user), `.claude/settings.json` (project), `.claude/settings.local.json` (local)
- Three nesting levels: **event** > **matcher group** (regex filter) > **handler(s)**
- Four handler types: `command` (shell), `http` (POST endpoint), `prompt` (single-turn LLM), `agent` (subagent with tools)
- Matcher is a regex: `"Bash"`, `"Edit|Write"`, `"mcp__memory__.*"`. Omit or use `"*"` to match all.
- Exit code 0 = success, exit code 2 = blocking error (denies/blocks), other = non-blocking error
- All matching hooks run in parallel; identical handlers are deduplicated
- `$CLAUDE_PROJECT_DIR` references project root; `$CLAUDE_ENV_FILE` is only available in SessionStart hooks
- Hooks can also be defined in skill/agent frontmatter under a `hooks:` key
- Use `/hooks` in Claude Code to review hook changes; changes require review

## Configuration

Basic structure in settings.json:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/validate-bash.sh",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

### All Hook Events

| Event | When | Can Block? |
|-------|------|-----------|
| `SessionStart` | Session begins/resumes | No |
| `UserPromptSubmit` | Before Claude processes prompt | Yes |
| `PreToolUse` | Before tool executes | Yes |
| `PostToolUse` | After tool succeeds | No |
| `PostToolUseFailure` | After tool fails | No |
| `PermissionRequest` | Permission dialog appears | Yes |
| `Stop` | Claude finishes responding | Yes (prevents stopping) |
| `SubagentStart` / `SubagentStop` | Subagent lifecycle | Start: No, Stop: Yes |
| `Notification` | Notification sent | No |
| `PreCompact` | Before compaction | No |
| `SessionEnd` | Session terminates | No |
| `WorktreeCreate` / `WorktreeRemove` | Worktree lifecycle | Create: Yes, Remove: No |
| `ConfigChange` | Config file changes | Yes |
| `TeammateIdle` | Teammate about to idle | Yes |
| `TaskCompleted` | Task marked completed | Yes |

### Handler Types

```json
// Shell command
{ "type": "command", "command": ".claude/hooks/check.sh", "timeout": 600 }

// HTTP endpoint
{ "type": "http", "url": "http://localhost:8080/hook", "timeout": 30, "headers": { "Authorization": "Bearer $TOKEN" }, "allowedEnvVars": ["TOKEN"] }

// LLM prompt (single-turn)
{ "type": "prompt", "prompt": "Is this command safe? $ARGUMENTS", "model": "sonnet" }

// Agent (subagent with tools)
{ "type": "agent", "prompt": "Verify conventions: $ARGUMENTS", "timeout": 60 }
```

## Common Patterns

### Block destructive commands (PreToolUse)
```bash
#!/bin/bash
# .claude/hooks/block-rm.sh
COMMAND=$(jq -r '.tool_input.command')
if echo "$COMMAND" | grep -q 'rm -rf'; then
  jq -n '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Destructive command blocked" } }'
else
  exit 0
fi
```

### Auto-lint after file edits (PostToolUse)
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/lint.sh" }]
      }
    ]
  }
}
```

### PreToolUse decision control
The `hookSpecificOutput` object supports:
- `permissionDecision`: `"allow"` (bypass permissions), `"deny"` (block), `"ask"` (prompt user)
- `permissionDecisionReason`: reason string
- `updatedInput`: modify tool input parameters before execution
- `additionalContext`: string added to Claude's context

## Gotchas
- Exit code 2 blocks in PreToolUse/UserPromptSubmit/Stop/PermissionRequest but is non-blocking in PostToolUse (tool already ran)
- HTTP hooks: non-2xx responses produce non-blocking errors. To block, return 2xx with appropriate JSON.
- `CLAUDE_ENV_FILE` is ONLY available in SessionStart hooks (for persisting env vars)
- Hook changes in settings require review via `/hooks`; Claude Code captures a snapshot at startup
- `disableAllHooks: true` in settings disables all hooks; `allowManagedHooksOnly` blocks user/project/plugin hooks
- Command hooks are deduplicated by command string; HTTP hooks by URL

@./Claude Code Features/03_Hooks/research.md
