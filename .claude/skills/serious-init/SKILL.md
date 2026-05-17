---
name: serious-init
description: "Scaffold a new project with Claude Code feature documentation, skills, workflow templates, and CLAUDE.md. Use when the user says 'serious init', 'serious setup', 'bootstrap', or wants to set up a new project with the full serious workflow toolkit."
user-invocable: true
---

# Serious Init

Scaffold or update the current project with the full serious workflow toolkit: feature documentation, skills, hooks, workflow skills, implementation plan template, and a CLAUDE.md with mandatory rules and feature index.

<!-- BEGIN CANONICAL VOICE BLOCK — do not edit; lint compares byte-for-byte across 24 surfaces -->
## Voice (MANDATORY — applies to all chat replies)

Talk to the user like a busy PM, not an engineer. Every chat reply uses this structure:

1. **What this does** — one sentence. Plain English. What the user experiences.
2. **What I need from you** — one ask, sometimes a short numbered list.
3. **What you need to set up first** — only if there's prep on the user's side.
4. **Question** — one line. Just the question, no preamble.

Style:
- ~10 lines max.
- No internal task labels ("Task 5", "Phase 2", "Plan 7B", "1v", "T0").
- No bare ordinal options ("Option 1", "Option 2"). Label alternatives by what they are.
- No file paths, library names, or framework names in chat.

Canonical card: `.claude/skills/_shared/voice-card.md`.
<!-- END CANONICAL VOICE BLOCK -->

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
2. **.claude/skills/** — All skills (11 workflow + feature auto-loaders + hooks subfolder + Agent Teams agents)
3. **.claude/agents/** — 8 Agent Teams agents (5 code + 3 review)
4. **.claude/settings.json** — Hook registration via composite-key merge (never overwrites non-hook user settings)
5. **Claude Code Features/** — 39 folders with detailed research.md files + README index
6. **_implementation_plan_template_v6.md** — The v6 implementation plan template (required by `/serious-plan`)
7. **_anti-rationalization-core.md** — Anti-rationalization reference (required by `/serious-review`)

### Workflow Skills (11)

| Skill | Purpose |
|-------|---------|
| `serious-init` | Scaffold/update project |
| `serious-conversation` | Persona panel for ideation |
| `serious-research` | Structured investigation |
| `serious-mock-ups` | UI wireframes before planning |
| `serious-scope` | Scope manifest from research findings |
| `serious-plan` | Implementation planning (v6 template) |
| `serious-review` | Plan quality gate with mandatory review personas |
| `serious-code` | Plan execution with TDD + Agent Teams |
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

<!-- voice-retrofit: rewritten; thread-1 line: 107 -->
Report in PM voice — "What this does: this looks like a first install — I'll set everything up for you" or "What this does: I see this is already set up; I'll update what's changed." No further detail unless the user asks.

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
<!-- voice-retrofit: rewritten; thread-1 line: 139 -->
- If it DOES exist: ask the user in PM voice — "What this does: there's already a project-config file on disk with your custom settings. I can replace it with our standard one or leave yours alone. Question: replace or skip?"
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
<!-- voice-retrofit: rewritten; thread-1 line: 183 -->
<!-- Surface the error to the user in PM voice, NOT verbatim: "What this does: the
     install template has a misconfiguration that would break the safety net. I'll skip
     it and warn the operator. Question: continue with the rest of the install, or stop?" -->
    ERROR: "Stop hook '${hook.command}' has an 'if' field. This will BREAK the hook — 'if' only works on tool events (PreToolUse, PostToolUse). Remove the 'if' field."
    EXIT with error
```

2. **PreToolUse matcher must be `"Edit|Write"`, not `"Write"`.** A `"Write"`-only matcher misses Edit tool calls, creating an enforcement gap.

3. **All `if` patterns must include the tool name.** `if: "Write(*verdict*)"` is correct. `if: "*verdict*"` without a tool name is invalid.

Run this validation on every settings.json that was written or merged (project + all global dirs). If any validation fails, report the error and fix it before continuing.

### Step 5: Verify and report

Check that everything was installed correctly.

<!-- voice-retrofit: rewritten; thread-1 line: 197 -->

Internally verify the count of installed components. For the user-facing report, use PM voice:

> What this does: all set — the workflows, sub-agents, safety nets, and reference docs are installed and validated.
>
> Question: ready to try one out?

Don't dump counts, folder paths, or template filenames to the user. The technical breakdown is for the operator (visible in the install log).

Internal count breakdown (operator-side only):
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

Remind the user of the workflow in PM voice.

<!-- voice-retrofit: rewritten; thread-1 line: 214 -->

Don't dump a 9-command menu. Recommend ONE thing to try first based on context (typically "brainstorm with the AI personas — fastest way to feel it"). Mention that other workflows exist if they want to explore.

> What this does: you're set up. Easiest first try is the brainstorm — describe what you're working on and a panel of AI personas talks it through with you. Takes ~5 minutes to feel the vibe.
>
> Question: want to try that, or just leave it for now?

The full command list lives in the project's CLAUDE.md if the user wants to browse later. Internal reference (for the agent's own use, NOT chat output):
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

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 236 -->
<!-- WHY: this is operator/engineering reference documentation about the hooks installed.
     It's reference material for the project maintainer, not chat output to the user. -->
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

