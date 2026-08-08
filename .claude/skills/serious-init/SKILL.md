---
name: serious-init
description: "Scaffold a new project with Claude Code feature documentation, skills, workflow templates, and CLAUDE.md. Use when the user says 'serious init', 'serious setup', 'bootstrap', or wants to set up a new project with the full serious workflow toolkit."
user-invocable: true
---

# Serious Init

Scaffold or update the current project with the full serious workflow toolkit: feature documentation, skills, hooks, workflow skills, implementation plan template, and a CLAUDE.md with mandatory rules and feature index.

**Idempotent:** Running `/serious-init` on a project that already has the toolkit updates everything in place. Template-owned files are overwritten with the latest versions. Merge-owned files (settings.json) are merged using composite-key logic. User-init files (CLAUDE.md) are copied only on first install.

**Manifest-driven:** All file distribution is controlled by `manifest.json` in the template source. The manifest defines ownership tiers (template, merge, user-init) that determine how each file is handled during install and update.

## Template Source

The local clone of the Serious Sidekick template repo:
```
~/.serious-sidekick/
```

Override with: `SERIOUS_SIDEKICK_HOME` environment variable.

If `~/.serious-sidekick/` does not exist, clone the repo first:
```bash
git clone https://github.com/AntoineDubuc/serious-sidekick.git ~/.serious-sidekick
```

If it already exists, pull latest:
```bash
git -C ~/.serious-sidekick pull
```

## What Gets Installed

1. **CLAUDE.md** — Mandatory rules + feature index, loaded every session (user-init: copy on first install, ask before overwriting on update)
2. **.claude/skills/** — All skills (15 workflow + feature auto-loaders + hooks subfolder + Agent Teams agents). `serious-prospect-research` is deliberately NOT distributed — it carries internal sales positioning and is skipped by `bin/generate-manifest.sh`.
3. **.claude/agents/** — 10 Agent Teams agents (5 code + 5 review)
4. **.claude/settings.json** — Hook registration via composite-key merge (never overwrites non-hook user settings)
5. **Claude Code Features/** — 39 folders with detailed research.md files + README index
6. **_implementation_plan_template_v6.md** — The v6 implementation plan template (required by `/serious-plan`)
7. **_anti-rationalization-core.md** — Anti-rationalization reference (required by `/serious-review`)

### Workflow Skills (15)

| Skill | Purpose |
|-------|---------|
| `serious-init` | Scaffold/update project |
| `serious-youtube-tldr` | Video ingestion — transcripts and summaries |
| `serious-conversation` | Persona panel for ideation |
| `serious-research` | Structured investigation |
| `serious-mock-ups` | UI wireframes before planning |
| `serious-scope` | Scope manifest from research findings |
| `serious-plan` | Implementation planning (v6 template) |
| `serious-review` | Plan quality gate with mandatory review personas |
| `serious-fit` | Codebase-grounded restraint pass — duplication, over-building, convention fit |
| `serious-debloat` | Bloat audit on a plan or diff — recommends the smaller version |
| `serious-code` | Plan execution with TDD + Agent Teams |
| `serious-debug` | Systematic debugging — 3 modes |
| `serious-status` | Workflow tree + status dashboard |
| `serious-abandon` | Bail out of sub-workflows |
| `serious-bananas` | Image generation via Gemini |

## Instructions

When the user invokes `/serious-init`, perform these steps:

### Step 0: Resolve the template source

```bash
SIDEKICK_HOME="${SERIOUS_SIDEKICK_HOME:-$HOME/.serious-sidekick}"
```

If `$SIDEKICK_HOME` does not exist:
```bash
git clone https://github.com/AntoineDubuc/serious-sidekick.git "$SIDEKICK_HOME"
```

If it already exists, pull latest:
```bash
git -C "$SIDEKICK_HOME" pull
```

Confirm the manifest and shared library exist:
```bash
ls "$SIDEKICK_HOME/manifest.json"
ls "$SIDEKICK_HOME/lib/serious-common.sh"
```

If either is missing, abort with an error telling the user to re-clone.

### Step 1: Detect what exists

Check the target project (`$PROJECT` = the current working directory) for existing installations:

```
Existing $PROJECT/.claude/skills/ ?
Existing $PROJECT/.claude/settings.json ?
Existing $PROJECT/CLAUDE.md ?
Existing $PROJECT/Claude Code Features/ ?
Existing $PROJECT/_implementation_plan_template_v6.md ?
Existing $PROJECT/_anti-rationalization-core.md ?
```

Also check for existing global profile installations:
```bash
ls ~/.claude/skills/ 2>/dev/null
ls ~/.claude-*/skills/ 2>/dev/null
```

Report: "Updating existing installation" or "Fresh install".

### Step 2: Parse the manifest and distribute files to the project

Source the shared library and parse the manifest:

```bash
source "$SIDEKICK_HOME/lib/serious-common.sh"
MANIFEST_ENTRIES=$(parse_manifest "$SIDEKICK_HOME/manifest.json")
```

For each entry in `MANIFEST_ENTRIES` (tab-separated: `source_path\townership\tdest\tsha256\tmerge_key`), apply the appropriate ownership logic to the **project's `.claude/` directory**:

**Template-owned files** (`ownership=template`):
- Source: `$SIDEKICK_HOME/<source_path>`
- Destination: `$PROJECT/.claude/<dest>`
- Note: entries with `dest` starting with `../` go to the project root (e.g., `../_implementation_plan_template_v6.md` becomes `$PROJECT/_implementation_plan_template_v6.md`)
- Action: always overwrite (create parent directories as needed)
- This covers: all skills, all agents, hook scripts, template files

**Merge-owned files** (`ownership=merge`):
- Currently: `.claude/settings.json` only
- If `$PROJECT/.claude/settings.json` does NOT exist (fresh install):
  - **Before copying, validate that the template's top-level JSON keys are all in `ALLOWED_TOP_LEVEL_KEYS` (defined in `lib/serious-common.sh`).** If unknown keys exist, ABORT with an error -- do NOT copy the template. This prevents a tampered upstream template from injecting malicious keys into a fresh install.
  - If all keys are allowlisted, proceed with the copy from `$SIDEKICK_HOME/.claude/settings.json`
- If it DOES exist (upgrade): run `merge_settings "$PROJECT/.claude/settings.json" "$SIDEKICK_HOME/.claude/settings.json"`
  - `merge_settings` has its own `ALLOWED_TOP_LEVEL_KEYS` check and will reject templates with unknown keys
- This preserves the user's non-hook settings while updating all serious-owned hook entries

**User-init files** (`ownership=user-init`):
- Currently: `CLAUDE.md` only
- If `$PROJECT/CLAUDE.md` does NOT exist: copy from `$SIDEKICK_HOME/CLAUDE.md`
- If it DOES exist: ask the user: "CLAUDE.md already exists. Overwrite with the template version, or skip?"
  - Overwrite: replace entirely
  - Skip: leave as-is

**Important:** Each skill's `hooks/` subfolder must be included in the copy — they contain the Stop hook scripts that enforce quality gates.

### Step 3: Copy Claude Code Features documentation

The `Claude Code Features/` directory is NOT tracked in the manifest (it is a bulk documentation folder). Copy it directly:

```bash
cp -r "$SIDEKICK_HOME/Claude Code Features" "$PROJECT/Claude Code Features"
```

This always overwrites — that is the update mechanism for documentation.

### Step 4: Update global directories

By default, also update the 3 global skill directories so slash commands are available globally:

```bash
~/.claude/
~/.claude-work/
~/.claude-alex/
```

For each global directory, apply the same manifest-driven distribution logic:
- Template-owned: overwrite
- Merge-owned (settings.json): use `merge_settings()` for composite-key merge
- User-init: skip if exists (do NOT prompt for global dirs — they are non-interactive)

**Skip this step if `--no-global` is passed.**

The global dirs receive the same `.claude/` content (skills, agents, settings.json, hooks). They do NOT receive `Claude Code Features/`, `CLAUDE.md`, or template files — those are project-level only.

### Step 4b: Validate hook configuration (MANDATORY)

After writing or merging settings.json (both project and global), validate:

1. **No `if` field on Stop hooks.** Adding `if` to a Stop hook silently prevents it from running — this breaks enforcement. Scan all Stop hook entries and reject any that contain an `if` field:
```bash
# Pseudocode — implement in whatever language the init uses
for each hook in settings.hooks.Stop[*].hooks[*]:
  if hook has "if" field:
    ERROR: "Stop hook '${hook.command}' has an 'if' field. This will BREAK the hook — 'if' only works on tool events (PreToolUse, PostToolUse). Remove the 'if' field."
    EXIT with error
```

2. **PreToolUse matcher must be `"Edit|Write"`, not `"Write"`.** A `"Write"`-only matcher misses Edit tool calls, creating an enforcement gap.

3. **All `if` patterns must include the tool name.** `if: "Write(*verdict*)"` is correct. `if: "*verdict*"` without a tool name is invalid.

Run this validation on every settings.json that was written or merged (project + all global dirs). If any validation fails, report the error and fix it before continuing.

### Step 5: Verify and report

Check that everything was installed correctly:

```
Skills: N installed (.claude/skills/)
Agents: N installed (.claude/agents/)
Hooks: N Stop hooks + N PreToolUse handlers (with conditional if filtering) registered in .claude/settings.json
Validation: No if fields on Stop hooks, matcher is Edit|Write
Docs: N feature folders (Claude Code Features/)
Template: _implementation_plan_template_v6.md
Template: _anti-rationalization-core.md
CLAUDE.md: installed / skipped / updated
```

**Key:** Use `$CLAUDE_PROJECT_DIR` in hook commands — Claude Code provides this at runtime, making paths portable.

Report whether this was a fresh install or an update:
- **Fresh:** "Serious Sidekick installed. Here's the workflow..."
- **Update:** "Updated to latest. Changes: {list what was newer in template}"

Remind the user of the workflow:
```
/serious-conversation  →  brainstorm with AI personas
/serious-research      →  investigate a bug, feature, or question
/serious-mock-ups      →  wireframes and visual mock-ups
/serious-scope         →  scope manifest from research findings
/serious-plan          →  generate an implementation plan
/serious-review        →  plan quality gate (runs before code)
/serious-code          →  execute the plan with TDD and verification
/serious-status        →  see all active workflows
/serious-abandon       →  bail out of a sub-workflow
```

## Arguments

`$ARGUMENTS` can be used to customize:
- `--skills-only` — Only distribute .claude/ manifest entries (skills, agents, hooks, settings.json). No docs, no CLAUDE.md, no template files.
- `--docs-only` — Only copy Claude Code Features/ and handle CLAUDE.md. No skills, hooks, agents, or template files.
- `--no-claude-md` — Skip CLAUDE.md handling entirely (useful if they already have a customized one)
- `--no-global` — Skip updating the 3 global directories (~/.claude/, ~/.claude-work/, ~/.claude-alex/)
- `--dry-run` — Show what would be installed/updated without making changes. For each manifest entry, report whether it would be NEW, OVERWRITE, MERGE, SKIP, or CURRENT.

## Hooks Reference

The hooks configuration has two sections, both managed via `settings.json`:

**PreToolUse hooks** (matcher: `"Edit|Write"`) — 3 gates with conditional `if` filtering:
- **TDD Gate**: 14 code extensions x 2 tools (Write + Edit) = 28 handlers with `if` patterns (e.g., `if: "Write(*.ts)"`, `if: "Edit(*.ts)"`)
- **Hedge Language Gate**: 2 handlers — `if: "Write(*implementation_plan*.md)"` + `if: "Edit(*implementation_plan*.md)"`
- **Review Theater Gate**: 2 handlers — `if: "Write(*review_verdict*)"` + `if: "Edit(*review_verdict*)"`

**Stop hooks** (6) — fire on session exit:

| Hook | Skill | What it catches |
|------|-------|-----------------|
| verify-completion-gate.sh | /serious-code | Blocks exit without gate_passed.md evidence |
| capture-conversation.sh | /serious-conversation | Warns if done without summary.md |
| capture-research.sh | /serious-research | Warns if research still active |
| check-extraction.sh | /serious-plan | Warns if plan has upstream but no _extracted_items.md |
| check-manifest.sh | /serious-scope | Warns if scope started but no manifest.md |
| check-verdict.sh | /serious-review | Warns if review started but no verdict |
