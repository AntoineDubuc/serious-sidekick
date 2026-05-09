# Task 6 — Reviewer follow-up commit

Three reviewer follow-ups addressed in a single commit on top of Task 6.

## Follow-up #1 — `test_migrate_realpath_failure_fail_safe` now exercises the failure path

**Source change:** extracted `_breadcrumb_migrate_canonicalize($path)` helper from
`breadcrumb_migrate`. The helper tries `/bin/realpath` first, then the
pure-shell `cd && pwd -P` fallback, returning non-zero if both fail. Both call
sites in `breadcrumb_migrate` (root canonicalize + per-target canonicalize) now
delegate to it.

**Test change:** rewrote `test_migrate_realpath_failure_fail_safe` to override
`_breadcrumb_migrate_canonicalize` in the bash subshell that sources the
helper. The stub succeeds for the project root path (so the function passes
its own root canonicalize step) and returns 1 for any other input — driving
the inner target canonicalize down the failure branch.

The fixture seeds an EXISTING target folder under canon_root, so
`[ ! -e "$target" ]` returns false and the orphan branch is NOT taken — the
function must fall through to the `MIGRATE: skip realpath-unavailable` log
emission and skip deletion.

The primary assertion is behavioral: legacy file present after run AND stderr
contains the exact `MIGRATE: skip realpath-unavailable {path}` line.
A redundant static-grep assertion on the helper body is kept as a secondary
check.

**Mutation verification:** changed the literal log marker
`MIGRATE: skip realpath-unavailable` to `MIGRATE: skip XYZ-DIFFERENT-MARKER`
in the source — the test failed and the captured stderr showed the new
marker, proving the test genuinely reaches the realpath-unavailable branch
and is not satisfied by some other code path.

## Follow-up #2 — added 2 missing filename shapes to `test_migrate_orphan_filename_shape`

Plan spec line 846 lists 6 filename shapes the orphan-branch must reject; the
existing test only covered 4. Added the 2 missing shapes inside the existing
test (no new test function — same fixture, same assertion structure):

- `.active-..` — basename contains a path-traversal sequence; rejected by
  Gate 3a's "first char [a-z]" rule (the suffix `..` starts with `.`).
- `.active-foo;bar` — basename contains a shell metacharacter; rejected by
  Gate 3a's "all chars [a-z0-9-]" rule.

Each new shape: seeded with valid content `somewhere\n` (target folder does
not exist, so the entry is an orphan candidate); after running
`breadcrumb_migrate` the file MUST still be present.

**Mutation verification:** removed the "all chars [a-z0-9-]" case block from
the source — `test_migrate_orphan_filename_shape` failed (the `;bar` shape
was no longer caught and the file was deleted via the orphan branch).
Removed the "first char [a-z]" case block — same test failed, proving the
`.active-..` shape's assertion is meaningful too.

## Follow-up #3 — corrected misleading `LC_ALL=C` comment

The original comment near the carve-out `case` block claimed `LC_ALL=C` was
"environment-scoped to this comparison via a subshell-free idiom." The code
did NOT actually set `LC_ALL=C` for that comparison — it relied on the parent
shell's locale.

Picked Option A (simpler, code-accurate): replaced the misleading comment
with one that accurately describes the existing behavior:

> The pattern `.active-conversation` is a literal byte sequence — no
> metacharacters, no character classes, no locale-sensitive collation —
> so bash's `case` matches byte-for-byte regardless of $LC_COLLATE /
> $LC_ALL. No locale wrapping needed for correctness.

Also updated the function docstring (Gate 1 description) to drop the stale
"under LC_ALL=C" phrasing for the same reason. The other `LC_ALL=C`
references in the file (`tr -d '[:space:]'` and `ps -p`) are real and remain.

## Test counts

| Stage | Pass | Fail | Total |
|---|---|---|---|
| Before this commit | 91 | 0 | 91 |
| After this commit | 91 | 0 | 91 |

Count unchanged because all changes are in-place: refactored test body for
#1, two extra shapes inside the same `test_migrate_orphan_filename_shape`
function for #2, comment-only edits for #3.

## Files changed

- `.claude/skills/_shared/path-resolve.sh` — extracted
  `_breadcrumb_migrate_canonicalize` helper; both `breadcrumb_migrate` call
  sites now delegate to it; corrected the `LC_ALL=C` comment.
- `.claude/skills/_shared/path-resolve.test.sh` — rewrote
  `test_migrate_realpath_failure_fail_safe` to genuinely exercise the
  failure branch via the new helper override; added 2 filename shapes
  (`.active-..`, `.active-foo;bar`) to `test_migrate_orphan_filename_shape`.

## Static analysis

`shellcheck` on both files: only pre-existing info-level warnings unrelated
to the changes (SC2153 on `PROJECT_ROOT` shadow, SC2012/SC2295/SC2059/SC2034
on test scaffolding). No new warnings introduced.

## Hard-rule compliance

- No prior commits amended; this is a new commit on top of Task 6.
- Did NOT touch the 9 SKILL.md startup-scan blocks (per reviewer's #3 — the
  3 SKILL.md files lacking `breadcrumb_migrate` are out of scope per the
  writer-roster spec).
- The realpath stub genuinely causes `breadcrumb_migrate` to log
  `MIGRATE: skip realpath-unavailable` and NOT delete the legacy file —
  verified by the mutation test (changing the log marker made the test
  fail with the mutated marker visible in captured stderr).
