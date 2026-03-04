# Memory System

## Overview

Claude Code provides two complementary memory mechanisms that carry knowledge across sessions: **CLAUDE.md files** (instructions you write to give Claude persistent context) and **auto memory** (notes Claude writes itself based on your corrections and preferences). Both are loaded at the start of every conversation. Claude treats them as context, not enforced configuration -- the more specific and concise your instructions, the more consistently Claude follows them.

## Key Capabilities

- **CLAUDE.md files**: Human-authored markdown files providing persistent instructions for a project, personal workflow, or organization. Loaded into every session.
- **Auto memory**: Claude automatically accumulates knowledge across sessions -- build commands, debugging insights, architecture notes, code style preferences, and workflow habits -- without you writing anything.
- **Scoped instructions**: Memory can be scoped at managed policy, project, user, or local levels, each with different precedence.
- **`.claude/rules/` directory**: Organize instructions into modular, topic-specific files with optional path-scoping via YAML frontmatter.
- **Import system**: CLAUDE.md files can import additional files using `@path/to/import` syntax, with support for relative/absolute paths and recursive imports (max depth of 5).
- **On-demand loading**: CLAUDE.md files in subdirectories load on demand when Claude reads files in those directories, rather than at launch.

## Configuration / Setup

### CLAUDE.md File Locations

| Scope | Location | Purpose | Shared With |
|-------|----------|---------|-------------|
| **Managed policy** | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md`; Linux/WSL: `/etc/claude-code/CLAUDE.md`; Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` | Organization-wide instructions managed by IT/DevOps | All users in organization |
| **Project instructions** | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Team-shared instructions for the project | Team members via source control |
| **User instructions** | `~/.claude/CLAUDE.md` | Personal preferences for all projects | Just you (all projects) |
| **Local instructions** | `./CLAUDE.local.md` | Personal project-specific preferences, not checked into git | Just you (current project) |

### Auto Memory Storage

Each project gets its own memory directory at `~/.claude/projects/<project>/memory/`. The `<project>` path is derived from the git repository, so all worktrees and subdirectories within the same repo share one auto memory directory.

The directory structure:
```
~/.claude/projects/<project>/memory/
├── MEMORY.md          # Concise index, loaded into every session
├── debugging.md       # Detailed notes on debugging patterns
├── api-conventions.md # API design decisions
└── ...                # Any other topic files Claude creates
```

### Enabling / Disabling Auto Memory

Auto memory is on by default. To toggle it:
- Open `/memory` in a session and use the auto memory toggle.
- Set `autoMemoryEnabled` in your project settings:
  ```json
  {
    "autoMemoryEnabled": false
  }
  ```
- Set the environment variable `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.

### Generating a Starter CLAUDE.md

Run `/init` to generate a starting CLAUDE.md automatically. Claude analyzes your codebase and creates a file with build commands, test instructions, and project conventions it discovers. If a CLAUDE.md already exists, `/init` suggests improvements rather than overwriting it.

## Usage Examples

### Setting Up a Project CLAUDE.md

```markdown
# Code style
- Use ES modules (import/export) syntax, not CommonJS (require)
- Destructure imports when possible (eg. import { foo } from 'bar')

# Workflow
- Be sure to typecheck when you're done making a series of code changes
- Prefer running single tests, and not the whole test suite, for performance
```

### Importing Additional Files

```markdown
See @README.md for project overview and @package.json for available npm commands.

# Additional Instructions
- Git workflow: @docs/git-instructions.md
- Personal overrides: @~/.claude/my-project-instructions.md
```

### Path-Specific Rules with `.claude/rules/`

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Development Rules

- All API endpoints must include input validation
- Use the standard error response format
- Include OpenAPI documentation comments
```

### Organizing Rules Into Directories

```
your-project/
├── .claude/
│   ├── CLAUDE.md           # Main project instructions
│   └── rules/
│       ├── code-style.md   # Code style guidelines
│       ├── testing.md      # Testing conventions
│       └── security.md     # Security requirements
```

### Sharing Rules Across Projects with Symlinks

```bash
ln -s ~/shared-claude-rules .claude/rules/shared
ln -s ~/company-standards/security.md .claude/rules/security.md
```

### Asking Claude to Remember Something

When you tell Claude something like "always use pnpm, not npm" or "remember that the API tests require a local Redis instance," Claude saves it to auto memory.

### Viewing and Editing Memory

Run `/memory` to list all CLAUDE.md and rules files loaded in the current session, toggle auto memory on/off, and open the auto memory folder.

## Important Details

### CLAUDE.md vs Auto Memory Comparison

| | CLAUDE.md files | Auto memory |
|---|---|---|
| **Who writes it** | You | Claude |
| **What it contains** | Instructions and rules | Learnings and patterns |
| **Scope** | Project, user, or org | Per working tree |
| **Loaded into** | Every session (full file) | Every session (first 200 lines of MEMORY.md) |
| **Use for** | Coding standards, workflows, project architecture | Build commands, debugging insights, preferences Claude discovers |

### The 200-Line Limit

The first 200 lines of `MEMORY.md` are loaded at the start of every conversation. Content beyond line 200 is not loaded at session start. Claude keeps `MEMORY.md` concise by moving detailed notes into separate topic files. This limit applies only to `MEMORY.md` -- CLAUDE.md files are loaded in full regardless of length, though shorter files produce better adherence.

### What to Save vs Not Save in CLAUDE.md

**Include:**
- Bash commands Claude cannot guess
- Code style rules that differ from defaults
- Testing instructions and preferred test runners
- Repository etiquette (branch naming, PR conventions)
- Architectural decisions specific to your project
- Developer environment quirks (required env vars)
- Common gotchas or non-obvious behaviors

**Exclude:**
- Anything Claude can figure out by reading code
- Standard language conventions Claude already knows
- Detailed API documentation (link to docs instead)
- Information that changes frequently
- Long explanations or tutorials
- File-by-file descriptions of the codebase
- Self-evident practices like "write clean code"

### Writing Effective Instructions

- **Size**: Target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence.
- **Structure**: Use markdown headers and bullets to group related instructions.
- **Specificity**: Write concrete, verifiable instructions (e.g., "Use 2-space indentation" instead of "Format code properly").
- **Consistency**: Avoid contradictions across CLAUDE.md files and rules.

### Surviving Compaction

CLAUDE.md fully survives compaction. After `/compact`, Claude re-reads your CLAUDE.md from disk and re-injects it fresh into the session. Instructions given only in conversation (not written to CLAUDE.md) may be lost after compaction.

### Auto Memory Is Machine-Local

Auto memory files are stored locally. All worktrees and subdirectories within the same git repository share one auto memory directory. Files are not shared across machines or cloud environments.

### Excluding CLAUDE.md Files in Large Monorepos

Use the `claudeMdExcludes` setting to skip specific files by path or glob pattern:

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

Managed policy CLAUDE.md files cannot be excluded.

### Loading CLAUDE.md from Additional Directories

When using the `--add-dir` flag, set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` to also load CLAUDE.md files from those additional directories:

```bash
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ../shared-config
```

## References

- [How Claude remembers your project](https://code.claude.com/docs/en/memory) -- Official Claude Code documentation on the memory system
- [Claude Code Settings](https://code.claude.com/docs/en/settings) -- Settings reference including memory-related configuration
- [Extend with Skills](https://code.claude.com/docs/en/skills) -- Skills as an alternative for on-demand instructions
- [Best Practices](https://code.claude.com/docs/en/best-practices) -- Best practices for writing effective CLAUDE.md files
