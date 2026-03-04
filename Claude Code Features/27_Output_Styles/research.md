# Output Styles

## Overview

Output Styles allow you to fundamentally alter how Claude Code communicates and behaves by directly modifying its system prompt. This feature enables Claude Code to be used as any type of agent -- not just a software engineering assistant -- while retaining its core capabilities such as running local scripts, reading/writing files, and tracking TODOs. Output styles can be selected from built-in presets or created as custom Markdown files with frontmatter.

## Key Capabilities

- **Three built-in styles**: Default, Explanatory, and Learning -- each designed for different workflows.
- **Custom style creation**: Define entirely new behavior profiles using Markdown files with YAML frontmatter.
- **System prompt replacement**: Output styles directly modify Claude Code's system prompt, unlike CLAUDE.md or `--append-system-prompt` which only add to it.
- **Non-coding agent support**: Custom output styles exclude the default coding-specific instructions (unless `keep-coding-instructions` is set to `true`), allowing Claude Code to function as a general-purpose agent.
- **All styles** exclude the default instructions for efficient/concise output, so responses are naturally more verbose and explanatory.
- **Style adherence reminders**: All output styles trigger periodic reminders during the conversation to ensure Claude continues following the style instructions.

## Built-in Styles

### Default
The existing Claude Code system prompt, optimized for completing software engineering tasks efficiently. This is what you get when no output style is selected.

### Explanatory
Provides educational "Insights" in between helping you complete software engineering tasks. Helps you understand implementation choices and codebase patterns. Good for developers who want to learn about the codebase as they work.

### Learning
A collaborative, learn-by-doing mode. Claude not only shares "Insights" while coding, but also asks you to contribute small, strategic pieces of code yourself. Claude adds `TODO(human)` markers in your code for you to implement. This is designed for pair-programming-style learning.

## Configuration / Setup

### Selecting a Style

You can change your output style in two ways:

1. **Interactive menu**: Run `/output-style` to access a selection menu (also accessible from `/config`).
2. **Direct selection**: Run `/output-style [style]`, for example `/output-style explanatory`, to switch directly.

Style selections are saved at the local project level in `.claude/settings.local.json` under the `outputStyle` field. You can also directly edit this field in a settings file at a different level.

### Creating a Custom Style

Custom output styles are Markdown files with YAML frontmatter. Save them in one of two locations:

- **User level**: `~/.claude/output-styles/` (available across all projects)
- **Project level**: `.claude/output-styles/` (specific to the project)

#### File Format

```markdown
---
name: My Custom Style
description: A brief description of what this style does, to be displayed to the user
keep-coding-instructions: false
---

# Custom Style Instructions

You are an interactive CLI tool that helps users with software engineering
tasks. [Your custom instructions here...]

## Specific Behaviors

[Define how the assistant should behave in this style...]
```

#### Frontmatter Fields

| Field                      | Purpose                                                                     | Default                 |
|:---------------------------|:----------------------------------------------------------------------------|:------------------------|
| `name`                     | Name of the output style, if not the file name                              | Inherits from file name |
| `description`              | Description shown in the `/output-style` UI                                 | None                    |
| `keep-coding-instructions` | Whether to keep the coding-specific parts of Claude Code's system prompt    | `false`                 |

### Generating a Style with Claude

Run `/output-style:new` followed by a description of the style you want. Claude will generate a Markdown file and save it in your `~/.claude/output-styles/` directory.

## Usage Examples

**Switch to the Explanatory style for a code review session:**
```
/output-style explanatory
```

**Create a custom style for technical writing:**
```markdown
---
name: Technical Writer
description: Focused on generating clear technical documentation
keep-coding-instructions: true
---

# Technical Writing Assistant

You help users create clear, well-structured technical documentation.

## Behaviors
- Write in plain, direct language
- Use consistent heading hierarchies
- Include code examples where relevant
- Follow the project's existing documentation conventions
```

**Switch back to Default:**
```
/output-style default
```

## Important Details

- **System prompt replacement**: Output styles are more powerful than CLAUDE.md or `--append-system-prompt`. CLAUDE.md adds content as a user message after the system prompt. `--append-system-prompt` appends to the system prompt. Output styles replace the engineering-specific portions of the system prompt entirely.
- **Custom styles disable coding instructions by default**: When `keep-coding-instructions` is `false` (the default for custom styles), instructions for coding best practices such as "verify code with tests" are removed. Set it to `true` if you want a custom communication style but still want coding guidance.
- **Output Styles vs. Agents**: Output styles affect the main agent loop and only modify the system prompt. Agents (sub-agents) are invoked for specific tasks and can include additional settings like model selection and available tools.
- **Output Styles vs. Skills**: Output styles modify how Claude responds (formatting, tone, structure) and are always active once selected. Skills are task-specific prompts invoked with `/skill-name` or loaded automatically when relevant. Use output styles for consistent formatting preferences; use skills for reusable workflows.
- **Persistence**: Style selections are saved in settings and persist across sessions until changed.

## References

- [Output Styles - Claude Code Docs](https://code.claude.com/docs/en/output-styles) -- Official documentation covering built-in styles, custom style creation, and comparisons to related features
- [A practical guide to output styles in Claude Code](https://www.eesel.ai/blog/output-styles-claude-code) -- Community guide with practical tips
- [awesome-claude-code-output-styles](https://github.com/hesreallyhim/awesome-claude-code-output-styles-that-i-really-like) -- Curated collection of community-created output styles
