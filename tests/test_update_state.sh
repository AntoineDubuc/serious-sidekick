#!/bin/bash
# test_update_state.sh — Tests for update_state function
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/lib/serious-common.sh"

ERRORS=0
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert() {
  local desc="$1"
  local result="$2"
  local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc"
    [ -n "$detail" ] && echo "        $detail"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "=== Test: update_state ==="
echo ""

TARGET_DIR="$TMP_DIR/target"
mkdir -p "$TARGET_DIR"

COMMIT_SHA="abc1234def5678901234567890abcdef12345678"
PREV_COMMIT="0000000000000000000000000000000000000000"
FILE_HASHES='{"skills/serious-code/SKILL.md": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "agents/serious-code-implementer.md": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"}'

# AC: update_state writes .serious-sidekick-state.json to target_dir
update_state "$TARGET_DIR" "$COMMIT_SHA" "$PREV_COMMIT" "$FILE_HASHES"
STATE_EXIT=$?
if [ "$STATE_EXIT" -eq 0 ]; then
  assert "update_state exits 0" "pass"
else
  assert "update_state exits 0" "fail" "exit=$STATE_EXIT"
fi

STATE_FILE="$TARGET_DIR/.serious-sidekick-state.json"
if [ -f "$STATE_FILE" ]; then
  assert "State file created" "pass"
else
  assert "State file created" "fail"
  echo "=== update_state Tests Complete: $ERRORS error(s) ==="
  exit 1
fi

# AC: State file is valid JSON
if validate_json "$STATE_FILE"; then
  assert "State file is valid JSON" "pass"
else
  assert "State file is valid JSON" "fail"
fi

# AC: State file conforms to schema
SCHEMA_CHECK=$(python3 -c "
import json, sys
with open('$STATE_FILE') as f:
    data = json.load(f)
checks = []
checks.append(('installed_from_commit' in data, 'missing installed_from_commit'))
checks.append(('previous_commit' in data, 'missing previous_commit'))
checks.append(('installed_at' in data, 'missing installed_at'))
checks.append(('file_hashes' in data, 'missing file_hashes'))
checks.append((isinstance(data.get('file_hashes'), dict), 'file_hashes not dict'))
failures = [msg for ok, msg in checks if not ok]
if failures:
    print('FAIL: ' + ', '.join(failures))
else:
    print('OK')
")
if [ "$SCHEMA_CHECK" = "OK" ]; then
  assert "State file conforms to schema" "pass"
else
  assert "State file conforms to schema" "fail" "$SCHEMA_CHECK"
fi

# AC: installed_from_commit matches
INSTALLED_COMMIT=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['installed_from_commit'])")
if [ "$INSTALLED_COMMIT" = "$COMMIT_SHA" ]; then
  assert "installed_from_commit matches" "pass"
else
  assert "installed_from_commit matches" "fail" "Got: $INSTALLED_COMMIT"
fi

# AC: previous_commit matches
STATE_PREV=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['previous_commit'])")
if [ "$STATE_PREV" = "$PREV_COMMIT" ]; then
  assert "previous_commit matches" "pass"
else
  assert "previous_commit matches" "fail" "Got: $STATE_PREV"
fi

# AC: installed_at is ISO 8601
INSTALLED_AT=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['installed_at'])")
if echo "$INSTALLED_AT" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
  assert "installed_at is ISO 8601" "pass"
else
  assert "installed_at is ISO 8601" "fail" "Got: $INSTALLED_AT"
fi

# AC: file_hashes maps dest paths to SHA-256 hashes
HASH_CHECK=$(python3 -c "
import json
data = json.load(open('$STATE_FILE'))
hashes = data['file_hashes']
if 'skills/serious-code/SKILL.md' in hashes and 'agents/serious-code-implementer.md' in hashes:
    print('OK')
else:
    print('FAIL: ' + str(list(hashes.keys())))
")
if [ "$HASH_CHECK" = "OK" ]; then
  assert "file_hashes contains expected entries" "pass"
else
  assert "file_hashes contains expected entries" "fail" "$HASH_CHECK"
fi

# AC: State file parseable by both python3 and jq
if command -v jq >/dev/null 2>&1; then
  if jq empty < "$STATE_FILE" 2>/dev/null; then
    assert "State file parseable by jq" "pass"
  else
    assert "State file parseable by jq" "fail"
  fi
else
  echo "  SKIP: jq not available"
fi
# python3 already validated above via validate_json

# AC: previous_commit can be empty string (first install)
TARGET_DIR2="$TMP_DIR/target2"
mkdir -p "$TARGET_DIR2"
update_state "$TARGET_DIR2" "$COMMIT_SHA" "" "$FILE_HASHES"
EMPTY_PREV=$(python3 -c "import json; print(repr(json.load(open('$TARGET_DIR2/.serious-sidekick-state.json'))['previous_commit']))")
if [ "$EMPTY_PREV" = "''" ]; then
  assert "Empty previous_commit on first install is valid" "pass"
else
  assert "Empty previous_commit on first install is valid" "fail" "Got: $EMPTY_PREV"
fi

# AC: update_state does NOT create the target directory
NON_EXISTENT="$TMP_DIR/nonexistent_dir"
if update_state "$NON_EXISTENT" "$COMMIT_SHA" "$PREV_COMMIT" "$FILE_HASHES" 2>/dev/null; then
  assert "Nonexistent target dir exits non-zero" "fail"
else
  assert "Nonexistent target dir exits non-zero" "pass"
fi
if [ ! -d "$NON_EXISTENT" ]; then
  assert "Does NOT create target directory" "pass"
else
  assert "Does NOT create target directory" "fail"
fi

# AC: Only modifies .serious-sidekick-state.json
TARGET_DIR3="$TMP_DIR/target3"
mkdir -p "$TARGET_DIR3"
echo "existing file" > "$TARGET_DIR3/other.txt"
ORIG_HASH=$(hash_file "$TARGET_DIR3/other.txt")
update_state "$TARGET_DIR3" "$COMMIT_SHA" "$PREV_COMMIT" "$FILE_HASHES"
AFTER_HASH=$(hash_file "$TARGET_DIR3/other.txt")
if [ "$ORIG_HASH" = "$AFTER_HASH" ]; then
  assert "Does NOT modify other files in target dir" "pass"
else
  assert "Does NOT modify other files in target dir" "fail"
fi
DIR_FILES=$(ls "$TARGET_DIR3" | grep -v "^\.serious-sidekick-state\.json$" | grep -v "^other.txt$" || true)
if [ -z "$DIR_FILES" ]; then
  assert "Only state file and existing files in target dir" "pass"
else
  assert "Only state file and existing files in target dir" "fail" "Extra: $DIR_FILES"
fi

# --- Negative tests ---

# Negative: empty commit_sha
TARGET_DIR4="$TMP_DIR/target4"
mkdir -p "$TARGET_DIR4"
if update_state "$TARGET_DIR4" "" "$PREV_COMMIT" "$FILE_HASHES" 2>/dev/null; then
  assert "Empty commit_sha exits non-zero" "fail"
else
  assert "Empty commit_sha exits non-zero" "pass"
fi

# Negative: invalid file_hashes_json
TARGET_DIR5="$TMP_DIR/target5"
mkdir -p "$TARGET_DIR5"
if update_state "$TARGET_DIR5" "$COMMIT_SHA" "$PREV_COMMIT" "{invalid json" 2>/dev/null; then
  assert "Invalid file_hashes_json exits non-zero" "fail"
else
  assert "Invalid file_hashes_json exits non-zero" "pass"
fi
# Verify no state file was written
if [ ! -f "$TARGET_DIR5/.serious-sidekick-state.json" ]; then
  assert "Invalid file_hashes_json does NOT write state file" "pass"
else
  assert "Invalid file_hashes_json does NOT write state file" "fail"
fi

echo ""

# --- REL5.* — corruption sentinel (Task 7, Finding 10) ---
# When post-write validation fails, update_state deletes the invalid state
# file AND writes a sentinel ".serious-sidekick-state.corrupt" alongside.
# We force the failure by stubbing validate_json to always return 1.
echo ""
echo "=== Test: update_state corruption sentinel (REL5.*) ==="

REL5_DIR="$TMP_DIR/rel5_sentinel"
mkdir -p "$REL5_DIR"
# We want validate_json to PASS on pre-write (file_hashes input) and FAIL on
# post-write (state file). Wrap: count invocations and fail on the 2nd.
# Use a file-based counter for subshell-safety.
REL5_COUNTER="$TMP_DIR/rel5_counter"
echo 0 > "$REL5_COUNTER"
# shellcheck disable=SC2034
set +e
(
  validate_json() {
    local n
    n=$(cat "$REL5_COUNTER")
    n=$((n + 1))
    echo "$n" > "$REL5_COUNTER"
    if [ "$n" -ge 2 ]; then
      return 1  # fail on post-write
    fi
    return 0  # pass on pre-write
  }
  update_state "$REL5_DIR" \
    "abc1234def5678901234567890abcdef12345678" "" \
    '{"skills/foo.md": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}' >/dev/null 2>&1
)
REL5_EXIT=$?
set -e

# REL5.U1: state file deleted on validation failure
if [ ! -f "$REL5_DIR/.serious-sidekick-state.json" ]; then
  assert "REL5.U1: invalid state file deleted on post-write validation failure" "pass"
else
  assert "REL5.U1: invalid state file deleted on post-write validation failure" "fail"
fi

# REL5.U2: sentinel written adjacent to deleted state file
if [ -f "$REL5_DIR/.serious-sidekick-state.corrupt" ]; then
  assert "REL5.U2: sentinel file .serious-sidekick-state.corrupt written" "pass"
else
  assert "REL5.U2: sentinel file .serious-sidekick-state.corrupt written" "fail"
fi

# REL5.U3: update_state still returns non-zero
if [ "$REL5_EXIT" -ne 0 ]; then
  assert "REL5.U3: update_state returns non-zero on validation failure" "pass"
else
  assert "REL5.U3: update_state returns non-zero on validation failure" "fail" "exit=$REL5_EXIT"
fi

# REL5.U4: sentinel content is two-line plain text
#   line 1: corrupt_at: <ISO 8601>
#   line 2: error: <single-line message>
if [ -f "$REL5_DIR/.serious-sidekick-state.corrupt" ]; then
  REL5_L1=$(sed -n '1p' "$REL5_DIR/.serious-sidekick-state.corrupt")
  REL5_L2=$(sed -n '2p' "$REL5_DIR/.serious-sidekick-state.corrupt")
  if echo "$REL5_L1" | grep -qE '^corrupt_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
     && echo "$REL5_L2" | grep -qE '^error: .+$'; then
    assert "REL5.U4: sentinel format is corrupt_at: <ISO 8601> + error: <message>" "pass"
  else
    assert "REL5.U4: sentinel format is corrupt_at: <ISO 8601> + error: <message>" "fail" \
      "l1='$REL5_L1' l2='$REL5_L2'"
  fi
fi

# REL5.U5: sentinel error line is single-line and <=510 chars (500 + small slack
# for the "error: " prefix).
if [ -f "$REL5_DIR/.serious-sidekick-state.corrupt" ]; then
  REL5_L2=$(sed -n '2p' "$REL5_DIR/.serious-sidekick-state.corrupt")
  REL5_L2_LEN=${#REL5_L2}
  REL5_LINE_COUNT=$(wc -l < "$REL5_DIR/.serious-sidekick-state.corrupt" | tr -d ' ')
  if [ "$REL5_L2_LEN" -le 510 ] && [ "$REL5_LINE_COUNT" -le 2 ]; then
    assert "REL5.U5: sentinel error line <=510 chars and total <=2 lines" "pass"
  else
    assert "REL5.U5: sentinel error line <=510 chars and total <=2 lines" "fail" \
      "err_len=$REL5_L2_LEN lines=$REL5_LINE_COUNT"
  fi
fi

# Re-source serious-common.sh so the rest of the file (if any) gets the real
# validate_json back. (No more tests after this point — defensive.)
unset -f validate_json 2>/dev/null || true
source "$REPO_ROOT/lib/serious-common.sh"

echo ""
echo "=== update_state Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
