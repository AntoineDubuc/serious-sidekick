---
name: serious-init
description: "Scaffold a new project with Claude Code feature documentation, skills, workflow templates, and CLAUDE.md. Use when the user says 'serious init', 'serious setup', 'bootstrap', or wants to set up a new project with the full serious workflow toolkit."
user-invocable: true
---

# Serious Init

Scaffold the current project with the full serious workflow toolkit: feature documentation, reference skills, workflow skills (`/serious-research`, `/serious-plan`), implementation plan template, and a CLAUDE.md with mandatory rules and feature index.

## Template Source

All template files live at:
```
/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/
```

## What Gets Copied

1. **CLAUDE.md** — Mandatory rules + feature index, loaded every session
2. **.claude/skills/** — All skills: 17 feature auto-loaders + `serious-research` + `serious-plan`
3. **Claude Code Features/** — 38 folders with detailed research.md files + README index
4. **_implementation_plan_template_v6.md** — The v6 implementation plan template (required by `/serious-plan`)

## Instructions

When the user invokes `/serious-init`, perform these steps:

### Step 1: Check for conflicts

- Check if `CLAUDE.md` already exists in the current directory
- Check if `.claude/skills/` already has any of the skills
- Check if `Claude Code Features/` already exists
- Check if `_implementation_plan_template_v6.md` already exists
- If any conflicts, ask the user whether to skip, merge, or overwrite

### Step 2: Copy the template files

Run these commands (adjust for any conflicts resolved in Step 1):

```bash
# Copy CLAUDE.md
cp "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/CLAUDE.md" ./CLAUDE.md

# Copy skills (create dir if needed)
mkdir -p .claude/skills
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/.claude/skills/"* .claude/skills/

# Copy feature documentation
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/Claude Code Features" "./Claude Code Features"

# Copy implementation plan template (required by /serious-plan)
cp "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/_implementation_plan_template_v6.md" ./_implementation_plan_template_v6.md
```

### Step 3: Adapt CLAUDE.md

- If the target project already has a CLAUDE.md, **append** the content rather than overwriting
- Preserve the mandatory rules section at the top
- If the project has existing content, add a separator (`---`) before the appended content

### Step 4: Confirm

Report what was copied:
- Number of skills installed (including `serious-research` and `serious-plan`)
- Number of feature research folders
- Whether CLAUDE.md was created or appended to
- Whether the v6 implementation plan template was installed
- Remind the user of the workflow:
  ```
  /serious-research   →  investigate a bug, feature, or question
  /serious-plan       →  generate an implementation plan
  ```

## Arguments

`$ARGUMENTS` can be used to customize:
- `--skills-only` — Only copy the .claude/skills/ (no documentation folders or template)
- `--docs-only` — Only copy Claude Code Features/ and CLAUDE.md (no skills or template)
- `--no-claude-md` — Skip CLAUDE.md (useful if they already have one)
