---
name: status-schema
version: 1
created: 2026-04-12
---

# Status JSON Schema Contract

This document defines the schema for `status.json` — the data contract between the `/serious-code` orchestrator (the writer) and the status line shell script (the reader, Plan 4b).

The orchestrator writes `$PLAN_DIR/status.json` on every state transition. The status line reads only this file. All string fields are sanitized at write time — the reader trusts the writer.

## Field Inventory

| Field | Type | Required | Constraints | Example |
|-------|------|----------|-------------|---------|
| `version` | integer | yes | Must equal `1` (current schema version) | `1` |
| `plan_name` | string | yes | Sanitized, max 200 bytes | `"path-canonicalization-hardening"` |
| `phase` | object | yes | Contains `current` (integer >= 0) and `total` (integer >= 0) | `{"current": 1, "total": 3}` |
| `task` | object | yes | Contains `current` (integer >= 0) and `total` (integer >= 0) | `{"current": 3, "total": 5}` |
| `agents` | object | yes | Contains 5 named agent keys, each with a state enum value | See Agent States below |
| `worktree_name` | string | yes | Sanitized, max 200 bytes, may be empty string `""` | `"wt-auth-hardening"` |
| `timestamp` | string | yes | ISO 8601 format (UTC preferred) | `"2026-04-12T10:30:00Z"` |

### Agent States

The `agents` object contains exactly 5 keys. Each key maps to a state enum string.

**Agent keys:** `implementer`, `reviewer`, `test_runner`, `runtime_checker`, `qa`

**Valid states:** `"idle"`, `"running"`, `"done"`, `"error"`

| State | Meaning |
|-------|---------|
| `idle` | Agent has not been dispatched for the current task |
| `running` | Agent is actively executing |
| `done` | Agent completed successfully |
| `error` | Agent encountered a failure |

## Sanitization Contract

All string fields (`plan_name`, `worktree_name`) are sanitized at write time via a 4-step pipeline. The reader (Plan 4b) trusts that the writer already sanitized — it performs no additional sanitization.

**4-step sanitization pipeline:**

1. **Strip ALL C0 control characters** including TAB (0x09), LF (0x0A), CR (0x0D) via `LC_ALL=C tr -d '\000-\037\177'`. Status.json string fields are single-line values that must not contain newlines or tabs.
2. **Strip UTF-8 bidi codepoints** — remove U+202A through U+202E (LRE, RLE, PDF, LRO, RLO), U+2066 through U+2069 (LRI, RLI, FSI, PDI), and U+200B through U+200F (ZWSP, ZWNJ, ZWJ, LRM, RLM). These prevent CVE-2021-42574 bidi override attacks.
3. **Truncate** each string field to 200 bytes max (measured in bytes, not characters).
4. **Serialize via a JSON serializer** — use `python3 json.dumps()` or `jq --arg` to produce the final JSON. NEVER string-interpolate values into a JSON template, because unescaped `"` or `\` in agent strings would break JSON structure.

## File Permissions Contract

The orchestrator writes `status.json.tmp` with mode 0600 (`-rw-------`) and the `mv` preserves this mode. This ensures only the file owner (the user running `/serious-code`) can read or write the file. An unauthorized process cannot replace `status.json` content.

## Atomic Write Contract

The orchestrator writes to `$PLAN_DIR/status.json.tmp` then `mv`s to `$PLAN_DIR/status.json`. The reader may see a stale file or no file but never partial JSON. POSIX guarantees that `mv` on the same filesystem is atomic (it is a rename, not a copy). The `.tmp` file is in the same directory as the final file, ensuring same-filesystem semantics.

## Consumers

- **Plan 4b (status line shell script):** Reads `$PLAN_DIR/status.json` every 5 seconds to display live progress in the Claude Code status line. Trusts write-time sanitization.

## Example

```json
{
  "version": 1,
  "plan_name": "path-canonicalization-hardening",
  "phase": {"current": 1, "total": 3},
  "task": {"current": 3, "total": 5},
  "agents": {
    "implementer": "running",
    "reviewer": "idle",
    "test_runner": "done",
    "runtime_checker": "idle",
    "qa": "idle"
  },
  "worktree_name": "wt-path-canon",
  "timestamp": "2026-04-12T10:30:00Z"
}
```

## Schema Version History

| Version | Date | Changes |
|---------|------|---------|
| 1 | 2026-04-12 | Initial schema — 7 fields, single-plan status only |

**Note:** This is single-plan status only. Cross-worktree aggregation is future work and will require a schema version bump.
