#!/bin/bash
# test_serious_update.sh — Tests for bin/serious-update
#
# Creates temp directories simulating ~/.serious-sidekick/ and target dirs.
# Uses SERIOUS_SIDEKICK_HOME and SERIOUS_TARGET_DIRS env var overrides.
# Git repos are set up with bare remotes so git pull/fetch work.
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
# Returns: sets SETUP_HOME and SETUP_REMOTE global vars
# ---------------------------------------------------------------
setup_sidekick_home() {
  local base_dir="$1"
  local home_dir="$base_dir/home"
  local remote_dir="$base_dir/remote.git"

  # Create the initial repo
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

  # Create a bare remote and push to it
  git clone -q --bare "$home_dir" "$remote_dir"
  git -C "$home_dir" remote add origin "$remote_dir" 2>/dev/null || \
    git -C "$home_dir" remote set-url origin "$remote_dir"
  git -C "$home_dir" fetch -q origin 2>/dev/null || true
  git -C "$home_dir" branch --set-upstream-to=origin/main main 2>/dev/null || \
    git -C "$home_dir" branch --set-upstream-to=origin/master master 2>/dev/null || true

  cd "$REPO_ROOT"

  # Export for caller
  SETUP_HOME="$home_dir"
  SETUP_REMOTE="$remote_dir"
}

# Add a commit to the remote (simulates upstream changes)
add_remote_commit() {
  local home_dir="$1"
  local remote_dir="$2"
  local msg="${3:-Update}"

  # Clone remote, make changes, push back
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

# Make a local commit and push to remote
make_local_commit() {
  local home_dir="$1"
  local msg="${2:-Local update}"
  cd "$home_dir"
  echo "# $msg $(date +%s)" >> "_anti-rationalization-core.md"
  git add -A
  git commit -q -m "$msg"
  git push -q origin 2>/dev/null || true
  cd "$REPO_ROOT"
}

setup_target_dirs() {
  local base="$1"
  mkdir -p "$base/claude" "$base/claude-work" "$base/claude-alex"
  echo "$base/claude $base/claude-work $base/claude-alex"
}

echo "=== Test: serious-update ==="
echo ""

# ===============================================================
# TASK 1: Script skeleton + argument parsing
# ===============================================================
echo "--- Task 1: Script skeleton + argument parsing ---"
echo ""

# AC1.1: bin/serious-update exists and is executable
if [ -x "$REPO_ROOT/bin/serious-update" ]; then
  assert "AC1.1: bin/serious-update exists and is executable" "pass"
else
  assert "AC1.1: bin/serious-update exists and is executable" "fail"
fi

# AC1.2: Script sources lib/serious-common.sh
if grep -q 'source.*lib/serious-common.sh' "$REPO_ROOT/bin/serious-update"; then
  assert "AC1.2: Script sources lib/serious-common.sh" "pass"
else
  assert "AC1.2: Script sources lib/serious-common.sh" "fail"
fi

# AC1.3: --help prints usage and exits 0
# Need a valid SIDEKICK_HOME for the script to load (--help exits before checking)
HELP_EXIT=0
HELP_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$TMP_DIR" bash "$REPO_ROOT/bin/serious-update" --help 2>&1) || HELP_EXIT=$?
if [ "$HELP_EXIT" -eq 0 ] && echo "$HELP_OUTPUT" | grep -q "Usage"; then
  assert "AC1.3: --help prints usage and exits 0" "pass"
else
  assert "AC1.3: --help prints usage and exits 0" "fail" "exit=$HELP_EXIT"
fi

# NT1.1: Unknown flag exits 1
UNKNOWN_EXIT=0
UNKNOWN_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$TMP_DIR" bash "$REPO_ROOT/bin/serious-update" --invalid-flag 2>&1) || UNKNOWN_EXIT=$?
if [ "$UNKNOWN_EXIT" -ne 0 ]; then
  assert "NT1.1: Unknown flag exits non-zero" "pass"
else
  assert "NT1.1: Unknown flag exits non-zero" "fail" "exit=$UNKNOWN_EXIT"
fi

# NT1.2: Missing SIDEKICK_HOME exits non-zero
MISSING_EXIT=0
MISSING_OUTPUT=$(SERIOUS_SIDEKICK_HOME="/tmp/nonexistent_serious_sidekick_$$_$RANDOM" bash "$REPO_ROOT/bin/serious-update" 2>&1) || MISSING_EXIT=$?
if [ "$MISSING_EXIT" -ne 0 ]; then
  assert "NT1.2: Missing SIDEKICK_HOME exits non-zero" "pass"
else
  assert "NT1.2: Missing SIDEKICK_HOME exits non-zero" "fail" "exit=$MISSING_EXIT"
fi

# AC1.11: Exit code 2 for nothing to update
TASK1_BASE="$TMP_DIR/task1"
setup_sidekick_home "$TASK1_BASE"
TASK1_TARGETS="$TMP_DIR/task1_targets"
TASK1_DIRS=$(setup_target_dirs "$TASK1_TARGETS")

# Seed state files in target dirs so NEEDS_FIRST_RUN=false
# (without state files, first-run detection bypasses the exit-2 "nothing to update" check)
for d in $TASK1_DIRS; do
  echo '{"installed_from_commit":"dummy","previous_commit":"","installed_at":"2026-04-02T00:00:00Z","file_hashes":{}}' > "$d/.serious-sidekick-state.json"
done

# Pull when already at HEAD = nothing to update → exit 2
EXIT2_CODE=0
EXIT2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK1_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || EXIT2_CODE=$?
if [ "$EXIT2_CODE" -eq 2 ]; then
  assert "AC1.11: Exit code 2 for nothing to update" "pass"
else
  assert "AC1.11: Exit code 2 for nothing to update" "fail" "exit=$EXIT2_CODE"
fi

echo ""

# ===============================================================
# TASK 2: Git pull + manifest reading
# ===============================================================
echo "--- Task 2: Git pull + manifest reading ---"
echo ""

# AC2.5: Corrupt manifest should fail
TASK2_BASE="$TMP_DIR/task2"
setup_sidekick_home "$TASK2_BASE"

# Corrupt the manifest in the local clone (push to remote first)
echo '{corrupt' > "$SETUP_HOME/manifest.json"
cd "$SETUP_HOME" && git add -A && git commit -q -m "corrupt manifest" && git push -q origin 2>/dev/null && cd "$REPO_ROOT"

# Add another commit to remote so pull has something to do
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "post-corrupt"

CORRUPT_EXIT=0
CORRUPT_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/nowhere1 $TMP_DIR/nowhere2 $TMP_DIR/nowhere3" bash "$REPO_ROOT/bin/serious-update" 2>&1) || CORRUPT_EXIT=$?
if [ "$CORRUPT_EXIT" -eq 1 ]; then
  assert "AC2.5: Corrupt manifest.json exits 1" "pass"
else
  assert "AC2.5: Corrupt manifest.json exits 1" "fail" "exit=$CORRUPT_EXIT"
fi

# NT2.1: Missing manifest.json
TASK2B_BASE="$TMP_DIR/task2b"
setup_sidekick_home "$TASK2B_BASE"

rm -f "$SETUP_HOME/manifest.json"
cd "$SETUP_HOME" && git add -A && git commit -q -m "remove manifest" && git push -q origin 2>/dev/null && cd "$REPO_ROOT"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "post-remove"

NOMANI_EXIT=0
NOMANI_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/nowhere4 $TMP_DIR/nowhere5 $TMP_DIR/nowhere6" bash "$REPO_ROOT/bin/serious-update" 2>&1) || NOMANI_EXIT=$?
if [ "$NOMANI_EXIT" -eq 1 ]; then
  assert "NT2.1: Missing manifest.json exits 1" "pass"
else
  assert "NT2.1: Missing manifest.json exits 1" "fail" "exit=$NOMANI_EXIT"
fi

echo ""

# ===============================================================
# TASK 3: File distribution engine
# ===============================================================
echo "--- Task 3: File distribution engine ---"
echo ""

TASK3_BASE="$TMP_DIR/task3"
setup_sidekick_home "$TASK3_BASE"

TASK3_TARGETS="$TMP_DIR/task3_targets"
TASK3_DIRS=$(setup_target_dirs "$TASK3_TARGETS")
TASK3_FIRST=$(echo "$TASK3_DIRS" | awk '{print $1}')

# Push a change to remote so pull has something to update
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Distribution test update"

DIST_EXIT=0
DIST_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK3_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || DIST_EXIT=$?

# AC3.1: Template-owned files are copied
if [ -f "$TASK3_FIRST/skills/serious-code/SKILL.md" ]; then
  assert "AC3.1: Template-owned files copied to target dir" "pass"
else
  assert "AC3.1: Template-owned files copied to target dir" "fail" \
    "Missing: $TASK3_FIRST/skills/serious-code/SKILL.md"
fi

# AC3.2: Merge-owned files (settings.json) SKIPPED for global dirs
# Hooks use $CLAUDE_PROJECT_DIR paths — only valid in projects with /serious-init
if [ ! -f "$TASK3_FIRST/settings.json" ]; then
  assert "AC3.2: Merge-owned file (settings.json) skipped for global dir" "pass"
else
  assert "AC3.2: Merge-owned file (settings.json) skipped for global dir" "fail" \
    "settings.json should NOT be distributed to global dirs"
fi

# AC3.3: User-init files copied on first install
if [ -f "$TASK3_FIRST/CLAUDE.md" ]; then
  assert "AC3.3: User-init file (CLAUDE.md) copied on first install" "pass"
else
  assert "AC3.3: User-init file (CLAUDE.md) copied on first install" "fail"
fi

# AC3.7: State file written
if [ -f "$TASK3_FIRST/.serious-sidekick-state.json" ]; then
  assert "AC3.7: State file written after distribution" "pass"
else
  assert "AC3.7: State file written after distribution" "fail"
fi

# State file valid JSON
if python3 -c "import json; json.load(open('$TASK3_FIRST/.serious-sidekick-state.json'))" 2>/dev/null; then
  assert "AC3.7: State file is valid JSON" "pass"
else
  assert "AC3.7: State file is valid JSON" "fail"
fi

# AC3.9: All 3 target dirs got state files
ALL_DIRS_OK=true
for dir in $TASK3_DIRS; do
  if [ ! -f "$dir/.serious-sidekick-state.json" ]; then
    ALL_DIRS_OK=false
    break
  fi
done
if $ALL_DIRS_OK; then
  assert "AC3.9: All 3 target dirs have state files" "pass"
else
  assert "AC3.9: All 3 target dirs have state files" "fail"
fi

# AC3.10: Whitelist invariant — place a user file and verify it survives update
USER_CUSTOM="$TASK3_FIRST/my_custom_plugin.md"
echo "# Custom plugin — must survive updates" > "$USER_CUSTOM"
USER_HASH_BEFORE=$(shasum -a 256 "$USER_CUSTOM" | awk '{print $1}')

# Push another change and update again
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Second distribution test"
DIST2_EXIT=0
DIST2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK3_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || DIST2_EXIT=$?

USER_HASH_AFTER=$(shasum -a 256 "$USER_CUSTOM" | awk '{print $1}')
if [ "$USER_HASH_BEFORE" = "$USER_HASH_AFTER" ]; then
  assert "AC3.10: Whitelist invariant — user file untouched after update" "pass"
else
  assert "AC3.10: Whitelist invariant — user file untouched after update" "fail"
fi

# AC3.3: User-init files skipped after first install
echo "# User's custom CLAUDE.md content" > "$TASK3_FIRST/CLAUDE.md"
CLAUDE_HASH_BEFORE=$(shasum -a 256 "$TASK3_FIRST/CLAUDE.md" | awk '{print $1}')

add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Third distribution test"
DIST3_EXIT=0
DIST3_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK3_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || DIST3_EXIT=$?

CLAUDE_HASH_AFTER=$(shasum -a 256 "$TASK3_FIRST/CLAUDE.md" | awk '{print $1}')
if [ "$CLAUDE_HASH_BEFORE" = "$CLAUDE_HASH_AFTER" ]; then
  assert "AC3.3: User-init file (CLAUDE.md) skipped on subsequent update" "pass"
else
  assert "AC3.3: User-init file (CLAUDE.md) skipped on subsequent update" "fail"
fi

echo ""

# ===============================================================
# TASK 4: --check flag
# ===============================================================
echo "--- Task 4: --check flag ---"
echo ""

TASK4_BASE="$TMP_DIR/task4"
setup_sidekick_home "$TASK4_BASE"

# --check needs a remote to fetch from (already set up by setup_sidekick_home)
CHECK_EXIT=0
CHECK_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" --check 2>&1) || CHECK_EXIT=$?

# AC4.3: staleness.json written
if [ -f "$SETUP_HOME/staleness.json" ]; then
  assert "AC4.3: staleness.json written" "pass"
else
  assert "AC4.3: staleness.json written" "fail"
fi

# AC4.4: staleness.json has required fields
if [ -f "$SETUP_HOME/staleness.json" ]; then
  SCHEMA_OK=$(python3 -c "
import json
data = json.load(open('$SETUP_HOME/staleness.json'))
required = ['checked_at', 'local_commit', 'remote_commit', 'stale_count', 'summary']
missing = [k for k in required if k not in data]
if missing:
    print('MISSING: ' + ', '.join(missing))
else:
    print('OK')
")
  if [ "$SCHEMA_OK" = "OK" ]; then
    assert "AC4.4: staleness.json has all required fields" "pass"
  else
    assert "AC4.4: staleness.json has all required fields" "fail" "$SCHEMA_OK"
  fi
fi

# AC4.5: --check exits 0
if [ "$CHECK_EXIT" -eq 0 ]; then
  assert "AC4.5: --check exits 0" "pass"
else
  assert "AC4.5: --check exits 0" "fail" "exit=$CHECK_EXIT"
fi

# AC4.6: Audit log CHECK entry
if [ -f "$SETUP_HOME/update.log" ] && grep -q "CHECK" "$SETUP_HOME/update.log"; then
  assert "AC4.6: Audit log has CHECK entry" "pass"
else
  assert "AC4.6: Audit log has CHECK entry" "fail"
fi

echo ""

# ===============================================================
# TASK 5: --diff flag
# ===============================================================
echo "--- Task 5: --diff flag ---"
echo ""

TASK5_BASE="$TMP_DIR/task5"
setup_sidekick_home "$TASK5_BASE"

TASK5_TARGETS="$TMP_DIR/task5_targets"
TASK5_DIRS=$(setup_target_dirs "$TASK5_TARGETS")
TASK5_FIRST=$(echo "$TASK5_DIRS" | awk '{print $1}')

# Push a change so there's something to diff
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Diff test commit"

DIFF_EXIT=0
DIFF_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK5_DIRS" bash "$REPO_ROOT/bin/serious-update" --diff 2>&1) || DIFF_EXIT=$?

# AC5.1: --diff shows files
if echo "$DIFF_OUTPUT" | grep -qE "OVERWRITE|NEW|MERGE|SKIP|CURRENT"; then
  assert "AC5.1: --diff shows file categorization" "pass"
else
  assert "AC5.1: --diff shows file categorization" "fail" "Output: $(echo "$DIFF_OUTPUT" | head -5)"
fi

# AC5.2: --diff does NOT write files
DIFF_FILE_COUNT=$(find "$TASK5_FIRST" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIFF_FILE_COUNT" -eq 0 ]; then
  assert "AC5.2: --diff does NOT write files" "pass"
else
  assert "AC5.2: --diff does NOT write files" "fail" "Found $DIFF_FILE_COUNT files"
fi

# AC5.3: --diff does NOT write state files
if [ ! -f "$TASK5_FIRST/.serious-sidekick-state.json" ]; then
  assert "AC5.3: --diff does NOT write state files" "pass"
else
  assert "AC5.3: --diff does NOT write state files" "fail"
fi

# AC5.5: Output categorizes by ownership
if echo "$DIFF_OUTPUT" | grep -q "NEW"; then
  assert "AC5.5: --diff output shows NEW category" "pass"
else
  assert "AC5.5: --diff output shows NEW category" "fail"
fi

echo ""

# ===============================================================
# TASK 6: --rollback flag
# ===============================================================
echo "--- Task 6: --rollback flag ---"
echo ""

TASK6_BASE="$TMP_DIR/task6"
setup_sidekick_home "$TASK6_BASE"

TASK6_TARGETS="$TMP_DIR/task6_targets"
TASK6_DIRS=$(setup_target_dirs "$TASK6_TARGETS")
TASK6_FIRST=$(echo "$TASK6_DIRS" | awk '{print $1}')

# First update (creates initial state)
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "v1 commit"
V1_EXIT=0
V1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK6_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || V1_EXIT=$?
V1_COMMIT=$(git -C "$SETUP_HOME" rev-parse HEAD)

# Second update
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "v2 commit"
V2_EXIT=0
V2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK6_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || V2_EXIT=$?
V2_COMMIT=$(git -C "$SETUP_HOME" rev-parse HEAD)

# Verify state file has previous_commit set
if [ -f "$TASK6_FIRST/.serious-sidekick-state.json" ]; then
  STATE_PREV=$(python3 -c "
import json
data = json.load(open('$TASK6_FIRST/.serious-sidekick-state.json'))
print(data.get('previous_commit', ''))
")
  if [ "$STATE_PREV" = "$V1_COMMIT" ]; then
    assert "Pre-rollback: state has correct previous_commit" "pass"
  else
    assert "Pre-rollback: state has correct previous_commit" "fail" \
      "expected=$V1_COMMIT got=$STATE_PREV"
  fi
else
  assert "Pre-rollback: state file exists" "fail" "No state file found"
fi

# Now rollback
ROLLBACK_EXIT=0
ROLLBACK_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK6_DIRS" bash "$REPO_ROOT/bin/serious-update" --rollback 2>&1) || ROLLBACK_EXIT=$?

# AC6.2 + AC6.3: Rollback should succeed
if [ "$ROLLBACK_EXIT" -eq 0 ]; then
  assert "AC6.2+AC6.3: --rollback succeeds" "pass"
else
  assert "AC6.2+AC6.3: --rollback succeeds" "fail" "exit=$ROLLBACK_EXIT output=$(echo "$ROLLBACK_OUTPUT" | head -3)"
fi

# AC6.4: After rollback, installed = V1, previous = V2
if [ -f "$TASK6_FIRST/.serious-sidekick-state.json" ]; then
  POST_INSTALLED=$(python3 -c "
import json
data = json.load(open('$TASK6_FIRST/.serious-sidekick-state.json'))
print(data.get('installed_from_commit', ''))
")
  POST_PREVIOUS=$(python3 -c "
import json
data = json.load(open('$TASK6_FIRST/.serious-sidekick-state.json'))
print(data.get('previous_commit', ''))
")

  if [ "$POST_INSTALLED" = "$V1_COMMIT" ]; then
    assert "AC6.4: After rollback, installed = v1 commit" "pass"
  else
    assert "AC6.4: After rollback, installed = v1 commit" "fail" \
      "expected=$V1_COMMIT got=$POST_INSTALLED"
  fi

  if [ "$POST_PREVIOUS" = "$V2_COMMIT" ]; then
    assert "AC6.4: After rollback, previous = v2 commit" "pass"
  else
    assert "AC6.4: After rollback, previous = v2 commit" "fail" \
      "expected=$V2_COMMIT got=$POST_PREVIOUS"
  fi
fi

# NT6.1: No state file → exit 1
TASK6_NOSTATE="$TMP_DIR/task6_nostate"
setup_target_dirs "$TASK6_NOSTATE" >/dev/null
NOSTATE_EXIT=0
NOSTATE_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK6_NOSTATE/claude $TASK6_NOSTATE/claude-work $TASK6_NOSTATE/claude-alex" bash "$REPO_ROOT/bin/serious-update" --rollback 2>&1) || NOSTATE_EXIT=$?
if [ "$NOSTATE_EXIT" -eq 1 ]; then
  assert "NT6.1: No state file → exit 1" "pass"
else
  assert "NT6.1: No state file → exit 1" "fail" "exit=$NOSTATE_EXIT"
fi

echo ""

# ===============================================================
# TASK 7: Audit log + completion receipt
# ===============================================================
echo "--- Task 7: Audit log + completion receipt ---"
echo ""

TASK7_BASE="$TMP_DIR/task7"
setup_sidekick_home "$TASK7_BASE"

TASK7_TARGETS="$TMP_DIR/task7_targets"
TASK7_DIRS=$(setup_target_dirs "$TASK7_TARGETS")

# Push a change
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Audit test commit"

AUDIT_EXIT=0
AUDIT_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK7_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || AUDIT_EXIT=$?

# AC7.1: Audit log exists
if [ -f "$SETUP_HOME/update.log" ]; then
  assert "AC7.1: Audit log written" "pass"
else
  assert "AC7.1: Audit log written" "fail"
fi

# AC7.3: UPDATE entry format
if [ -f "$SETUP_HOME/update.log" ] && grep -q "UPDATE" "$SETUP_HOME/update.log"; then
  UPDATE_LINE=$(grep "UPDATE" "$SETUP_HOME/update.log" | head -1)
  if echo "$UPDATE_LINE" | grep -qE 'UPDATE .+->.+ files=[0-9]+ new=[0-9]+ dirs=[0-9]+/[0-9]+ OK'; then
    assert "AC7.3: UPDATE entry has correct format" "pass"
  else
    assert "AC7.3: UPDATE entry has correct format" "fail" "Got: $UPDATE_LINE"
  fi
else
  assert "AC7.3: UPDATE entry exists" "fail"
fi

# AC7.5: Receipt prints commit SHA
if echo "$AUDIT_OUTPUT" | grep -q "Serious Sidekick updated to"; then
  assert "AC7.5: Receipt shows commit SHA change" "pass"
else
  assert "AC7.5: Receipt shows commit SHA change" "fail"
fi

# AC7.7: Receipt shows audit log path
if echo "$AUDIT_OUTPUT" | grep -q "Audit log:"; then
  assert "AC7.7: Receipt shows audit log path" "pass"
else
  assert "AC7.7: Receipt shows audit log path" "fail"
fi

# AC7.2: Append-only (run another update and verify 2+ entries)
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Second audit test"
AUDIT2_EXIT=0
AUDIT2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK7_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || AUDIT2_EXIT=$?

LOG_LINES=$(wc -l < "$SETUP_HOME/update.log" | tr -d ' ')
if [ "$LOG_LINES" -ge 2 ]; then
  assert "AC7.2: Audit log is append-only (multiple entries)" "pass"
else
  assert "AC7.2: Audit log is append-only" "fail" "Only $LOG_LINES lines"
fi

echo ""

# ===============================================================
# TASK 8: --no-global flag
# ===============================================================
echo "--- Task 8: --no-global flag ---"
echo ""

TASK8_BASE="$TMP_DIR/task8"
setup_sidekick_home "$TASK8_BASE"

TASK8_TARGETS="$TMP_DIR/task8_targets"
TASK8_DIRS=$(setup_target_dirs "$TASK8_TARGETS")
TASK8_FIRST=$(echo "$TASK8_DIRS" | awk '{print $1}')

add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "No-global test"

NOGLOBAL_EXIT=0
NOGLOBAL_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TASK8_DIRS" bash "$REPO_ROOT/bin/serious-update" --no-global 2>&1) || NOGLOBAL_EXIT=$?

# AC8.5: --no-global skips global dirs (no files written to targets)
NOGLOBAL_FILES=$(find "$TASK8_FIRST" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$NOGLOBAL_FILES" -eq 0 ]; then
  assert "AC8.5: --no-global skips global dirs (no files written)" "pass"
else
  assert "AC8.5: --no-global skips global dirs" "fail" "Found $NOGLOBAL_FILES files"
fi

echo ""
echo "=== serious-update Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
