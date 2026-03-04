---
name: agent-teams
description: "Auto-load when user asks about agent teams, swarms, multi-agent collaboration, parallel agents, or coordinating multiple Claude instances"
---

# Agent Teams (Swarms)

## Quick Reference
- **Experimental feature** -- disabled by default. Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- One **lead agent** coordinates; multiple **teammates** work independently in their own context windows.
- Unlike subagents, teammates can **message each other directly** (peer-to-peer), not just report back.
- **Shared task board** with states (pending, in progress, completed) and dependency tracking.
- Teammates **self-claim tasks** when they finish one, and can be required to get **plan approval** before implementing.
- **Two display modes**: `in-process` (one terminal, Shift+Down to cycle) or `tmux` (split panes).
- Teammates inherit lead's permission settings but do NOT inherit conversation history.
- **Best team size**: 3-5 teammates, 5-6 tasks per teammate.
- **Token cost is significantly higher** than single sessions -- each teammate has its own context window.

## Configuration

**Enable agent teams:**
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Display mode** (`settings.json`):
```json
{
  "teammateMode": "in-process"
}
```

| Mode | Behavior |
|------|----------|
| `"auto"` (default) | Split panes if in tmux, otherwise in-process |
| `"in-process"` | All teammates in one terminal, Shift+Down to cycle |
| `"tmux"` | Each teammate in its own pane (requires tmux or iTerm2 with `it2` CLI) |

Override per session: `claude --teammate-mode in-process`

**Split pane requirements:**
- tmux: install via package manager
- iTerm2: install `it2` CLI, enable Python API in Settings > General > Magic
- NOT supported in: VS Code terminal, Windows Terminal, Ghostty

## Common Patterns

1. **Parallel code review:**
   ```
   Create an agent team to review PR #142. Spawn three reviewers:
   - One focused on security implications
   - One checking performance impact
   - One validating test coverage
   Have them each review and report findings.
   ```

2. **Competing hypothesis investigation:**
   ```
   Users report the app exits after one message. Spawn 5 agent teammates
   to investigate different hypotheses. Have them talk to each other to
   disprove each other's theories. Update findings with consensus.
   ```

3. **Plan approval pattern:**
   ```
   Spawn an architect teammate to refactor the auth module.
   Require plan approval before they make any changes.
   ```

4. **Always clean up via the lead:**
   ```
   Clean up the team
   ```
   Teammates should NOT run cleanup -- always use the lead.

## Gotchas
- **No session resumption**: `/resume` and `/rewind` do not restore in-process teammates.
- **Task status can lag**: teammates sometimes fail to mark tasks completed, blocking dependents.
- **One team per session**: clean up the current team before starting a new one.
- **No nested teams**: teammates cannot spawn their own teams.
- **Lead is fixed**: cannot promote a teammate to lead or transfer leadership.
- **Shutdown can be slow**: teammates finish current tool calls before shutting down.
- **Context isolation**: teammates load project context (CLAUDE.md, MCP servers, skills) but NOT the lead's conversation history -- include task-specific details in spawn prompts.
- **Avoid file conflicts**: ensure each teammate owns different files.
- **Start with non-coding tasks** (PR reviews, research) when first learning agent teams.
- **Storage**: team config at `~/.claude/teams/{team-name}/config.json`, tasks at `~/.claude/tasks/{team-name}/`.

### Agent Teams vs Subagents

| Aspect | Subagents | Agent Teams |
|--------|-----------|-------------|
| Context | Results return to caller | Fully independent |
| Communication | Report to main agent only | Peer-to-peer messaging |
| Coordination | Main agent manages all | Shared task list, self-coordination |
| Best for | Focused tasks needing only results | Complex work needing discussion |
| Token cost | Lower (summarized results) | Higher (separate context per teammate) |

@./Claude Code Features/28_Agent_Teams/research.md
