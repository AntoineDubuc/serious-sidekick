# Git Worktrees

## Overview

Git worktrees allow you to run multiple Claude Code sessions in parallel, each with its own isolated copy of the codebase so changes do not collide. Each worktree has its own files and branch while sharing the same repository history and remote connections. Claude Code integrates worktree support directly via the `--worktree` (`-w`) CLI flag, which creates a worktree, checks out a new branch, and starts Claude in the isolated directory. Worktrees can also be created during an interactive session by asking Claude to "work in a worktree" or "start a worktree."

## Key Capabilities

- **Parallel development**: Run multiple Claude sessions on different tasks simultaneously without file conflicts
- **Automatic worktree creation**: Use `--worktree <name>` or `-w <name>` to create an isolated worktree and start Claude in it
- **Auto-generated names**: Omit the name and Claude generates a random one (e.g., "bright-running-fox")
- **Branch isolation**: Each worktree gets its own branch named `worktree-<name>`, branched from the default remote branch
- **Subagent worktrees**: Subagents can use worktree isolation to work in parallel without conflicts
- **Automatic cleanup**: When exiting, worktrees with no changes are removed automatically; worktrees with changes prompt for keep/remove
- **Non-git VCS support**: For SVN, Perforce, Mercurial, etc., configure `WorktreeCreate` and `WorktreeRemove` hooks to provide custom worktree logic
- **In-session creation**: Ask Claude to "work in a worktree" during an interactive session

## Configuration / Setup

### Using the --worktree flag

```bash
# Start Claude in a worktree named "feature-auth"
# Creates .claude/worktrees/feature-auth/ with a new branch worktree-feature-auth
claude --worktree feature-auth

# Start another session in a separate worktree
claude --worktree bugfix-123

# Auto-generate a random name
claude --worktree
# or equivalently:
claude -w
```

### Worktree location

Worktrees are created at:
```
<repo>/.claude/worktrees/<name>
```

The worktree branch is named `worktree-<name>` and branches from the default remote branch.

### Gitignore configuration

Add `.claude/worktrees/` to your `.gitignore` to prevent worktree contents from appearing as untracked files in your main repository:

```gitignore
.claude/worktrees/
```

### Subagent worktree isolation

Configure a custom subagent to use worktree isolation by adding `isolation: worktree` to the agent's frontmatter:

```yaml
isolation: worktree
```

Or ask Claude to "use worktrees for your agents" during a session. Each subagent gets its own worktree that is automatically cleaned up when the subagent finishes without changes.

### Non-git VCS hooks

For version control systems other than git (SVN, Perforce, Mercurial), configure `WorktreeCreate` and `WorktreeRemove` hooks in your settings to provide custom worktree creation and cleanup logic. When configured, these hooks replace the default git behavior when you use `--worktree`.

See the hooks documentation for `WorktreeCreate` and `WorktreeRemove` hook event details.

## Usage Examples

### Running parallel tasks

Terminal 1:
```bash
claude --worktree feature-auth
> Implement OAuth2 login flow
```

Terminal 2:
```bash
claude --worktree bugfix-123
> Fix the race condition in the payment processor
```

Each session operates on an independent copy of the codebase with its own branch.

### Creating a worktree during an interactive session

During an active Claude session, simply ask:
```
> work in a worktree
```
or:
```
> start a worktree
```

Claude will create a worktree automatically and switch to it.

### Manual worktree management with git

For more control over worktree location and branch configuration, create worktrees with Git directly:

```bash
# Create a worktree with a new branch
git worktree add ../project-feature-a -b feature-a

# Create a worktree with an existing branch
git worktree add ../project-bugfix bugfix-123

# Start Claude in the worktree
cd ../project-feature-a && claude

# List all worktrees
git worktree list

# Clean up when done
git worktree remove ../project-feature-a
```

### Combining with session management

Sessions are tied to directories. Since each worktree is a separate directory, each has its own session history. The `/resume` session picker shows sessions from the same git repository, including worktrees.

## Important Details

### Worktree cleanup behavior

When you exit a worktree session:
- **No changes**: the worktree directory and its branch are removed automatically
- **Changes or commits exist**: Claude prompts you to keep or remove the worktree
  - **Keep**: preserves the directory and branch so you can return later
  - **Remove**: deletes the worktree directory and its branch, discarding all uncommitted changes and commits

To clean up worktrees outside of a Claude session, use standard `git worktree remove` commands.

### Subagent worktree cleanup

Each subagent that uses worktree isolation gets its own worktree. These are automatically cleaned up when the subagent finishes without changes, preventing worktree accumulation.

### Environment initialization

Remember to initialize your development environment in each new worktree according to your project's setup. Depending on your stack, this might include:
- Running dependency installation (`npm install`, `yarn`, `pip install`)
- Setting up virtual environments
- Following your project's standard setup process

### CLAUDE.local.md and worktrees

`CLAUDE.local.md` only exists in one worktree. If you work across multiple git worktrees and want to share personal instructions across all of them, use a home-directory import in your CLAUDE.md instead:

```markdown
# Individual Preferences
- @~/.claude/my-project-instructions.md
```

### Auto memory is shared across worktrees

Auto memory is stored at `~/.claude/projects/<project>/memory/`. The `<project>` path is derived from the git repository, so all worktrees and subdirectories within the same repo share one auto memory directory.

### Session picker and worktrees

The `/resume` picker shows sessions from the same git repository, including those from different worktrees. This makes it easy to find and resume sessions from any worktree in the same project.

### Agent teams and worktrees

For automated coordination of parallel sessions with shared tasks and messaging, Claude Code offers "agent teams" as a complementary feature to worktrees. Agent teams can spawn multiple teammates, each potentially in their own worktree.

## References

- [Common Workflows: Git Worktrees](https://docs.anthropic.com/en/docs/claude-code/common-workflows#run-parallel-claude-code-sessions-with-git-worktrees) -- Primary documentation for worktree usage
- [CLI Reference: --worktree flag](https://docs.anthropic.com/en/docs/claude-code/cli-reference) -- CLI flag documentation
- [Hooks: WorktreeCreate and WorktreeRemove](https://docs.anthropic.com/en/docs/claude-code/hooks) -- Non-git VCS support via hooks
- [Subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) -- Subagent worktree isolation
- [Agent Teams](https://docs.anthropic.com/en/docs/claude-code/agent-teams) -- Coordinated parallel sessions
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree) -- Official Git documentation for worktrees
