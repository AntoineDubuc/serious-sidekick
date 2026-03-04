# Session Management

## Overview

Claude Code automatically saves conversations locally as you work. Each message, tool use, and result is stored, enabling rewinding, resuming, and forking sessions. Sessions are independent -- each new session starts with a fresh context window without conversation history from previous sessions. Claude can persist learnings across sessions using auto memory, and you can add persistent instructions in CLAUDE.md files. Sessions are tied to your current working directory, and when you resume, you only see sessions from that directory (or the same git repository).

## Key Capabilities

- **Automatic session persistence**: All conversations are saved locally with full message history
- **Continue most recent session**: Use `--continue` (`-c`) to resume the most recent conversation in the current directory
- **Resume by ID or name**: Use `--resume` (`-r`) with a session ID or name to resume a specific session
- **Resume from PR**: Use `--from-pr <number>` to resume sessions linked to a specific GitHub pull request
- **Fork sessions**: Use `--fork-session` to branch off from a session without affecting the original
- **Name sessions**: Use `/rename` to give sessions descriptive names for easy retrieval
- **Interactive session picker**: Use `/resume` or `claude --resume` (without arguments) to browse sessions
- **Session-scoped checkpoints**: Rewind code and/or conversation to any previous point in the session
- **Targeted summarization**: Compress conversation from a selected point forward to free context space
- **Non-interactive continuation**: Use `--continue --print` for headless multi-turn conversations
- **Session persistence control**: Disable saving with `--no-session-persistence` for ephemeral runs
- **Custom session IDs**: Use `--session-id` to specify a UUID for the conversation

## Configuration / Setup

### CLI flags for session management

| Flag | Description | Example |
|------|-------------|---------|
| `--continue`, `-c` | Load the most recent conversation in the current directory | `claude -c` |
| `--resume`, `-r` | Resume a specific session by ID or name, or open the picker | `claude -r auth-refactor` |
| `--from-pr` | Resume sessions linked to a specific GitHub PR | `claude --from-pr 123` |
| `--fork-session` | Create a new session ID when resuming (use with `--resume` or `--continue`) | `claude --continue --fork-session` |
| `--session-id` | Use a specific session ID (must be a valid UUID) | `claude --session-id "550e8400-..."` |
| `--no-session-persistence` | Do not save the session to disk (print mode only) | `claude -p --no-session-persistence "query"` |

### Interactive commands

| Command | Purpose |
|---------|---------|
| `/resume` or `/continue` | Resume a conversation by ID or name, or open the session picker |
| `/rename [name]` | Rename the current session; auto-generates a name if omitted |
| `/fork [name]` | Create a fork of the current conversation at this point |
| `/clear` | Clear conversation history and free up context (aliases: `/reset`, `/new`) |
| `/rewind` or `/checkpoint` | Rewind conversation and/or code to a previous point, or summarize |

### Session storage

Sessions are stored per project directory. The `/resume` picker shows sessions from the same git repository, including worktrees. Sessions are automatically cleaned up after 30 days (configurable).

## Usage Examples

### Continue the most recent conversation

```bash
claude --continue
# or
claude -c
```

### Continue with a new prompt in headless mode

```bash
claude -c -p "Check for type errors"
```

### Resume a specific named session

```bash
claude --resume auth-refactor
# or
claude -r auth-refactor
```

### Name a session for later retrieval

During a session:
```
/rename auth-refactor
```

You can also rename from the picker: run `/resume`, navigate to a session, and press `R`.

### Browse sessions with the interactive picker

```bash
claude --resume
```

Or during a session:
```
/resume
```

**Picker keyboard shortcuts:**

| Shortcut | Action |
|----------|--------|
| Up/Down | Navigate between sessions |
| Right/Left | Expand or collapse grouped sessions |
| Enter | Select and resume the highlighted session |
| P | Preview the session content |
| R | Rename the highlighted session |
| / | Search to filter sessions |
| A | Toggle between current directory and all projects |
| B | Filter to sessions from your current git branch |
| Esc | Exit the picker or search mode |

The picker displays session name or initial prompt, time elapsed since last activity, message count, and git branch (if applicable). Forked sessions are grouped under their root session.

### Fork a session to try a different approach

```bash
claude --continue --fork-session
```

This creates a new session ID while preserving the conversation history up to that point. The original session remains unchanged.

Or during a session:
```
/fork
```

### Multi-turn conversations in headless mode

```bash
# First request
claude -p "Review this codebase for performance issues"

# Continue the most recent conversation
claude -p "Now focus on the database queries" --continue
claude -p "Generate a summary of all issues found" --continue
```

### Capture session ID for programmatic use

```bash
session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')
claude -p "Continue that review" --resume "$session_id"
```

### Resume sessions linked to a PR

When you create a PR using `gh pr create`, the session is automatically linked to that PR:

```bash
claude --from-pr 123
```

### Rewind to a previous checkpoint

Press `Esc` twice or use `/rewind` to open the rewind menu. Choose from:

- **Restore code and conversation**: revert both to that point
- **Restore conversation**: rewind to that message while keeping current code
- **Restore code**: revert file changes while keeping the conversation
- **Summarize from here**: compress from this point forward into a summary
- **Never mind**: return without changes

### Disable session persistence for ephemeral runs

```bash
claude -p --no-session-persistence "Run this analysis"
```

## Important Details

### Sessions are independent

Each new session starts with a fresh context window. There is no automatic carry-over of conversation history between sessions. To persist knowledge across sessions:
- Use CLAUDE.md files for project-level instructions
- Let auto memory capture learnings automatically
- Resume sessions explicitly with `--continue` or `--resume`

### What is restored when resuming

- Full conversation history (messages, tool uses, results) is restored
- Tool state from the previous conversation is preserved
- **Session-scoped permissions are NOT restored** -- you need to re-approve those
- The conversation resumes with the same model and configuration as the original

### Same session in multiple terminals

If you resume the same session in multiple terminals, both terminals write to the same session file. Messages from both get interleaved. Each terminal only sees its own messages during the session, but if you resume later, you see everything interleaved. For parallel work from the same starting point, use `--fork-session`.

### Sessions and branches

Claude sees your current branch's files. When you switch branches, Claude sees the new branch's files, but the conversation history stays the same. Claude remembers what you discussed even after switching branches.

### Checkpoints vs. version control

Checkpoints are designed for quick, session-level recovery:
- Every user prompt creates a new checkpoint
- Checkpoints persist across sessions (accessible in resumed conversations)
- Automatically cleaned up along with sessions after 30 days
- Only track direct file edits through Claude's file editing tools
- Bash command changes (rm, mv, cp) are NOT tracked
- External changes made outside Claude Code are normally not captured

Checkpoints complement but do not replace proper version control (Git).

### Summarize vs. fork

- **Summarize** (via `/rewind`): stays in the same session, compresses context from a selected point forward. No files on disk are changed.
- **Fork** (via `--fork-session` or `/fork`): creates a new session ID while preserving conversation history. The original session remains unchanged.

### Session auto-cleanup

Sessions are automatically cleaned up after 30 days (configurable). Use `/rename` to give important sessions descriptive names so you can find them before they are cleaned up.

## References

- [How Claude Code Works: Sessions](https://docs.anthropic.com/en/docs/claude-code/how-claude-code-works) -- Session architecture, resume, fork, and context window details
- [Common Workflows: Resume Sessions](https://docs.anthropic.com/en/docs/claude-code/common-workflows#resume-previous-conversations) -- Practical session management workflows
- [CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-reference) -- All CLI flags including session-related flags
- [Interactive Mode](https://docs.anthropic.com/en/docs/claude-code/interactive-mode) -- Built-in commands for session management
- [Checkpointing](https://docs.anthropic.com/en/docs/claude-code/checkpointing) -- Rewind, restore, and summarize within sessions
- [Headless Mode](https://docs.anthropic.com/en/docs/claude-code/headless) -- Multi-turn conversations with --continue and --resume in print mode
- [Memory](https://docs.anthropic.com/en/docs/claude-code/memory) -- How CLAUDE.md and auto memory persist across sessions
