# Implementation Report

**Task:** Task 2 — Add Staleness Detection (Steps 2b + 2c) to All 9 Skill Files
**Status:** COMPLETE

### Criteria Implemented
| # | Criterion | Test File | Status |
|---|-----------|-----------|--------|
| 1 | All 9 files contain step 2b "Status-based staleness check" | grep -c "Status-based staleness" = 1 per file | PASS |
| 2 | Step 2b specifies detection method (read first 10 lines, grep ^status:, done/abandoned = stale, remove silently) | Visual inspection of verbose text | PASS |
| 3 | All 9 files contain step 2c "Age-based staleness check" | grep -c "Age-based staleness" = 1 per file | PASS |
| 4 | Step 2c specifies age check (stat -f %m macOS, stat -c %Y Linux, ls -l fallback, 4-hour threshold, user prompt) | Visual inspection of verbose text | PASS |
| 5 | Scope file uses compact equivalents matching one-line style | Visual inspection — shorter 2b/2c text | PASS |
| 6 | 4-hour threshold consistent across all 9 files | grep -c "4 hours" = 1 per file | PASS |

### Negative Tests
| # | Description | Test File | Status |
|---|-------------|-----------|--------|
| 1 | Steps 2b and 2c are between step 2 and step 3, not inside step 3 or 5 | Line number ordering check: 2 < 2b < 2c < 3 | PASS |
| 2 | No file references a staleness threshold other than 4 hours | grep "hours" excluding "4 hours" = 0 | PASS |

### Files Changed
- `.claude/skills/serious-conversation/SKILL.md` — added 2b + 2c after step 2
- `.claude/skills/serious-research/SKILL.md` — added 2b + 2c after step 2
- `.claude/skills/serious-mock-ups/SKILL.md` — added 2b + 2c after step 2
- `.claude/skills/serious-scope/SKILL.md` — added 2b + 2c (compact format) after step 2
- `.claude/skills/serious-plan/SKILL.md` — added 2b + 2c after step 2
- `.claude/skills/serious-review/SKILL.md` — added 2b + 2c after step 2
- `.claude/skills/serious-review/_serious-review-v1-defect-capture.md` — added 2b + 2c after step 2
- `.claude/skills/serious-code/SKILL.md` — added 2b + 2c after step 2
- `.claude/skills/serious-debug/SKILL.md` — added 2b + 2c after step 2

### Commits
- `117698e` — test: RED — staleness detection substeps (2b + 2c) absent in all 9 skill files
- `49ef0c9` — feat: GREEN — add staleness detection substeps (2b + 2c) to all 9 skill files

### Evidence

**GREEN verification (3 mandatory grep checks):**

"Status-based staleness" count per file: all 9 files = 1
"Age-based staleness" count per file: all 9 files = 1
"4 hours" count per file: all 9 files = 1

**Negative test 1 (positioning):** All 9 files confirmed step ordering: 2 < 2b < 2c < 3
**Negative test 2 (threshold consistency):** No "hours" reference other than "4 hours" found

### Issues
None
