---
name: worktrees
description: "Auto-load when user asks about git worktrees, parallel development sessions, isolated branches, running multiple Claude sessions simultaneously, or worktree isolation."
---

# Git Worktrees in Claude Code

## Quick Reference
- Worktrees let you run multiple Claude sessions in parallel, each with isolated files and branches
- Use `--worktree <name>` or `-w <name>` to create a worktree and start Claude in it
- Omit the name for an auto-generated random name (e.g., "bright-running-fox")
- Worktrees are created at `<repo>/.claude/worktrees/<name>/`
- Each worktree gets a branch named `worktree-<name>`, branched from the default remote branch
- On exit: no changes = auto-cleanup; changes exist = prompt to keep or remove
- Subagents can use worktree isolation with `isolation: worktree` in frontmatter
- Add `.claude/worktrees/` to `.gitignore` to keep worktree contents out of the main repo
- In-session: ask Claude to "work in a worktree" or "start a worktree"
- Auto memory is shared across worktrees (stored per-repo at `~/.claude/projects/<project>/memory/`)

## Configuration

### CLI usage
```bash
# Named worktree
claude --worktree feature-auth
claude -w bugfix-123

# Auto-generated name
claude --worktree
claude -w
```

### Subagent worktree isolation
```yaml
---
name: parallel-worker
description: Works on tasks in isolation
isolation: worktree
---
```

### Non-git VCS support
Configure `WorktreeCreate` and `WorktreeRemove` hooks in settings for SVN, Perforce, Mercurial, etc. These replace the default git behavior when using `--worktree`.

### Gitignore
```gitignore
.claude/worktrees/
```

## Common Patterns

### Parallel tasks in separate terminals
```bash
# Terminal 1
claude --worktree feature-auth
> Implement OAuth2 login flow

# Terminal 2
claude --worktree bugfix-123
> Fix the race condition in the payment processor
```

### In-session worktree creation
```
> work in a worktree
> start a worktree
```

### Manual git worktree management
```bash
git worktree add ../project-feature-a -b feature-a
cd ../project-feature-a && claude
git worktree list
git worktree remove ../project-feature-a
```

## Gotchas
- Each worktree needs its own environment setup (npm install, pip install, etc.) since it is a separate directory
- `CLAUDE.local.md` only exists in one worktree. For shared personal instructions across worktrees, use a home-directory import: `@~/.claude/my-project-instructions.md`
- Sessions are tied to directories, so each worktree has its own session history. The `/resume` picker shows sessions across all worktrees in the same repo.
- Cleanup on "remove" discards ALL uncommitted changes and commits in that worktree branch -- there is no undo
- Agent teams can spawn teammates in their own worktrees for coordinated parallel work
- For non-git VCS, you MUST configure WorktreeCreate/WorktreeRemove hooks or worktree creation will fail

@./Claude Code Features/13_Git_Worktrees/research.md
