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
  # bin/generate-manifest.sh is required for the auto-regen-on-pull path
  # added in install-bug-fixes Task 1 (research.md#Finding-1 part 2 option a).
  cp "$REPO_ROOT/bin/generate-manifest.sh" "$home_dir/bin/generate-manifest.sh"
  chmod +x "$home_dir/bin/generate-manifest.sh"

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

# AC2.5 (REVISED post Task 1 install-bug-fixes): Corrupt manifest is auto-healed
# by regen-on-pull (research.md#Finding-1 part 2 option a). The manifest is
# regenerated from sources after every successful pull, so a corrupt manifest in
# the working tree is replaced with a fresh, valid one.
TASK2_BASE="$TMP_DIR/task2"
setup_sidekick_home "$TASK2_BASE"

# Corrupt the manifest in the local clone (push to remote first)
echo '{corrupt' > "$SETUP_HOME/manifest.json"
cd "$SETUP_HOME" && git add -A && git commit -q -m "corrupt manifest" && git push -q origin 2>/dev/null && cd "$REPO_ROOT"

# Add another commit to remote so pull has something to do
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "post-corrupt"

CORRUPT_EXIT=0
CORRUPT_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/nowhere1 $TMP_DIR/nowhere2 $TMP_DIR/nowhere3" bash "$REPO_ROOT/bin/serious-update" 2>&1) || CORRUPT_EXIT=$?
if [ "$CORRUPT_EXIT" -eq 0 ] && python3 -m json.tool "$SETUP_HOME/manifest.json" >/dev/null 2>&1; then
  assert "AC2.5: Corrupt manifest.json auto-healed by regen-on-pull" "pass"
else
  assert "AC2.5: Corrupt manifest.json auto-healed by regen-on-pull" "fail" "exit=$CORRUPT_EXIT"
fi

# NT2.1 (REVISED post Task 1 install-bug-fixes): Missing manifest is auto-recreated
# by regen-on-pull. Same auto-heal contract as AC2.5.
TASK2B_BASE="$TMP_DIR/task2b"
setup_sidekick_home "$TASK2B_BASE"

rm -f "$SETUP_HOME/manifest.json"
cd "$SETUP_HOME" && git add -A && git commit -q -m "remove manifest" && git push -q origin 2>/dev/null && cd "$REPO_ROOT"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "post-remove"

NOMANI_EXIT=0
NOMANI_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/nowhere4 $TMP_DIR/nowhere5 $TMP_DIR/nowhere6" bash "$REPO_ROOT/bin/serious-update" 2>&1) || NOMANI_EXIT=$?
if [ "$NOMANI_EXIT" -eq 0 ] && [ -f "$SETUP_HOME/manifest.json" ] && python3 -m json.tool "$SETUP_HOME/manifest.json" >/dev/null 2>&1; then
  assert "NT2.1: Missing manifest.json auto-recreated by regen-on-pull" "pass"
else
  assert "NT2.1: Missing manifest.json auto-recreated by regen-on-pull" "fail" "exit=$NOMANI_EXIT"
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

# ===============================================================
# install-bug-fixes Task 1 — new tests for the regen-on-pull pipeline
# ===============================================================
echo "--- install-bug-fixes Task 1: regen-on-pull, dry-run parity, SKIPPED clause ---"
echo ""

# test_dryrun_sha256_parity — --diff shows SKIP for files whose source hash
# diverged from the manifest, matching the real run's silent-skip behavior.
TASK_BF1A="$TMP_DIR/bf1a"
setup_sidekick_home "$TASK_BF1A"
# Stomp on generate-manifest.sh so regen-on-pull is suppressed (we want to test
# the pre-regen state where the manifest is stale relative to sources).
rm -f "$SETUP_HOME/bin/generate-manifest.sh"
# Edit a SKILL.md so its hash diverges from the in-tree manifest.
echo "" >> "$SETUP_HOME/.claude/skills/serious-code/SKILL.md"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Diverged hash for dry-run parity test"

BF1A_DIRS=$(setup_target_dirs "$TMP_DIR/bf1a_targets")
DRYRUN_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$BF1A_DIRS" bash "$REPO_ROOT/bin/serious-update" --diff 2>&1) || true
if echo "$DRYRUN_OUTPUT" | grep -q "SKIP.*hash mismatch.*would be skipped"; then
  assert "BF1.A: --diff shows SKIP for hash-mismatched files" "pass"
else
  assert "BF1.A: --diff shows SKIP for hash-mismatched files" "fail" "Output did not contain SKIP/hash mismatch line"
fi

# test_dir_report_shows_skipped_clause — when regen can't run AND there are
# mismatches, the per-dir summary line surfaces the skipped count instead of
# silently lying about success.
TASK_BF1B="$TMP_DIR/bf1b"
setup_sidekick_home "$TASK_BF1B"
rm -f "$SETUP_HOME/bin/generate-manifest.sh"
echo "" >> "$SETUP_HOME/.claude/skills/serious-code/SKILL.md"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Diverged hash for SKIPPED clause test"

BF1B_DIRS=$(setup_target_dirs "$TMP_DIR/bf1b_targets")
SKIPPED_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$BF1B_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || true
if echo "$SKIPPED_OUTPUT" | grep -q "SKIPPED (hash mismatch — see stderr)"; then
  assert "BF1.B: per-dir summary shows SKIPPED clause when mismatches occur" "pass"
else
  assert "BF1.B: per-dir summary shows SKIPPED clause when mismatches occur" "fail" "Output: $SKIPPED_OUTPUT"
fi

# test_no_skipped_clause_on_clean_run — when there are zero mismatches (regen
# either healed everything OR all files were already in sync), the SKIPPED
# clause is absent — no clutter on the happy path.
TASK_BF1C="$TMP_DIR/bf1c"
setup_sidekick_home "$TASK_BF1C"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Clean-run check"

BF1C_DIRS=$(setup_target_dirs "$TMP_DIR/bf1c_targets")
CLEAN_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$BF1C_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || true
if ! echo "$CLEAN_OUTPUT" | grep -q "SKIPPED (hash mismatch"; then
  assert "BF1.C: clean run does NOT show SKIPPED clause" "pass"
else
  assert "BF1.C: clean run does NOT show SKIPPED clause" "fail" "Unexpected SKIPPED clause: $CLEAN_OUTPUT"
fi

# test_do_git_pull_handles_regen_failure — stub generate-manifest.sh to exit 1.
# Expect serious-update to exit 1 and stderr to contain "manifest regeneration failed".
TASK_BF1D="$TMP_DIR/bf1d"
setup_sidekick_home "$TASK_BF1D"
# Replace generate-manifest.sh with a stub that exits 1.
cat > "$SETUP_HOME/bin/generate-manifest.sh" << 'STUB'
#!/bin/bash
echo "stub regen failure" >&2
exit 1
STUB
chmod +x "$SETUP_HOME/bin/generate-manifest.sh"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Regen failure test"

BF1D_DIRS=$(setup_target_dirs "$TMP_DIR/bf1d_targets")
REGEN_FAIL_EXIT=0
REGEN_FAIL_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$BF1D_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REGEN_FAIL_EXIT=$?
if [ "$REGEN_FAIL_EXIT" -eq 1 ] && echo "$REGEN_FAIL_OUTPUT" | grep -q "manifest regeneration failed"; then
  assert "BF1.D: do_git_pull exits 1 when regen fails" "pass"
else
  assert "BF1.D: do_git_pull exits 1 when regen fails" "fail" "exit=$REGEN_FAIL_EXIT, output: $REGEN_FAIL_OUTPUT"
fi

# test_do_git_pull_handles_invalid_json — stub generate-manifest.sh to exit 0
# but emit malformed JSON. Expect serious-update to exit 1 and the original
# manifest to remain untouched (no half-installed garbage).
TASK_BF1E="$TMP_DIR/bf1e"
setup_sidekick_home "$TASK_BF1E"
ORIG_MANIFEST_HASH=$(shasum -a 256 "$SETUP_HOME/manifest.json" | awk '{print $1}')
cat > "$SETUP_HOME/bin/generate-manifest.sh" << 'STUB'
#!/bin/bash
# Stub: exits 0 but emits broken JSON to MANIFEST_PATH
echo '{not valid json' > "${MANIFEST_PATH:-/dev/null}"
echo "stub emitted malformed json" >&2
exit 0
STUB
chmod +x "$SETUP_HOME/bin/generate-manifest.sh"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "Invalid JSON test"

BF1E_DIRS=$(setup_target_dirs "$TMP_DIR/bf1e_targets")
INVALID_JSON_EXIT=0
INVALID_JSON_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$BF1E_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || INVALID_JSON_EXIT=$?
POST_MANIFEST_HASH=$(shasum -a 256 "$SETUP_HOME/manifest.json" | awk '{print $1}')
if [ "$INVALID_JSON_EXIT" -eq 1 ] \
   && echo "$INVALID_JSON_OUTPUT" | grep -q "manifest regeneration failed" \
   && [ "$ORIG_MANIFEST_HASH" = "$POST_MANIFEST_HASH" ] \
   && [ ! -f "$SETUP_HOME/manifest.json.new" ]; then
  assert "BF1.E: do_git_pull rejects malformed JSON, leaves original intact" "pass"
else
  assert "BF1.E: do_git_pull rejects malformed JSON, leaves original intact" "fail" \
    "exit=$INVALID_JSON_EXIT orig=$ORIG_MANIFEST_HASH post=$POST_MANIFEST_HASH new_exists=$([ -f $SETUP_HOME/manifest.json.new ] && echo yes || echo no)"
fi

# test_comment_at_line_268_updated — verify the misleading "supply-chain
# hardening" comment was replaced (research.md#Finding-9).
if grep -q "self-consistency check (sources must match the in-tree manifest" "$REPO_ROOT/bin/serious-update"; then
  assert "BF1.F: SHA-256 comment updated to 'self-consistency check'" "pass"
else
  assert "BF1.F: SHA-256 comment updated to 'self-consistency check'" "fail"
fi
if grep -q "supply-chain hardening" "$REPO_ROOT/bin/serious-update"; then
  assert "BF1.G: misleading 'supply-chain hardening' comment removed" "fail"
else
  assert "BF1.G: misleading 'supply-chain hardening' comment removed" "pass"
fi

# Static control-flow checks for the no-regen-on-X paths.
# Use `|| true` to keep set -euo pipefail happy when grep finds no match.
ROLLBACK_LINE=$(grep -n '\[ "\$ROLLBACK" = "true" \]' "$REPO_ROOT/bin/serious-update" | head -1 | cut -d: -f1 || true)
CHECK_LINE=$(grep -n '\[ "\$CHECK_ONLY" = "true" \]' "$REPO_ROOT/bin/serious-update" | head -1 | cut -d: -f1 || true)
PULL_LINE=$(grep -n 'pull_output=\$(do_git_pull)' "$REPO_ROOT/bin/serious-update" | head -1 | cut -d: -f1 || true)
EXIT1_LINE=$(grep -n 'log_audit "ERROR git pull failed"' "$REPO_ROOT/bin/serious-update" | head -1 | cut -d: -f1 || true)
REGEN_LINE=$(grep -n 'MANIFEST_PATH="\$SIDEKICK_HOME/manifest.json.new"' "$REPO_ROOT/bin/serious-update" | head -1 | cut -d: -f1 || true)

# test_rollback_no_regen — --rollback returns BEFORE do_git_pull is called.
if [ -n "$ROLLBACK_LINE" ] && [ -n "$PULL_LINE" ] && [ "$ROLLBACK_LINE" -lt "$PULL_LINE" ]; then
  assert "BF1.H: --rollback returns before do_git_pull (regen never runs)" "pass"
else
  assert "BF1.H: --rollback returns before do_git_pull (regen never runs)" "fail" "rollback_line=$ROLLBACK_LINE pull_line=$PULL_LINE"
fi

# test_check_no_regen — --check returns BEFORE do_git_pull is called.
if [ -n "$CHECK_LINE" ] && [ -n "$PULL_LINE" ] && [ "$CHECK_LINE" -lt "$PULL_LINE" ]; then
  assert "BF1.I: --check returns before do_git_pull (regen never runs)" "pass"
else
  assert "BF1.I: --check returns before do_git_pull (regen never runs)" "fail" "check_line=$CHECK_LINE pull_line=$PULL_LINE"
fi

# test_pull_failure_no_regen — git-pull failure causes do_git_pull to exit 1
# BEFORE the regen block is reached.
if [ -n "$EXIT1_LINE" ] && [ -n "$REGEN_LINE" ] && [ "$EXIT1_LINE" -lt "$REGEN_LINE" ]; then
  assert "BF1.J: pull-failure exits 1 before regen block (regen never runs on pull failure)" "pass"
else
  assert "BF1.J: pull-failure exits 1 before regen block (regen never runs on pull failure)" "fail" "exit1_line=$EXIT1_LINE regen_line=$REGEN_LINE"
fi

echo ""

# ===============================================================
# install-bug-fixes Task 2 — REPO_ROOT fallback for SIDEKICK_HOME
# ===============================================================
echo "--- install-bug-fixes Task 2: REPO_ROOT fallback for SIDEKICK_HOME ---"
echo ""

# BF2.A: line 55 reads exactly the new fallback expression.
if grep -qF 'SIDEKICK_HOME="${SERIOUS_SIDEKICK_HOME:-$REPO_ROOT}"' "$REPO_ROOT/bin/serious-update"; then
  assert "BF2.A: SIDEKICK_HOME defaults to REPO_ROOT (was \$HOME/.serious-sidekick)" "pass"
else
  assert "BF2.A: SIDEKICK_HOME defaults to REPO_ROOT (was \$HOME/.serious-sidekick)" "fail"
fi

# BF2.B: old default text removed.
if grep -q 'SIDEKICK_HOME="\${SERIOUS_SIDEKICK_HOME:-\$HOME/\.serious-sidekick}"' "$REPO_ROOT/bin/serious-update"; then
  assert "BF2.B: old \$HOME/.serious-sidekick fallback removed" "fail" "old fallback still present"
else
  assert "BF2.B: old \$HOME/.serious-sidekick fallback removed" "pass"
fi

# BF2.C: SERIOUS_SIDEKICK_HOME env var still overrides REPO_ROOT (parameter expansion default-or-override semantics).
# We verify this by running the script with an explicit env var pointing to a non-default location and confirming
# it doesn't try to resolve REPO_ROOT instead.
TASK_BF2C="$TMP_DIR/bf2c"
setup_sidekick_home "$TASK_BF2C"
BF2C_DIRS=$(setup_target_dirs "$TMP_DIR/bf2c_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "BF2.C env-override test"
# Use a SECOND sidekick home as the env-var override target. If the env var is honored,
# serious-update will fail because the env-var path doesn't have a manifest. If REPO_ROOT
# silently shadows the env var, the test would pass spuriously.
DUMMY_HOME="$TMP_DIR/bf2c_dummy"
mkdir -p "$DUMMY_HOME"
BF2C_EXIT=0
SERIOUS_SIDEKICK_HOME="$DUMMY_HOME" SERIOUS_TARGET_DIRS="$BF2C_DIRS" bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || BF2C_EXIT=$?
if [ "$BF2C_EXIT" -ne 0 ]; then
  assert "BF2.C: SERIOUS_SIDEKICK_HOME env var overrides REPO_ROOT" "pass"
else
  assert "BF2.C: SERIOUS_SIDEKICK_HOME env var overrides REPO_ROOT" "fail" "expected non-zero exit, got 0"
fi

# BF2.D: when REPO_ROOT resolves to a path that's NOT a directory, the existing
# validation at lines 107-111 still fires. We can't easily simulate "REPO_ROOT
# resolves to non-dir" because the candidate loop verifies lib/serious-common.sh
# exists; instead we verify the validation block exists.
if grep -q 'ERROR: Serious Sidekick home not found' "$REPO_ROOT/bin/serious-update"; then
  assert "BF2.D: SIDEKICK_HOME existence check still present (defends against bad REPO_ROOT)" "pass"
else
  assert "BF2.D: SIDEKICK_HOME existence check still present (defends against bad REPO_ROOT)" "fail"
fi

echo ""

# ===============================================================
# install-bug-fixes Task 4 — reword opaque first-run message
# ===============================================================
echo "--- install-bug-fixes Task 4: first-run message reword ---"
echo ""

# BF4.A: new message text is present.
if grep -q "First run for \$dir: scanned \$migrated_count existing manifest-matched file(s) (preserved). Proceeding with install." "$REPO_ROOT/bin/serious-update"; then
  assert "BF4.A: new first-run message present (scanned + preserved + Proceeding)" "pass"
else
  assert "BF4.A: new first-run message present (scanned + preserved + Proceeding)" "fail"
fi

# BF4.B: old opaque "Built initial state from N existing files" text removed.
if grep -q "Built initial state from" "$REPO_ROOT/bin/serious-update"; then
  assert "BF4.B: old 'Built initial state' message removed" "fail"
else
  assert "BF4.B: old 'Built initial state' message removed" "pass"
fi

# ===============================================================
# DD (Detect-Dirs) section — install-ux-detect-dirs Plan 1
# ===============================================================
# Tests that the TARGET_DIRS default auto-detects existing ~/.claude*
# dirs instead of hardcoding three. Tests that distribute_to_dir skips
# missing dirs with a WARNING instead of silently mkdir -p'ing them.
# Tests dangling-symlink handling and the migration-warning marker file.
echo ""
echo "--- DD: install-ux-detect-dirs (Plan 1) ---"
echo ""

# Helper: run serious-update against an isolated TEST_HOME.
# Returns exit code; captures stdout/stderr to caller-supplied files.
# Args: $1=test_home, $2=stdout_file, $3=stderr_file, $4=optional_env_var_setup
run_dd_update() {
  local test_home="$1"
  local stdout_file="$2"
  local stderr_file="$3"
  local task_base="$4"

  setup_sidekick_home "$task_base"
  add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "DD seed commit"

  local exit_code=0
  HOME="$test_home" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" \
    bash "$REPO_ROOT/bin/serious-update" \
    1>"$stdout_file" 2>"$stderr_file" || exit_code=$?
  return $exit_code
}

# DD.1: test_dd_autodetect_single_profile
# Only ~/.claude/ pre-exists in TEST_HOME. After serious-update:
#   - ~/.claude/ should have files distributed
#   - ~/.claude-work/ should NOT exist
#   - ~/.claude-alex/ should NOT exist
DD_BASE_1="$TMP_DIR/dd_single"
DD_HOME_1="$DD_BASE_1/test-home"
mkdir -p "$DD_HOME_1/.claude"
DD_EXIT_1=0
run_dd_update "$DD_HOME_1" "$DD_BASE_1/stdout.txt" "$DD_BASE_1/stderr.txt" "$DD_BASE_1" || DD_EXIT_1=$?

if [ -d "$DD_HOME_1/.claude" ] && [ ! -e "$DD_HOME_1/.claude-work" ] && [ ! -e "$DD_HOME_1/.claude-alex" ]; then
  assert "test_dd_autodetect_single_profile: only .claude/ written, .claude-work/.claude-alex skipped" "pass"
else
  detail="claude=$([ -d "$DD_HOME_1/.claude" ] && echo Y || echo N) work=$([ -e "$DD_HOME_1/.claude-work" ] && echo Y || echo N) alex=$([ -e "$DD_HOME_1/.claude-alex" ] && echo Y || echo N) exit=$DD_EXIT_1"
  assert "test_dd_autodetect_single_profile: only .claude/ written, .claude-work/.claude-alex skipped" "fail" "$detail"
fi

# DD.2: test_dd_autodetect_three_profile
# All three pre-exist. After serious-update: all three should have files distributed.
DD_BASE_2="$TMP_DIR/dd_three"
DD_HOME_2="$DD_BASE_2/test-home"
mkdir -p "$DD_HOME_2/.claude" "$DD_HOME_2/.claude-work" "$DD_HOME_2/.claude-alex"
DD_EXIT_2=0
run_dd_update "$DD_HOME_2" "$DD_BASE_2/stdout.txt" "$DD_BASE_2/stderr.txt" "$DD_BASE_2" || DD_EXIT_2=$?

# At least the canonical content file should land in each pre-existing dir
if [ -f "$DD_HOME_2/.claude/agents/serious-code-implementer.md" ] \
   && [ -f "$DD_HOME_2/.claude-work/agents/serious-code-implementer.md" ] \
   && [ -f "$DD_HOME_2/.claude-alex/agents/serious-code-implementer.md" ]; then
  assert "test_dd_autodetect_three_profile: all three pre-existing dirs received distribution" "pass"
else
  detail="claude=$([ -f "$DD_HOME_2/.claude/agents/serious-code-implementer.md" ] && echo Y || echo N) work=$([ -f "$DD_HOME_2/.claude-work/agents/serious-code-implementer.md" ] && echo Y || echo N) alex=$([ -f "$DD_HOME_2/.claude-alex/agents/serious-code-implementer.md" ] && echo Y || echo N)"
  assert "test_dd_autodetect_three_profile: all three pre-existing dirs received distribution" "fail" "$detail"
fi

# DD.3: test_dd_autodetect_empty_slate
# No ~/.claude* pre-exist. After serious-update:
#   - ~/.claude/ should be created (canonical fallback)
#   - ~/.claude-work/ should NOT exist
#   - ~/.claude-alex/ should NOT exist
DD_BASE_3="$TMP_DIR/dd_empty"
DD_HOME_3="$DD_BASE_3/test-home"
mkdir -p "$DD_HOME_3"
DD_EXIT_3=0
run_dd_update "$DD_HOME_3" "$DD_BASE_3/stdout.txt" "$DD_BASE_3/stderr.txt" "$DD_BASE_3" || DD_EXIT_3=$?

if [ -d "$DD_HOME_3/.claude" ] && [ ! -e "$DD_HOME_3/.claude-work" ] && [ ! -e "$DD_HOME_3/.claude-alex" ]; then
  assert "test_dd_autodetect_empty_slate: only .claude/ created (canonical fallback)" "pass"
else
  detail="claude=$([ -d "$DD_HOME_3/.claude" ] && echo Y || echo N) work=$([ -e "$DD_HOME_3/.claude-work" ] && echo Y || echo N) alex=$([ -e "$DD_HOME_3/.claude-alex" ] && echo Y || echo N) exit=$DD_EXIT_3"
  assert "test_dd_autodetect_empty_slate: only .claude/ created (canonical fallback)" "fail" "$detail"
fi

# DD.4: test_dd_dangling_symlink
# ~/.claude is a dangling symlink. After serious-update:
#   - distinct dangling-symlink WARNING on stderr
#   - no file is written through the dangling symlink
DD_BASE_4="$TMP_DIR/dd_dangling"
DD_HOME_4="$DD_BASE_4/test-home"
mkdir -p "$DD_HOME_4"
ln -s "/nonexistent/path/$$" "$DD_HOME_4/.claude"
DD_EXIT_4=0
run_dd_update "$DD_HOME_4" "$DD_BASE_4/stdout.txt" "$DD_BASE_4/stderr.txt" "$DD_BASE_4" || DD_EXIT_4=$?

# Check for distinct dangling-symlink warning (NOT just "does not exist")
DD4_STDERR=$(cat "$DD_BASE_4/stderr.txt" 2>/dev/null || echo "")
if echo "$DD4_STDERR" | grep -q "dangling symlink"; then
  assert "test_dd_dangling_symlink: distinct dangling-symlink WARNING emitted" "pass"
else
  assert "test_dd_dangling_symlink: distinct dangling-symlink WARNING emitted" "fail" "stderr did not contain 'dangling symlink': $DD4_STDERR"
fi

# DD.5: test_dd_envvar_overrides_autodetect
# SERIOUS_TARGET_DIRS set → auto-detect bypassed, env var honored
DD_BASE_5="$TMP_DIR/dd_envvar"
DD_HOME_5="$DD_BASE_5/test-home"
DD_TARGET_5="$DD_BASE_5/explicit-target"
mkdir -p "$DD_HOME_5" "$DD_TARGET_5"
setup_sidekick_home "$DD_BASE_5"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "DD5 seed"
DD_EXIT_5=0
HOME="$DD_HOME_5" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$DD_TARGET_5" \
  bash "$REPO_ROOT/bin/serious-update" \
  1>"$DD_BASE_5/stdout.txt" 2>"$DD_BASE_5/stderr.txt" || DD_EXIT_5=$?

# The explicit target dir should have content; the auto-detect dirs should not be touched.
if [ -f "$DD_TARGET_5/agents/serious-code-implementer.md" ] \
   && [ ! -e "$DD_HOME_5/.claude" ] \
   && [ ! -e "$DD_HOME_5/.claude-work" ] \
   && [ ! -e "$DD_HOME_5/.claude-alex" ]; then
  assert "test_dd_envvar_overrides_autodetect: env var honored, auto-detect bypassed" "pass"
else
  detail="target=$([ -f "$DD_TARGET_5/agents/serious-code-implementer.md" ] && echo Y || echo N) home_claude=$([ -e "$DD_HOME_5/.claude" ] && echo Y || echo N) exit=$DD_EXIT_5"
  assert "test_dd_envvar_overrides_autodetect: env var honored, auto-detect bypassed" "fail" "$detail"
fi

# DD.6: test_dd_envvar_with_missing_dir_warns
# SERIOUS_TARGET_DIRS=/foo where /foo doesn't exist:
#   - WARNING about missing dir on stderr
#   - /foo NOT created
#   - script exits 0 (skip is not error)
DD_BASE_6="$TMP_DIR/dd_envvar_missing"
DD_HOME_6="$DD_BASE_6/test-home"
DD_MISSING_6="$DD_BASE_6/never-create-me-$$"
mkdir -p "$DD_HOME_6"
setup_sidekick_home "$DD_BASE_6"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "DD6 seed"
DD_EXIT_6=0
HOME="$DD_HOME_6" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$DD_MISSING_6" \
  bash "$REPO_ROOT/bin/serious-update" \
  1>"$DD_BASE_6/stdout.txt" 2>"$DD_BASE_6/stderr.txt" || DD_EXIT_6=$?

DD6_STDERR=$(cat "$DD_BASE_6/stderr.txt" 2>/dev/null || echo "")
DD6_STDOUT=$(cat "$DD_BASE_6/stdout.txt" 2>/dev/null || echo "")
DD6_COMBINED="$DD6_STDOUT$DD6_STDERR"
if echo "$DD6_COMBINED" | grep -q "WARNING.*does not exist" \
   && [ ! -e "$DD_MISSING_6" ] \
   && [ "$DD_EXIT_6" -eq 0 ]; then
  assert "test_dd_envvar_with_missing_dir_warns: WARNING emitted, dir not created, exit 0" "pass"
else
  detail="warning=$(echo "$DD6_COMBINED" | grep -c "WARNING.*does not exist") missing_created=$([ -e "$DD_MISSING_6" ] && echo Y || echo N) exit=$DD_EXIT_6"
  assert "test_dd_envvar_with_missing_dir_warns: WARNING emitted, dir not created, exit 0" "fail" "$detail"
fi

# DD.7: test_dd_empty_home_errors
# HOME='' AND SERIOUS_TARGET_DIRS unset → exit 1, error message about HOME
DD_BASE_7="$TMP_DIR/dd_empty_home"
mkdir -p "$DD_BASE_7"
setup_sidekick_home "$DD_BASE_7"
DD_EXIT_7=0
HOME="" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" \
  bash "$REPO_ROOT/bin/serious-update" \
  1>"$DD_BASE_7/stdout.txt" 2>"$DD_BASE_7/stderr.txt" || DD_EXIT_7=$?

DD7_STDERR=$(cat "$DD_BASE_7/stderr.txt" 2>/dev/null || echo "")
if [ "$DD_EXIT_7" -eq 1 ] && echo "$DD7_STDERR" | grep -q "HOME"; then
  assert "test_dd_empty_home_errors: exit 1 with HOME error message" "pass"
else
  assert "test_dd_empty_home_errors: exit 1 with HOME error message" "fail" "exit=$DD_EXIT_7 stderr_has_HOME=$(echo "$DD7_STDERR" | grep -c HOME)"
fi

# DD.8: test_dd_migration_warning_one_shot
# TEST_HOME with audit log showing prior write to .claude-work, but .claude-work no longer exists.
# First invocation: NOTE printed, marker file written.
# Second invocation: NOTE NOT printed (suppressed by marker).
# Audit log lives at $SIDEKICK_HOME/update.log; marker co-located there.
DD_BASE_8="$TMP_DIR/dd_migration"
DD_HOME_8="$DD_BASE_8/test-home"
mkdir -p "$DD_HOME_8/.claude"

setup_sidekick_home "$DD_BASE_8"
# Pre-seed audit log AT SIDEKICK_HOME (where serious-update actually writes it)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DD8_LOG="$SETUP_HOME/update.log"
echo "$TS DISTRIBUTE-DIR dir=$DD_HOME_8/.claude-work" > "$DD8_LOG"
echo "$TS DISTRIBUTE-DIR dir=$DD_HOME_8/.claude" >> "$DD8_LOG"

add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "DD8 seed"

# First invocation
DD_EXIT_8A=0
HOME="$DD_HOME_8" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" \
  bash "$REPO_ROOT/bin/serious-update" \
  1>"$DD_BASE_8/stdout1.txt" 2>"$DD_BASE_8/stderr1.txt" || DD_EXIT_8A=$?

DD8A_COMBINED=$(cat "$DD_BASE_8/stdout1.txt" "$DD_BASE_8/stderr1.txt" 2>/dev/null || echo "")
DD8A_HAS_NOTE=$(echo "$DD8A_COMBINED" | grep -c "NOTE.*claude-work" 2>/dev/null | head -1 || true)
DD8A_HAS_NOTE=${DD8A_HAS_NOTE:-0}
DD8A_HAS_MARKER=$([ -f "$SETUP_HOME/migration-warned-claude-work" ] && echo 1 || echo 0)

# Second invocation
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "DD8 seed 2"
DD_EXIT_8B=0
HOME="$DD_HOME_8" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" \
  bash "$REPO_ROOT/bin/serious-update" \
  1>"$DD_BASE_8/stdout2.txt" 2>"$DD_BASE_8/stderr2.txt" || DD_EXIT_8B=$?

DD8B_COMBINED=$(cat "$DD_BASE_8/stdout2.txt" "$DD_BASE_8/stderr2.txt" 2>/dev/null || echo "")
DD8B_HAS_NOTE=$(echo "$DD8B_COMBINED" | grep -c "NOTE.*claude-work" 2>/dev/null | head -1 || true)
DD8B_HAS_NOTE=${DD8B_HAS_NOTE:-0}

if [ "$DD8A_HAS_NOTE" -ge 1 ] && [ "$DD8A_HAS_MARKER" -eq 1 ] && [ "$DD8B_HAS_NOTE" -eq 0 ]; then
  assert "test_dd_migration_warning_one_shot: NOTE on first run, marker written, suppressed on second" "pass"
else
  assert "test_dd_migration_warning_one_shot: NOTE on first run, marker written, suppressed on second" "fail" "first_note=$DD8A_HAS_NOTE marker=$DD8A_HAS_MARKER second_note=$DD8B_HAS_NOTE"
fi

# DD.9: test_dd_first_run_only_for_present_dirs
# .claude/ exists, .claude-work/ doesn't, no audit-log evidence of prior write to .claude-work.
# Expectation: NO migration NOTE printed (no prior-write evidence = no NOTE).
DD_BASE_9="$TMP_DIR/dd_first_run"
DD_HOME_9="$DD_BASE_9/test-home"
mkdir -p "$DD_HOME_9/.claude"

setup_sidekick_home "$DD_BASE_9"
# Audit log at SIDEKICK_HOME mentions ONLY .claude, NOT .claude-work
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$TS DISTRIBUTE-DIR dir=$DD_HOME_9/.claude" > "$SETUP_HOME/update.log"

add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "DD9 seed"

DD_EXIT_9=0
HOME="$DD_HOME_9" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" \
  bash "$REPO_ROOT/bin/serious-update" \
  1>"$DD_BASE_9/stdout.txt" 2>"$DD_BASE_9/stderr.txt" || DD_EXIT_9=$?

DD9_COMBINED=$(cat "$DD_BASE_9/stdout.txt" "$DD_BASE_9/stderr.txt" 2>/dev/null || echo "")
DD9_HAS_NOTE=$(echo "$DD9_COMBINED" | grep -c "NOTE.*claude-work" 2>/dev/null | head -1 || true)
DD9_HAS_NOTE=${DD9_HAS_NOTE:-0}
if [ "$DD9_HAS_NOTE" -eq 0 ]; then
  assert "test_dd_first_run_only_for_present_dirs: no migration NOTE without prior-write evidence" "pass"
else
  assert "test_dd_first_run_only_for_present_dirs: no migration NOTE without prior-write evidence" "fail" "unexpected NOTE count: $DD9_HAS_NOTE"
fi

# DD.10: test_dd_marker_filename_is_allowlisted
# Verify (via source-code grep) that the migration-marker filename is built
# from a fixed allowlist of three string literals, NOT from runtime basename
# derivation. The allowlist may be expressed as a `case` statement or as a
# bash `for X in literal literal literal` loop — both are acceptable as long
# as the literals are the only source of {dirname}.
SU_SRC="$REPO_ROOT/bin/serious-update"
# Pattern 1: case statement
P1=$(grep -cE 'case .* in[[:space:]]*claude\|claude-work\|claude-alex\)' "$SU_SRC" 2>/dev/null | head -1 || true)
P1=${P1:-0}
# Pattern 2: for loop with literals (the implementation we use)
P2=$(grep -cE 'for [a-zA-Z_]+ in claude-work claude-alex' "$SU_SRC" 2>/dev/null | head -1 || true)
P2=${P2:-0}
# Pattern 3: explicit array of literals
P3=$(grep -cE '"claude-work"[[:space:]]+"claude-alex"' "$SU_SRC" 2>/dev/null | head -1 || true)
P3=${P3:-0}
# AND: must NOT use basename to derive the marker filename
P_BASENAME=$(grep -cE 'migration-warned.*\$\(basename' "$SU_SRC" 2>/dev/null | head -1 || true)
P_BASENAME=${P_BASENAME:-0}
if [ "$((P1 + P2 + P3))" -gt 0 ] && [ "$P_BASENAME" -eq 0 ]; then
  assert "test_dd_marker_filename_is_allowlisted: source uses fixed allowlist (no basename derivation)" "pass"
else
  assert "test_dd_marker_filename_is_allowlisted: source uses fixed allowlist (no basename derivation)" "fail" "case=$P1 for=$P2 array=$P3 basename_misuse=$P_BASENAME"
fi

# Negative tests (anti-creep)
# NT.DD.1: No new file added to bin/ other than the modified bin/serious-update + bin/generate-manifest.sh
NEW_BIN_FILES_RAW=$(cd "$REPO_ROOT" && git diff --name-only main -- bin/ 2>/dev/null || echo "")
if [ -z "$NEW_BIN_FILES_RAW" ]; then
  NEW_BIN_FILES=0
else
  NEW_BIN_FILES=$(echo "$NEW_BIN_FILES_RAW" | grep -vE '^bin/(serious-update|generate-manifest\.sh)$' | wc -l | tr -d ' ' || true)
  [ -z "$NEW_BIN_FILES" ] && NEW_BIN_FILES=0
fi
if [ "$NEW_BIN_FILES" -eq 0 ]; then
  assert "NT.DD.1: no new file added to bin/" "pass"
else
  assert "NT.DD.1: no new file added to bin/" "fail" "new bin/ files detected: $NEW_BIN_FILES"
fi

# NT.DD.2: --help text unchanged from baseline
HELP_AFTER=$(SERIOUS_SIDEKICK_HOME="$TMP_DIR" bash "$REPO_ROOT/bin/serious-update" --help 2>&1 || true)
HELP_BEFORE_FILE="$REPO_ROOT/Research/features/install-ux-detect-dirs/evidence/assets/help_before.txt"
if [ -f "$HELP_BEFORE_FILE" ] && [ "$HELP_AFTER" = "$(cat "$HELP_BEFORE_FILE")" ]; then
  assert "NT.DD.2: --help text unchanged from baseline" "pass"
else
  assert "NT.DD.2: --help text unchanged from baseline" "fail" "diff detected vs baseline"
fi

# NT.DD.3: No change to install.sh
INSTALL_DIFF_RAW=$(cd "$REPO_ROOT" && git diff --stat main -- install.sh 2>/dev/null || echo "")
INSTALL_DIFF=$(echo "$INSTALL_DIFF_RAW" | grep -c . 2>/dev/null || true)
[ -z "$INSTALL_DIFF_RAW" ] && INSTALL_DIFF=0
if [ "$INSTALL_DIFF" -eq 0 ]; then
  assert "NT.DD.3: no change to install.sh" "pass"
else
  assert "NT.DD.3: no change to install.sh" "fail" "install.sh changes detected"
fi

# NT.DD.4: No change to receipt formatting (the "Serious Sidekick updated to ..." block)
# Verify no edits to the receipt-printing lines or DIR_REPORTS format.
RECEIPT_DIFF_RAW=$(cd "$REPO_ROOT" && git diff main -- bin/serious-update 2>/dev/null || echo "")
RECEIPT_CHANGES=$(echo "$RECEIPT_DIFF_RAW" | grep -cE '^[+-].*("Serious Sidekick updated to|"Audit log:|DIR_REPORTS\+=)' 2>/dev/null | head -1 || true)
RECEIPT_CHANGES=${RECEIPT_CHANGES:-0}
if [ "$RECEIPT_CHANGES" -eq 0 ]; then
  assert "NT.DD.4: no change to receipt formatting" "pass"
else
  assert "NT.DD.4: no change to receipt formatting" "fail" "$RECEIPT_CHANGES receipt-line edits"
fi

# NT.DD.5: SERIOUS_TARGET_DIRS env-var override path still present
if grep -q 'SERIOUS_TARGET_DIRS' "$REPO_ROOT/bin/serious-update"; then
  assert "NT.DD.5: SERIOUS_TARGET_DIRS env var override still works" "pass"
else
  assert "NT.DD.5: SERIOUS_TARGET_DIRS env var override still works" "fail" "env var reference missing"
fi

# NT.DD.6: No new --target-dir flag added
if grep -qE '\-\-target-dir' "$REPO_ROOT/bin/serious-update"; then
  assert "NT.DD.6: no --target-dir flag added (deferred to future plan)" "fail" "flag found"
else
  assert "NT.DD.6: no --target-dir flag added (deferred to future plan)" "pass"
fi

# NT.DD.7: --help on a blank-slate machine does NOT create ~/.claude as side effect
# (Empty-slate fallback must be lazy — gated on actual distribution intent.)
DD_BASE_NT7=$(mktemp -d -t nt-dd-7-helpsideeffect.XXXXXX)
HOME="$DD_BASE_NT7" SERIOUS_SIDEKICK_HOME="$DD_BASE_NT7/sidekick" \
  bash "$REPO_ROOT/bin/serious-update" --help >/dev/null 2>&1 || true
if [ -e "$DD_BASE_NT7/.claude" ]; then
  assert "NT.DD.7: --help does not create ~/.claude on blank-slate (read-only contract)" "fail" ".claude was created"
else
  assert "NT.DD.7: --help does not create ~/.claude on blank-slate (read-only contract)" "pass"
fi
rm -rf "$DD_BASE_NT7"

echo ""
echo "=== serious-update Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
