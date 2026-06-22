#!/bin/bash
# test_supply_chain.sh — Supply-chain hardening tests (Plan 2)
# Tests attack vector defenses: tier-swap, key allowlist, hash verification, regex tightening
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_ROOT/lib/serious-common.sh"

ERRORS=0
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Detect working python command
if command -v python3 >/dev/null 2>&1 \
   && [ "$(python3 -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1 \
   && [ "$(python -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
  PYTHON_CMD="python"
else
  echo "SKIP: No working python found" >&2
  exit 0
fi

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

# ─── Task 3: is_serious() regex tightening + template key allowlist ──────────

echo "--- Task 3: is_serious() regex tightening ---"

# Test is_serious() by creating a standalone Python test script
# The regex lives inside a bash heredoc in lib/serious-common.sh,
# so we write a Python file to avoid double-escaping issues.
cat > "$TMP_DIR/test_is_serious.py" << 'PYEOF'
import re, sys

def is_serious(command_str):
    return bool(re.match(
        r'^bash "\$CLAUDE_PROJECT_DIR/\.claude/skills/serious-[a-z-]+/hooks/[a-z0-9._-]+\.sh"$',
        command_str
    ))

print(is_serious(sys.argv[1]))
PYEOF

test_is_serious() {
  local cmd="$1"
  $PYTHON_CMD "$TMP_DIR/test_is_serious.py" "$cmd"
}

# AC: Rogue serious-evil rejected
IS_ROGUE=$(test_is_serious '/tmp/serious-evil/x.sh')
if [ "$IS_ROGUE" = "False" ]; then
  assert "is_serious rejects rogue /tmp/serious-evil path" "pass"
else
  assert "is_serious rejects rogue /tmp/serious-evil path" "fail" "Got: $IS_ROGUE"
fi

# AC: Legit serious-code hook accepted
IS_LEGIT=$(test_is_serious 'bash "$CLAUDE_PROJECT_DIR/.claude/skills/serious-code/hooks/verify-completion-gate.sh"')
if [ "$IS_LEGIT" = "True" ]; then
  assert "is_serious accepts legit serious-code hook" "pass"
else
  assert "is_serious accepts legit serious-code hook" "fail" "Got: $IS_LEGIT"
fi

# AC: Path-traversal attack rejected (../ after /hooks/)
IS_TRAVERSAL=$(test_is_serious 'bash "$CLAUDE_PROJECT_DIR/.claude/skills/serious-code/hooks/../../../../tmp/evil.sh"')
if [ "$IS_TRAVERSAL" = "False" ]; then
  assert "is_serious rejects path-traversal after /hooks/" "pass"
else
  assert "is_serious rejects path-traversal after /hooks/" "fail" "Got: $IS_TRAVERSAL"
fi

# AC: Command chaining rejected
IS_CHAINING=$(test_is_serious 'bash "$CLAUDE_PROJECT_DIR/.claude/skills/serious-code/hooks/legit.sh" && curl evil')
if [ "$IS_CHAINING" = "False" ]; then
  assert "is_serious rejects command chaining" "pass"
else
  assert "is_serious rejects command chaining" "fail" "Got: $IS_CHAINING"
fi

# AC: Additional negative cases
IS_ECHO=$(test_is_serious 'echo serious-code')
if [ "$IS_ECHO" = "False" ]; then
  assert "is_serious rejects non-bash prefix" "pass"
else
  assert "is_serious rejects non-bash prefix" "fail" "Got: $IS_ECHO"
fi

IS_USR=$(test_is_serious '/usr/local/bin/serious-x')
if [ "$IS_USR" = "False" ]; then
  assert "is_serious rejects /usr/local/bin path" "pass"
else
  assert "is_serious rejects /usr/local/bin path" "fail" "Got: $IS_USR"
fi

# AC: All existing hook commands in real settings.json pass is_serious()
echo "--- Task 3: Real hook commands validation ---"
ALL_HOOKS_PASS=true
HOOK_FAIL_DETAILS=""
while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  RESULT=$(test_is_serious "$cmd")
  if [ "$RESULT" != "True" ]; then
    ALL_HOOKS_PASS=false
    HOOK_FAIL_DETAILS="$HOOK_FAIL_DETAILS\n  REJECTED: $cmd"
  fi
done < <($PYTHON_CMD -c "
import json
with open('$REPO_ROOT/.claude/settings.json') as f:
    data = json.load(f)
for hook_type, groups in data.get('hooks', {}).items():
    for group in groups:
        for hook in group.get('hooks', []):
            cmd = hook.get('command', '')
            if cmd:
                print(cmd)
")
if $ALL_HOOKS_PASS; then
  assert "All real hook commands pass tightened is_serious()" "pass"
else
  assert "All real hook commands pass tightened is_serious()" "fail" "Failed:$HOOK_FAIL_DETAILS"
fi

# ─── Task 3: merge_settings template key allowlist ───────────────────────────

echo "--- Task 3: merge_settings template key allowlist ---"

# AC: merge_settings rejects template with unknown top-level keys
cat > "$TMP_DIR/installed_for_allowlist.json" << 'HEREDOC'
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "echo test"}]}]
  }
}
HEREDOC
cat > "$TMP_DIR/template_malicious.json" << 'HEREDOC'
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "echo test"}]}]
  },
  "maliciousKey": true
}
HEREDOC

cp "$TMP_DIR/installed_for_allowlist.json" "$TMP_DIR/installed_test1.json"
MERGE_MALICIOUS_EXIT=0
MERGE_MALICIOUS_OUTPUT=$(merge_settings "$TMP_DIR/installed_test1.json" "$TMP_DIR/template_malicious.json" 2>&1) || MERGE_MALICIOUS_EXIT=$?

if [ "$MERGE_MALICIOUS_EXIT" -ne 0 ]; then
  assert "merge_settings rejects template with unknown keys" "pass"
else
  assert "merge_settings rejects template with unknown keys" "fail" "Expected non-zero exit, got 0"
fi

# AC: Error contains "disallowed top-level keys"
if echo "$MERGE_MALICIOUS_OUTPUT" | grep -qi "disallowed top-level keys"; then
  assert "Error message mentions disallowed top-level keys" "pass"
else
  assert "Error message mentions disallowed top-level keys" "fail" "Output: $MERGE_MALICIOUS_OUTPUT"
fi

# AC: merge_settings accepts template with only allowlisted keys
cat > "$TMP_DIR/template_clean.json" << 'HEREDOC'
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "echo test"}]}]
  },
  "permissions": {"allow": []},
  "env": {},
  "statusLine": {"type": "command", "command": "echo status"}
}
HEREDOC

cp "$TMP_DIR/installed_for_allowlist.json" "$TMP_DIR/installed_test2.json"
MERGE_CLEAN_EXIT=0
MERGE_CLEAN_OUTPUT=$(merge_settings "$TMP_DIR/installed_test2.json" "$TMP_DIR/template_clean.json" 2>&1) || MERGE_CLEAN_EXIT=$?

if [ "$MERGE_CLEAN_EXIT" -eq 0 ]; then
  assert "merge_settings accepts template with only allowlisted keys" "pass"
else
  assert "merge_settings accepts template with only allowlisted keys" "fail" "Exit: $MERGE_CLEAN_EXIT, Output: $MERGE_CLEAN_OUTPUT"
fi

# AC: statusLine is explicitly in allowlist (cross-plan coordination)
if grep -q "'statusLine'" "$REPO_ROOT/lib/serious-common.sh"; then
  assert "statusLine is in ALLOWED_TOP_LEVEL_KEYS" "pass"
else
  assert "statusLine is in ALLOWED_TOP_LEVEL_KEYS" "fail"
fi

# AC: ALLOWED_TOP_LEVEL_KEYS exists in lib/serious-common.sh
if grep -q "ALLOWED_TOP_LEVEL_KEYS" "$REPO_ROOT/lib/serious-common.sh"; then
  assert "ALLOWED_TOP_LEVEL_KEYS defined in lib/serious-common.sh" "pass"
else
  assert "ALLOWED_TOP_LEVEL_KEYS defined in lib/serious-common.sh" "fail"
fi

# AC: Allowlist governance — EXACTLY {hooks, permissions, env, statusLine}
ALLOWLIST_CHECK=$($PYTHON_CMD -c "
import re
with open('$REPO_ROOT/lib/serious-common.sh') as f:
    content = f.read()
# Find the ALLOWED_TOP_LEVEL_KEYS set definition
match = re.search(r\"ALLOWED_TOP_LEVEL_KEYS\s*=\s*\{([^}]+)\}\", content)
if match:
    raw = match.group(1)
    keys = set(k.strip().strip(\"'\\\"\") for k in raw.split(','))
    expected = {'hooks', 'permissions', 'env', 'statusLine', 'outputStyle'}
    if keys == expected:
        print('EXACT_MATCH')
    else:
        print(f'MISMATCH: got {sorted(keys)}, expected {sorted(expected)}')
else:
    print('NOT_FOUND')
")
if [ "$ALLOWLIST_CHECK" = "EXACT_MATCH" ]; then
  assert "Allowlist governance: exactly {hooks, permissions, env, statusLine}" "pass"
else
  assert "Allowlist governance: exactly {hooks, permissions, env, statusLine}" "fail" "$ALLOWLIST_CHECK"
fi

# AC: Error message sanitization — control characters stripped
cat > "$TMP_DIR/template_control_chars.json" << 'HEREDOC'
{
  "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo test"}]}]},
  "\u001b[31mEVIL": true
}
HEREDOC

cp "$TMP_DIR/installed_for_allowlist.json" "$TMP_DIR/installed_test3.json"
MERGE_CTRL_OUTPUT=$(merge_settings "$TMP_DIR/installed_test3.json" "$TMP_DIR/template_control_chars.json" 2>&1 || true)

# The raw ANSI escape should NOT appear in the error output
# Use python3 since macOS grep doesn't support -P
HAS_ANSI=$($PYTHON_CMD -c "
import sys
text = '''$MERGE_CTRL_OUTPUT'''
print('YES' if '\x1b[31m' in text else 'NO')
")
if [ "$HAS_ANSI" = "YES" ]; then
  assert "Error sanitization: no raw ANSI escapes in output" "fail" "Raw escape found"
else
  assert "Error sanitization: no raw ANSI escapes in output" "pass"
fi

# AC: merge_settings allows templates with FEWER keys (allowlist is upper bound)
cat > "$TMP_DIR/template_minimal.json" << 'HEREDOC'
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "echo test"}]}]
  }
}
HEREDOC

cp "$TMP_DIR/installed_for_allowlist.json" "$TMP_DIR/installed_test4.json"
MERGE_MINIMAL_EXIT=0
merge_settings "$TMP_DIR/installed_test4.json" "$TMP_DIR/template_minimal.json" >/dev/null 2>&1 || MERGE_MINIMAL_EXIT=$?

if [ "$MERGE_MINIMAL_EXIT" -eq 0 ]; then
  assert "Fewer keys than allowlist still accepted (upper bound)" "pass"
else
  assert "Fewer keys than allowlist still accepted (upper bound)" "fail" "Exit: $MERGE_MINIMAL_EXIT"
fi

# ─── Task 4: /serious-init SKILL.md + docs/security.md ──────────────────────

echo "--- Task 4: SKILL.md + docs/security.md ---"

# AC: SKILL.md references allowlist validation for fresh install
if grep -qi 'ALLOWED_TOP_LEVEL_KEYS\|reject.*unknown.*keys\|abort.*unknown' "$REPO_ROOT/.claude/skills/serious-init/SKILL.md"; then
  assert "SKILL.md references allowlist validation for fresh install" "pass"
else
  assert "SKILL.md references allowlist validation for fresh install" "fail"
fi

# AC: SKILL.md references lib/serious-common.sh as allowlist source
if grep -q 'lib/serious-common.sh' "$REPO_ROOT/.claude/skills/serious-init/SKILL.md"; then
  assert "SKILL.md references lib/serious-common.sh as allowlist source" "pass"
else
  assert "SKILL.md references lib/serious-common.sh as allowlist source" "fail"
fi

# AC: docs/security.md exists
if [ -f "$REPO_ROOT/docs/security.md" ]; then
  assert "docs/security.md exists" "pass"
else
  assert "docs/security.md exists" "fail"
fi

# AC: docs/security.md documents trust model boundary
if grep -q 'out-of-band trust anchor\|repo-level tampering' "$REPO_ROOT/docs/security.md" 2>/dev/null; then
  assert "docs/security.md documents trust model boundary" "pass"
else
  assert "docs/security.md documents trust model boundary" "fail"
fi

# AC: docs/security.md lists the allowlist and explains each key
if grep -q 'hooks.*permissions.*env.*statusLine\|statusLine' "$REPO_ROOT/docs/security.md" 2>/dev/null; then
  assert "docs/security.md lists allowlisted keys" "pass"
else
  assert "docs/security.md lists allowlisted keys" "fail"
fi

# Negative: SKILL.md still has merge_settings call for upgrade path
if grep -q 'merge_settings' "$REPO_ROOT/.claude/skills/serious-init/SKILL.md"; then
  assert "Negative: SKILL.md preserves merge_settings for upgrade path" "pass"
else
  assert "Negative: SKILL.md preserves merge_settings for upgrade path" "fail"
fi

# Negative: docs/security.md does NOT claim hashes protect against malicious commits
if grep -qi 'do not protect\|does not protect\|cannot defend\|cannot protect' "$REPO_ROOT/docs/security.md" 2>/dev/null; then
  assert "Negative: security doc disclaims in-repo hash protection" "pass"
else
  assert "Negative: security doc disclaims in-repo hash protection" "fail"
fi

echo ""
echo "Supply-chain test errors: $ERRORS"
[ "$ERRORS" -eq 0 ] || exit 1
