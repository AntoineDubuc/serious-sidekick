# Task 1 Gate — PASS

**Date:** 2026-04-12

- [x] parse_manifest rejects ownership=template for settings.json (exit 1)
- [x] Error message contains "must be merge-tier"
- [x] parse_manifest rejects empty merge_key for settings.json
- [x] parse_manifest accepts merge+hooks for settings.json
- [x] Real project manifest still parses (exit 0)
- [x] Negative: other files' ownership NOT pinned
- [x] bash -n lib/serious-common.sh exits 0
- [x] Full test suite: 16/16 pass
