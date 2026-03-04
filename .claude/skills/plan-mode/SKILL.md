---
name: plan-mode
description: "Auto-load when user asks about plan mode, read-only exploration, analysis-only mode, planning before implementation, or safe codebase exploration."
---

# Claude Code Plan Mode

## Quick Reference
- Plan Mode restricts Claude to read-only analysis and structured planning without modifying files
- Operates through system prompt instructions, NOT hard technical tool restrictions
- Claude follows four phases: (1) understand request/codebase, (2) design approach, (3) review alignment, (4) write plan
- Uses the Explore subagent (Haiku-powered) for efficient codebase searching
- Claude creates a markdown plan file that can be reviewed and edited before execution
- `ExitPlanMode` tool signals planning is complete; user reviews then switches to normal mode
- `Ctrl+G` opens the plan file in your default text editor for direct editing

## Configuration

### Activating Plan Mode

```bash
# Method 1: Shift+Tab cycling (in interactive mode)
# First press: Auto-Accept Mode, Second press: Plan Mode (shows "plan mode on")

# Method 2: /plan command during a session
> /plan

# Method 3: CLI flag
claude --permission-mode plan

# Method 4: Headless mode
claude --permission-mode plan -p "Analyze the auth system and suggest improvements"
```

### Set Plan Mode as default
```json
// .claude/settings.json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

## Common Patterns

### Planning a complex refactor
```bash
claude --permission-mode plan
> I need to refactor our authentication system to use OAuth2. Create a detailed migration plan.
> What about backward compatibility?
> How should we handle database migration?
# Press Ctrl+G to open and edit the plan
# Switch to normal mode to execute
```

### Safe codebase exploration
```
> Give me an overview of the authentication module architecture and identify security concerns.
```

### Multi-step implementation planning
When a feature requires edits across many files, iterate on direction with Claude before any changes are made. Review the plan, refine, then switch modes to execute.

## Gotchas
- Plan Mode is NOT strictly enforced at the tool level. It relies on prompt-based instructions, meaning Claude is guided but not technically blocked from using write tools.
- Available tools in Plan Mode: Read, Glob, Grep, WebFetch, WebSearch, AskUserQuestion, ExitPlanMode
- Prompt suggestions are automatically skipped in Plan Mode
- The plan file workflow: Claude creates it, updates as analysis progresses, then calls ExitPlanMode which reads the final plan
- Best used for: multi-step implementations, codebase exploration, iterative direction-setting, safety-first workflows

@./Claude Code Features/21_Plan_Mode/research.md
