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

### Step 1: Detect global skills

Before copying anything, check whether skills are already installed at the user's global profile level. Check these paths in order:

```bash
# Standard Claude Code profile
~/.claude/skills/

# Any alternate profiles (e.g., ~/.claude-alex/skills/)
~/.claude-*/skills/
```

For each workflow skill (`serious-research`, `serious-plan`, `serious-code`, `serious-conversation`, `serious-bananas`, `serious-init`), check if a matching directory with a `SKILL.md` exists globally.

**If all workflow skills exist globally:** Skip local skills copy entirely. Report: "All workflow skills detected globally at {path} — skipping local copy."

**If some skills exist globally but not all:** Copy only the missing ones locally. Report which are global and which were copied locally.

**If no global skills found:** Proceed with full local copy (Step 3).

### Step 2: Check for conflicts

- Check if `CLAUDE.md` already exists in the current directory
- Check if `Claude Code Features/` already exists
- Check if `_implementation_plan_template_v6.md` already exists
- If skills are being copied locally (from Step 1), check if `.claude/skills/` already has any of them
- If any conflicts, ask the user whether to skip, merge, or overwrite

### Step 3: Copy the template files

Run these commands (adjust based on Step 1 global detection and Step 2 conflict resolution):

```bash
# Copy CLAUDE.md
cp "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/CLAUDE.md" ./CLAUDE.md

# Copy skills ONLY if not already installed globally (see Step 1)
mkdir -p .claude/skills
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/.claude/skills/"* .claude/skills/

# Copy feature documentation
cp -r "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/Claude Code Features" "./Claude Code Features"

# Copy implementation plan template (required by /serious-plan)
cp "/Users/cg-adubuc/Desktop/Antoine/_claude_code_template_/_implementation_plan_template_v6.md" ./_implementation_plan_template_v6.md
```

### Step 4: Adapt CLAUDE.md

- If the target project already has a CLAUDE.md, **append** the content rather than overwriting
- Preserve the mandatory rules section at the top
- If the project has existing content, add a separator (`---`) before the appended content

### Step 5: Confirm

Report what was set up:
- **Skills:** How many installed locally vs detected globally (and where)
- **Feature docs:** Number of feature research folders copied
- **CLAUDE.md:** Created or appended to
- **Template:** Whether the v6 implementation plan template was installed
- Remind the user of the workflow:
  ```
  /serious-conversation  →  brainstorm with AI personas
  /serious-research      →  investigate a bug, feature, or question
  /serious-plan          →  generate an implementation plan
  /serious-code          →  execute the plan with TDD and verification
  ```

## Arguments

`$ARGUMENTS` can be used to customize:
- `--skills-only` — Only copy the .claude/skills/ (no documentation folders or template)
- `--docs-only` — Only copy Claude Code Features/ and CLAUDE.md (no skills or template)
- `--no-claude-md` — Skip CLAUDE.md (useful if they already have one)
