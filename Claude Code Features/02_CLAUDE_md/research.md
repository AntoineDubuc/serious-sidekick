# CLAUDE.md (Project Memory)

## Overview

Claude Code has two complementary memory systems that carry knowledge across sessions: **CLAUDE.md files** (instructions you write) and **Auto Memory** (notes Claude writes itself). Both are loaded at the start of every conversation. Claude treats them as context, not enforced configuration. The more specific and concise your instructions, the more consistently Claude follows them.

## Key Capabilities

- **Persistent project instructions**: Give Claude context about your project's coding standards, architecture, build commands, and workflows that survives across sessions.
- **Multi-level scoping**: Instructions can be set at managed policy, project, user, folder, or local level, each with different visibility and sharing rules.
- **Auto Memory**: Claude automatically accumulates knowledge across sessions (build commands, debugging insights, architecture notes, code style preferences) without you writing anything.
- **Import system**: CLAUDE.md files can import other files using `@path/to/import` syntax.
- **Path-specific rules**: `.claude/rules/` files can be scoped to specific file types using YAML frontmatter, loading only when Claude works with matching files.
- **Survives compaction**: CLAUDE.md fully survives `/compact`. After compaction, Claude re-reads CLAUDE.md from disk and re-injects it.
- **Subdirectory discovery**: CLAUDE.md files in subdirectories load on demand when Claude reads files in those directories.

## Configuration / Setup

### CLAUDE.md File Locations

| Scope | Location | Purpose | Shared With |
|-------|----------|---------|-------------|
| **Managed policy** | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md`, Linux/WSL: `/etc/claude-code/CLAUDE.md`, Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` | Organization-wide instructions managed by IT/DevOps | All users in organization |
| **Project instructions** | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Team-shared instructions for the project | Team members via source control |
| **User instructions** | `~/.claude/CLAUDE.md` | Personal preferences for all projects | Just you (all projects) |
| **Local instructions** | `./CLAUDE.local.md` | Personal project-specific preferences, not checked into git | Just you (current project) |

### Setting Up a Project CLAUDE.md

1. Create `CLAUDE.md` at the project root (or `.claude/CLAUDE.md`).
2. Add instructions that apply to anyone working on the project: build/test commands, coding standards, architectural decisions, naming conventions, common workflows.
3. Alternatively, run `/init` to generate a starting CLAUDE.md automatically. Claude analyzes your codebase and creates a file with discovered conventions. If one already exists, `/init` suggests improvements rather than overwriting.

### Organizing Rules with `.claude/rules/`

For larger projects, organize instructions into multiple files:

```
your-project/
  .claude/
    CLAUDE.md           # Main project instructions
    rules/
      code-style.md     # Code style guidelines
      testing.md        # Testing conventions
      security.md       # Security requirements
```

Rules without `paths` frontmatter load at launch with the same priority as `.claude/CLAUDE.md`.

### Path-Specific Rules

Scope rules to specific file types using YAML frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Development Rules
- All API endpoints must include input validation
- Use the standard error response format
```

Supported glob patterns:
| Pattern | Matches |
|---------|---------|
| `**/*.ts` | All TypeScript files in any directory |
| `src/**/*` | All files under `src/` |
| `*.md` | Markdown files in the project root |
| `src/components/*.tsx` | React components in a specific directory |

Multiple patterns and brace expansion are supported:
```markdown
---
paths:
  - "src/**/*.{ts,tsx}"
  - "lib/**/*.ts"
  - "tests/**/*.test.ts"
---
```

### Auto Memory

Auto memory is on by default. To toggle:
- Use `/memory` in a session and use the auto memory toggle.
- Or set in project settings:
  ```json
  { "autoMemoryEnabled": false }
  ```
- Or via environment variable: `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.

Storage location: `~/.claude/projects/<project>/memory/`

Structure:
```
~/.claude/projects/<project>/memory/
  MEMORY.md          # Concise index, loaded into every session (first 200 lines)
  debugging.md       # Detailed notes on debugging patterns
  api-conventions.md # API design decisions
```

## Usage Examples

### Basic CLAUDE.md file
```markdown
# Project: My Web App

## Build & Test
- Run `npm test` before committing
- Build with `npm run build`

## Code Standards
- Use 2-space indentation
- All functions must have JSDoc comments
- API handlers live in `src/api/handlers/`

## Architecture
- Frontend: React with TypeScript
- Backend: Express.js
- Database: PostgreSQL
```

### Import additional files
```markdown
See @README for project overview and @package.json for available npm commands.

# Additional Instructions
- git workflow @docs/git-instructions.md
```

Relative paths resolve relative to the file containing the import (not the working directory). Imported files can recursively import other files with a max depth of five hops.

### Share personal instructions across worktrees
In your `CLAUDE.local.md`:
```markdown
# Individual Preferences
- @~/.claude/my-project-instructions.md
```

### Share rules across projects with symlinks
```bash
ln -s ~/shared-claude-rules .claude/rules/shared
ln -s ~/company-standards/security.md .claude/rules/security.md
```

### User-level rules
Personal rules in `~/.claude/rules/` apply to every project:
```
~/.claude/rules/
  preferences.md    # Your personal coding preferences
  workflows.md      # Your preferred workflows
```
User-level rules load before project rules, giving project rules higher priority.

### View and edit memory
Run `/memory` in a session to:
- List all loaded CLAUDE.md and rules files
- Toggle auto memory on/off
- Open the auto memory folder
- Select any file to open in your editor

### Ask Claude to remember something
Tell Claude "always use pnpm, not npm" or "remember that the API tests require a local Redis instance" and it saves to auto memory. To add to CLAUDE.md instead, say "add this to CLAUDE.md" or edit via `/memory`.

## Important Details

- **CLAUDE.md is context, not enforcement**: Claude reads it and tries to follow it, but there is no guarantee of strict compliance, especially for vague or conflicting instructions.
- **Size guideline**: Target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence. Split using imports or `.claude/rules/` files.
- **Structure matters**: Use markdown headers and bullets to group related instructions. Organized sections are easier for Claude to follow.
- **Specificity**: Write concrete, verifiable instructions. "Use 2-space indentation" works better than "Format code properly."
- **Conflict resolution**: If two rules contradict each other, Claude may pick one arbitrarily. Review periodically to remove outdated or conflicting instructions.
- **Auto Memory 200-line limit**: Only the first 200 lines of `MEMORY.md` are loaded at session start. Claude keeps it concise by moving detailed notes into separate topic files.
- **Auto Memory is machine-local**: All worktrees and subdirectories within the same git repository share one auto memory directory. Files are not shared across machines.
- **Loading behavior**: CLAUDE.md files above the working directory load in full at launch. CLAUDE.md files in subdirectories load on demand.
- **`--add-dir` directories**: CLAUDE.md files from these directories are NOT loaded by default. Set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` to load them.
- **Monorepo exclusions**: Use `claudeMdExcludes` setting (glob patterns) to skip irrelevant CLAUDE.md files from other teams.
- **Managed policy CLAUDE.md cannot be excluded**: Organization-wide instructions always apply regardless of individual settings.
- **First-time import approval**: The first time Claude Code encounters external imports in a project, it shows an approval dialog. If declined, imports stay disabled.

## References

- [How Claude Remembers Your Project](https://docs.anthropic.com/en/docs/claude-code/memory) -- Full documentation on CLAUDE.md and auto memory
- [Skills](https://code.claude.com/docs/en/skills) -- Package repeatable workflows that load on demand
- [Settings](https://code.claude.com/docs/en/settings) -- Configure Claude Code behavior with settings files
- [Manage Sessions](https://code.claude.com/docs/en/sessions) -- Manage context, resume conversations, run parallel sessions
