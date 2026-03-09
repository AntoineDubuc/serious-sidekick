---
task: 4
title: Create /serious-status skill
gate: PASSED
verified_by: completion-gate-subagent
date: 2026-03-09
---

# Task 4 Completion Gate: PASSED

All acceptance criteria, negative tests, and evidence requirements verified.

## Acceptance Criteria Results

| AC  | Description | Result |
|-----|-------------|--------|
| AC1 | Correct frontmatter (name, user-invocable, no hooks) | PASS |
| AC2 | Description triggers on all four phrases | PASS |
| AC3 | Scan algorithm covers all required paths | PASS |
| AC4 | Checks .active-* breadcrumbs for non-standard locations | PASS |
| AC5 | Reads YAML frontmatter fields (skill, slug, status, parent, created) | PASS |
| AC6 | Falls back to markdown bold headers for legacy files | PASS |
| AC7 | Uses skill: field as primary stage source, file existence as fallback | PASS |
| AC8 | Builds tree from parent: references, identifies roots | PASS |
| AC9 | Sorts roots by created: date (newest first) | PASS |
| AC10 | Status precedence: breadcrumb=active, done/abandoned=terminal | PASS |
| AC11 | Flat table with Status, Workflow, Stage, Path columns | PASS |
| AC12 | Correct status glyphs (check, bullet, circle, x, ?) | PASS |
| AC13 | 2-space indentation with connector for children | PASS |
| AC14 | Validates frontmatter, skips malformed with warning | PASS |
| AC15 | Validates parent paths, shows orphans at top level with warning | PASS |

## Negative Test Results

| NT  | Description | Result |
|-----|-------------|--------|
| NT1 | Does NOT modify any files (read-only) | PASS |
| NT2 | Does NOT crash on empty Research/ folder | PASS |
| NT3 | Does NOT crash on files without frontmatter | PASS |

## Evidence

| EV  | Description | Result |
|-----|-------------|--------|
| EV1 | Full SKILL.md content verified by reading | PASS |
| EV2 | Example output format matches spec | PASS |

## Key Evidence Quotes

**AC1 (frontmatter):** Lines 1-5 contain `name: serious-status`, `user-invocable: true`, no hooks field.

**AC2 (triggers):** Description includes 'serious status', 'what am I working on', 'show workflows', 'where am I'.

**AC10 (status precedence):** Lines 110-115 define: breadcrumb=active (overrides frontmatter), done/abandoned are authoritative terminal states, active without breadcrumb=pending, no frontmatter=legacy.

**AC12 (glyphs):** Lines 138-144 define all five glyphs matching spec exactly.

**NT1 (read-only):** Line 9: "This skill does NOT modify any files."

**NT2 (empty state):** Lines 168-172: Shows "No workflows found" message with suggested next commands.

## Verified File

- `.claude/skills/serious-status/SKILL.md` (182 lines, fully read and verified)
