# Claude Code on the Web

## Overview

Claude Code on the web lets developers run Claude Code tasks from a browser at [claude.ai/code](https://claude.ai/code), with no local setup required. Repositories are cloned into Anthropic-managed virtual machines where Claude analyzes code, makes changes, runs tests, and pushes results to a branch. The feature is available as a research preview for Pro, Max, Team, and Enterprise users, and also works from the Claude iOS and Android apps.

## Key Capabilities

- **No local setup required**: Work on repositories without cloning them locally. Connect your GitHub account, install the Claude GitHub app, and submit tasks directly from the browser.
- **Long-running tasks**: Sessions run on Anthropic cloud infrastructure and continue even if you close the browser or shut down your computer. Check back anytime to see progress.
- **Parallel tasks**: Each `--remote` command creates an independent web session. Kick off multiple tasks simultaneously and they run in separate sessions.
- **Working with repos not on your machine**: Connect to any GitHub repository you have access to without needing a local checkout.
- **Diff view**: Review changes file by file directly in the app before creating a pull request. Comment on specific changes and iterate with Claude through multiple rounds of feedback.
- **Mobile app support**: Available on the Claude app for iOS and Android for kicking off tasks on the go and monitoring work in progress.
- **Session handoff (terminal to web)**: Start a web session from the terminal with `claude --remote "your task"`. Use `/tasks` to check progress.
- **Session handoff (web to terminal)**: Pull web sessions into your terminal with `/teleport` (or `/tp`), `claude --teleport`, or from `/tasks` by pressing `t`.
- **Multi-repository support**: Remote sessions support multiple repositories. Add additional repos with the "+" button. Each repo gets its own branch selector.
- **Session sharing**: Toggle visibility to share sessions with team members (Enterprise/Teams) or publicly (Pro/Max). Repository access verification available.

## Configuration / Setup

### Getting Started
1. Visit [claude.ai/code](https://claude.ai/code)
2. Connect your GitHub account
3. Install the Claude GitHub app in your repositories
4. Select your default environment
5. Submit your coding task
6. Review changes in diff view, iterate with comments, then create a pull request

### Cloud Environment
The default universal image includes:
- **Languages**: Python 3.x, Node.js (LTS), Ruby (3.1-3.3), PHP 8.4, Java (OpenJDK), Go, Rust, C++ (GCC, Clang)
- **Databases**: PostgreSQL 16, Redis 7.0
- **Package managers**: pip, poetry, npm, yarn, pnpm, bun, gem, bundler, cargo, Maven, Gradle
- Run `check-tools` to see what is pre-installed

### Network Access Levels
- **Limited (default)**: Access to a curated allowlist of domains (GitHub, npm, PyPI, crates.io, cloud platforms, etc.)
- **Full internet**: Unrestricted access
- **No internet**: No network access (note: Claude can still communicate with the Anthropic API)

### Custom Environments
Select the environment dropdown and choose "Add environment" to specify:
- Environment name
- Network access level
- Environment variables (in `.env` format)

### Dependency Management
Use SessionStart hooks to install packages when a session starts:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/install_pkgs.sh"
          }
        ]
      }
    ]
  }
}
```
Check `CLAUDE_CODE_REMOTE` in scripts to skip local execution. Write to `CLAUDE_ENV_FILE` to persist environment variables.

## Usage Examples

**Start a remote task from terminal**:
```bash
claude --remote "Fix the authentication bug in src/auth/login.ts"
```

**Plan locally, execute remotely**:
```bash
# First, plan in the terminal
claude --permission-mode plan
# Then send to cloud
claude --remote "Execute the migration plan in docs/migration-plan.md"
```

**Run multiple tasks in parallel**:
```bash
claude --remote "Fix the flaky test in auth.spec.ts"
claude --remote "Update the API documentation"
claude --remote "Refactor the logger to use structured output"
```

**Teleport a web session to terminal**:
```bash
claude --teleport          # Interactive session picker
claude --teleport <id>     # Resume specific session
```
Or use `/teleport` from within Claude Code.

**Select remote environment from terminal**:
```
/remote-env
```

## Important Details

- **Platform restriction**: Only works with code hosted on GitHub. GitLab and other non-GitHub repositories are not supported.
- **Security**: Each session runs in an isolated, Anthropic-managed VM. Git credentials and signing keys never exist inside the sandbox. A dedicated GitHub proxy handles authentication using scoped credentials.
- **Pricing**: Shares rate limits with all other Claude and Claude Code usage within your account. Multiple parallel tasks consume proportionally more rate limits.
- **Teleport requirements**: Clean git state (no uncommitted changes), correct repository checkout (not a fork), branch must have been pushed to remote, same Claude.ai account.
- **Dependency management limitations**: SessionStart hooks fire for all sessions (check `CLAUDE_CODE_REMOTE`), require network access for package registries, Bun has known proxy compatibility issues, and hooks run on every session start/resume.
- **Session management**: Archive sessions to organize your list. Delete sessions permanently (cannot be undone). Filter for archived sessions to manage old work.
- **Default allowed domains**: Extensive list covering Anthropic services, GitHub/GitLab/Bitbucket, container registries, cloud platforms (AWS, GCP, Azure), all major package registries (npm, PyPI, RubyGems, crates.io, Maven, etc.), Kubernetes, HashiCorp, and more.

## References

- [Claude Code on the Web](https://code.claude.com/docs/en/claude-code-on-the-web) — Official documentation
- [Claude Code Web: Browser-Based AI Coding IDE](https://techbytes.app/posts/claude-code-web-browser-ide/) — Overview article
- [Claude Code arrives on the web](https://tessl.io/blog/anthropic-brings-claude-code-to-the-web-and-mobile/) — Announcement coverage
- [Claude Code on the Web Complete Guide](https://www.cursor-ide.com/blog/claude-code-on-the-web) — Developer guide
