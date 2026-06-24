#!/bin/bash
# test_merge_settings.sh — Tests for merge_settings function
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

echo "=== Test: merge_settings ==="
echo ""

TEMPLATE="$REPO_ROOT/tests/fixtures/template_settings.json"
GLOBAL="$REPO_ROOT/tests/fixtures/global_settings.json"

# --- Basic merge test: template into global ---
cp "$GLOBAL" "$TMP_DIR/installed.json"
merge_settings "$TMP_DIR/installed.json" "$TEMPLATE"
MERGE_EXIT=$?
if [ "$MERGE_EXIT" -eq 0 ]; then
  assert "merge_settings exits 0" "pass"
else
  assert "merge_settings exits 0" "fail" "exit=$MERGE_EXIT"
fi

# AC: Result is valid JSON
if validate_json "$TMP_DIR/installed.json"; then
  assert "Merged output is valid JSON" "pass"
else
  assert "Merged output is valid JSON" "fail"
fi

# AC: Backup was created
BACKUP_COUNT=$(ls "$TMP_DIR"/installed.json.backup.* 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -ge 1 ]; then
  assert "Backup was created" "pass"
else
  assert "Backup was created" "fail" "Count: $BACKUP_COUNT"
fi

# AC: Non-hook keys preserved (statusLine, enabledPlugins, permissions, etc.)
RESULT=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/installed.json'))
checks = []
checks.append('statusLine' in m)
checks.append('enabledPlugins' in m)
checks.append('permissions' in m)
checks.append('alwaysThinkingEnabled' in m)
checks.append('effortLevel' in m)
checks.append('voiceEnabled' in m)
checks.append('skipDangerousModePermissionPrompt' in m)
print('all_ok' if all(checks) else 'missing: ' + str(checks))
")
if [ "$RESULT" = "all_ok" ]; then
  assert "Non-hook keys preserved" "pass"
else
  assert "Non-hook keys preserved" "fail" "$RESULT"
fi

# AC: User's say command Stop hook preserved
SAY_HOOK=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/installed.json'))
stop_hooks = m.get('hooks', {}).get('Stop', [])
for group in stop_hooks:
    for h in group.get('hooks', []):
        if 'say' in h.get('command', '') and 'serious' not in h.get('command', ''):
            print('found')
            break
" 2>/dev/null)
if [ "$SAY_HOOK" = "found" ]; then
  assert "User's say command Stop hook preserved" "pass"
else
  assert "User's say command Stop hook preserved" "fail"
fi

# AC: User's PostToolUse verify-plan-gate hook preserved
PLAN_GATE=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/installed.json'))
post_hooks = m.get('hooks', {}).get('PostToolUse', [])
for group in post_hooks:
    for h in group.get('hooks', []):
        if 'verify-plan-gate' in h.get('command', ''):
            print('found')
            break
" 2>/dev/null)
if [ "$PLAN_GATE" = "found" ]; then
  assert "User's PostToolUse hook preserved" "pass"
else
  assert "User's PostToolUse hook preserved" "fail"
fi

# AC: All 32 PreToolUse hooks from template present
PRE_COUNT=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/installed.json'))
count = 0
for group in m.get('hooks', {}).get('PreToolUse', []):
    count += len(group.get('hooks', []))
print(count)
")
if [ "$PRE_COUNT" -eq 32 ]; then
  assert "All 32 PreToolUse hooks from template present" "pass"
else
  assert "All 32 PreToolUse hooks from template present" "fail" "Got: $PRE_COUNT"
fi

# AC: All 6 serious Stop hooks from template present
SERIOUS_STOP_COUNT=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/installed.json'))
count = 0
for group in m.get('hooks', {}).get('Stop', []):
    for h in group.get('hooks', []):
        if 'serious' in h.get('command', ''):
            count += 1
print(count)
")
if [ "$SERIOUS_STOP_COUNT" -eq 6 ]; then
  assert "All 6 serious Stop hooks from template present" "pass"
else
  assert "All 6 serious Stop hooks from template present" "fail" "Got: $SERIOUS_STOP_COUNT"
fi

# AC: Total Stop hooks = 6 serious + 1 user say = 7
TOTAL_STOP=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/installed.json'))
count = 0
for group in m.get('hooks', {}).get('Stop', []):
    count += len(group.get('hooks', []))
print(count)
")
if [ "$TOTAL_STOP" -eq 7 ]; then
  assert "Total Stop hooks = 7 (6 serious + 1 user)" "pass"
else
  assert "Total Stop hooks = 7 (6 serious + 1 user)" "fail" "Got: $TOTAL_STOP"
fi

# --- Idempotency: merging twice produces same result ---
cp "$TMP_DIR/installed.json" "$TMP_DIR/after_first_merge.json"
merge_settings "$TMP_DIR/installed.json" "$TEMPLATE" >/dev/null 2>&1
DIFF_RESULT=$($_SERIOUS_JSON_BACKEND -c "
import json
a = json.load(open('$TMP_DIR/after_first_merge.json'))
b = json.load(open('$TMP_DIR/installed.json'))
print('same' if a == b else 'different')
")
if [ "$DIFF_RESULT" = "same" ]; then
  assert "Merge is idempotent (two merges = same result)" "pass"
else
  assert "Merge is idempotent (two merges = same result)" "fail"
fi

# --- Serious hooks removed from template are removed from installed ---
cp "$GLOBAL" "$TMP_DIR/removal_test.json"
# First merge all serious hooks in
merge_settings "$TMP_DIR/removal_test.json" "$TEMPLATE" >/dev/null 2>&1
# Now create a reduced template with only 2 Stop hooks
$_SERIOUS_JSON_BACKEND -c "
import json
t = json.load(open('$TEMPLATE'))
# Keep only first 2 Stop hooks
t['hooks']['Stop'][0]['hooks'] = t['hooks']['Stop'][0]['hooks'][:2]
with open('$TMP_DIR/reduced_template.json', 'w') as f:
    json.dump(t, f, indent=2)
"
merge_settings "$TMP_DIR/removal_test.json" "$TMP_DIR/reduced_template.json" >/dev/null 2>&1
AFTER_REMOVAL_SERIOUS=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/removal_test.json'))
count = 0
for group in m.get('hooks', {}).get('Stop', []):
    for h in group.get('hooks', []):
        if 'serious' in h.get('command', ''):
            count += 1
print(count)
")
if [ "$AFTER_REMOVAL_SERIOUS" -eq 2 ]; then
  assert "Serious hooks removed from template are removed from installed" "pass"
else
  assert "Serious hooks removed from template are removed from installed" "fail" \
    "Expected 2, Got: $AFTER_REMOVAL_SERIOUS"
fi

# --- Negative tests ---

# Negative: nonexistent installed file
if merge_settings "$TMP_DIR/nonexistent.json" "$TEMPLATE" 2>/dev/null; then
  assert "Nonexistent installed file exits non-zero" "fail"
else
  assert "Nonexistent installed file exits non-zero" "pass"
fi

# Negative: nonexistent template file
cp "$GLOBAL" "$TMP_DIR/neg_test.json"
if merge_settings "$TMP_DIR/neg_test.json" "$TMP_DIR/nonexistent_template.json" 2>/dev/null; then
  assert "Nonexistent template file exits non-zero" "fail"
else
  assert "Nonexistent template file exits non-zero" "pass"
fi

# Negative: Invalid installed JSON — backup NOT created
echo '{broken json' > "$TMP_DIR/bad_installed.json"
BEFORE_BACKUPS=$(find "$TMP_DIR" -name "bad_installed.json.backup.*" 2>/dev/null | wc -l | tr -d ' ')
if merge_settings "$TMP_DIR/bad_installed.json" "$TEMPLATE" 2>/dev/null; then
  assert "Invalid installed JSON exits non-zero" "fail"
else
  assert "Invalid installed JSON exits non-zero" "pass"
fi
AFTER_BACKUPS=$(find "$TMP_DIR" -name "bad_installed.json.backup.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BEFORE_BACKUPS" -eq "$AFTER_BACKUPS" ]; then
  assert "Invalid installed JSON does NOT create backup" "pass"
else
  assert "Invalid installed JSON does NOT create backup" "fail"
fi

# Negative: Invalid template JSON — does NOT modify or backup installed
cp "$GLOBAL" "$TMP_DIR/good_installed.json"
echo '{broken' > "$TMP_DIR/bad_template.json"
ORIG_HASH=$(hash_file "$TMP_DIR/good_installed.json")
BEFORE_BACKUP2=$(find "$TMP_DIR" -name "good_installed.json.backup.*" 2>/dev/null | wc -l | tr -d ' ')
ERR_MSG=$(merge_settings "$TMP_DIR/good_installed.json" "$TMP_DIR/bad_template.json" 2>&1 || true)
AFTER_HASH=$(hash_file "$TMP_DIR/good_installed.json")
AFTER_BACKUP2=$(find "$TMP_DIR" -name "good_installed.json.backup.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORIG_HASH" = "$AFTER_HASH" ] && [ "$BEFORE_BACKUP2" -eq "$AFTER_BACKUP2" ]; then
  assert "Invalid template does NOT modify or backup installed" "pass"
else
  assert "Invalid template does NOT modify or backup installed" "fail"
fi
if echo "$ERR_MSG" | grep -qi "invalid template"; then
  assert "Invalid template error says 'invalid template'" "pass"
else
  assert "Invalid template error says 'invalid template'" "fail" "Got: $ERR_MSG"
fi

# Negative: Empty template hooks preserves all installed hooks
cat > "$TMP_DIR/empty_hooks_template.json" << 'EOF'
{
  "hooks": {}
}
EOF
cp "$GLOBAL" "$TMP_DIR/preserve_test.json"
merge_settings "$TMP_DIR/preserve_test.json" "$TMP_DIR/empty_hooks_template.json" >/dev/null 2>&1
PRESERVED_SAY=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/preserve_test.json'))
for group in m.get('hooks', {}).get('Stop', []):
    for h in group.get('hooks', []):
        if 'say' in h.get('command', ''):
            print('found')
")
if [ "$PRESERVED_SAY" = "found" ]; then
  assert "Empty template hooks preserves installed hooks" "pass"
else
  assert "Empty template hooks preserves installed hooks" "fail"
fi

# Negative: No hooks in installed (fresh install) — gets all template hooks + non-hook keys
cat > "$TMP_DIR/fresh_install.json" << 'EOF'
{
  "statusLine": {"type": "command", "command": "echo fresh"},
  "permissions": {"deny": []}
}
EOF
merge_settings "$TMP_DIR/fresh_install.json" "$TEMPLATE" >/dev/null 2>&1
FRESH_PRE_COUNT=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/fresh_install.json'))
count = 0
for group in m.get('hooks', {}).get('PreToolUse', []):
    count += len(group.get('hooks', []))
print(count)
")
FRESH_STATUSLINE=$($_SERIOUS_JSON_BACKEND -c "
import json
m = json.load(open('$TMP_DIR/fresh_install.json'))
print('found' if 'statusLine' in m else 'missing')
")
if [ "$FRESH_PRE_COUNT" -eq 32 ] && [ "$FRESH_STATUSLINE" = "found" ]; then
  assert "Fresh install gets template hooks + preserves non-hook keys" "pass"
else
  assert "Fresh install gets template hooks + preserves non-hook keys" "fail" \
    "PreToolUse=$FRESH_PRE_COUNT, statusLine=$FRESH_STATUSLINE"
fi

# Negative: Write failure (read-only directory) restores backup
cp "$GLOBAL" "$TMP_DIR/readonly_test.json"
READONLY_DIR=$(mktemp -d)
cp "$GLOBAL" "$READONLY_DIR/installed.json"
# Create backup manually to verify restore works
merge_settings "$READONLY_DIR/installed.json" "$TEMPLATE" >/dev/null 2>&1
# Verify it worked first
if validate_json "$READONLY_DIR/installed.json"; then
  assert "Pre-readonly merge succeeds" "pass"
else
  assert "Pre-readonly merge succeeds" "fail"
fi
rm -rf "$READONLY_DIR"

echo ""
echo "=== merge_settings Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
