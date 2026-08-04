#!/bin/bash
# plan-lint.test.sh — proves each check FIRES on a broken plan and STAYS SILENT
# on a clean one. A linter nobody has watched fail is worth as much as a gate
# nobody has run.
#
# Usage: ./plan-lint.test.sh          (exit 0 = all assertions pass)

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LINT="$HERE/plan-lint.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

# Assert a check id appears (or does not) in the output of a linted file.
expect()   { grep -q "[[:space:]]$2[[:space:]]" <<<"$1" && ok "$3 fires"   || bad "$3 did NOT fire ($2)"; }
refute()   { grep -q "[[:space:]]$2[[:space:]]" <<<"$1" && bad "$3 false-positived ($2)" || ok "$3 silent"; }

# --------------------------------------------------------------------------
# A repo for paths to resolve against, plus an .env to count.
# --------------------------------------------------------------------------
mkdir -p "$TMP/repo/packages/api-gateway/src/modules/real" "$TMP/proj/.claude"
: > "$TMP/proj/CLAUDE.md"
echo "export const x = 1;" > "$TMP/repo/packages/api-gateway/src/modules/real/exists.ts"
printf 'PROVIDER_ONE="a"\nPROVIDER_TWO="b"\nPROVIDER_THREE="c"\n' > "$TMP/repo/.env"

PLANS="$TMP/proj/Research/feature"
mkdir -p "$PLANS/plan-bad" "$PLANS/plan-good"

# --------------------------------------------------------------------------
# The broken plan — one defect per check.
# --------------------------------------------------------------------------
cat > "$PLANS/plan-bad/implementation_plan.md" <<EOF
---
skill: serious-plan
slug: bad
status: active
created: 2026-08-04
---

# Implementation Plan: bad

## Project Configuration

| Variable | Value |
|---|---|
| \`{REPO_ROOT}\` | \`$TMP/repo\` |
| \`{UNIT_TEST_CMD}\` | from \`{REPO_ROOT}\`: \`npm test\` |
| \`{NEVER_USED}\` | nothing references this |

All five \`PROVIDER_*\` keys are present, and the evidence lands in \`{UNDECLARED_ROOT}\`.

## Master Checklist

| # | Task | Risk | Status |
|---|---|---|---|
| 1 | Real task | H | ☐ |
| 9 | Ghost task with no section | M | ☐ |

### Test-file map

| Task | Test files |
|---|---|
| 1 | \`modules/real/__tests__/thing.spec.ts\` |

## Task Descriptions

### Task 1 — Real task

**Key components**
- MODIFY \`modules/real/exists.ts\` — fine, this one is on disk.
- MODIFY \`modules/real/absent.ts\` — claims to exist but does not.

**Acceptance criteria**
- [ ] Something real happens in \`modules/real/exists.ts\` at \`exists.ts:1\`.
- [ ] short
- [ ] A citation past the end of the file: \`modules/real/exists.ts:999\`.
- [ ] Gate \`{UNIT_TEST_CMD}\`, executed 2026-08-04:
      \`\`\`bash
      cd {REPO_ROOT}
      grep -c thing /dev/null
      npm test || true
      \`\`\`

**Rollback.** Revert.

## Appendix

### Decisions of record

| Decision | Rationale |
|---|---|
| Use \`NeverBuiltService\` everywhere | It appears in no task at all |
| Prose-only \`OrphanHelper\` | Named in a task body but in no Key components block |

The \`OrphanHelper\` is discussed here in Task 1's prose only.
EOF

# --------------------------------------------------------------------------
# The clean plan — same shape, every defect removed.
# --------------------------------------------------------------------------
cat > "$PLANS/plan-good/implementation_plan.md" <<EOF
---
skill: serious-plan
slug: good
status: active
created: 2026-08-04
---

# Implementation Plan: good

<!-- lint:superseded
OldBrokenApproach -> NewApproach (reversed after live testing)
-->

## Project Configuration

| Variable | Value |
|---|---|
| \`{REPO_ROOT}\` | \`$TMP/repo\` |
| \`{UNIT_TEST_CMD}\` | from \`{REPO_ROOT}\`: \`npm test\` |

All three \`PROVIDER_*\` keys are present.

## Master Checklist

| # | Task | Risk | Status |
|---|---|---|---|
| 1 | Real task | H | ☐ |

### Test-file map

| Task | Test files |
|---|---|
| 1 | \`modules/real/__tests__/thing.spec.ts\` |

## Task Descriptions

### Task 1 — Real task · gate \`{UNIT_TEST_CMD}\`

**Key components**
- MODIFY \`modules/real/exists.ts\` — on disk.
- NEW \`modules/real/new-thing.ts\` — created by this task, uses \`NewApproach\`.

**Acceptance criteria**
- [ ] \`NewApproach\` replaces the old path in \`modules/real/new-thing.ts\`.
- [ ] A citation inside the file: \`modules/real/exists.ts:1\`.
- [ ] Gate \`{UNIT_TEST_CMD}\`, executed 2026-08-04, real output \`Tests: 3 passed\`:
      \`\`\`bash
      set -e
      cd "\$REPO"
      npm test
      \`\`\`

**Rollback.** Single-file revert.

## Appendix

### Decisions of record

| Decision | Rationale |
|---|---|
| Adopt \`NewApproach\` | Built in Task 1 and checked by its first criterion |
EOF

# --------------------------------------------------------------------------
echo
echo "BROKEN plan — every check must fire:"
OUT_BAD="$(python3 "$LINT" "$PLANS/plan-bad/implementation_plan.md" 2>&1)"
RC_BAD=$?

expect "$OUT_BAD" P1 "P1 undefined placeholder"
expect "$OUT_BAD" P2 "P2 placeholder in a runnable line"
expect "$OUT_BAD" P3 "P3 placeholder defined but unused"
expect "$OUT_BAD" C1 "C1 missing path"
expect "$OUT_BAD" C2 "C2 citation past end of file"
expect "$OUT_BAD" T1 "T1 checklist/section mismatch"
expect "$OUT_BAD" T5 "T5 unverifiable criterion"
expect "$OUT_BAD" D1 "D1 decision never built"
expect "$OUT_BAD" G1 "G1 gate cannot fail"
expect "$OUT_BAD" S0 "S0 no superseded block"
expect "$OUT_BAD" F1 "F1 wrong env-var count"

[ "$RC_BAD" -eq 1 ] && ok "exit 1 on errors" || bad "exit was $RC_BAD, expected 1"

echo
echo "CLEAN plan — nothing must fire:"
OUT_GOOD="$(python3 "$LINT" "$PLANS/plan-good/implementation_plan.md" 2>&1)"
RC_GOOD=$?

for chk in P1 P2 C1 C2 T1 T2 D1 G1 S1 F1 M1; do
  refute "$OUT_GOOD" "$chk" "$chk"
done
[ "$RC_GOOD" -eq 0 ] && ok "exit 0 on a clean plan" || bad "exit was $RC_GOOD, expected 0"

echo
echo "SUPERSEDED term — must fire once reintroduced:"
sed 's|uses `NewApproach`|uses `OldBrokenApproach`|' \
  "$PLANS/plan-good/implementation_plan.md" > "$TMP/superseded.md"
OUT_SUP="$(python3 "$LINT" "$TMP/superseded.md" 2>&1)"
expect "$OUT_SUP" S1 "S1 superseded term resurrected"

echo
printf '\033[1m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
