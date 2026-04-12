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

echo ""
echo "Supply-chain test errors: $ERRORS"
[ "$ERRORS" -eq 0 ] || exit 1
