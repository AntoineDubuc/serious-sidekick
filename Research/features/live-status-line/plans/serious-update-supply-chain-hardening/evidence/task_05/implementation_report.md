# Implementation Report — Supply-Chain Hardening

**Plan:** serious-update-supply-chain-hardening
**Status:** COMPLETE

## Criteria Implemented

| # | Criterion | Test File | Status |
|---|-----------|-----------|--------|
| T0-1 | parse_manifest accepts tier-swap (baseline) | evidence/task_00/probe1-tier-swap.txt | PASS |
| T0-2 | Existing tests pass (baseline) | evidence/task_00/existing-tests-baseline.txt | PASS |
| T0-3 | SHA-256 dead code confirmed (baseline) | evidence/task_00/probe3-dead-hash.txt | PASS |
| T0-4 | baseline.md exists | evidence/task_00/baseline.md | PASS |
| T1-1 | parse_manifest rejects ownership=template for settings.json | tests/test_supply_chain.sh | PASS |
| T1-2 | Error contains "must be merge-tier" | tests/test_supply_chain.sh | PASS |
| T1-3 | parse_manifest rejects empty merge_key | tests/test_supply_chain.sh | PASS |
| T1-4 | parse_manifest accepts merge+hooks | tests/test_supply_chain.sh | PASS |
| T1-5 | Real manifest still parses | tests/test_supply_chain.sh | PASS |
| T1-6 | Other files' ownership NOT pinned | tests/test_supply_chain.sh | PASS |
| T2-1 | Hash mismatch produces HASH MISMATCH error | tests/test_supply_chain.sh | PASS |
| T2-2 | Tampered file NOT copied | tests/test_supply_chain.sh | PASS |
| T2-3 | Empty hash = backward compat | tests/test_supply_chain.sh | PASS |
| T2-4 | Truncated hashes in error | tests/test_supply_chain.sh | PASS |
| T3-1 | is_serious() rejects rogue path | tests/test_supply_chain.sh | PASS |
| T3-2 | is_serious() accepts legit hook | tests/test_supply_chain.sh | PASS |
| T3-3 | is_serious() rejects path traversal | tests/test_supply_chain.sh | PASS |
| T3-4 | is_serious() rejects command chaining | tests/test_supply_chain.sh | PASS |
| T3-5 | is_serious() rejects non-bash prefix | tests/test_supply_chain.sh | PASS |
| T3-6 | All real hooks pass tightened regex | tests/test_supply_chain.sh | PASS |
| T3-7 | ALLOWED_TOP_LEVEL_KEYS defined | tests/test_supply_chain.sh | PASS |
| T3-8 | statusLine in allowlist | tests/test_supply_chain.sh | PASS |
| T3-9 | Rejects unknown keys | tests/test_supply_chain.sh | PASS |
| T3-10 | Accepts only allowlisted keys | tests/test_supply_chain.sh | PASS |
| T3-11 | Error sanitization | tests/test_supply_chain.sh | PASS |
| T3-12 | Allowlist governance (exactly 4 keys) | tests/test_supply_chain.sh | PASS |
| T3-13 | Fewer keys accepted | tests/test_supply_chain.sh | PASS |
| T4-1 | SKILL.md references allowlist | tests/test_supply_chain.sh | PASS |
| T4-2 | SKILL.md references lib/serious-common.sh | tests/test_supply_chain.sh | PASS |
| T4-3 | docs/security.md exists | tests/test_supply_chain.sh | PASS |
| T4-4 | Trust model documented | tests/test_supply_chain.sh | PASS |
| T4-5 | Allowlist keys documented | tests/test_supply_chain.sh | PASS |
| T5-1 | test_supply_chain.sh runs clean | evidence/task_05/test-run-output.txt | PASS |
| T5-2 | Full suite 16/16 | evidence/task_05/full-suite.txt | PASS |

## Negative Tests

| # | Description | Test File | Status |
|---|-------------|-----------|--------|
| N1 | Other files' ownership NOT pinned | tests/test_supply_chain.sh | PASS |
| N2 | SKILL.md preserves merge_settings for upgrade | tests/test_supply_chain.sh | PASS |
| N3 | Security doc disclaims in-repo hash protection | tests/test_supply_chain.sh | PASS |
| N4 | is_serious rejects /usr/local/bin path | tests/test_supply_chain.sh | PASS |
| N5 | Fewer keys than allowlist accepted | tests/test_supply_chain.sh | PASS |

## Files Changed

- `lib/serious-common.sh` — parse_manifest ownership pinning, is_serious() regex, ALLOWED_TOP_LEVEL_KEYS
- `bin/serious-update` — SHA-256 hash verification in distribute_to_dir
- `.claude/skills/serious-init/SKILL.md` — fresh-install key validation instruction
- `docs/security.md` — trust model documentation (new file)
- `tests/test_supply_chain.sh` — 32-assertion supply-chain test harness (new file)
- `tests/run_tests.sh` — comment noting test_supply_chain.sh inclusion

## Commits

- 3555cc0 — test: Task 0 — smoke baseline
- 7e26957 — test: RED — parse_manifest must reject tier-swap
- 408c4ab — feat: GREEN — pin settings.json ownership in parse_manifest
- 0b29d09 — test: RED — SHA-256 hash verification must reject mismatched files
- 195e8ae — feat: GREEN — activate SHA-256 verification in serious-update
- 5a56abc — test: RED — is_serious() regex tightening + template key allowlist
- 44fc6ab — feat: GREEN — tighten is_serious() regex + add template key allowlist
- d70c6ed — test: RED — SKILL.md allowlist reference + docs/security.md existence
- dd13f14 — feat: GREEN — update /serious-init SKILL.md + create docs/security.md
- 45a5dcd — feat: GREEN — end-to-end integration test harness + final verification

## Issues

None.
