---
name: skills-and-commands
description: "Auto-load when user asks about creating custom commands, slash commands, skills, SKILL.md files, or extending Claude Code with reusable prompts."
---

# Claude Code Skills and Slash Commands

## Quick Reference
- A skill is a directory with a `SKILL.md` entrypoint containing YAML frontmatter + markdown instructions
- Skills live at: `~/.claude/skills/<name>/SKILL.md` (personal), `.claude/skills/<name>/SKILL.md` (project), or plugin scope
- Priority order: enterprise > personal > project. Plugin skills use `plugin-name:skill-name` namespace.
- Invoke with `/skill-name` or let Claude auto-invoke based on the `description` field
- `$ARGUMENTS` passes all args; `$ARGUMENTS[N]` or `$N` for indexed args (0-based)
- `context: fork` runs the skill in an isolated subagent context
- `!`command`` syntax runs shell commands and injects output before sending to Claude
- Legacy `.claude/commands/` files still work but skills take precedence if names collide
- Keep SKILL.md under 500 lines; move detailed reference to separate files in the skill directory
- Description budget is 2% of context window (~16,000 chars fallback); check with `/context`

## Configuration

### SKILL.md Format
```yaml
---
name: my-skill
description: "What this skill does. Claude uses this for auto-invocation."
argument-hint: "[arg1] [arg2]"
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Grep, Glob
model: sonnet
context: fork
agent: Explore
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/check.sh"
---

Your instructions to Claude here. Use $ARGUMENTS for passed arguments.
```

### Frontmatter Fields

| Field | Description |
|-------|-------------|
| `name` | Display name (lowercase, hyphens, max 64 chars). Defaults to directory name. |
| `description` | What the skill does and when to use it. Critical for auto-invocation. |
| `argument-hint` | Hint shown in autocomplete (e.g., `[issue-number]`) |
| `disable-model-invocation` | `true` = only user can invoke via `/`. Default: `false` |
| `user-invocable` | `false` = hidden from `/` menu. Default: `true` |
| `allowed-tools` | Restrict tools Claude can use (e.g., `Read, Grep, Glob`) |
| `model` | Model override when skill is active |
| `context` | `fork` to run in isolated subagent context |
| `agent` | Subagent type when `context: fork` (e.g., `Explore`) |
| `hooks` | Lifecycle hooks scoped to this skill |

### Invocation Control

| Setting | User invokes | Claude invokes | In context |
|---------|-------------|---------------|-----------|
| Default | Yes | Yes | Description always loaded |
| `disable-model-invocation: true` | Yes | No | Description excluded |
| `user-invocable: false` | No | Yes | Description always loaded |

## Common Patterns

### Task workflow skill
```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---
Fix GitHub issue $ARGUMENTS:
1. Read the issue description
2. Implement the fix
3. Write tests
4. Create a commit
```

### Dynamic context injection
```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---
## Context
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

Summarize this pull request concisely.
```

### Read-only exploration skill
```yaml
---
name: safe-reader
description: Read files without making changes
allowed-tools: Read, Grep, Glob
---
Analyze the requested code. Do not modify any files.
```

## Gotchas
- `user-invocable: false` only hides from the `/` menu; it does NOT prevent Skill tool access. Use permission rules to truly block.
- If many skills exist, some descriptions may be excluded from context. Check with `/context` and override limit with `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var.
- `$ARGUMENTS` is appended as `ARGUMENTS: <value>` if the placeholder is not found in content.
- To enable extended thinking in a skill, include the word "ultrathink" anywhere in the content.
- Skills in nested `.claude/skills/` directories (e.g., `packages/frontend/.claude/skills/`) are auto-discovered when working with files in those subdirectories.
- Bundled skills: `/simplify` (parallel code review), `/batch` (large-scale parallel changes with worktrees), `/debug` (session troubleshooting).

@./Claude Code Features/04_Skills_and_Slash_Commands/research.md
