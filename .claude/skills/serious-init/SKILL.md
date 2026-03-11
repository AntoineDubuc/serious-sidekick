---
name: serious-init
description: "Scaffold a new project with Claude Code feature documentation, skills, workflow templates, and CLAUDE.md. Use when the user says 'serious init', 'serious setup', 'bootstrap', or wants to set up a new project with the full serious workflow toolkit."
user-invocable: true
---

# Serious Init

Scaffold or update the current project with the full serious workflow toolkit: feature documentation, skills, hooks, workflow skills, implementation plan template, and a CLAUDE.md with mandatory rules and feature index.

**Idempotent:** Running `/serious-init` on a project that already has the toolkit updates everything in place. Files are overwritten with the latest versions — no duplication.

## Template Source

All template files live at:
```
/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/
```

## What Gets Installed

1. **CLAUDE.md** — Mandatory rules + feature index, loaded every session
2. **.claude/skills/** — All skills (10 workflow + 17 feature auto-loaders + hooks subfolder + 5 Agent Teams agents)
3. **.claude/settings.json** — Stop hook registration for the Completion Gate
4. **Claude Code Features/** — 38 folders with detailed research.md files + README index
5. **_implementation_plan_template_v6.md** — The v6 implementation plan template (required by `/serious-plan`)

### Workflow Skills (10)

| Skill | Purpose |
|-------|---------|
| `serious-init` | Scaffold/update project |
| `serious-conversation` | Persona panel for ideation |
| `serious-research` | Structured investigation |
| `serious-mock-ups` | UI wireframes before planning |
| `serious-plan` | Implementation planning (v6 template) |
| `serious-code` | Plan execution with TDD + Agent Teams |
| `serious-review` | Structured review + defect capture |
| `serious-status` | Workflow tree + status dashboard |
| `serious-abandon` | Bail out of sub-workflows |
| `serious-bananas` | Image generation via Gemini |

## Instructions

When the user invokes `/serious-init`, perform these steps:

### Step 1: Detect what exists

Check the target project for existing installations:

```
Existing .claude/skills/ ?
Existing .claude/settings.json ?
Existing CLAUDE.md ?
Existing Claude Code Features/ ?
Existing _implementation_plan_template_v6.md ?
```

Also check for global profile skills:
```bash
~/.claude/skills/
~/.claude-*/skills/
```

Report: "Updating existing installation" or "Fresh install".

### Step 2: Copy skills

Copy all skills from the template to the project. This always overwrites — that's the update mechanism.

```bash
# Create directories if needed
mkdir -p .claude/skills
mkdir -p .claude/agents

# Copy all skills (overwrites existing)
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/.claude/skills/"* .claude/skills/

# Copy Agent Teams agents (overwrites existing)
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/.claude/agents/"* .claude/agents/
```

**Important:** The `serious-code/hooks/` subfolder must be included — it contains `verify-completion-gate.sh` which is referenced by the Stop hook.

### Step 3: Register hooks in settings.json

The Completion Gate stop hook must be registered in `.claude/settings.json`. This is what makes the hook actually fire — the script alone does nothing without registration.

**If `.claude/settings.json` does not exist:** Copy the template's settings.json:
```bash
cp "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/.claude/settings.json" .claude/settings.json
```

**If `.claude/settings.json` already exists:** Merge the hooks. Read the existing file, check if `hooks.Stop` already has the `verify-completion-gate.sh` entry. If not, add it. If yes, update the command path. Do NOT overwrite the entire file — preserve the user's other settings.

The hook entry to ensure exists:
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/skills/serious-code/hooks/verify-completion-gate.sh\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Key:** Use `$CLAUDE_PROJECT_DIR` in the command — Claude Code provides this environment variable at runtime, making the path portable across machines.

### Step 4: Copy documentation and template

```bash
# Copy feature documentation (overwrites existing)
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/Claude Code Features" "./Claude Code Features"

# Copy implementation plan template (overwrites existing)
cp "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/_implementation_plan_template_v6.md" ./_implementation_plan_template_v6.md
```

### Step 5: Handle CLAUDE.md

- **If CLAUDE.md does not exist:** Copy from template
- **If CLAUDE.md exists:** Ask the user: "CLAUDE.md already exists. Overwrite with the template version, or skip?"
  - Overwrite: replace entirely
  - Skip: leave as-is

### Step 6: Verify and report

Check that everything was installed correctly:

```
✓ Skills: 28 installed (.claude/skills/)
✓ Agents: 5 installed (.claude/agents/)
✓ Hooks: Stop hook registered in .claude/settings.json
✓ Docs: 38 feature folders (Claude Code Features/)
✓ Template: _implementation_plan_template_v6.md
✓ CLAUDE.md: installed / skipped
```

Report whether this was a fresh install or an update:
- **Fresh:** "Serious Sidekick installed. Here's the workflow..."
- **Update:** "Updated to latest. Changes: {list what was newer in template}"

Remind the user of the workflow:
```
/serious-conversation  →  brainstorm with AI personas
/serious-research      →  investigate a bug, feature, or question
/serious-mock-ups      →  wireframes and visual mock-ups
/serious-plan          →  generate an implementation plan
/serious-code          →  execute the plan with TDD and verification
/serious-review        →  capture defects and cycle back
/serious-status        →  see all active workflows
/serious-abandon       →  bail out of a sub-workflow
```

## Arguments

`$ARGUMENTS` can be used to customize:
- `--skills-only` — Only copy .claude/skills/ and register hooks (no docs or template)
- `--docs-only` — Only copy Claude Code Features/ and CLAUDE.md (no skills, hooks, or template)
- `--no-claude-md` — Skip CLAUDE.md (useful if they already have a customized one)
- `--dry-run` — Show what would be installed/updated without making changes
