#!/bin/bash
# test_backup_restore.sh — Tests for backup_file and restore_backup functions
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

echo "=== Test: backup_file and restore_backup ==="
echo ""

# --- backup_file tests ---

# AC: backup_file creates a timestamped copy
echo "original content" > "$TMP_DIR/testfile.txt"
BACKUP_PATH=$(backup_file "$TMP_DIR/testfile.txt")
BACKUP_EXIT=$?
if [ "$BACKUP_EXIT" -eq 0 ]; then
  assert "backup_file exits 0 on valid file" "pass"
else
  assert "backup_file exits 0 on valid file" "fail" "exit=$BACKUP_EXIT"
fi

if [ -f "$BACKUP_PATH" ]; then
  assert "backup_file creates the backup file" "pass"
else
  assert "backup_file creates the backup file" "fail" "Path: $BACKUP_PATH"
fi

# AC: backup has correct name format (YYYYMMDD_HHMMSS)
BACKUP_BASE=$(basename "$BACKUP_PATH")
if echo "$BACKUP_BASE" | grep -qE '^testfile\.txt\.backup\.[0-9]{8}_[0-9]{6}$'; then
  assert "backup has correct timestamp format" "pass"
else
  assert "backup has correct timestamp format" "fail" "Got: $BACKUP_BASE"
fi

# AC: backup content matches original
BACKUP_CONTENT=$(cat "$BACKUP_PATH")
if [ "$BACKUP_CONTENT" = "original content" ]; then
  assert "backup content matches original" "pass"
else
  assert "backup content matches original" "fail"
fi

# AC: original file is not modified
ORIG_CONTENT=$(cat "$TMP_DIR/testfile.txt")
if [ "$ORIG_CONTENT" = "original content" ]; then
  assert "original file is not modified" "pass"
else
  assert "original file is not modified" "fail"
fi

# Negative: backup_file on nonexistent file exits non-zero
if backup_file "$TMP_DIR/nonexistent.txt" 2>/dev/null; then
  assert "backup_file on nonexistent file exits non-zero" "fail" "Exited 0"
else
  assert "backup_file on nonexistent file exits non-zero" "pass"
fi

# Negative: backup_file on nonexistent file does not create any files
BEFORE_COUNT=$(ls "$TMP_DIR" | wc -l)
backup_file "$TMP_DIR/nofile.txt" 2>/dev/null || true
AFTER_COUNT=$(ls "$TMP_DIR" | wc -l)
if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
  assert "backup_file on nonexistent file creates no files" "pass"
else
  assert "backup_file on nonexistent file creates no files" "fail"
fi

# --- restore_backup tests ---

# AC: restore_backup copies backup to original location
echo "modified content" > "$TMP_DIR/testfile.txt"
restore_backup "$BACKUP_PATH" "$TMP_DIR/testfile.txt"
RESTORE_EXIT=$?
if [ "$RESTORE_EXIT" -eq 0 ]; then
  assert "restore_backup exits 0" "pass"
else
  assert "restore_backup exits 0" "fail" "exit=$RESTORE_EXIT"
fi

RESTORED_CONTENT=$(cat "$TMP_DIR/testfile.txt")
if [ "$RESTORED_CONTENT" = "original content" ]; then
  assert "restore_backup restores original content" "pass"
else
  assert "restore_backup restores original content" "fail" \
    "Got: '$RESTORED_CONTENT'"
fi

# Negative: restore_backup with nonexistent backup exits non-zero
echo "some content" > "$TMP_DIR/target.txt"
if restore_backup "$TMP_DIR/nonexistent_backup" "$TMP_DIR/target.txt" 2>/dev/null; then
  assert "restore_backup with nonexistent backup exits non-zero" "fail" "Exited 0"
else
  assert "restore_backup with nonexistent backup exits non-zero" "pass"
fi

# AC: restore_backup with nonexistent backup does not modify original
TARGET_CONTENT=$(cat "$TMP_DIR/target.txt")
if [ "$TARGET_CONTENT" = "some content" ]; then
  assert "restore_backup with nonexistent backup preserves original" "pass"
else
  assert "restore_backup with nonexistent backup preserves original" "fail"
fi

echo ""
echo "=== backup_file / restore_backup Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
