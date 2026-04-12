# Task 5 Final Report — End-to-end Integration Test

**Date:** 2026-04-12

## Attack Probe Results (Before vs After)

| Probe | Attack Vector | Task 0 Baseline | After Hardening | Status |
|-------|--------------|----------------|-----------------|--------|
| 1 | Tier-swap (settings.json as template) | ACCEPTED (exit 0) | REJECTED (exit 1, "must be merge-tier") | FIXED |
| 2 | Unknown top-level keys in template | NOT TESTED (no filter) | REJECTED ("disallowed top-level keys") | FIXED |
| 3 | Hash mismatch (dead verification) | NO ERROR (dead code) | REJECTED ("HASH MISMATCH") | FIXED |
| 4 | Clean template (only allowlisted keys) | ACCEPTED | ACCEPTED | PASS (positive path) |
| 5 | Rogue serious-evil directory | ACCEPTED (loose regex) | REJECTED (tightened regex) | FIXED |
| 6 | Path traversal after /hooks/ | ACCEPTED (no end-anchor) | REJECTED (end-anchor) | FIXED |
| 7 | Command chaining after closing quote | ACCEPTED (no end-anchor) | REJECTED (end-anchor) | FIXED |

## Full Test Suite

- `bash tests/test_supply_chain.sh`: 32/32 pass, exit 0
- `bash tests/run_tests.sh`: 16/16 pass, exit 0

## Changes Summary

| Task | File | Change |
|------|------|--------|
| 1 | `lib/serious-common.sh` | parse_manifest rejects settings.json ownership flip |
| 2 | `bin/serious-update` | SHA-256 verification in template branch before cp |
| 3 | `lib/serious-common.sh` | is_serious() end-anchored regex + ALLOWED_TOP_LEVEL_KEYS |
| 4 | `.claude/skills/serious-init/SKILL.md` | Fresh-install key validation instruction |
| 4 | `docs/security.md` | Trust model documentation |
| 5 | `tests/test_supply_chain.sh` | 32 assertions covering all 7 probes |
| 5 | `tests/run_tests.sh` | Comment noting test_supply_chain.sh inclusion |

## Comparison Against Task 0 Baseline

Task 0 confirmed 3 attack vectors were exploitable:
1. Manifest tier-swap: parse_manifest accepted malicious manifest (exit 0) -- NOW REJECTED
2. Dead hash verification: sha256 read but never compared -- NOW ACTIVE
3. Fresh-install bypass: no key filtering -- NOW DOCUMENTED with reject instruction

All 3 vectors are now closed. The 15 original tests + 1 new test = 16 total, all passing.
