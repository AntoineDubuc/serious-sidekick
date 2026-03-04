# Plan Mode

## Overview

Plan Mode is a read-only exploration mode in Claude Code that instructs Claude to analyze the codebase and create a detailed plan without making any modifications. It restricts Claude's behavior to analysis-only operations, making it ideal for exploring unfamiliar codebases, planning complex refactors, or reviewing code safely before committing to changes. Plan Mode is implemented primarily through system prompt instructions rather than hard technical tool restrictions.

## Key Capabilities

- **Read-only codebase exploration**: Claude analyzes code, traces execution flows, and understands architecture without modifying any files
- **Structured planning workflow**: Claude follows a four-phase approach: (1) understanding the request and codebase, (2) designing implementation approach, (3) reviewing plan alignment, (4) writing the final plan
- **Interactive requirement gathering**: Claude uses the `AskUserQuestion` tool to gather requirements and clarify goals before proposing a plan
- **Plan file creation**: Claude writes a markdown plan file that can be reviewed and edited before execution
- **Explore Subagent**: A Haiku-powered specialist that automatically activates during Plan Mode to efficiently search the codebase while saving context tokens
- **Seamless mode transitions**: Claude can exit plan mode via the `ExitPlanMode` tool when planning is complete, signaling readiness for user review

## Configuration / Setup

### Activating Plan Mode

There are three ways to enter Plan Mode:

1. **Shift+Tab cycling**: Press `Shift+Tab` to cycle through permission modes. The first press switches to Auto-Accept Mode (indicated by `⏵⏵ accept edits on`), and the second press activates Plan Mode (indicated by `⏸ plan mode on`). On some configurations, `Alt+M` can also be used.

2. **The /plan command**: Type `/plan` at the prompt to enter Plan Mode directly during a session.

3. **CLI flag**: Start a new session in Plan Mode with the `--permission-mode plan` flag:
   ```bash
   claude --permission-mode plan
   ```

4. **Headless mode**: Run a query in Plan Mode directly with `-p`:
   ```bash
   claude --permission-mode plan -p "Analyze the authentication system and suggest improvements"
   ```

### Setting Plan Mode as Default

Configure Plan Mode as the default permission mode in project settings:

```json
// .claude/settings.json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

## Usage Examples

### Planning a Complex Refactor

```bash
claude --permission-mode plan
```

Then ask:
```
I need to refactor our authentication system to use OAuth2. Create a detailed migration plan.
```

Claude will analyze the current implementation and create a comprehensive plan. Refine with follow-ups:
```
What about backward compatibility?
How should we handle database migration?
```

Press `Ctrl+G` to open the plan in your default text editor, where you can edit it directly before Claude proceeds.

### Codebase Exploration

```
Give me an overview of the authentication module architecture and identify potential security concerns.
```

### Multi-step Implementation Planning

When a feature requires making edits to many files, Plan Mode allows you to iterate on the direction with Claude before any changes are made.

## Important Details

### How Plan Mode Works Internally

Plan Mode operates primarily through prompt injection rather than hard technical enforcement. When Plan Mode is activated, the system adds contextual instructions that read: "Plan mode is active. The user indicated that they do not want you to execute yet -- you MUST NOT make any edits...run any non-readonly tools...or otherwise make any changes" (with plan file editing as the exception).

Tools are not technically removed in Plan Mode -- the distinction comes through prompt guidance. This means Claude is instructed to use read-only operations but this is not enforced at the tool level.

### Available Tools in Plan Mode

Claude is instructed to limit itself to read-only tools:
- **Read**: Read file contents
- **Glob**: Search for files by pattern
- **Grep**: Search file contents
- **WebFetch**: Fetch content from URLs
- **WebSearch**: Search the web
- **AskUserQuestion**: Ask the user clarifying questions
- **ExitPlanMode**: Signal that planning is complete and exit plan mode

### The Plan File Workflow

1. Claude creates a markdown plan file in its plans folder
2. Claude uses the edit file tool to update the plan as analysis progresses
3. When planning is complete, Claude invokes `ExitPlanMode` which reads the written plan file
4. The user can then review, edit (via `Ctrl+G`), and approve the plan before switching to normal mode for execution

### Four Planning Phases

The injected system prompt structures planning into:
- **Phase 1**: Understanding the request and codebase
- **Phase 2**: Designing the implementation approach
- **Phase 3**: Reviewing plan alignment with requirements
- **Phase 4**: Writing the final plan

### When to Use Plan Mode

- **Multi-step implementation**: When a feature requires edits across many files
- **Code exploration**: When researching the codebase thoroughly before making changes
- **Interactive development**: When iterating on direction with Claude
- **Safety-first workflows**: When you want to understand impact before any modifications

### Limitations

- Plan Mode is not strictly enforced at the tool level; it relies on prompt-based instructions
- Prompt suggestions are automatically skipped in Plan Mode
- Plan Mode does not restrict tool availability technically -- it guides behavior through natural language

## References

- [Interactive Mode - Claude Code Docs](https://code.claude.com/docs/en/interactive-mode) -- Official documentation on keyboard shortcuts and interactive features including Plan Mode
- [Common Workflows - Claude Code Docs](https://code.claude.com/docs/en/common-workflows) -- Official documentation on Plan Mode workflow and usage
- [CLI Reference - Claude Code Docs](https://code.claude.com/docs/en/cli-reference) -- Documentation on `--permission-mode plan` flag
- [What Actually Is Claude Code's Plan Mode?](https://lucumr.pocoo.org/2025/12/17/what-is-plan-mode/) -- Armin Ronacher's technical analysis of Plan Mode internals
- [Plan Mode in Claude Code](https://codewithmukesh.com/blog/plan-mode-claude-code/) -- Community guide on Plan Mode usage
