#!/bin/bash
# test_json_backend.sh — Tests for JSON backend detection
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# cross-platform: paths handed to native exes (python) must be readable on Windows; no-op on macOS/Linux
source "$REPO_ROOT/tests/lib/portable.sh"
REPO_ROOT="$(winpath "$REPO_ROOT")"
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

# AC: Sourcing sets _SERIOUS_JSON_BACKEND to python3, python, or jq
if [ "$_SERIOUS_JSON_BACKEND" = "python3" ] || [ "$_SERIOUS_JSON_BACKEND" = "python" ] || [ "$_SERIOUS_JSON_BACKEND" = "jq" ]; then
  assert "_SERIOUS_JSON_BACKEND is set to python3, python, or jq" "pass"
else
  assert "_SERIOUS_JSON_BACKEND is set to python3, python, or jq" "fail" \
    "Got: '$_SERIOUS_JSON_BACKEND'"
fi

# AC: A working python (python3 or python) is primary when available
_SERIOUS_DETECTED_PYTHON=""
if command -v python3 >/dev/null 2>&1 \
   && [ "$(python3 -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  _SERIOUS_DETECTED_PYTHON="python3"
elif command -v python >/dev/null 2>&1 \
   && [ "$(python -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  _SERIOUS_DETECTED_PYTHON="python"
fi
if [ -n "$_SERIOUS_DETECTED_PYTHON" ]; then
  if [ "$_SERIOUS_JSON_BACKEND" = "$_SERIOUS_DETECTED_PYTHON" ]; then
    assert "python is primary when available (backend: $_SERIOUS_DETECTED_PYTHON)" "pass"
  else
    assert "python is primary when available (backend: $_SERIOUS_DETECTED_PYTHON)" "fail" \
      "working python '$_SERIOUS_DETECTED_PYTHON' is available but backend is '$_SERIOUS_JSON_BACKEND'"
  fi
fi
unset _SERIOUS_DETECTED_PYTHON

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

# AC: Test python backend path by overriding with whichever python is available
_SERIOUS_TEST_PYTHON=""
if command -v python3 >/dev/null 2>&1 \
   && [ "$(python3 -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  _SERIOUS_TEST_PYTHON="python3"
elif command -v python >/dev/null 2>&1 \
   && [ "$(python -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  _SERIOUS_TEST_PYTHON="python"
fi
if [ -n "$_SERIOUS_TEST_PYTHON" ]; then
  _SERIOUS_JSON_BACKEND="$_SERIOUS_TEST_PYTHON"
  TMP_DIR=$(mktemp -d)
  echo '{"test": true}' > "$TMP_DIR/valid.json"
  if validate_json "$TMP_DIR/valid.json"; then
    assert "validate_json works with $_SERIOUS_TEST_PYTHON backend" "pass"
  else
    assert "validate_json works with $_SERIOUS_TEST_PYTHON backend" "fail"
  fi
  rm -rf "$TMP_DIR"
  _SERIOUS_JSON_BACKEND="$SAVED_BACKEND"
else
  echo "  SKIP: no working python found, skipping python backend test"
fi
unset _SERIOUS_TEST_PYTHON

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
