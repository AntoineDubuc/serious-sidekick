# Smoke Test: Baseline Audit — Task 0

**Date:** 2026-03-09

## Breadcrumb Status

| Skill | Has Breadcrumb? | Breadcrumb File | Write Location | Remove Location |
|-------|----------------|-----------------|----------------|-----------------|
| conversation | YES | `.active-conversation` | Phase 0e | Phase 3c (wrap-up) |
| research | YES | `.active-research` | Phase 1b | Phase 6 (cleanup) |
| mock-ups | NO | — | — | — |
| plan | NO | — | — | — |
| code | YES | `.active-code` | Phase 0d | Phase 2b (cleanup) |
| review | NO | — | — | — |

**3 of 6 skills have breadcrumbs. 3 need them added: mock-ups, plan, review.**

## YAML Frontmatter Status

| Skill | Has YAML Frontmatter in output template? |
|-------|----------------------------------------|
| conversation | NO — no structured metadata in conversation.md template |
| research | NO — uses `**Status:**`, `**Date:**` bold markdown headers |
| mock-ups | NO — mock-up-summary.md created at end (Phase 4) with no metadata |
| plan | NO — implementation_plan.md uses markdown sections only |
| code | NO — execution_log.md uses `**Status:**` bold headers |
| review | NO — findings.md uses `**Status:**` bold headers |

**0 of 6 skills use YAML frontmatter. ALL 6 need it added.**

## Research.md Metadata Format

Research uses bold markdown headers, NOT YAML frontmatter:
- `**Status:** In Progress` (line ~156 in template)
- `**Date:**`, `**Classification:**`, `**Scope:**`, `**Mode:**`

Skills that auto-detect research status (plan, mock-ups) currently check for `**Status: Complete**`.

## Current .active-* Files in Project Root

**None.** (No active workflows — clean state.)
Note: `.active-code` was just created by this /serious-code session.

## Conclusion

Baseline confirmed — matches research findings exactly:
- 3 skills need breadcrumbs added
- 6 skills need YAML frontmatter added
- Research format change (bold → YAML) will need legacy fallback
- Clean starting state (no pre-existing breadcrumbs to conflict)
