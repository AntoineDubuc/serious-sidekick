#!/bin/bash
# test_validate_json.sh — Tests for validate_json function
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

echo "=== Test: validate_json ==="
echo ""

# AC: validate_json exits 0 for valid JSON
echo '{"key": "value"}' > "$TMP_DIR/valid.json"
if validate_json "$TMP_DIR/valid.json"; then
  assert "validate_json exits 0 for valid JSON object" "pass"
else
  assert "validate_json exits 0 for valid JSON object" "fail"
fi

# AC: valid JSON array
echo '[1, 2, 3]' > "$TMP_DIR/array.json"
if validate_json "$TMP_DIR/array.json"; then
  assert "validate_json exits 0 for valid JSON array" "pass"
else
  assert "validate_json exits 0 for valid JSON array" "fail"
fi

# AC: valid nested JSON
echo '{"a": {"b": [1, 2, {"c": true}]}}' > "$TMP_DIR/nested.json"
if validate_json "$TMP_DIR/nested.json"; then
  assert "validate_json exits 0 for nested JSON" "pass"
else
  assert "validate_json exits 0 for nested JSON" "fail"
fi

# AC: validate_json uses detected backend — test with python3
SAVED_BACKEND="$_SERIOUS_JSON_BACKEND"
_SERIOUS_JSON_BACKEND="python3"
if validate_json "$TMP_DIR/valid.json"; then
  assert "validate_json works with python3 backend" "pass"
else
  assert "validate_json works with python3 backend" "fail"
fi
_SERIOUS_JSON_BACKEND="$SAVED_BACKEND"

# Negative: invalid JSON exits 1
echo '{invalid json' > "$TMP_DIR/invalid.json"
if validate_json "$TMP_DIR/invalid.json"; then
  assert "validate_json exits 1 for invalid JSON" "fail" "Exited 0 on invalid JSON"
else
  assert "validate_json exits 1 for invalid JSON" "pass"
fi

# Negative: empty file exits 1
touch "$TMP_DIR/empty.json"
if validate_json "$TMP_DIR/empty.json"; then
  assert "validate_json exits 1 for empty file" "fail" "Exited 0 on empty file"
else
  assert "validate_json exits 1 for empty file" "pass"
fi

# Negative: nonexistent file exits 1
if validate_json "$TMP_DIR/nonexistent.json" 2>/dev/null; then
  assert "validate_json exits 1 for nonexistent file" "fail" "Exited 0"
else
  assert "validate_json exits 1 for nonexistent file" "pass"
fi

# Negative: file with trailing garbage
echo '{"valid": true} extra stuff' > "$TMP_DIR/trailing.json"
if validate_json "$TMP_DIR/trailing.json"; then
  assert "validate_json exits 1 for trailing garbage" "fail" "Exited 0"
else
  assert "validate_json exits 1 for trailing garbage" "pass"
fi

echo ""
echo "=== validate_json Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
