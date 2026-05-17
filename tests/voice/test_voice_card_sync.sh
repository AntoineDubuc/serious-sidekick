#!/bin/bash
# test_voice_card_sync.sh — Task 1 RED test for the voice-card sync lint.
#
# Verifies AC3 + AC11 + AC13 of implementation_plan.md Task 1:
#   AC3:  ## Voice content matches voice-card.md byte-for-byte (4 structure + 4 style)
#   AC11: lint script lives at scripts/verify-voice-card-sync.sh, exits 0 if all surfaces match
#   AC13: lint enumerates exactly 24 surfaces via hardcoded allowlist
#         (1 canonical card + 1 Output Style + 14 SKILL.md + 8 agents)
#         realpath canonicalization rejects out-of-tree paths

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$PROJECT_ROOT/scripts/verify-voice-card-sync.sh"

PASS=0
FAIL=0
assert() {
  local name="$1"; local result="$2"; local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS+1)); echo "  PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $name${detail:+ — $detail}"
  fi
}

echo "=== Task 1 voice-card sync lint ==="

# AC11/AC13: lint exists and is executable
if [ -x "$LINT" ]; then
  assert "scripts/verify-voice-card-sync.sh exists and is executable" "pass"
else
  assert "scripts/verify-voice-card-sync.sh exists and is executable" "fail" "missing or not executable"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Bash syntax
if bash -n "$LINT" 2>/dev/null; then
  assert "lint passes bash -n" "pass"
else
  assert "lint passes bash -n" "fail"
fi

# AC11: lint exits 0 on a synced tree
set +e
"$LINT" >/tmp/lint-out.txt 2>&1
EC=$?
set -e
if [ "$EC" = "0" ]; then
  assert "lint exits 0 on synced tree" "pass"
else
  assert "lint exits 0 on synced tree" "fail" "exit=$EC; output:\n$(cat /tmp/lint-out.txt)"
fi

# AC13: lint reports exactly 25 surfaces (was 24 in Task 1; Task 3 added voice-translator)
SURFACE_COUNT=$(grep -cE '^Checked: ' /tmp/lint-out.txt || true)
if [ "$SURFACE_COUNT" = "25" ] || grep -qE 'Surfaces?:?\s*25\b|25 surfaces' /tmp/lint-out.txt; then
  assert "lint reports exactly 25 surfaces" "pass"
else
  assert "lint reports exactly 25 surfaces" "fail" "got count=$SURFACE_COUNT, output:\n$(cat /tmp/lint-out.txt)"
fi

# AC11 negative: introduce drift in one SKILL.md → lint exits 1
# Uses a trap to guarantee restoration even on test failure or signal.
DRIFT_TARGET="$PROJECT_ROOT/.claude/skills/serious-abandon/SKILL.md"
if [ -f "$DRIFT_TARGET" ] && grep -q '^## Voice' "$DRIFT_TARGET"; then
  DRIFT_BACKUP="$(mktemp)"
  cp "$DRIFT_TARGET" "$DRIFT_BACKUP"

  cleanup_drift_test() {
    if [ -f "$DRIFT_BACKUP" ]; then
      cp "$DRIFT_BACKUP" "$DRIFT_TARGET"
      rm -f "$DRIFT_BACKUP" "$DRIFT_TARGET.tmp" "$DRIFT_TARGET.bak"
    fi
  }
  trap cleanup_drift_test EXIT

  # Tweak the first style rule
  sed -i.tmp 's/~10 lines max/~99 lines max/' "$DRIFT_TARGET"
  set +e
  "$LINT" >/tmp/lint-drift.txt 2>&1
  DRIFT_EC=$?
  set -e

  cleanup_drift_test
  trap - EXIT

  if [ "$DRIFT_EC" = "1" ]; then
    assert "drift detected → lint exits 1" "pass"
  else
    assert "drift detected → lint exits 1" "fail" "exit=$DRIFT_EC"
  fi

  # Belt-and-suspenders: verify the file is byte-identical to git HEAD before continuing.
  # (Catches an order-sensitivity flake where the second mutation test would otherwise
  # see drift state left by the first.)
  if git -C "$PROJECT_ROOT" diff --quiet -- ".claude/skills/serious-abandon/SKILL.md" 2>/dev/null \
      || git -C "$PROJECT_ROOT" diff --no-ext-diff -- ".claude/skills/serious-abandon/SKILL.md" 2>/dev/null \
        | grep -q '^[+-][^+-]'; then
    # The first form is the strict check; the second tolerates that the file
    # is intentionally modified in this branch (canonical block added).
    # We only need to ensure no NEW drift relative to the working-tree state at test entry.
    # Re-run lint to confirm tree is back to synced.
    if "$LINT" >/dev/null 2>&1; then
      assert "drift test cleanup verified — tree synced after restore" "pass"
    else
      assert "drift test cleanup verified — tree synced after restore" "fail" "lint reports drift after restore"
    fi
  fi
else
  assert "drift test (precondition: serious-abandon has ## Voice)" "fail" "skipped — file missing or no Voice section"
fi

# AC13 negative: replace a real allowlist entry with a symlink → lint must exit 2.
# Approach: take one of the hardcoded surfaces (a SKILL.md), swap it with a symlink
# pointing outside .claude/, run the lint, and assert exit 2 with the right message.
# Restore the original on completion regardless of pass/fail.
SURFACE_TO_HIJACK="$PROJECT_ROOT/.claude/skills/serious-bananas/SKILL.md"
BACKUP_FILE="$(mktemp)"
EXTERNAL_TARGET="$(mktemp)"
# Seed the external target with a valid-looking canonical block so the lint doesn't
# fail on "no canonical block extractable" before reaching the symlink check.
cat > "$EXTERNAL_TARGET" <<'EXT'
# Decoy
<!-- BEGIN CANONICAL VOICE BLOCK — decoy -->
fake content that won't match the real block
<!-- END CANONICAL VOICE BLOCK -->
EXT

cleanup_symlink_test() {
  if [ -L "$SURFACE_TO_HIJACK" ] || [ ! -f "$SURFACE_TO_HIJACK" ]; then
    rm -f "$SURFACE_TO_HIJACK"
    cp "$BACKUP_FILE" "$SURFACE_TO_HIJACK"
  fi
  rm -f "$BACKUP_FILE" "$EXTERNAL_TARGET"
}
trap cleanup_symlink_test EXIT

cp "$SURFACE_TO_HIJACK" "$BACKUP_FILE"
rm -f "$SURFACE_TO_HIJACK"
ln -s "$EXTERNAL_TARGET" "$SURFACE_TO_HIJACK"

set +e
"$LINT" >/tmp/lint-symlink.txt 2>&1
SYM_EC=$?
set -e

# Restore immediately so subsequent test code sees the real file
cleanup_symlink_test
trap - EXIT

if [ "$SYM_EC" = "2" ]; then
  assert "symlink at surface path → lint exits 2" "pass"
else
  assert "symlink at surface path → lint exits 2" "fail" "exit=$SYM_EC; output: $(cat /tmp/lint-symlink.txt)"
fi
if grep -qE 'symlink|outside|escape' /tmp/lint-symlink.txt; then
  assert "lint stderr names the symlink/escape cause" "pass"
else
  assert "lint stderr names the symlink/escape cause" "fail" "stderr: $(cat /tmp/lint-symlink.txt)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
