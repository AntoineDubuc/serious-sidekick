#!/bin/bash
# test_generate_manifest.sh — Tests for bin/generate-manifest.sh
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

echo "=== Test: generate-manifest.sh ==="
echo ""

# Generate into a temp location to avoid polluting repo root during test
MANIFEST_OUT="$TMP_DIR/manifest.json"

# AC: generate-manifest.sh is executable
if [ -x "$REPO_ROOT/bin/generate-manifest.sh" ]; then
  assert "generate-manifest.sh is executable" "pass"
else
  assert "generate-manifest.sh is executable" "fail"
fi

# AC: Running from repo root produces manifest.json
MANIFEST_PATH="$MANIFEST_OUT" bash "$REPO_ROOT/bin/generate-manifest.sh" "$REPO_ROOT" >/dev/null 2>&1
GEN_EXIT=$?
if [ "$GEN_EXIT" -eq 0 ]; then
  assert "generate-manifest.sh exits 0 from repo root" "pass"
else
  assert "generate-manifest.sh exits 0 from repo root" "fail" "exit=$GEN_EXIT"
fi

if [ -f "$MANIFEST_OUT" ]; then
  assert "manifest.json was created" "pass"
else
  assert "manifest.json was created" "fail"
  echo "=== Generate Manifest Tests Complete: $ERRORS error(s) ==="
  exit 1
fi

# AC: Generated manifest passes parse_manifest validation
if parse_manifest "$MANIFEST_OUT" >/dev/null 2>&1; then
  assert "Generated manifest passes parse_manifest validation" "pass"
else
  assert "Generated manifest passes parse_manifest validation" "fail"
fi

# AC: Generated manifest is valid JSON
if validate_json "$MANIFEST_OUT"; then
  assert "Generated manifest is valid JSON" "pass"
else
  assert "Generated manifest is valid JSON" "fail"
fi

# AC: version field is 1
VERSION=$(python3 -c "import json; print(json.load(open('$MANIFEST_OUT'))['version'])")
if [ "$VERSION" = "1" ]; then
  assert "version field is 1" "pass"
else
  assert "version field is 1" "fail" "Got: $VERSION"
fi

# AC: generated_from_commit matches HEAD
HEAD_SHA=$(cd "$REPO_ROOT" && git rev-parse HEAD)
GEN_COMMIT=$(python3 -c "import json; print(json.load(open('$MANIFEST_OUT'))['generated_from_commit'])")
if [ "$GEN_COMMIT" = "$HEAD_SHA" ]; then
  assert "generated_from_commit matches HEAD" "pass"
else
  assert "generated_from_commit matches HEAD" "fail" \
    "Expected: $HEAD_SHA, Got: $GEN_COMMIT"
fi

# AC: Skills included as template tier
SKILL_ENTRY=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
for k, v in m['files'].items():
    if 'serious-code/SKILL.md' in k:
        print(v['ownership'])
        break
")
if [ "$SKILL_ENTRY" = "template" ]; then
  assert "Skills are template tier" "pass"
else
  assert "Skills are template tier" "fail" "Got: $SKILL_ENTRY"
fi

# AC: Agents included as template tier
AGENT_ENTRY=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
for k, v in m['files'].items():
    if 'serious-code-implementer.md' in k:
        print(v['ownership'])
        break
")
if [ "$AGENT_ENTRY" = "template" ]; then
  assert "Agents are template tier" "pass"
else
  assert "Agents are template tier" "fail" "Got: $AGENT_ENTRY"
fi

# AC: settings.json included as merge tier with merge_key "hooks"
SETTINGS_ENTRY=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
e = m['files'].get('.claude/settings.json', {})
print(e.get('ownership', ''), e.get('merge_key', ''))
")
if [ "$SETTINGS_ENTRY" = "merge hooks" ]; then
  assert "settings.json is merge tier with merge_key=hooks" "pass"
else
  assert "settings.json is merge tier with merge_key=hooks" "fail" "Got: '$SETTINGS_ENTRY'"
fi

# AC: CLAUDE.md included as user-init
CLAUDE_ENTRY=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
e = m['files'].get('CLAUDE.md', {})
print(e.get('ownership', ''))
")
if [ "$CLAUDE_ENTRY" = "user-init" ]; then
  assert "CLAUDE.md is user-init tier" "pass"
else
  assert "CLAUDE.md is user-init tier" "fail" "Got: $CLAUDE_ENTRY"
fi

# AC: Hook scripts included with correct dest paths
HOOK_DEST=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
for k, v in m['files'].items():
    if 'verify-completion-gate.sh' in k:
        print(v['dest'])
        break
")
if [ "$HOOK_DEST" = "skills/serious-code/hooks/verify-completion-gate.sh" ]; then
  assert "Hook scripts have correct dest paths" "pass"
else
  assert "Hook scripts have correct dest paths" "fail" "Got: $HOOK_DEST"
fi

# AC: _implementation_plan_template_v6.md included
TEMPLATE_ENTRY=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
e = m['files'].get('_implementation_plan_template_v6.md', {})
print(e.get('ownership', ''), e.get('dest', ''))
")
if echo "$TEMPLATE_ENTRY" | grep -q "template"; then
  assert "_implementation_plan_template_v6.md included as template" "pass"
else
  assert "_implementation_plan_template_v6.md included as template" "fail" "Got: '$TEMPLATE_ENTRY'"
fi

# AC: Template-tier entries have sha256 matching actual hash
SKILL_SHA=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
for k, v in m['files'].items():
    if 'serious-code/SKILL.md' in k:
        print(v.get('sha256', ''))
        break
")
ACTUAL_SHA=$(hash_file "$REPO_ROOT/.claude/skills/serious-code/SKILL.md")
if [ "$SKILL_SHA" = "$ACTUAL_SHA" ]; then
  assert "Template sha256 matches actual file hash" "pass"
else
  assert "Template sha256 matches actual file hash" "fail" \
    "Manifest: $SKILL_SHA, Actual: $ACTUAL_SHA"
fi

# AC: Merge-tier entries do NOT have sha256
MERGE_SHA=$(python3 -c "
import json
m = json.load(open('$MANIFEST_OUT'))
e = m['files'].get('.claude/settings.json', {})
print('has_sha' if 'sha256' in e else 'no_sha')
")
if [ "$MERGE_SHA" = "no_sha" ]; then
  assert "Merge-tier entries have no sha256" "pass"
else
  assert "Merge-tier entries have no sha256" "fail"
fi

# AC: Deterministic output — run twice and compare
MANIFEST_OUT2="$TMP_DIR/manifest2.json"
MANIFEST_PATH="$MANIFEST_OUT2" bash "$REPO_ROOT/bin/generate-manifest.sh" "$REPO_ROOT" >/dev/null 2>&1
if diff -q "$MANIFEST_OUT" "$MANIFEST_OUT2" >/dev/null 2>&1; then
  assert "Deterministic: two runs produce identical output" "pass"
else
  assert "Deterministic: two runs produce identical output" "fail"
fi

# AC: File count is reasonable (should be substantial — skills + agents + hooks + templates)
FILE_COUNT=$(python3 -c "import json; print(len(json.load(open('$MANIFEST_OUT'))['files']))")
if [ "$FILE_COUNT" -gt 10 ]; then
  assert "Manifest has >10 file entries ($FILE_COUNT total)" "pass"
else
  assert "Manifest has >10 file entries ($FILE_COUNT total)" "fail" "Got: $FILE_COUNT"
fi

# --- Negative tests ---

# Negative: Running outside repo root (no .claude/ folder)
EMPTY_DIR=$(mktemp -d)
if MANIFEST_PATH="$EMPTY_DIR/manifest.json" bash "$REPO_ROOT/bin/generate-manifest.sh" "$EMPTY_DIR" >/dev/null 2>&1; then
  assert "Exits non-zero outside repo root" "fail" "Exited 0"
else
  assert "Exits non-zero outside repo root" "pass"
fi
rm -rf "$EMPTY_DIR"

# Negative: Not in a git repo
NO_GIT_DIR=$(mktemp -d)
mkdir -p "$NO_GIT_DIR/.claude/skills/serious-test" "$NO_GIT_DIR/.claude/agents"
echo "test" > "$NO_GIT_DIR/.claude/skills/serious-test/SKILL.md"
if MANIFEST_PATH="$NO_GIT_DIR/manifest.json" bash "$REPO_ROOT/bin/generate-manifest.sh" "$NO_GIT_DIR" >/dev/null 2>&1; then
  assert "Exits non-zero when not in git repo" "fail" "Exited 0"
else
  assert "Exits non-zero when not in git repo" "pass"
fi
rm -rf "$NO_GIT_DIR"

echo ""
echo "=== Generate Manifest Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
