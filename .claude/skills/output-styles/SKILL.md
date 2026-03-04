---
name: output-styles
description: "Assist with output styles, explanatory mode, learning mode, response format, or customizing how Claude Code communicates"
---

# Output Styles

## Quick Reference
- Output styles modify Claude Code's **system prompt** directly -- more powerful than CLAUDE.md or `--append-system-prompt`
- Three built-in styles: **Default** (efficient engineering), **Explanatory** (educational insights), **Learning** (pair-programming with `TODO(human)` markers)
- Switch styles: `/output-style [style]` or `/output-style` for interactive menu (also in `/config`)
- Generate a custom style with natural language: `/output-style:new describe your style here`
- Custom styles are Markdown files with YAML frontmatter
- Save custom styles in `~/.claude/output-styles/` (user-level) or `.claude/output-styles/` (project-level)
- Style selection persists in `.claude/settings.local.json` under `outputStyle`
- All styles (including Default when selected explicitly) remove the default concise-output instructions, making responses more verbose
- Custom styles disable coding instructions by default (`keep-coding-instructions: false`)

## Configuration

### Custom Style File Format
```markdown
---
name: My Custom Style
description: A brief description shown in the /output-style UI
keep-coding-instructions: false
---

# Custom Style Instructions

You are an interactive CLI tool that helps users with [your purpose].

## Specific Behaviors

- [Define how the assistant should behave]
- [Response format, tone, structure]
```

### Frontmatter Fields
| Field | Purpose | Default |
|:------|:--------|:--------|
| `name` | Display name | Inherits from filename |
| `description` | Shown in `/output-style` menu | None |
| `keep-coding-instructions` | Keep coding-specific system prompt parts | `false` |

### Quick Commands
```
/output-style                    # Interactive selection menu
/output-style explanatory        # Switch directly
/output-style default            # Switch back to default
/output-style:new tech writer    # Auto-generate a custom style
```

## Common Patterns

### Use Explanatory mode for code reviews
```
/output-style explanatory
```
Claude provides educational "Insights" alongside its work, explaining implementation choices and codebase patterns.

### Create a non-coding agent
Save a custom style with `keep-coding-instructions: false` (the default). The coding-specific system prompt instructions are removed, letting Claude Code function as a general-purpose agent while retaining file/tool access.

### Keep coding guidance with custom formatting
Set `keep-coding-instructions: true` in frontmatter to get your custom communication style while keeping coding best practices like "verify code with tests."

## Gotchas
- **System prompt replacement, not addition**: Output styles replace engineering-specific parts of the system prompt. CLAUDE.md adds a user message; `--append-system-prompt` appends. Output styles are the most powerful of the three.
- **Custom styles drop coding instructions by default**: If you create a custom style for coding tasks, set `keep-coding-instructions: true` or you lose best-practice guidance
- **Output Styles vs. Skills**: Styles modify how Claude responds (always active once selected). Skills are task-specific prompts invoked on demand. Use styles for formatting preferences; use skills for reusable workflows.
- **Output Styles vs. Agents**: Styles affect the main agent loop's system prompt only. Agents (sub-agents) are invoked for specific tasks and can include model selection and tool restrictions.
- **All styles increase verbosity**: Even the Default style, when explicitly selected, removes concise-output instructions

@../../Claude Code Features/27_Output_Styles/research.md
