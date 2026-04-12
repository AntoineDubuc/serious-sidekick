#!/bin/bash
# test_supply_chain.sh — Supply-chain hardening tests (Plan 2)
# Tests attack vector defenses: tier-swap, key allowlist, hash verification, regex tightening
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

echo "=== Test: supply-chain hardening ==="
echo ""

# ─── Task 1: parse_manifest tier-swap rejection ─────────────────────────────

echo "--- Task 1: parse_manifest ownership pinning ---"

# AC: Manifest with ownership=template for settings.json is rejected
cat > "$TMP_DIR/tierswap_manifest.json" << 'HEREDOC'
{
  "version": 1,
  "generated_from_commit": "deadbeef",
  "files": {
    ".claude/settings.json": {
      "ownership": "template",
      "dest": "settings.json",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
HEREDOC

TIERSWAP_OUTPUT=$(parse_manifest "$TMP_DIR/tierswap_manifest.json" 2>&1 || true)
TIERSWAP_EXIT=$?
# The function is called in a subshell for exit code capture
TIERSWAP_EXIT=$(source "$REPO_ROOT/lib/serious-common.sh" && parse_manifest "$TMP_DIR/tierswap_manifest.json" >/dev/null 2>&1; echo $?)

if [ "$TIERSWAP_EXIT" -ne 0 ]; then
  assert "parse_manifest rejects ownership=template for settings.json" "pass"
else
  assert "parse_manifest rejects ownership=template for settings.json" "fail" "Expected non-zero exit, got 0"
fi

# AC: Error message contains "must be merge-tier"
TIERSWAP_STDERR=$(source "$REPO_ROOT/lib/serious-common.sh" && parse_manifest "$TMP_DIR/tierswap_manifest.json" 2>&1 >/dev/null || true)
if echo "$TIERSWAP_STDERR" | grep -qi "must be merge-tier"; then
  assert "Rejection error contains 'must be merge-tier'" "pass"
else
  assert "Rejection error contains 'must be merge-tier'" "fail" "stderr: $TIERSWAP_STDERR"
fi

# AC: Manifest with merge_key empty for settings.json is rejected
cat > "$TMP_DIR/bad_mergekey_manifest.json" << 'HEREDOC'
{
  "version": 1,
  "generated_from_commit": "deadbeef",
  "files": {
    ".claude/settings.json": {
      "ownership": "merge",
      "dest": "settings.json",
      "merge_key": ""
    }
  }
}
HEREDOC

BAD_MK_EXIT=$(source "$REPO_ROOT/lib/serious-common.sh" && parse_manifest "$TMP_DIR/bad_mergekey_manifest.json" >/dev/null 2>&1; echo $?)
if [ "$BAD_MK_EXIT" -ne 0 ]; then
  assert "parse_manifest rejects empty merge_key for settings.json" "pass"
else
  assert "parse_manifest rejects empty merge_key for settings.json" "fail" "Expected non-zero exit, got 0"
fi

# AC: Manifest with ownership=merge and merge_key=hooks for settings.json is ACCEPTED
cat > "$TMP_DIR/legit_manifest.json" << 'HEREDOC'
{
  "version": 1,
  "generated_from_commit": "deadbeef",
  "files": {
    ".claude/settings.json": {
      "ownership": "merge",
      "dest": "settings.json",
      "merge_key": "hooks"
    }
  }
}
HEREDOC

LEGIT_EXIT=$(source "$REPO_ROOT/lib/serious-common.sh" && parse_manifest "$TMP_DIR/legit_manifest.json" >/dev/null 2>&1; echo $?)
if [ "$LEGIT_EXIT" -eq 0 ]; then
  assert "parse_manifest accepts merge+hooks for settings.json" "pass"
else
  assert "parse_manifest accepts merge+hooks for settings.json" "fail" "Expected exit 0, got $LEGIT_EXIT"
fi

# AC: Real project manifest still parses
REAL_EXIT=$(source "$REPO_ROOT/lib/serious-common.sh" && parse_manifest "$REPO_ROOT/manifest.json" >/dev/null 2>&1; echo $?)
if [ "$REAL_EXIT" -eq 0 ]; then
  assert "Real project manifest still parses successfully" "pass"
else
  assert "Real project manifest still parses successfully" "fail" "Expected exit 0, got $REAL_EXIT"
fi

# Negative: Other files' ownership is NOT pinned
cat > "$TMP_DIR/other_template_manifest.json" << 'HEREDOC'
{
  "version": 1,
  "generated_from_commit": "deadbeef",
  "files": {
    ".claude/skills/serious-code/SKILL.md": {
      "ownership": "template",
      "dest": "skills/serious-code/SKILL.md",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
HEREDOC

OTHER_EXIT=$(source "$REPO_ROOT/lib/serious-common.sh" && parse_manifest "$TMP_DIR/other_template_manifest.json" >/dev/null 2>&1; echo $?)
if [ "$OTHER_EXIT" -eq 0 ]; then
  assert "Negative: other files' ownership NOT pinned (template accepted)" "pass"
else
  assert "Negative: other files' ownership NOT pinned (template accepted)" "fail" "Expected exit 0, got $OTHER_EXIT"
fi

# ─── Task 2: SHA-256 hash verification ──────────────────────────────────────

echo "--- Task 2: SHA-256 hash verification ---"

# We test hash verification by calling distribute_to_dir directly.
# Extract the function from bin/serious-update (it's a function, not top-level code).
# We can source lib/serious-common.sh for hash_file, then define distribute_to_dir
# from a copy of the script.

# Create a helper script that extracts distribute_to_dir and calls it
cat > "$TMP_DIR/test_hash_verify.sh" << 'TESTSCRIPT'
#!/bin/bash
set -euo pipefail
REPO_ROOT="$1"
SIDEKICK_HOME="$2"
TARGET_DIR="$3"
MANIFEST="$4"

source "$REPO_ROOT/lib/serious-common.sh"
ENTRIES=$(parse_manifest "$MANIFEST")

# Extract the distribute_to_dir function from bin/serious-update
# by sourcing it inside a function context that prevents the main logic from running
eval "$(sed -n '/^distribute_to_dir()/,/^}/p' "$REPO_ROOT/bin/serious-update")"

distribute_to_dir "$TARGET_DIR" "$ENTRIES" "false" "abc" "def" 2>&1 || true
TESTSCRIPT
chmod +x "$TMP_DIR/test_hash_verify.sh"

# Set up a mini sidekick home with a source file
SIDEKICK_HOME="$TMP_DIR/sidekick-home"
mkdir -p "$SIDEKICK_HOME"

# Create a legit source file and compute its hash
echo '#!/bin/bash' > "$SIDEKICK_HOME/test-script.sh"
echo 'echo "I am legitimate"' >> "$SIDEKICK_HOME/test-script.sh"
LEGIT_HASH=$(hash_file "$SIDEKICK_HOME/test-script.sh")

# Now tamper the source (hash will no longer match)
echo '# injected malicious code' >> "$SIDEKICK_HOME/test-script.sh"

# Create manifest with the ORIGINAL (pre-tamper) hash
cat > "$SIDEKICK_HOME/manifest.json" << HEREDOC
{
  "version": 1,
  "generated_from_commit": "deadbeef",
  "files": {
    "test-script.sh": {
      "ownership": "template",
      "dest": "test-script.sh",
      "sha256": "$LEGIT_HASH"
    }
  }
}
HEREDOC

TARGET_DIR="$TMP_DIR/target-hash-test"
mkdir -p "$TARGET_DIR"

HASH_OUTPUT=$(bash "$TMP_DIR/test_hash_verify.sh" "$REPO_ROOT" "$SIDEKICK_HOME" "$TARGET_DIR" "$SIDEKICK_HOME/manifest.json" 2>&1 || true)

# AC: Hash mismatch error should be reported
if echo "$HASH_OUTPUT" | grep -q "HASH MISMATCH"; then
  assert "Hash mismatch produces HASH MISMATCH error" "pass"
else
  assert "Hash mismatch produces HASH MISMATCH error" "fail" "Output: $HASH_OUTPUT"
fi

# AC: Tampered file should NOT be copied to target
if [ ! -f "$TARGET_DIR/test-script.sh" ]; then
  assert "Tampered file NOT copied on hash mismatch" "pass"
else
  assert "Tampered file NOT copied on hash mismatch" "fail" "File exists at $TARGET_DIR/test-script.sh"
fi

# AC: Empty hash means skip verification (backward compat)
echo '#!/bin/bash' > "$SIDEKICK_HOME/no-hash-script.sh"
echo 'echo "no hash test"' >> "$SIDEKICK_HOME/no-hash-script.sh"
cat > "$SIDEKICK_HOME/manifest-nohash.json" << 'HEREDOC'
{
  "version": 1,
  "generated_from_commit": "deadbeef",
  "files": {
    "no-hash-script.sh": {
      "ownership": "template",
      "dest": "no-hash-script.sh"
    }
  }
}
HEREDOC

TARGET_DIR2="$TMP_DIR/target-nohash-test"
mkdir -p "$TARGET_DIR2"

NOHASH_OUTPUT=$(bash "$TMP_DIR/test_hash_verify.sh" "$REPO_ROOT" "$SIDEKICK_HOME" "$TARGET_DIR2" "$SIDEKICK_HOME/manifest-nohash.json" 2>&1 || true)

if [ -f "$TARGET_DIR2/no-hash-script.sh" ]; then
  assert "Empty hash: file IS copied (backward compat)" "pass"
else
  assert "Empty hash: file IS copied (backward compat)" "fail" "File not found. Output: $NOHASH_OUTPUT"
fi

# AC: Error message contains truncated hashes (16 chars + ...)
if echo "$HASH_OUTPUT" | grep -qE '[a-f0-9]{16}'; then
  assert "Hash mismatch error shows truncated hashes" "pass"
else
  assert "Hash mismatch error shows truncated hashes" "fail" "Output: $HASH_OUTPUT"
fi

echo ""
echo "Supply-chain test errors: $ERRORS"
[ "$ERRORS" -eq 0 ] || exit 1
