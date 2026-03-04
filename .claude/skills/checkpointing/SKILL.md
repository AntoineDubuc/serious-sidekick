---
name: checkpointing
description: "Assist with checkpointing, rewind, undo, restoring code, or reverting changes in Claude Code"
---

# Checkpointing and Rewind

## Quick Reference
- Every user prompt automatically creates a checkpoint -- no manual action needed
- Open the rewind menu: press `Esc` twice (`Esc` + `Esc`) or type `/rewind`
- Four options at each checkpoint: **Restore code**, **Restore conversation**, **Restore code and conversation**, **Summarize from here**
- Checkpoints persist across resumed sessions and are cleaned up after 30 days
- Only file edits made through Claude's tools (Write, Edit, NotebookEdit) are tracked
- Bash command changes (`rm`, `mv`, `sed`, etc.) are NOT tracked and cannot be undone
- External/manual file changes are not captured
- Checkpoints are session-level "local undo" -- they complement Git, not replace it
- After restoring or summarizing, the original prompt is placed back in the input field for re-sending

## Restore Options

| Option | Files on Disk | Conversation | Use When |
|:-------|:-------------|:-------------|:---------|
| **Restore code** | Reverted | Kept | Implementation was wrong but Claude's understanding is correct |
| **Restore conversation** | Kept | Reverted | Code is fine but Claude got confused about architecture |
| **Restore code and conversation** | Reverted | Reverted | Entire approach failed, want to start fresh from that point |
| **Summarize from here** | Unchanged | Compressed | Context window is filling up, want to free space |

## Common Patterns

### Undo a failed refactor
1. `Esc` + `Esc` to open rewind menu
2. Scroll to the checkpoint before the refactoring prompt
3. Select **Restore code and conversation**
4. Try a different approach

### Free context window space (targeted compact)
1. `/rewind` and select a message from the middle of the session
2. Choose **Summarize from here** -- messages before the selection stay intact, everything after is compressed
3. Optionally type instructions to guide what the summary focuses on
4. Unlike `/compact`, this lets you keep early context in full detail

### Branch off to try alternatives
Use `claude --continue --fork-session` instead of rewind when you want to preserve the original session intact and explore a different path.

## Gotchas
- **Bash changes are invisible to checkpoints**: If Claude runs `sed -i` or `rm` via bash, rewind cannot undo those changes -- only tool-based edits (Write/Edit) are tracked
- **VS Code extension limitation**: Editor integrations cannot reliably rewind code changes programmatically (known gap)
- **30-day expiry**: Checkpoints are cleaned up with sessions after 30 days (configurable)
- **Not a Git replacement**: Always commit important milestones with Git for permanent history

@../../Claude Code Features/30_Checkpointing_and_Rewind/research.md
