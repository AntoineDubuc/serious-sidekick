#!/bin/bash
# test_hash_file.sh — Tests for hash_file function
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

echo "=== Test: hash_file ==="
echo ""

# AC: hash_file returns SHA-256 hex digest and exits 0
echo -n "hello world" > "$TMP_DIR/test.txt"
EXPECTED_HASH="b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
ACTUAL_HASH=$(hash_file "$TMP_DIR/test.txt")
HASH_EXIT=$?
if [ "$HASH_EXIT" -eq 0 ]; then
  assert "hash_file exits 0 on valid file" "pass"
else
  assert "hash_file exits 0 on valid file" "fail" "exit=$HASH_EXIT"
fi

if [ "$ACTUAL_HASH" = "$EXPECTED_HASH" ]; then
  assert "hash_file returns correct SHA-256 digest" "pass"
else
  assert "hash_file returns correct SHA-256 digest" "fail" \
    "Expected: $EXPECTED_HASH, Got: $ACTUAL_HASH"
fi

# AC: hash_file is consistent across calls
HASH2=$(hash_file "$TMP_DIR/test.txt")
if [ "$ACTUAL_HASH" = "$HASH2" ]; then
  assert "hash_file is deterministic" "pass"
else
  assert "hash_file is deterministic" "fail"
fi

# AC: hash_file on empty file returns a valid hash
touch "$TMP_DIR/empty.txt"
EMPTY_HASH=$(hash_file "$TMP_DIR/empty.txt")
EXPECTED_EMPTY="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
if [ "$EMPTY_HASH" = "$EXPECTED_EMPTY" ]; then
  assert "hash_file handles empty file" "pass"
else
  assert "hash_file handles empty file" "fail" \
    "Expected: $EXPECTED_EMPTY, Got: $EMPTY_HASH"
fi

# AC: hash_file does NOT depend on JSON backend (uses shasum/sha256sum directly)
SAVED_BACKEND="$_SERIOUS_JSON_BACKEND"
_SERIOUS_JSON_BACKEND="jq"
HASH_JQ=$(hash_file "$TMP_DIR/test.txt")
_SERIOUS_JSON_BACKEND="python"
HASH_PY=$(hash_file "$TMP_DIR/test.txt")
_SERIOUS_JSON_BACKEND="$SAVED_BACKEND"
if [ "$HASH_JQ" = "$HASH_PY" ] && [ "$HASH_JQ" = "$EXPECTED_HASH" ]; then
  assert "hash_file is backend-independent" "pass"
else
  assert "hash_file is backend-independent" "fail" \
    "jq=$HASH_JQ, python=$HASH_PY"
fi

# Negative: hash_file on nonexistent file exits non-zero
if hash_file "$TMP_DIR/nonexistent.txt" 2>/dev/null; then
  assert "hash_file on nonexistent file exits non-zero" "fail" "Exited 0"
else
  assert "hash_file on nonexistent file exits non-zero" "pass"
fi

# Negative: hash_file on nonexistent file prints error to stderr
ERR_OUTPUT=$(hash_file "$TMP_DIR/nonexistent.txt" 2>&1 >/dev/null || true)
if [ -n "$ERR_OUTPUT" ]; then
  assert "hash_file on nonexistent file prints error to stderr" "pass"
else
  assert "hash_file on nonexistent file prints error to stderr" "fail"
fi

echo ""
echo "=== hash_file Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
