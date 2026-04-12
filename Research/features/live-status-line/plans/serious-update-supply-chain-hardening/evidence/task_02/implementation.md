# Task 2 Implementation — Activate SHA-256 verification in bin/serious-update

## Change

Added SHA-256 hash verification block in `bin/serious-update`'s `distribute_to_dir` function, in the `template)` branch. The block runs BEFORE the `cp` command:

1. If `$sha256` is non-empty, compute actual hash via `hash_file`
2. If actual hash differs from manifest hash, print `HASH MISMATCH` error with truncated hashes and skip the copy
3. If `$sha256` is empty, skip verification (backward compatibility)

Used separate `hash_mismatches` counter instead of `errors` to avoid blocking state file writes.

## Files Changed

- `bin/serious-update` — added hash verification block + `hash_mismatches` counter
- `tests/test_supply_chain.sh` — added 4 Task 2 assertions

## Test Results

- 10/10 supply chain tests pass
- 16/16 full suite pass (0 regressions)
- `bash -n bin/serious-update` — syntax valid
- `bash bin/serious-update --check | grep HASH MISMATCH` — 0 matches (legitimate files pass)
