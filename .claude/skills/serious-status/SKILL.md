---
name: serious-status
description: "Show all active and completed workflows with their tree structure. Use when the user says 'serious status', 'what am I working on', 'show workflows', 'where am I', or wants to see their workflow state."
user-invocable: true
---

# Serious Status

A read-only diagnostic command that scans all workflow folders, reads YAML frontmatter, reconstructs the parent-child tree, and displays a flat table. **This skill does NOT modify any files.**

---

## Phase 1: Scan

### 1a. Collect workflow folders

Scan these paths for workflow output files:

**Conversation workflows:**
- `Research/conversations/*/conversation.md`
- `Research/**/sub/*/conversation.md`

**Research, feature, bug, exploratory workflows:**
- `Research/bugs/*/research.md`
- `Research/features/*/research.md`
- `Research/exploratory/*/research.md`
- `Research/**/sub/*/research.md`

**Mock-up workflows:**
- `Research/**/mock-ups/mock-up-summary.md`
- `Research/**/sub/*/mock-ups/mock-up-summary.md`

**Scope workflows:**
- `Research/**/manifest.md`
- `Research/**/sub/*/manifest.md`

**Plan workflows:**
- `Research/**/implementation_plan.md`
- `Research/**/phase_map.md`
- `Research/**/sub/*/implementation_plan.md`
- `Research/**/sub/*/phase_map.md`

**Code workflows:**
- `Research/**/execution_log.md`
- `Research/**/sub/*/execution_log.md`

**Review workflows:**
- `Research/**/findings.md`
- `Research/**/verdict.md`
- `QA/*/findings.md`
- `Research/**/sub/*/findings.md`
- `Research/**/sub/*/verdict.md`

### 1b. Check breadcrumbs

Source `.claude/skills/_shared/path-resolve.sh`. Run `breadcrumb_migrate` once to delete legacy `.active-{skill}` files at the project root under the agreement-or-orphan condition (preserves `.active-conversation` as the in-flight parent carve-out; emits `MIGRATE:` lines to stderr for every action). Then for each known skill name in the writer roster (`conversation`, `research`, `mock-ups`, `scope`, `plan`, `review`, `code`, `debug`, `prospect-research`, `youtube-tldr`), enumerate ALL active sessions across terminals by running `breadcrumb_list_all {skill}` (which scans `.claude-active/*-{skill}` for every PID, NOT just this terminal's). Also read any legacy `.active-{skill}` files at the project root for transition-window completeness. Do NOT iterate `claude_pid` yourself — that would only show this terminal's session and silently hide every other terminal's active workflow.

For each breadcrumb found, display its filename (which encodes the {PID}), read its content for the slug + cwd, and validate the target folder exists. If it does, include it in the scan (it may point to a folder not covered by the standard paths above). If the target folder does NOT exist, note it as a stale breadcrumb for the warnings section.

---

## Phase 2: Parse Frontmatter

For each output file found, read the first 20 lines and attempt to parse YAML frontmatter (between `---` delimiters).

**Expected fields:**
- `skill:` — which skill produced this (conversation, research, mock-ups, scope, plan, review, code)
- `slug:` — the workflow's identifier
- `status:` — active, done, abandoned
- `parent:` — relative path to parent workflow folder (empty if top-level)
- `created:` — date (YYYY-MM-DD)

**Legacy fallback:** If no YAML frontmatter is found, attempt to read bold markdown headers:
- `**Status:** Complete` → status: done
- `**Status:** In Progress` → status: active
- `**Date:**` → created date
- `**Classification:**` → can infer slug from folder name

**If neither format is found:** Mark the workflow with status `?` (legacy/unknown).

**Frontmatter validation:**
- If YAML is present but malformed (unparseable), skip the file and add to warnings: `⚠ Malformed frontmatter: {path}`
- Use `skill:` field as primary source for determining the workflow stage
- Fall back to file existence priority only when no frontmatter exists:
  - `findings.md` or `verdict.md` → review
  - `execution_log.md` → code
  - `implementation_plan.md` or `phase_map.md` → plan
  - `manifest.md` → scope
  - `mock-up-summary.md` → mock-ups
  - `research.md` → research
  - `conversation.md` → conversation

---

## Phase 3: Build Tree

### 3a. Link parents and children

For each workflow with a `parent:` field, resolve the path and link it to its parent. If the parent path doesn't resolve to a known workflow, mark the child as an orphan.

### 3b. Identify roots

Roots are workflows with no `parent:` field (or orphaned workflows whose parent couldn't be resolved).

### 3c. Sort

Sort roots by `created:` date, newest first. Within each tree, sort children by `created:` date, newest first.

### 3d. Determine status

Status precedence:
1. **Breadcrumb file exists** for this workflow's skill type AND the breadcrumb points to this workflow's folder → **active** (live signal, overrides frontmatter)
2. **Frontmatter `status: done`** → **done** (authoritative terminal state)
3. **Frontmatter `status: abandoned`** → **abandoned** (authoritative terminal state)
4. **Frontmatter `status: active`** but no matching breadcrumb → **pending** (was active, may have been interrupted)
5. **No frontmatter** → **legacy** (unknown state)

---

## Phase 4: Render

### 4a. Table format

Display a flat table with tree indentation:

```
| Status | Workflow                          | Stage        | Path                                              |
|--------|-----------------------------------|--------------|----------------------------------------------------|
| ✓      | recursive-workflow-pipeline        | research     | Research/features/recursive-workflow-pipeline/      |
| ●      |   └ token-expiry-investigation    | research     | .../sub/token-expiry-investigation/                 |
| ○      |     └ token-cache-fix             | plan         | .../sub/token-cache-fix/                            |
| ✓      | notifications                     | code         | Research/features/notifications/                    |
| ✗      |   └ email-templates               | mock-ups     | .../sub/email-templates/                            |
| ?      | old-auth-fix                      | research     | Research/bugs/old-auth-fix/                         |
```

### 4b. Status glyphs

| Glyph | Meaning |
|-------|---------|
| `✓` | done |
| `●` | active (breadcrumb exists) |
| `○` | pending (was active, no breadcrumb now) |
| `✗` | abandoned |
| `?` | legacy (no frontmatter found) |

### 4c. Indentation

- 2 spaces per depth level
- `└` connector for children
- Example: depth 0 = no indent, depth 1 = `  └ `, depth 2 = `    └ `

### 4d. Path truncation

For deeply nested paths, truncate the beginning with `...` to keep the table readable. Show at minimum the last 2 path segments.

---

## Phase 5: Warnings

After the table, display any warnings:

- **Stale breadcrumbs:** `.active-{skill}` points to a folder that doesn't exist → `⚠ Stale breadcrumb: .active-{skill} → {path} (folder missing)`
- **Orphaned workflows:** `parent:` field points to a path that doesn't resolve → `⚠ Orphan: {slug} claims parent at {path} (not found)`
- **Malformed frontmatter:** YAML present but unparseable → `⚠ Malformed frontmatter: {path}`

---

## Phase 6: Empty State

If no workflow folders are found at all:

> "No workflows found. Start one with `/serious-conversation`, `/serious-research`, or `/serious-plan`."

---

## Arguments

`$ARGUMENTS` can specify:
- `--active` — show only active workflows (filter to `●` status)
- `--tree {slug}` — show only the tree containing the named workflow
- No arguments — show everything (default)
