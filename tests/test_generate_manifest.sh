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

# ===============================================================
# install-bug-fixes Task 3 — relax serious-only filter, hardcode prospect-research skip
# ===============================================================
echo "--- install-bug-fixes Task 3: filter relaxation + hardcoded prospect-research skip ---"
echo ""

# Regenerate against a fresh tmp path so we don't disturb the in-tree manifest.
BF3_TMPMANI=$(mktemp -t bf3manifest.XXXXXX)
MANIFEST_PATH="$BF3_TMPMANI" bash "$REPO_ROOT/bin/generate-manifest.sh" "$REPO_ROOT" >/dev/null 2>&1

# BF3.A: filter excludes serious-prospect-research entirely.
BF3_PROSPECT_COUNT=$(python3 -c "import json; d=json.load(open('$BF3_TMPMANI')); print(len([k for k in d['files'] if 'serious-prospect-research' in k]))")
if [ "$BF3_PROSPECT_COUNT" -eq 0 ]; then
  assert "BF3.A: regenerated manifest excludes serious-prospect-research entirely" "pass"
else
  assert "BF3.A: regenerated manifest excludes serious-prospect-research entirely" "fail" "found $BF3_PROSPECT_COUNT entries"
fi

# BF3.B: filter includes all 18 advertised knowledge skills.
BF3_MISSING=""
for s in agent-teams checkpointing chrome-integration fast-mode headless-mode hooks \
         keybindings mcp-integration output-styles permissions plan-mode plugins \
         remote-control scheduled-tasks skills-and-commands status-line subagents worktrees; do
  if ! python3 -c "import json,sys; d=json.load(open('$BF3_TMPMANI')); k='.claude/skills/$s/SKILL.md'; sys.exit(0 if k in d['files'] else 1)"; then
    BF3_MISSING="$BF3_MISSING $s"
  fi
done
if [ -z "$BF3_MISSING" ]; then
  assert "BF3.B: all 18 knowledge skills present in manifest" "pass"
else
  assert "BF3.B: all 18 knowledge skills present in manifest" "fail" "missing:$BF3_MISSING"
fi

# BF3.C: total SKILL.md entries = 31 (13 public serious-* + 18 knowledge).
BF3_SKILLMD_COUNT=$(python3 -c "import json; d=json.load(open('$BF3_TMPMANI')); print(len([k for k in d['files'] if k.endswith('SKILL.md')]))")
if [ "$BF3_SKILLMD_COUNT" -eq 31 ]; then
  assert "BF3.C: regenerated manifest has exactly 31 SKILL.md entries (13 + 18)" "pass"
else
  assert "BF3.C: regenerated manifest has exactly 31 SKILL.md entries (13 + 18)" "fail" "got $BF3_SKILLMD_COUNT"
fi

# BF3.D: filter excludes skill-shaped directories without a SKILL.md (silent skip).
BF3_FAKE_REPO=$(mktemp -d)
cp -R "$REPO_ROOT/.claude" "$BF3_FAKE_REPO/.claude"
mkdir -p "$BF3_FAKE_REPO/.claude/skills/fake-skill-no-md"
echo "// not a skill — has no SKILL.md" > "$BF3_FAKE_REPO/.claude/skills/fake-skill-no-md/random.txt"
( cd "$BF3_FAKE_REPO" && git init -q && git config user.email "t@t" && git config user.name "t" && git add -A && git commit -q -m "init" )
BF3_FAKE_MANI=$(mktemp -t bf3fakemanifest.XXXXXX)
MANIFEST_PATH="$BF3_FAKE_MANI" bash "$REPO_ROOT/bin/generate-manifest.sh" "$BF3_FAKE_REPO" >/dev/null 2>&1
BF3_FAKE_COUNT=$(python3 -c "import json; d=json.load(open('$BF3_FAKE_MANI')); print(len([k for k in d['files'] if 'fake-skill-no-md' in k]))")
if [ "$BF3_FAKE_COUNT" -eq 0 ]; then
  assert "BF3.D: filter excludes skill dirs without SKILL.md" "pass"
else
  assert "BF3.D: filter excludes skill dirs without SKILL.md" "fail" "got $BF3_FAKE_COUNT entries"
fi
rm -rf "$BF3_FAKE_REPO" "$BF3_FAKE_MANI"

# BF3.E: _shared is still routed through section 1b.
BF3_SHARED_COUNT=$(python3 -c "import json; d=json.load(open('$BF3_TMPMANI')); print(len([k for k in d['files'] if '_shared/' in k]))")
if [ "$BF3_SHARED_COUNT" -gt 0 ]; then
  assert "BF3.E: _shared still routed through section 1b" "pass"
else
  assert "BF3.E: _shared still routed through section 1b" "fail" "got $BF3_SHARED_COUNT _shared entries"
fi

# BF3.F: scope-lock anti-creep — no `distribute:` frontmatter was added.
BF3_DIST_FRONTMATTER=$( { grep -rl '^distribute:' "$REPO_ROOT/.claude/skills/" 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$BF3_DIST_FRONTMATTER" -eq 0 ]; then
  assert "BF3.F: no per-skill distribute frontmatter added (scope-lock honored)" "pass"
else
  assert "BF3.F: no per-skill distribute frontmatter added (scope-lock honored)" "fail" "found $BF3_DIST_FRONTMATTER files"
fi

# BF3.G: no .distribution-banlist file created (scope-lock).
if [ ! -f "$REPO_ROOT/.distribution-banlist" ]; then
  assert "BF3.G: no .distribution-banlist file created (scope-lock honored)" "pass"
else
  assert "BF3.G: no .distribution-banlist file created (scope-lock honored)" "fail"
fi

rm -f "$BF3_TMPMANI"

echo ""
echo "=== Generate Manifest Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
