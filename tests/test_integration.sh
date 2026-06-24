#!/bin/bash
# test_integration.sh — End-to-end integration test for serious-common.sh
#
# Exercises the complete library against real repo data:
#   parse_manifest → hash_file → merge_settings → update_state
# Validates the whitelist invariant (user files untouched) and backup lifecycle.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# cross-platform: paths handed to native exes (python) must be readable on Windows; no-op on macOS/Linux
source "$REPO_ROOT/tests/lib/portable.sh"
REPO_ROOT="$(winpath "$REPO_ROOT")"
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

echo "=== Test: Integration (end-to-end) ==="
echo ""

# ---------------------------------------------------------------
# Step 1: Generate the real manifest into temp dir (avoid polluting repo root)
# ---------------------------------------------------------------
MANIFEST="$TMP_DIR/manifest.json"
MANIFEST_PATH="$MANIFEST" bash "$REPO_ROOT/bin/generate-manifest.sh" "$REPO_ROOT" >/dev/null 2>&1

# ---------------------------------------------------------------
# Step 2: parse_manifest on the real manifest.json
# ---------------------------------------------------------------
PARSED=$(parse_manifest "$MANIFEST" 2>&1)
PARSE_EXIT=$?
if [ "$PARSE_EXIT" -eq 0 ]; then
  assert "parse_manifest succeeds on real manifest.json" "pass"
else
  assert "parse_manifest succeeds on real manifest.json" "fail" "exit=$PARSE_EXIT"
fi

# Count entries (non-empty lines)
FILE_COUNT=$(echo "$PARSED" | grep -c $'.' || true)
if [ "$FILE_COUNT" -gt 0 ]; then
  assert "Manifest has >0 file entries (got $FILE_COUNT)" "pass"
else
  assert "Manifest has >0 file entries" "fail" "Count: $FILE_COUNT"
fi

# ---------------------------------------------------------------
# Step 3: hash_file on 3 real repo files — verify vs manifest sha256
# ---------------------------------------------------------------

# Pick 3 template-tier files from the manifest that have sha256
# Extract: source_path\townership\tdest\tsha256\tmerge_key
HASH_MISMATCHES=0
HASH_CHECKED=0
while IFS=$'\t' read -r src ownership dest sha256 merge_key; do
  [ -z "$sha256" ] && continue
  [ "$HASH_CHECKED" -ge 3 ] && break
  FULL_PATH="$REPO_ROOT/$src"
  if [ ! -f "$FULL_PATH" ]; then
    continue
  fi
  ACTUAL_HASH=$(hash_file "$FULL_PATH")
  if [ "$ACTUAL_HASH" = "$sha256" ]; then
    assert "hash_file matches manifest for $src" "pass"
  else
    assert "hash_file matches manifest for $src" "fail" \
      "expected=$sha256, got=$ACTUAL_HASH"
    HASH_MISMATCHES=$((HASH_MISMATCHES + 1))
  fi
  HASH_CHECKED=$((HASH_CHECKED + 1))
done <<< "$PARSED"

if [ "$HASH_CHECKED" -lt 3 ]; then
  assert "Checked at least 3 file hashes" "fail" "Only checked $HASH_CHECKED"
else
  assert "Checked at least 3 file hashes" "pass"
fi

# ---------------------------------------------------------------
# Step 4: Create temp dir simulating a target install
# ---------------------------------------------------------------
TARGET="$TMP_DIR/target_install"
mkdir -p "$TARGET"

# Copy global_settings.json as the installed settings.json
cp "$REPO_ROOT/tests/fixtures/global_settings.json" "$TARGET/settings.json"

# Place a user file NOT in the manifest
USER_FILE="$TARGET/my_custom_skill.md"
cat > "$USER_FILE" << 'USEREOF'
# My Custom Skill

This is a user-owned file that the updater must never touch.
It has unique content that should survive any update operation.
USEREOF
USER_FILE_HASH_BEFORE=$(hash_file "$USER_FILE")

# ---------------------------------------------------------------
# Step 5: merge_settings with real template and installed settings
# ---------------------------------------------------------------
TEMPLATE_SETTINGS="$REPO_ROOT/.claude/settings.json"
merge_settings "$TARGET/settings.json" "$TEMPLATE_SETTINGS"
MERGE_EXIT=$?
if [ "$MERGE_EXIT" -eq 0 ]; then
  assert "merge_settings succeeds" "pass"
else
  assert "merge_settings succeeds" "fail" "exit=$MERGE_EXIT"
fi

# ---------------------------------------------------------------
# Step 6: Verify merged output has both serious and user hooks
# ---------------------------------------------------------------

# Check serious hooks present (PreToolUse hooks from template)
SERIOUS_PRE=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TARGET/settings.json'))
count = 0
for group in m.get('hooks', {}).get('PreToolUse', []):
    for h in group.get('hooks', []):
        if 'serious' in h.get('command', ''):
            count += 1
print(count)
")
if [ "$SERIOUS_PRE" -gt 0 ]; then
  assert "Merged output has serious PreToolUse hooks ($SERIOUS_PRE)" "pass"
else
  assert "Merged output has serious PreToolUse hooks" "fail" "Count: $SERIOUS_PRE"
fi

# Check user's say command Stop hook preserved
SAY_HOOK=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TARGET/settings.json'))
for group in m.get('hooks', {}).get('Stop', []):
    for h in group.get('hooks', []):
        if 'say' in h.get('command', '') and 'serious' not in h.get('command', ''):
            print('found')
            break
" 2>/dev/null)
if [ "$SAY_HOOK" = "found" ]; then
  assert "User's say command hook preserved in merge" "pass"
else
  assert "User's say command hook preserved in merge" "fail"
fi

# Check user's verify-plan-gate PostToolUse hook preserved
PLAN_GATE=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TARGET/settings.json'))
for group in m.get('hooks', {}).get('PostToolUse', []):
    for h in group.get('hooks', []):
        if 'verify-plan-gate' in h.get('command', ''):
            print('found')
            break
" 2>/dev/null)
if [ "$PLAN_GATE" = "found" ]; then
  assert "User's verify-plan-gate hook preserved in merge" "pass"
else
  assert "User's verify-plan-gate hook preserved in merge" "fail"
fi

# ---------------------------------------------------------------
# Step 7: Build file_hashes_json from a few manifest entries
# ---------------------------------------------------------------
FILE_HASHES_JSON=$($_SERIOUS_JSON_BACKEND -c "
import json, sys

parsed_lines = sys.argv[1].strip().split('\n')
hashes = {}
count = 0
for line in parsed_lines:
    parts = line.split('\t')
    if len(parts) >= 4 and parts[3]:  # has sha256
        hashes[parts[2]] = parts[3]   # dest -> sha256
        count += 1
        if count >= 5:
            break
print(json.dumps(hashes))
" "$PARSED")

if validate_json <(echo "$FILE_HASHES_JSON") 2>/dev/null || $_SERIOUS_JSON_BACKEND -c "import json; json.loads('''$FILE_HASHES_JSON''')" 2>/dev/null; then
  assert "Built valid file_hashes_json from manifest entries" "pass"
else
  assert "Built valid file_hashes_json from manifest entries" "fail"
fi

# ---------------------------------------------------------------
# Step 8: update_state with a commit SHA, empty previous, and hashes
# ---------------------------------------------------------------
COMMIT_SHA=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$MANIFEST'))
print(m['generated_from_commit'])
")
update_state "$TARGET" "$COMMIT_SHA" "" "$FILE_HASHES_JSON"
STATE_EXIT=$?
if [ "$STATE_EXIT" -eq 0 ]; then
  assert "update_state succeeds" "pass"
else
  assert "update_state succeeds" "fail" "exit=$STATE_EXIT"
fi

# ---------------------------------------------------------------
# Step 9: Verify .serious-sidekick-state.json schema
# ---------------------------------------------------------------
STATE_FILE="$TARGET/.serious-sidekick-state.json"
if [ -f "$STATE_FILE" ]; then
  assert "State file exists" "pass"
else
  assert "State file exists" "fail"
fi

if validate_json "$STATE_FILE"; then
  assert "State file is valid JSON" "pass"
else
  assert "State file is valid JSON" "fail"
fi

SCHEMA_CHECK=$($_SERIOUS_JSON_BACKEND -c "
import json
data = json.load(open('$STATE_FILE'))
checks = []
checks.append(('installed_from_commit' in data, 'missing installed_from_commit'))
checks.append(('previous_commit' in data, 'missing previous_commit'))
checks.append(('installed_at' in data, 'missing installed_at'))
checks.append(('file_hashes' in data, 'missing file_hashes'))
checks.append((isinstance(data.get('file_hashes'), dict), 'file_hashes not dict'))
checks.append((data['installed_from_commit'] == '$COMMIT_SHA', 'commit mismatch'))
checks.append((data['previous_commit'] == '', 'previous_commit should be empty'))
failures = [msg for ok, msg in checks if not ok]
if failures:
    print('FAIL: ' + ', '.join(failures))
else:
    print('OK')
")
if [ "$SCHEMA_CHECK" = "OK" ]; then
  assert "State file schema is correct" "pass"
else
  assert "State file schema is correct" "fail" "$SCHEMA_CHECK"
fi

# Verify installed_at is ISO 8601
INSTALLED_AT=$($_SERIOUS_JSON_BACKEND -c "import json; print(json.load(open('$STATE_FILE'))['installed_at'])")
if echo "$INSTALLED_AT" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
  assert "State installed_at is ISO 8601" "pass"
else
  assert "State installed_at is ISO 8601" "fail" "Got: $INSTALLED_AT"
fi

# ---------------------------------------------------------------
# Step 10: Whitelist invariant — user file untouched
# ---------------------------------------------------------------
USER_FILE_HASH_AFTER=$(hash_file "$USER_FILE")
if [ "$USER_FILE_HASH_BEFORE" = "$USER_FILE_HASH_AFTER" ]; then
  assert "Whitelist invariant: user file untouched (same hash)" "pass"
else
  assert "Whitelist invariant: user file untouched" "fail" \
    "before=$USER_FILE_HASH_BEFORE, after=$USER_FILE_HASH_AFTER"
fi

# Verify content is intact too
if grep -q "My Custom Skill" "$USER_FILE"; then
  assert "Whitelist invariant: user file content intact" "pass"
else
  assert "Whitelist invariant: user file content intact" "fail"
fi

# ---------------------------------------------------------------
# Step 11: Backup file from merge_settings exists
# ---------------------------------------------------------------
BACKUP_COUNT=$(find "$TARGET" -name "settings.json.backup.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -ge 1 ]; then
  assert "Backup file from merge_settings exists" "pass"
else
  assert "Backup file from merge_settings exists" "fail" "Count: $BACKUP_COUNT"
fi

# ---------------------------------------------------------------
# Negative: Corrupt template → backup restored, no state file
# ---------------------------------------------------------------
echo ""
echo "--- Negative tests ---"
echo ""

NEG_DIR="$TMP_DIR/neg_corrupt"
mkdir -p "$NEG_DIR"
cp "$REPO_ROOT/tests/fixtures/global_settings.json" "$NEG_DIR/settings.json"
ORIG_HASH=$(hash_file "$NEG_DIR/settings.json")

# Create a corrupt template (invalid JSON)
echo '{corrupt json here' > "$TMP_DIR/corrupt_template.json"

# merge_settings should fail because the template is invalid
if merge_settings "$NEG_DIR/settings.json" "$TMP_DIR/corrupt_template.json" 2>/dev/null; then
  assert "Corrupt template: merge_settings fails" "fail" "Exited 0"
else
  assert "Corrupt template: merge_settings fails" "pass"
fi

# Installed file should NOT be modified (template is validated first, before backup)
AFTER_HASH=$(hash_file "$NEG_DIR/settings.json")
if [ "$ORIG_HASH" = "$AFTER_HASH" ]; then
  assert "Corrupt template: installed file unmodified" "pass"
else
  assert "Corrupt template: installed file unmodified" "fail"
fi

# No backup should have been created (template fails validation before backup)
NEG_BACKUP_COUNT=$(find "$NEG_DIR" -name "settings.json.backup.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$NEG_BACKUP_COUNT" -eq 0 ]; then
  assert "Corrupt template: no backup created" "pass"
else
  assert "Corrupt template: no backup created" "fail" "Count: $NEG_BACKUP_COUNT"
fi

# No state file should be written (we never called update_state)
if [ ! -f "$NEG_DIR/.serious-sidekick-state.json" ]; then
  assert "Corrupt template: no state file written" "pass"
else
  assert "Corrupt template: no state file written" "fail"
fi

# ---------------------------------------------------------------
# Negative: Manifest entry pointing to nonexistent file
# ---------------------------------------------------------------

# Create a manifest with an entry that points to a file that doesn't exist
cat > "$TMP_DIR/bad_manifest.json" << 'EOF'
{
  "version": 1,
  "generated_from_commit": "abc123",
  "files": {
    "nonexistent/file/that/does/not/exist.md": {
      "ownership": "template",
      "dest": "does-not-exist.md",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    ".claude/skills/serious-code/SKILL.md": {
      "ownership": "template",
      "dest": "skills/serious-code/SKILL.md",
      "sha256": "abc123"
    }
  }
}
EOF

# parse_manifest should still succeed — it validates structure, not file existence
PARSE_BAD=$(parse_manifest "$TMP_DIR/bad_manifest.json" 2>&1)
PARSE_BAD_EXIT=$?
if [ "$PARSE_BAD_EXIT" -eq 0 ]; then
  assert "Manifest with nonexistent file: parse_manifest succeeds (structure-only)" "pass"
else
  assert "Manifest with nonexistent file: parse_manifest succeeds (structure-only)" "fail" \
    "exit=$PARSE_BAD_EXIT"
fi

# hash_file on the nonexistent file should fail gracefully (no crash)
HASH_ERR=$(hash_file "$REPO_ROOT/nonexistent/file/that/does/not/exist.md" 2>&1) || HASH_EXIT=$?
HASH_EXIT=${HASH_EXIT:-0}
if [ "$HASH_EXIT" -ne 0 ]; then
  assert "hash_file on nonexistent file: exits non-zero (no crash)" "pass"
else
  assert "hash_file on nonexistent file: exits non-zero" "fail"
fi
if echo "$HASH_ERR" | grep -qi "not found\|error"; then
  assert "hash_file on nonexistent file: logs error" "pass"
else
  assert "hash_file on nonexistent file: logs error" "fail" "Got: $HASH_ERR"
fi

echo ""
echo "=== Integration Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
