# Task 1 Implementation — Pin settings.json ownership in parse_manifest

## Change

Added 8-line validation block in `lib/serious-common.sh` inside the `parse_manifest` Python heredoc, after the existing ownership validation (line 173). The new block:

1. Checks if `source_path == '.claude/settings.json'`
2. Rejects `ownership != 'merge'` with error "MUST be merge-tier"
3. Rejects `merge_key != 'hooks'` with error "MUST have merge_key=hooks"

## Files Changed

- `lib/serious-common.sh` — added settings.json ownership pinning in parse_manifest
- `tests/test_supply_chain.sh` — new test file with 6 assertions for Task 1

## Test Results

- 6/6 supply chain tests pass
- 16/16 full suite pass (0 regressions)
- `bash -n lib/serious-common.sh` — syntax valid
