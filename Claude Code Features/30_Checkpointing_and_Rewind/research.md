# Checkpointing and Rewind

## Overview

Claude Code automatically tracks file edits as you work, creating checkpoints that capture the state of your code before each edit. This safety net allows you to pursue ambitious, wide-scale changes knowing you can always return to a prior code state. Checkpoints are session-level snapshots -- think of them as "local undo" that complements but does not replace proper version control like Git.

## Key Capabilities

- **Automatic checkpoint creation**: Every user prompt creates a new checkpoint. No manual action required.
- **Persistence across sessions**: Checkpoints persist and are available in resumed conversations.
- **Automatic cleanup**: Checkpoints are cleaned up along with sessions after 30 days (configurable).
- **Multiple restore options**: Restore code only, conversation only, or both together.
- **Summarize from a point**: Compress conversation from a selected point forward to free context window space, without changing any files on disk.
- **Scrollable checkpoint list**: Navigate through all prompts from the session to find the exact point to rewind to.
- **Prompt restoration**: After restoring conversation or summarizing, the original prompt from the selected message is restored into the input field so you can re-send or edit it.

## Configuration / Setup

Checkpointing is enabled automatically -- no configuration is required. It works out of the box for all Claude Code sessions.

### Accessing Checkpoints

There are two ways to open the rewind menu:

1. **Keyboard shortcut**: Press `Esc` twice (`Esc` + `Esc`).
2. **Slash command**: Type `/rewind`.

Both open a scrollable list of every prompt from the session.

## Usage Examples

### Rewind After a Failed Approach

You ask Claude to refactor a module but the new approach introduces bugs:

1. Press `Esc` + `Esc` to open the rewind menu.
2. Scroll to the checkpoint before the refactoring prompt.
3. Select **Restore code and conversation** to go back to that exact state.
4. Try a different approach from there.

### Keep Code but Reset Claude's Understanding

Claude gets confused about the architecture but the code changes are correct:

1. Run `/rewind`.
2. Select the appropriate checkpoint.
3. Choose **Restore conversation** -- this resets Claude's context while keeping your current code on disk.

### Keep Claude's Context but Undo Code Changes

Claude's understanding of the task is correct but the implementation was wrong:

1. Press `Esc` + `Esc`.
2. Select the checkpoint.
3. Choose **Restore code** -- this reverts files while preserving Claude's mental model of what you are trying to do.

### Free Up Context Window Space

After a long debugging session, early messages are consuming context:

1. Run `/rewind`.
2. Select a message from the middle of the session.
3. Choose **Summarize from here** -- this keeps early context in full detail and compresses everything from the selected point forward into a compact AI-generated summary.
4. Optionally type instructions to guide what the summary focuses on.

## Restore vs. Summarize

The three **restore** options revert state (undo code changes, conversation history, or both). **Summarize from here** works differently:

- Messages before the selected message stay intact.
- The selected message and all subsequent messages are replaced with a compact AI-generated summary.
- No files on disk are changed.
- The original messages are preserved in the session transcript, so Claude can reference the details if needed.
- This is similar to `/compact`, but targeted: you keep early context in full detail and only compress the parts using up space.

Note: If you want to branch off and try a different approach while preserving the original session intact, use fork instead (`claude --continue --fork-session`).

## Important Details

### What Gets Tracked

- All file changes made through Claude Code's file editing tools (Write, Edit, NotebookEdit).

### What Does NOT Get Tracked

- **Bash command changes**: Files modified by bash commands (`rm`, `mv`, `cp`, `sed`, etc.) cannot be undone through rewind. Only direct file edits through Claude's tools are tracked.
- **External changes**: Manual changes you make to files outside of Claude Code, and edits from other concurrent sessions, are normally not captured (unless they modify the same files as the current session).

### Complements Git, Does Not Replace It

- Checkpoints are designed for quick, session-level recovery.
- Continue using Git for commits, branches, and long-term history.
- Think of checkpoints as "local undo" and Git as "permanent history."
- For permanent version history and collaboration, always rely on proper version control.

### Limitations

- Bash-executed file modifications cannot be undone through rewind.
- External changes are not captured.
- Editor integrations (like VS Code extension) cannot reliably rewind code changes programmatically -- this is a known gap with ongoing feature requests.
- Checkpoints are tied to the session and cleaned up after 30 days.

## References

- [Checkpointing - Claude Code Docs](https://code.claude.com/docs/en/checkpointing) -- Official documentation covering how checkpoints work, restore options, summarize, and limitations
- [Rewind file changes with checkpointing - Claude API Docs](https://platform.claude.com/docs/en/agent-sdk/file-checkpointing) -- Agent SDK documentation for file checkpointing
- [How to Use Checkpoints in Claude Code](https://claudelog.com/faqs/how-to-use-checkpoints-in-claude-code/) -- Community FAQ on checkpoint usage
