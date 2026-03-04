# Skills and Slash Commands

## Overview

Skills extend what Claude can do in Claude Code. A skill is a `SKILL.md` file with instructions that Claude adds to its toolkit. Claude can use skills automatically when relevant to a conversation, or you can invoke one directly with `/skill-name`. Skills follow the Agent Skills open standard (agentskills.io) and support additional Claude Code features like invocation control, subagent execution, and dynamic context injection. Legacy `.claude/commands/` files continue to work and have been merged into the skills system.

## Key Capabilities

- **Custom slash commands**: Create `/skill-name` commands that you or Claude can invoke, packaging repeatable workflows.
- **Automatic invocation**: Claude can load skills automatically when relevant to the conversation based on the skill's description.
- **Invocation control**: Control whether a skill can be invoked by you, by Claude, or both.
- **Argument passing**: Skills support `$ARGUMENTS`, `$ARGUMENTS[N]`, and `$N` placeholders for dynamic input.
- **Supporting files**: Skills can include templates, examples, scripts, and reference docs in their directory.
- **Subagent execution**: Run skills in isolated forked contexts with `context: fork`.
- **Dynamic context injection**: Use `!`command`` syntax to run shell commands and inject their output before the skill is sent to Claude.
- **Tool restriction**: Limit which tools Claude can use when a skill is active.
- **Bundled skills**: Built-in skills like `/simplify`, `/batch`, and `/debug` ship with Claude Code.
- **Multi-level scoping**: Skills can be enterprise, personal, project, or plugin-scoped.

## Configuration / Setup

### Skill Directory Structure

Each skill is a directory with `SKILL.md` as the entrypoint:

```
my-skill/
  SKILL.md           # Main instructions (required)
  template.md        # Template for Claude to fill in
  examples/
    sample.md        # Example output
  scripts/
    validate.sh      # Script Claude can execute
```

### Where Skills Live

| Location | Path | Applies to |
|----------|------|-----------|
| Enterprise | See managed settings | All users in your organization |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin is enabled |

Priority order: enterprise > personal > project. Plugin skills use a `plugin-name:skill-name` namespace so they cannot conflict.

Legacy `.claude/commands/` files still work. If a skill and a command share the same name, the skill takes precedence.

### SKILL.md Format

Every skill needs a `SKILL.md` file with two parts:
1. **YAML frontmatter** (between `---` markers) that tells Claude when to use the skill
2. **Markdown content** with instructions Claude follows when the skill is invoked

```yaml
---
name: explain-code
description: Explains code with visual diagrams and analogies. Use when explaining how code works.
---

When explaining code, always include:

1. **Start with an analogy**: Compare the code to something from everyday life
2. **Draw a diagram**: Use ASCII art to show the flow
3. **Walk through the code**: Explain step-by-step what happens
4. **Highlight a gotcha**: What's a common mistake or misconception?
```

### Frontmatter Reference

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name. If omitted, uses directory name. Lowercase letters, numbers, hyphens (max 64 chars) |
| `description` | Recommended | What the skill does and when to use it. Claude uses this for auto-invocation |
| `argument-hint` | No | Hint shown during autocomplete (e.g., `[issue-number]`) |
| `disable-model-invocation` | No | `true` prevents Claude from auto-loading. Default: `false` |
| `user-invocable` | No | `false` hides from `/` menu. Default: `true` |
| `allowed-tools` | No | Tools Claude can use without permission when skill is active |
| `model` | No | Model to use when skill is active |
| `context` | No | Set to `fork` to run in a forked subagent context |
| `agent` | No | Which subagent type to use when `context: fork` is set |
| `hooks` | No | Hooks scoped to this skill's lifecycle |

### String Substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking. If not in content, arguments are appended as `ARGUMENTS: <value>` |
| `$ARGUMENTS[N]` | Access specific argument by 0-based index |
| `$N` | Shorthand for `$ARGUMENTS[N]` (e.g., `$0`, `$1`, `$2`) |
| `${CLAUDE_SESSION_ID}` | Current session ID |

## Usage Examples

### Simple task skill (deploy)
```yaml
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
---

Deploy $ARGUMENTS to production:

1. Run the test suite
2. Build the application
3. Push to the deployment target
4. Verify the deployment succeeded
```

Invoked with `/deploy staging`.

### Skill with indexed arguments
```yaml
---
name: migrate-component
description: Migrate a component from one framework to another
---

Migrate the $0 component from $1 to $2.
Preserve all existing behavior and tests.
```

Invoked with `/migrate-component SearchBar React Vue`.

### Read-only exploration skill
```yaml
---
name: safe-reader
description: Read files without making changes
allowed-tools: Read, Grep, Glob
---
```

### Fix GitHub issue skill
```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---

Fix GitHub issue $ARGUMENTS following our coding standards.

1. Read the issue description
2. Understand the requirements
3. Implement the fix
4. Write tests
5. Create a commit
```

### Dynamic context injection with shell commands
```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

The `!`command`` syntax runs shell commands before the skill content is sent to Claude. The output replaces the placeholder.

### Research skill using subagent
```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:

1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

### Bundled Skills

- **`/simplify`**: Reviews recently changed files for code reuse, quality, and efficiency issues, then fixes them. Spawns three review agents in parallel.
- **`/batch <instruction>`**: Orchestrates large-scale changes across a codebase in parallel. Decomposes work into 5-30 independent units, spawns agents in isolated git worktrees, each opening a PR. Requires a git repository.
- **`/debug [description]`**: Troubleshoots the current Claude Code session by reading the debug log.

## Important Details

### Invocation Control

| Frontmatter | You can invoke | Claude can invoke | When loaded into context |
|-------------|---------------|-------------------|------------------------|
| (default) | Yes | Yes | Description always in context, full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context, full skill loads when you invoke |
| `user-invocable: false` | No | Yes | Description always in context, full skill loads when invoked |

### Context Budget
- Skill descriptions are loaded into context so Claude knows what is available, but full skill content only loads when invoked.
- The description budget scales dynamically at 2% of the context window, with a fallback of 16,000 characters.
- If you have many skills, some may be excluded. Run `/context` to check. Override the limit with `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var.
- Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

### Skill vs Command Precedence
- Files in `.claude/commands/` still work and support the same frontmatter.
- If a skill and a command share the same name, the skill takes precedence.
- Skills are recommended over commands because they support additional features like supporting files.

### Restricting Skill Access
- Disable all skills: deny the `Skill` tool in `/permissions`.
- Allow/deny specific skills: `Skill(commit)`, `Skill(review-pr *)`, `Skill(deploy *)` in permission rules.
- Hide individual skills: add `disable-model-invocation: true` to frontmatter.
- `user-invocable` only controls menu visibility, NOT Skill tool access.

### Automatic Discovery
- Skills in `--add-dir` directories are loaded automatically with live change detection.
- Skills in nested `.claude/skills/` directories (e.g., `packages/frontend/.claude/skills/`) are discovered when working with files in those subdirectories.

### Extended Thinking
- To enable extended thinking in a skill, include the word "ultrathink" anywhere in the skill content.

## References

- [Extend Claude with Skills](https://docs.anthropic.com/en/docs/claude-code/skills) -- Full documentation on creating, configuring, and sharing skills
- [Interactive Mode Built-in Commands](https://code.claude.com/docs/en/interactive-mode#built-in-commands) -- Built-in commands like /help, /compact, /clear
- [Subagents](https://code.claude.com/docs/en/sub-agents) -- Delegate tasks to specialized agents
- [Plugins](https://code.claude.com/docs/en/plugins) -- Package and distribute skills with other extensions
- [Hooks](https://code.claude.com/docs/en/hooks) -- Automate workflows around tool events
- [Permissions](https://code.claude.com/docs/en/permissions) -- Control tool and skill access
