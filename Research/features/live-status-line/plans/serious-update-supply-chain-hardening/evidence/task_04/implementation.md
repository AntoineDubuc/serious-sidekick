# Task 4 Implementation — Update /serious-init SKILL.md + create docs/security.md

## Changes

### SKILL.md update
Updated `.claude/skills/serious-init/SKILL.md` merge-owned files section (lines 127-131) to require top-level key validation against `ALLOWED_TOP_LEVEL_KEYS` (from `lib/serious-common.sh`) before fresh-install copy. Unknown keys = abort, not strip.

### docs/security.md
Created `docs/security.md` documenting:
- Manifest integrity model (what hashes protect and don't protect)
- Template key allowlist (all 4 keys explained)
- Ownership pinning
- Hook command validation regex
- Explicit disclaimer: in-repo hashes do NOT protect against repo-level tampering

## Files Changed

- `.claude/skills/serious-init/SKILL.md` — added allowlist validation for fresh install
- `docs/security.md` — new file documenting trust model
- `tests/test_supply_chain.sh` — added 7 Task 4 assertions

## Test Results

- 32/32 supply chain tests pass
- 16/16 full suite pass (0 regressions)
