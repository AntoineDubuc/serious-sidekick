#!/bin/bash
# test_json_backend.sh — Tests for JSON backend detection
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/lib/serious-common.sh"

ERRORS=0

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

echo "=== Test: JSON Backend Detection ==="
echo ""

# AC: Sourcing sets _SERIOUS_JSON_BACKEND to python3 or jq
if [ "$_SERIOUS_JSON_BACKEND" = "python3" ] || [ "$_SERIOUS_JSON_BACKEND" = "jq" ]; then
  assert "_SERIOUS_JSON_BACKEND is set to python3 or jq" "pass"
else
  assert "_SERIOUS_JSON_BACKEND is set to python3 or jq" "fail" \
    "Got: '$_SERIOUS_JSON_BACKEND'"
fi

# AC: python3 is primary (checked first) — on this machine python3 exists
if command -v python3 >/dev/null 2>&1; then
  if [ "$_SERIOUS_JSON_BACKEND" = "python3" ]; then
    assert "python3 is primary when available" "pass"
  else
    assert "python3 is primary when available" "fail" \
      "python3 is available but backend is '$_SERIOUS_JSON_BACKEND'"
  fi
fi

# AC: Backend is detected once and does not change on re-source
FIRST_BACKEND="$_SERIOUS_JSON_BACKEND"
source "$REPO_ROOT/lib/serious-common.sh"
if [ "$_SERIOUS_JSON_BACKEND" = "$FIRST_BACKEND" ]; then
  assert "Re-sourcing does not re-detect backend" "pass"
else
  assert "Re-sourcing does not re-detect backend" "fail" \
    "First: '$FIRST_BACKEND', Second: '$_SERIOUS_JSON_BACKEND'"
fi

# AC: Test jq backend path by overriding
SAVED_BACKEND="$_SERIOUS_JSON_BACKEND"
_SERIOUS_JSON_BACKEND="jq"
# validate_json should work with jq backend if jq is available
if command -v jq >/dev/null 2>&1; then
  TMP_DIR=$(mktemp -d)
  echo '{"test": true}' > "$TMP_DIR/valid.json"
  if validate_json "$TMP_DIR/valid.json"; then
    assert "validate_json works with jq backend" "pass"
  else
    assert "validate_json works with jq backend" "fail"
  fi
  rm -rf "$TMP_DIR"
else
  echo "  SKIP: jq not available, skipping jq backend test"
fi
_SERIOUS_JSON_BACKEND="$SAVED_BACKEND"

# AC: Test python3 backend path by overriding
_SERIOUS_JSON_BACKEND="python3"
TMP_DIR=$(mktemp -d)
echo '{"test": true}' > "$TMP_DIR/valid.json"
if validate_json "$TMP_DIR/valid.json"; then
  assert "validate_json works with python3 backend" "pass"
else
  assert "validate_json works with python3 backend" "fail"
fi
rm -rf "$TMP_DIR"
_SERIOUS_JSON_BACKEND="$SAVED_BACKEND"

# Negative: No backend available (mock command -v to fail)
# We simulate this by sourcing in a subshell with overridden PATH
RESULT=$(bash -c '
  unset _SERIOUS_JSON_BACKEND
  # Override PATH so neither python3 nor jq can be found
  export PATH="/nonexistent"
  source "'"$REPO_ROOT"'/lib/serious-common.sh" 2>/tmp/serious-nobackend-err.txt
  echo "exit=$?"
' 2>/dev/null || echo "exit=1")
if echo "$RESULT" | grep -q "exit=1"; then
  assert "No backend available returns non-zero" "pass"
else
  assert "No backend available returns non-zero" "fail" \
    "Got: $RESULT"
fi

echo ""
echo "=== JSON Backend Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
