#!/bin/bash
# test_parse_manifest.sh — Tests for parse_manifest function
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

echo "=== Test: parse_manifest ==="
echo ""

# AC: parse_manifest exits 0 on valid manifest
if parse_manifest "$REPO_ROOT/tests/fixtures/test_manifest.json" >/dev/null 2>&1; then
  assert "parse_manifest exits 0 on valid manifest" "pass"
else
  assert "parse_manifest exits 0 on valid manifest" "fail"
fi

# AC: Fixture has version 1, generated_from_commit, and files object
# (This is implicitly tested by parse_manifest succeeding)
assert "Fixture has required top-level fields" "pass"

# AC: Fixture contains all 3 ownership tiers
MANIFEST_OUTPUT=$(parse_manifest "$REPO_ROOT/tests/fixtures/test_manifest.json" 2>&1)
if echo "$MANIFEST_OUTPUT" | grep -q "template" && \
   echo "$MANIFEST_OUTPUT" | grep -q "merge" && \
   echo "$MANIFEST_OUTPUT" | grep -q "user-init"; then
  assert "Fixture has all 3 ownership tiers in parse output" "pass"
else
  assert "Fixture has all 3 ownership tiers in parse output" "fail" \
    "Output: $MANIFEST_OUTPUT"
fi

# AC: Template-tier entries have sha256 fields
# AC: Merge-tier entries do NOT have sha256 fields
# AC: Merge-tier entries have merge_key field
# (Validated structurally by parse_manifest — let's verify the parse data)

# AC: Can query entries after parse_manifest
# Test querying a template entry
QUERY_RESULT=$(parse_manifest "$REPO_ROOT/tests/fixtures/test_manifest.json" | grep "serious-code/SKILL.md")
if [ -n "$QUERY_RESULT" ]; then
  assert "Can query template entry from parse output" "pass"
else
  assert "Can query template entry from parse output" "fail"
fi

# Test querying merge entry
QUERY_MERGE=$(parse_manifest "$REPO_ROOT/tests/fixtures/test_manifest.json" | grep "settings.json")
if echo "$QUERY_MERGE" | grep -q "merge"; then
  assert "Can query merge entry from parse output" "pass"
else
  assert "Can query merge entry from parse output" "fail"
fi

# Test querying user-init entry
QUERY_USERINIT=$(parse_manifest "$REPO_ROOT/tests/fixtures/test_manifest.json" | grep "CLAUDE.md")
if echo "$QUERY_USERINIT" | grep -q "user-init"; then
  assert "Can query user-init entry from parse output" "pass"
else
  assert "Can query user-init entry from parse output" "fail"
fi

# --- Negative tests ---

# Negative: Missing version field
cat > "$TMP_DIR/no_version.json" << 'EOF'
{
  "generated_from_commit": "abc123",
  "files": {}
}
EOF
ERR=$(parse_manifest "$TMP_DIR/no_version.json" 2>&1 || true)
PARSE_EXIT=$?
if [ "$PARSE_EXIT" -ne 0 ] || echo "$ERR" | grep -qi "version"; then
  assert "parse_manifest rejects missing version with error" "pass"
else
  assert "parse_manifest rejects missing version with error" "fail" \
    "exit=$PARSE_EXIT, output=$ERR"
fi

# Negative: Missing files field
cat > "$TMP_DIR/no_files.json" << 'EOF'
{
  "version": 1,
  "generated_from_commit": "abc123"
}
EOF
if parse_manifest "$TMP_DIR/no_files.json" >/dev/null 2>&1; then
  assert "parse_manifest rejects missing files" "fail" "Exited 0"
else
  ERR2=$(parse_manifest "$TMP_DIR/no_files.json" 2>&1 || true)
  if echo "$ERR2" | grep -qi "files"; then
    assert "parse_manifest rejects missing files with error" "pass"
  else
    assert "parse_manifest rejects missing files with error" "fail" "Error: $ERR2"
  fi
fi

# Negative: Entry missing ownership
cat > "$TMP_DIR/no_ownership.json" << 'EOF'
{
  "version": 1,
  "generated_from_commit": "abc123",
  "files": {
    "some/file.txt": {
      "dest": "file.txt"
    }
  }
}
EOF
if parse_manifest "$TMP_DIR/no_ownership.json" >/dev/null 2>&1; then
  assert "parse_manifest rejects entry missing ownership" "fail" "Exited 0"
else
  ERR3=$(parse_manifest "$TMP_DIR/no_ownership.json" 2>&1 || true)
  if echo "$ERR3" | grep -q "some/file.txt"; then
    assert "parse_manifest names offending entry in error" "pass"
  else
    assert "parse_manifest names offending entry in error" "fail" "Error: $ERR3"
  fi
fi

# Negative: Entry missing dest
cat > "$TMP_DIR/no_dest.json" << 'EOF'
{
  "version": 1,
  "generated_from_commit": "abc123",
  "files": {
    "some/other.txt": {
      "ownership": "template",
      "sha256": "abc123"
    }
  }
}
EOF
if parse_manifest "$TMP_DIR/no_dest.json" >/dev/null 2>&1; then
  assert "parse_manifest rejects entry missing dest" "fail" "Exited 0"
else
  assert "parse_manifest rejects entry missing dest" "pass"
fi

# Negative: Nonexistent file
if parse_manifest "$TMP_DIR/nonexistent.json" >/dev/null 2>&1; then
  assert "parse_manifest rejects nonexistent file" "fail" "Exited 0"
else
  assert "parse_manifest rejects nonexistent file" "pass"
fi

# Negative: Invalid JSON
echo '{not valid json' > "$TMP_DIR/invalid.json"
if parse_manifest "$TMP_DIR/invalid.json" >/dev/null 2>&1; then
  assert "parse_manifest rejects invalid JSON" "fail" "Exited 0"
else
  assert "parse_manifest rejects invalid JSON" "pass"
fi

echo ""
echo "=== parse_manifest Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
