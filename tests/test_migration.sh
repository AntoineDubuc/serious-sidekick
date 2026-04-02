#!/bin/bash
# test_migration.sh — Tests for serious-update migration mode
#
# Verifies first-run detection: when .serious-sidekick-state.json is missing,
# serious-update hashes existing files and builds an initial state file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

# ---------------------------------------------------------------
# Helper: Create a simulated sidekick home with a bare remote
# Sets SETUP_HOME and SETUP_REMOTE
# ---------------------------------------------------------------
setup_sidekick_home() {
  local base_dir="$1"
  local home_dir="$base_dir/home"
  local remote_dir="$base_dir/remote.git"

  mkdir -p "$home_dir"
  cd "$home_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  # Copy real files from the template repo
  cp "$REPO_ROOT/manifest.json" "$home_dir/manifest.json"
  mkdir -p "$home_dir/lib"
  cp "$REPO_ROOT/lib/serious-common.sh" "$home_dir/lib/serious-common.sh"
  mkdir -p "$home_dir/bin"
  cp "$REPO_ROOT/bin/serious-update" "$home_dir/bin/serious-update"
  chmod +x "$home_dir/bin/serious-update"

  # Copy .claude directory
  if [ -d "$REPO_ROOT/.claude" ]; then
    cp -R "$REPO_ROOT/.claude" "$home_dir/.claude"
  fi

  # Copy root-level template files
  for f in CLAUDE.md _anti-rationalization-core.md _implementation_plan_template_v6.md; do
    [ -f "$REPO_ROOT/$f" ] && cp "$REPO_ROOT/$f" "$home_dir/$f"
  done

  git add -A
  git commit -q -m "Initial commit"

  # Create bare remote
  git clone -q --bare "$home_dir" "$remote_dir"
  git -C "$home_dir" remote add origin "$remote_dir" 2>/dev/null || \
    git -C "$home_dir" remote set-url origin "$remote_dir"
  git -C "$home_dir" fetch -q origin 2>/dev/null || true
  git -C "$home_dir" branch --set-upstream-to=origin/main main 2>/dev/null || \
    git -C "$home_dir" branch --set-upstream-to=origin/master master 2>/dev/null || true

  cd "$REPO_ROOT"

  SETUP_HOME="$home_dir"
  SETUP_REMOTE="$remote_dir"
}

add_remote_commit() {
  local home_dir="$1"
  local remote_dir="$2"
  local msg="${3:-Update}"

  local tmp_clone="$TMP_DIR/tmp_clone_$$_$RANDOM"
  git clone -q "$remote_dir" "$tmp_clone"
  cd "$tmp_clone"
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "# $msg $(date +%s)" >> "_anti-rationalization-core.md"
  git add -A
  git commit -q -m "$msg"
  git push -q origin 2>/dev/null
  cd "$REPO_ROOT"
  rm -rf "$tmp_clone"
}

setup_target_dirs() {
  local base="$1"
  mkdir -p "$base/claude" "$base/claude-work" "$base/claude-alex"
  echo "$base/claude $base/claude-work $base/claude-alex"
}

echo "=== Test: migration mode ==="
echo ""

# ===============================================================
# Test 1: First run with no state file -> state file created
# ===============================================================
echo "--- Test 1: First run creates state file ---"
echo ""

T1_BASE="$TMP_DIR/t1"
setup_sidekick_home "$T1_BASE"
T1_TARGETS="$TMP_DIR/t1_targets"
T1_DIRS=$(setup_target_dirs "$T1_TARGETS")
T1_FIRST=$(echo "$T1_DIRS" | awk '{print $1}')

# Pre-install some files that match manifest entries (simulate existing installation)
# Copy a template-owned file
mkdir -p "$T1_FIRST/skills/serious-code"
cp "$REPO_ROOT/.claude/skills/serious-code/SKILL.md" "$T1_FIRST/skills/serious-code/SKILL.md"

# Copy another template-owned file
mkdir -p "$T1_FIRST/agents"
cp "$REPO_ROOT/.claude/agents/serious-code-implementer.md" "$T1_FIRST/agents/serious-code-implementer.md"

# Verify no state file exists before update
if [ ! -f "$T1_FIRST/.serious-sidekick-state.json" ]; then
  assert "Pre-condition: no state file before first run" "pass"
else
  assert "Pre-condition: no state file before first run" "fail"
fi

# Push a change so git pull finds something
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Migration test"

T1_EXIT=0
T1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$T1_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || T1_EXIT=$?

# AC: State file created
if [ -f "$T1_FIRST/.serious-sidekick-state.json" ]; then
  assert "First run: state file created" "pass"
else
  assert "First run: state file created" "fail" "output: $(echo "$T1_OUTPUT" | head -5)"
fi

# AC: State file is valid JSON
if python3 -c "import json; json.load(open('$T1_FIRST/.serious-sidekick-state.json'))" 2>/dev/null; then
  assert "First run: state file is valid JSON" "pass"
else
  assert "First run: state file is valid JSON" "fail"
fi

# AC: Migration message printed
if echo "$T1_OUTPUT" | grep -q "First run detected"; then
  assert "First run: prints migration message" "pass"
else
  assert "First run: prints migration message" "fail" "output: $(echo "$T1_OUTPUT" | head -10)"
fi

echo ""

# ===============================================================
# Test 2: State file contains hashes of existing files
# ===============================================================
echo "--- Test 2: State file contains file hashes ---"
echo ""

# The state file should have file_hashes with entries
if [ -f "$T1_FIRST/.serious-sidekick-state.json" ]; then
  HASH_COUNT=$(python3 -c "
import json
data = json.load(open('$T1_FIRST/.serious-sidekick-state.json'))
hashes = data.get('file_hashes', {})
print(len(hashes))
" 2>/dev/null || echo "0")

  # After migration + distribution, there should be hashes for installed files
  if [ "$HASH_COUNT" -gt 0 ]; then
    assert "State file: contains file hashes ($HASH_COUNT files)" "pass"
  else
    assert "State file: contains file hashes" "fail" "hash_count=$HASH_COUNT"
  fi

  # Check that installed_from_commit is set
  INSTALLED_COMMIT=$(python3 -c "
import json
data = json.load(open('$T1_FIRST/.serious-sidekick-state.json'))
print(data.get('installed_from_commit', ''))
" 2>/dev/null || echo "")

  if [ -n "$INSTALLED_COMMIT" ]; then
    assert "State file: has installed_from_commit" "pass"
  else
    assert "State file: has installed_from_commit" "fail"
  fi

  # Check installed_at is set
  INSTALLED_AT=$(python3 -c "
import json
data = json.load(open('$T1_FIRST/.serious-sidekick-state.json'))
print(data.get('installed_at', ''))
" 2>/dev/null || echo "")

  if [ -n "$INSTALLED_AT" ]; then
    assert "State file: has installed_at timestamp" "pass"
  else
    assert "State file: has installed_at timestamp" "fail"
  fi
else
  assert "State file: exists (required for hash check)" "fail"
  assert "State file: has installed_from_commit" "fail"
  assert "State file: has installed_at timestamp" "fail"
fi

echo ""

# ===============================================================
# Test 3: Second run (state exists) -> no migration message
# ===============================================================
echo "--- Test 3: Second run skips migration ---"
echo ""

# Push another change so there's something to update
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Second run test"

T3_EXIT=0
T3_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$T1_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || T3_EXIT=$?

# AC: No migration message on second run
if echo "$T3_OUTPUT" | grep -q "First run detected"; then
  assert "Second run: no migration message" "fail" "Still printing migration message"
else
  assert "Second run: no migration message" "pass"
fi

# AC: State file still exists
if [ -f "$T1_FIRST/.serious-sidekick-state.json" ]; then
  assert "Second run: state file persists" "pass"
else
  assert "Second run: state file persists" "fail"
fi

echo ""

# ===============================================================
# Test 4: Migration + diff shows correct counts
# ===============================================================
echo "--- Test 4: Migration with --diff ---"
echo ""

T4_BASE="$TMP_DIR/t4"
setup_sidekick_home "$T4_BASE"
T4_TARGETS="$TMP_DIR/t4_targets"
T4_DIRS=$(setup_target_dirs "$T4_TARGETS")
T4_FIRST=$(echo "$T4_DIRS" | awk '{print $1}')

# Pre-install one file that matches a manifest entry
mkdir -p "$T4_FIRST/skills/serious-code"
cp "$REPO_ROOT/.claude/skills/serious-code/SKILL.md" "$T4_FIRST/skills/serious-code/SKILL.md"

# Push a change
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Diff migration test"

T4_EXIT=0
T4_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$T4_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" --diff 2>&1) || T4_EXIT=$?

# AC: --diff shows categorized output
if echo "$T4_OUTPUT" | grep -qE "OVERWRITE|NEW|CURRENT|MERGE|SKIP"; then
  assert "Migration+diff: shows file categorization" "pass"
else
  assert "Migration+diff: shows file categorization" "fail" "output: $(echo "$T4_OUTPUT" | head -10)"
fi

# AC: --diff exits 0
if [ "$T4_EXIT" -eq 0 ]; then
  assert "Migration+diff: exits 0" "pass"
else
  assert "Migration+diff: exits 0" "fail" "exit=$T4_EXIT"
fi

# AC: Dry run complete message
if echo "$T4_OUTPUT" | grep -q "Dry run complete"; then
  assert "Migration+diff: prints dry run complete" "pass"
else
  assert "Migration+diff: prints dry run complete" "fail"
fi

echo ""

# ===============================================================
# Test 5: Migration with empty target dir (no existing files)
# ===============================================================
echo "--- Test 5: Migration with empty target dir ---"
echo ""

T5_BASE="$TMP_DIR/t5"
setup_sidekick_home "$T5_BASE"
T5_TARGETS="$TMP_DIR/t5_targets"
T5_DIRS=$(setup_target_dirs "$T5_TARGETS")
T5_FIRST=$(echo "$T5_DIRS" | awk '{print $1}')

# Don't pre-install any files — target dirs are empty

add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Empty target migration"

T5_EXIT=0
T5_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$T5_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || T5_EXIT=$?

# AC: Migration message with 0 existing files
if echo "$T5_OUTPUT" | grep -q "First run detected"; then
  assert "Empty migration: prints first run message" "pass"
else
  assert "Empty migration: prints first run message" "fail" "output: $(echo "$T5_OUTPUT" | head -5)"
fi

# AC: State file created even with 0 existing files
if [ -f "$T5_FIRST/.serious-sidekick-state.json" ]; then
  assert "Empty migration: state file created" "pass"
else
  assert "Empty migration: state file created" "fail"
fi

echo ""
echo "=== migration Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
