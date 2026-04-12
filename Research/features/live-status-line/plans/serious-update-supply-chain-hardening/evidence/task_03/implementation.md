# Task 3 Implementation — Tighten is_serious() regex + template key allowlist

## Changes

### is_serious() regex tightening
Replaced `re.search(r'serious-', command_str)` with:
```python
re.match(r'^bash "\$CLAUDE_PROJECT_DIR/\.claude/skills/serious-[a-z-]+/hooks/[a-z0-9._-]+\.sh"$', command_str)
```

This prevents:
- Rogue `serious-evil` directory bypass
- Path traversal via `../../../../` after `/hooks/`
- Command chaining via `&& curl evil` after the closing quote
- Any command not using the `bash "$CLAUDE_PROJECT_DIR/..."` prefix

### Template key allowlist
Added before the merge logic in `merge_settings`:
```python
ALLOWED_TOP_LEVEL_KEYS = {'hooks', 'permissions', 'env', 'statusLine'}
```
Templates with unknown keys are rejected with sanitized error messages.

## Files Changed

- `lib/serious-common.sh` — tightened is_serious() regex + added ALLOWED_TOP_LEVEL_KEYS
- `tests/test_supply_chain.sh` — 15 new Task 3 assertions

## Test Results

- 25/25 supply chain tests pass
- 16/16 full suite pass (0 regressions)
- `bash -n lib/serious-common.sh` — syntax valid
