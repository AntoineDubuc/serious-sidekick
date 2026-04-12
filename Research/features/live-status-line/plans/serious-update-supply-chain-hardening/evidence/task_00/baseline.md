# Task 0 — Smoke Baseline

**Date:** 2026-04-12

## Existing Test Suite Status

**PASS** — 15/15 tests pass. See `existing-tests-baseline.txt`.

## Probe 1: Tier-Swap Manifest

**VULNERABILITY CONFIRMED.** `parse_manifest` accepts a manifest where `.claude/settings.json` has `ownership=template` (exit 0). This means a malicious PR can flip settings.json from safe-merge to raw-overwrite.

## Probe 3: Dead Hash Verification

**VULNERABILITY CONFIRMED.** `bin/serious-update` reads `sha256` from the manifest into a variable (line 190) but never compares it against the actual source file hash. The variable is dead code — file integrity hashes are decorative only.

## Pre-Hardening State

This baseline establishes the pre-hardening state of the codebase. All three attack vectors from Thread 2 are confirmed exploitable:

1. Manifest tier-swap: EXPLOITABLE (Probe 1)
2. Fresh-install key bypass: EXPLOITABLE (no key filtering in `/serious-init`)
3. Dead hash verification: EXPLOITABLE (Probe 3)

No code changes were made in this task. This is a read-only baseline capture.
