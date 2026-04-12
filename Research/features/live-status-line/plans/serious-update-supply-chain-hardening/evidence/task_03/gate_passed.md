# Task 3 Gate — PASS

**Date:** 2026-04-12

- [x] is_serious() uses re.match with start + end anchor
- [x] Rejects rogue /tmp/serious-evil path
- [x] Accepts legit serious-code hook
- [x] Rejects path-traversal after /hooks/
- [x] Rejects command chaining
- [x] All real hook commands still pass
- [x] ALLOWED_TOP_LEVEL_KEYS = {hooks, permissions, env, statusLine}
- [x] statusLine explicitly in allowlist (cross-plan coordination)
- [x] Rejects template with unknown keys
- [x] Error mentions disallowed top-level keys
- [x] Accepts template with only allowlisted keys
- [x] Accepts template with fewer keys (upper bound)
- [x] Error message sanitization (no raw ANSI escapes)
- [x] Allowlist governance test (exactly 4 keys)
- [x] bash -n lib/serious-common.sh exits 0
- [x] Full test suite: 16/16 pass
