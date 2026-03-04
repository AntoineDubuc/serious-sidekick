# Agent Teams / Swarms

## Overview

Agent Teams (also called "Swarms") let you coordinate multiple Claude Code instances working together as a team. One session acts as the team lead, coordinating work, assigning tasks, and synthesizing results. Teammates work independently, each in its own context window, and can communicate directly with each other via peer-to-peer messaging. This is fundamentally different from subagents, which can only report results back to the main agent.

Agent teams are experimental and disabled by default. They must be explicitly enabled and have known limitations around session resumption, task coordination, and shutdown behavior.

## Key Capabilities

- **Parallel multi-agent orchestration**: Multiple Claude Code instances work simultaneously on different aspects of a problem.
- **Peer-to-peer communication**: Teammates can message each other directly (not just report back to the lead), enabling debate, collaboration, and challenge.
- **Shared task board**: A centralized task list with states (pending, in progress, completed) and dependency tracking. Tasks auto-unblock when dependencies complete.
- **Lead agent planning**: The lead creates the team, spawns teammates, assigns tasks, and synthesizes results.
- **Self-claiming tasks**: Teammates can autonomously pick up the next unassigned, unblocked task when they finish one.
- **Plan approval mode**: Teammates can be required to plan before implementing. The lead reviews and approves or rejects plans before implementation begins.
- **Two display modes**: In-process (all in one terminal, cycle with Shift+Down) or split panes (each teammate in its own tmux/iTerm2 pane).
- **Quality enforcement via hooks**: `TeammateIdle` and `TaskCompleted` hooks can enforce rules when teammates finish work.
- **Broadcast messaging**: The lead can send messages to all teammates simultaneously.
- **File-lock-based task claiming**: Prevents race conditions when multiple teammates try to claim the same task.

## How Agent Teams Differ from Subagents

| Aspect            | Subagents                                        | Agent Teams                                         |
|:------------------|:-------------------------------------------------|:----------------------------------------------------|
| **Context**       | Own context window; results return to caller     | Own context window; fully independent               |
| **Communication** | Report results back to main agent only           | Teammates message each other directly               |
| **Coordination**  | Main agent manages all work                      | Shared task list with self-coordination             |
| **Best for**      | Focused tasks where only the result matters      | Complex work requiring discussion and collaboration |
| **Token cost**    | Lower: results summarized back to main context   | Higher: each teammate is a separate Claude instance |

## Configuration / Setup

### Enabling Agent Teams

Agent teams are disabled by default. Enable them by setting the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable to `1`, either in your shell or in `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Display Mode Configuration

Set `teammateMode` in `settings.json`:

```json
{
  "teammateMode": "in-process"
}
```

Options:
- `"auto"` (default): Uses split panes if running inside tmux; in-process otherwise.
- `"in-process"`: All teammates in one terminal. Use Shift+Down to cycle.
- `"tmux"`: Each teammate in its own pane. Requires tmux or iTerm2 with the `it2` CLI.

Override per-session with: `claude --teammate-mode in-process`

### Split Pane Requirements

- **tmux**: Install via your system's package manager.
- **iTerm2**: Install the `it2` CLI, then enable the Python API in iTerm2 Settings > General > Magic > Enable Python API.

Note: Split-pane mode is not supported in VS Code's integrated terminal, Windows Terminal, or Ghostty.

## Usage Examples

### Starting a Team

```
I'm designing a CLI tool that helps developers track TODO comments across
their codebase. Create an agent team to explore this from different angles: one
teammate on UX, one on technical architecture, one playing devil's advocate.
```

### Parallel Code Review

```
Create an agent team to review PR #142. Spawn three reviewers:
- One focused on security implications
- One checking performance impact
- One validating test coverage
Have them each review and report findings.
```

### Competing Hypothesis Investigation

```
Users report the app exits after one message instead of staying connected.
Spawn 5 agent teammates to investigate different hypotheses. Have them talk to
each other to try to disprove each other's theories, like a scientific
debate. Update the findings doc with whatever consensus emerges.
```

### Requiring Plan Approval

```
Spawn an architect teammate to refactor the authentication module.
Require plan approval before they make any changes.
```

### Specifying Models

```
Create a team with 4 teammates to refactor these modules in parallel.
Use Sonnet for each teammate.
```

### Shutting Down and Cleaning Up

```
Ask the researcher teammate to shut down
```
```
Clean up the team
```

Always use the lead to clean up. Teammates should not run cleanup.

## Important Details

### Architecture

| Component     | Role                                                                  |
|:------------- |:----------------------------------------------------------------------|
| **Team lead** | Main session that creates the team, spawns teammates, coordinates     |
| **Teammates** | Separate Claude Code instances working on assigned tasks              |
| **Task list** | Shared work items that teammates claim and complete                   |
| **Mailbox**   | Messaging system for inter-agent communication                        |

Teams and tasks are stored locally:
- **Team config**: `~/.claude/teams/{team-name}/config.json`
- **Task list**: `~/.claude/tasks/{team-name}/`

### Context and Communication

- Teammates load the same project context (CLAUDE.md, MCP servers, skills) but do NOT inherit the lead's conversation history.
- Messages are delivered automatically to recipients; no polling needed.
- Teammates notify the lead automatically when they go idle.

### Permissions

- Teammates inherit the lead's permission settings at spawn time.
- If the lead runs with `--dangerously-skip-permissions`, all teammates do too.
- Individual teammate modes can be changed after spawning.

### Best Practices

- **Team size**: Start with 3-5 teammates. Aim for 5-6 tasks per teammate.
- **Task sizing**: Avoid tasks that are too small (coordination overhead exceeds benefit) or too large (risk of wasted effort without check-ins).
- **Avoid file conflicts**: Ensure each teammate owns different files.
- **Give enough context**: Include task-specific details in spawn prompts since conversation history is not inherited.
- **Monitor progress**: Check in on teammates regularly to redirect if needed.
- **Start with research/review**: If new to agent teams, begin with non-coding tasks like PR reviews or library research.

### Known Limitations

- **No session resumption with in-process teammates**: `/resume` and `/rewind` do not restore in-process teammates.
- **Task status can lag**: Teammates sometimes fail to mark tasks completed, blocking dependents.
- **Shutdown can be slow**: Teammates finish current tool calls before shutting down.
- **One team per session**: Clean up the current team before starting a new one.
- **No nested teams**: Teammates cannot spawn their own teams.
- **Lead is fixed**: Cannot promote a teammate to lead or transfer leadership.
- **Token cost**: Agent teams use significantly more tokens than single sessions; each teammate has its own context window.

## References

- [Orchestrate teams of Claude Code sessions - Claude Code Docs](https://code.claude.com/docs/en/agent-teams) -- Official documentation with full setup, architecture, and best practices
- [Claude Code Swarms - Addy Osmani](https://addyosmani.com/blog/claude-code-agent-teams/) -- In-depth blog post on agent team patterns
- [Claude Code Swarms: Multi-Agent AI Coding Is Here](https://zenvanriel.com/ai-engineer-blog/claude-code-swarms-multi-agent-orchestration/) -- Guide covering multi-agent orchestration patterns
