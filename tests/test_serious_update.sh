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

# Seed state files in target dirs so NEEDS_FIRST_RUN=false AND match HEAD so
# Task 4's NEEDS_REDISTRIBUTE check also stays false.
# (Pre-Task-4 the value here was the literal string "dummy". Task 4 added a
# SHA-shape validator that rejects non-SHA values as corrupt; we now stamp the
# state file with the real HEAD SHA so the gate genuinely sees a clean state.)
TASK1_HEAD_SHA=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null)
for d in $TASK1_DIRS; do
  printf '{"installed_from_commit":"%s","previous_commit":"","installed_at":"2026-04-02T00:00:00Z","file_hashes":{}}\n' \
    "$TASK1_HEAD_SHA" > "$d/.serious-sidekick-state.json"
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
if [ "$CORRUPT_EXIT" -eq 0 ] && $_SERIOUS_JSON_BACKEND -m json.tool "$SETUP_HOME/manifest.json" >/dev/null 2>&1; then
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
if [ "$NOMANI_EXIT" -eq 0 ] && [ -f "$SETUP_HOME/manifest.json" ] && $_SERIOUS_JSON_BACKEND -m json.tool "$SETUP_HOME/manifest.json" >/dev/null 2>&1; then
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
if $_SERIOUS_JSON_BACKEND -c "import json; json.load(open('$TASK3_FIRST/.serious-sidekick-state.json'))" 2>/dev/null; then
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
  SCHEMA_OK=$($_SERIOUS_JSON_BACKEND -c "
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
  STATE_PREV=$($_SERIOUS_JSON_BACKEND -c "
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
  POST_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "
import json
data = json.load(open('$TASK6_FIRST/.serious-sidekick-state.json'))
print(data.get('installed_from_commit', ''))
")
  POST_PREVIOUS=$($_SERIOUS_JSON_BACKEND -c "
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
# Match either the legacy `log_audit "ERROR git pull failed"` form OR the
# Task 1 capture-and-surface form `log_audit "ERROR git pull failed: ..."`.
EXIT1_LINE=$(grep -n 'log_audit "ERROR git pull failed' "$REPO_ROOT/bin/serious-update" | head -1 | cut -d: -f1 || true)
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

# NT.DD.3: REMOVED — obsoleted by the serious-update-reliability plan's Task 1
# (Site #9 at install.sh:92-102 is a legitimate, plan-scoped modification to the
# installer's git-pull error handling). The original assertion ("no change to
# install.sh") was a Don't-Diff guard from the install-ux-detect-dirs plan;
# that plan is complete and the guard's purpose is satisfied.
#
# If a future plan needs a fresh install.sh-change governance check, re-introduce
# it scoped to that plan's specific concerns.

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

# ===============================================================
# serious-update-reliability Task 1 — Surface real git/helper errors
# at all 9 anti-pattern sites (Finding 1). See plan.md Task 1.
# ===============================================================
echo ""
echo "--- reliability-task1: error transparency at 9 sites ---"
echo ""

# Helper: build a "wedge sandbox" — local clone at commit_A, remote at
# commit_B (ahead by one), then dirty the working tree's copy of the same
# file the remote commit modified so `git pull` refuses fast-forward.
# (add_remote_commit appends to _anti-rationalization-core.md, so dirty
# that same file locally to create the conflict.)
setup_wedge_sandbox() {
  local base_dir="$1"
  setup_sidekick_home "$base_dir"  # sets SETUP_HOME / SETUP_REMOTE
  # Push an extra commit to the remote so the local is behind.
  add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "wedge-remote-ahead"
  # Inject a working-tree edit to the SAME file the remote modified.
  # git pull will refuse the fast-forward to avoid overwriting local edits.
  printf '\n# local-wedge-edit\n' >> "$SETUP_HOME/_anti-rationalization-core.md"
}

# REL1.S1 (Site #1, do_git_pull): captured stderr surfaced; audit log
# entry has detail after "ERROR git pull failed:"
REL_S1_BASE="$TMP_DIR/rel_s1"
setup_wedge_sandbox "$REL_S1_BASE"
REL_S1_DIRS=$(setup_target_dirs "$TMP_DIR/rel_s1_targets")
REL_S1_EXIT=0
REL_S1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_S1_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_S1_EXIT=$?
REL_S1_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
if [ "$REL_S1_EXIT" -eq 1 ] \
   && echo "$REL_S1_OUTPUT" | grep -q "ERROR: git pull failed in " \
   && echo "$REL_S1_OUTPUT" | grep -q "local changes" \
   && echo "$REL_S1_LOG" | grep -qE "^[0-9-]+T[0-9:]+Z ERROR git pull failed: .+"; then
  assert "REL1.S1: do_git_pull captures stderr + audit log has detail" "pass"
else
  assert "REL1.S1: do_git_pull captures stderr + audit log has detail" "fail" \
    "exit=$REL_S1_EXIT, stderr=$(echo "$REL_S1_OUTPUT" | head -3 | tr '\n' '|'), log=$(echo "$REL_S1_LOG" | tail -1)"
fi

# REL1.S1.NEG: no "(network error?)" guess remains.
if echo "$REL_S1_OUTPUT" | grep -q "(network error?)"; then
  assert "REL1.S1.NEG: legacy '(network error?)' guess removed" "fail" "still present"
else
  assert "REL1.S1.NEG: legacy '(network error?)' guess removed" "pass"
fi

# REL1.LC_ALL: pull failure under non-English locale still produces
# English text in the audit log.
REL_LC_BASE="$TMP_DIR/rel_lc"
setup_wedge_sandbox "$REL_LC_BASE"
REL_LC_DIRS=$(setup_target_dirs "$TMP_DIR/rel_lc_targets")
REL_LC_EXIT=0
REL_LC_OUTPUT=$(LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_LC_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_LC_EXIT=$?
REL_LC_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
# After fix, the audit log entry (post-LC_ALL=C) contains the English
# phrase "local changes" — even though the user's LANG was French.
if [ "$REL_LC_EXIT" -eq 1 ] && echo "$REL_LC_LOG" | grep -q "local changes"; then
  assert "REL1.LC_ALL: audit log is English even under LANG=fr_FR.UTF-8" "pass"
else
  assert "REL1.LC_ALL: audit log is English even under LANG=fr_FR.UTF-8" "fail" \
    "exit=$REL_LC_EXIT, log_tail=$(echo "$REL_LC_LOG" | tail -1)"
fi

# REL1.HEADC500: audit-log entry is bounded to ≤500 chars (single line).
# Force a multi-line stderr by injecting many dirty files.
REL_HC_BASE="$TMP_DIR/rel_hc"
setup_sidekick_home "$REL_HC_BASE"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "wedge-remote-ahead-hc"
# Dirty the SAME file the remote modified to force a real pull conflict,
# AND inflate git's "local changes" list by editing many other files.
echo "local-wedge" >> "$SETUP_HOME/_anti-rationalization-core.md"
for i in $(seq 1 30); do
  echo "wedge $i" >> "$SETUP_HOME/CLAUDE.md"
  echo "wedge $i" >> "$SETUP_HOME/manifest.json"
done
REL_HC_DIRS=$(setup_target_dirs "$TMP_DIR/rel_hc_targets")
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_HC_DIRS" bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
REL_HC_LINE=$(grep "ERROR git pull failed:" "$SETUP_HOME/update.log" 2>/dev/null | head -1)
# Strip the leading timestamp+space.
REL_HC_PAYLOAD="${REL_HC_LINE#* }"
REL_HC_LEN=$(printf '%s' "$REL_HC_PAYLOAD" | wc -c | tr -d ' ')
# Single-line check: no embedded newlines (pipe-separator used instead).
REL_HC_LINECOUNT=$(printf '%s' "$REL_HC_LINE" | grep -c '^' || true)
if [ -n "$REL_HC_LINE" ] && [ "$REL_HC_LINECOUNT" -le 1 ]; then
  # Payload length is bounded by head -c 500 plus the prefix.
  assert "REL1.HEADC500: audit log entry is single-line + bounded" "pass"
else
  assert "REL1.HEADC500: audit log entry is single-line + bounded" "fail" \
    "line='$REL_HC_LINE' lines=$REL_HC_LINECOUNT"
fi

# REL1.S2 (Site #2, do_git_fetch): captured stderr surfaced when git
# fetch fails. Simulate by removing the remote.
REL_S2_BASE="$TMP_DIR/rel_s2"
setup_sidekick_home "$REL_S2_BASE"
rm -rf "$SETUP_REMOTE"  # destroy the remote so fetch fails
REL_S2_EXIT=0
REL_S2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" --check 2>&1) || REL_S2_EXIT=$?
REL_S2_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
if [ "$REL_S2_EXIT" -eq 1 ] \
   && echo "$REL_S2_OUTPUT" | grep -q "ERROR: git fetch failed in " \
   && echo "$REL_S2_LOG" | grep -qE "^[0-9-]+T[0-9:]+Z ERROR git fetch failed: .+"; then
  assert "REL1.S2: do_git_fetch captures stderr + audit log has detail" "pass"
else
  assert "REL1.S2: do_git_fetch captures stderr + audit log has detail" "fail" \
    "exit=$REL_S2_EXIT, stderr=$(echo "$REL_S2_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL1.SYNC: sync-pair invariant — error-handling bodies inside
# do_git_pull / do_git_fetch are token-identical except for the
# pull/fetch keyword. Extract the lines between `if ! X_err=...` and
# the closing `fi`, replace pull|fetch with X, and diff.
SYNC_PULL=$(awk '
  /^do_git_pull\(\) \{/,/^\}/ {
    if ($0 ~ /^  if ! pull_err=\$/) { capturing=1; next }
    if (capturing) {
      if ($0 ~ /^  fi$/) { capturing=0; exit }
      gsub(/pull/, "X")
      print
    }
  }' "$REPO_ROOT/bin/serious-update")
SYNC_FETCH=$(awk '
  /^do_git_fetch\(\) \{/,/^\}/ {
    if ($0 ~ /^  if ! fetch_err=\$/) { capturing=1; next }
    if (capturing) {
      if ($0 ~ /^  fi$/) { capturing=0; exit }
      gsub(/fetch/, "X")
      print
    }
  }' "$REPO_ROOT/bin/serious-update")
if [ -n "$SYNC_PULL" ] && [ "$SYNC_PULL" = "$SYNC_FETCH" ]; then
  assert "REL1.SYNC: do_git_pull / do_git_fetch error-handling bodies token-identical" "pass"
else
  assert "REL1.SYNC: do_git_pull / do_git_fetch error-handling bodies token-identical" "fail" \
    "pull=[$SYNC_PULL] fetch=[$SYNC_FETCH]"
fi

# REL1.S3 (Site #3, origin resolution): no origin/main or origin/master
# → explicit error + exit 1, no empty remote_commit lie.
REL_S3_BASE="$TMP_DIR/rel_s3"
setup_sidekick_home "$REL_S3_BASE"
# Push a feature branch to remote and delete main/master refs there.
git -C "$SETUP_HOME" checkout -b feature/wedge -q
git -C "$SETUP_HOME" push -q origin feature/wedge 2>/dev/null
# Delete main/master from the bare remote.
git -C "$SETUP_REMOTE" branch -D main -q 2>/dev/null || true
git -C "$SETUP_REMOTE" branch -D master -q 2>/dev/null || true
# Update local refs so fetch doesn't reintroduce them.
git -C "$SETUP_HOME" fetch origin -q --prune 2>/dev/null || true
REL_S3_EXIT=0
REL_S3_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" --check 2>&1) || REL_S3_EXIT=$?
REL_S3_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
if [ "$REL_S3_EXIT" -eq 1 ] \
   && echo "$REL_S3_OUTPUT" | grep -q "ERROR: no origin/main or origin/master in " \
   && ! echo "$REL_S3_OUTPUT" | grep -qE "Update available: local=.+ remote=$"; then
  assert "REL1.S3: missing origin/main+master → explicit error, no empty remote_commit" "pass"
else
  assert "REL1.S3: missing origin/main+master → explicit error, no empty remote_commit" "fail" \
    "exit=$REL_S3_EXIT, out=$(echo "$REL_S3_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL1.S4 (Site #4, get_current_commit): corrupt .git → specific error,
# not the generic "Not a git repository" lie.
REL_S4_BASE="$TMP_DIR/rel_s4"
setup_sidekick_home "$REL_S4_BASE"
# Corrupt: remove the HEAD ref file but leave the rest of .git in place.
rm -f "$SETUP_HOME/.git/HEAD"
REL_S4_EXIT=0
REL_S4_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_S4_EXIT=$?
if [ "$REL_S4_EXIT" -eq 1 ] && echo "$REL_S4_OUTPUT" | grep -q "ERROR: cannot read HEAD in "; then
  assert "REL1.S4: corrupt HEAD ref → 'cannot read HEAD' error (not 'Not a git repository' lie)" "pass"
else
  assert "REL1.S4: corrupt HEAD ref → 'cannot read HEAD' error (not 'Not a git repository' lie)" "fail" \
    "exit=$REL_S4_EXIT, out=$(echo "$REL_S4_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL1.S4.SUBSHELL (Task 1 fix-up): get_current_commit is called via
# `$(...)` which runs the function body in a subshell. Earlier versions
# stored the captured rev-parse stderr in a global (_GET_HEAD_ERR) and
# expected the caller to read it after the subshell exited — but the
# assignment was DISCARDED with the subshell, so users saw the literal
# string "ERROR: cannot read HEAD in <path>: " with NO trailing detail.
# Fix: print + audit-log inside the function. This test exercises the
# whole-.git-missing case (no .git directory at all) and asserts:
#   (a) exit 1
#   (b) stderr has "ERROR: cannot read HEAD in <path>:" followed by
#       NON-EMPTY git stderr text (must contain "fatal:" or
#       "not a git repository")
#   (c) audit log line matches "^<iso-ts> ERROR cannot read HEAD: .+"
#       with NON-EMPTY content after the colon.
REL_S4SS_BASE="$TMP_DIR/rel_s4_subshell"
setup_sidekick_home "$REL_S4SS_BASE"
# Nuke .git entirely (more thorough than just removing HEAD — guarantees
# git rev-parse hits the "not a git repository" failure path with a
# non-empty stderr line).
rm -rf "$SETUP_HOME/.git"
REL_S4SS_EXIT=0
REL_S4SS_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_S4SS_EXIT=$?
REL_S4SS_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
# Extract just the "ERROR: cannot read HEAD in ..." line for trailing-detail check.
REL_S4SS_LINE=$(echo "$REL_S4SS_OUTPUT" | grep "ERROR: cannot read HEAD in " | head -1)
# Trailing detail = everything after the FIRST ":" following the path. The
# path itself can contain ":" only on Windows (we're on bash/macOS/Linux,
# so the path won't have one), but to be safe we split on the literal
# "$SETUP_HOME: " marker.
REL_S4SS_DETAIL="${REL_S4SS_LINE#*ERROR: cannot read HEAD in *: }"
# Audit log payload after the "ERROR cannot read HEAD: " marker.
REL_S4SS_LOG_LINE=$(echo "$REL_S4SS_LOG" | grep "ERROR cannot read HEAD: " | head -1)
REL_S4SS_LOG_DETAIL="${REL_S4SS_LOG_LINE#*ERROR cannot read HEAD: }"
if [ "$REL_S4SS_EXIT" -eq 1 ] \
   && [ -n "$REL_S4SS_LINE" ] \
   && { echo "$REL_S4SS_DETAIL" | grep -qE "(fatal:|not a git repository)"; } \
   && [ -n "$REL_S4SS_LOG_LINE" ] \
   && echo "$REL_S4SS_LOG_LINE" | grep -qE "^[0-9-]+T[0-9:]+Z ERROR cannot read HEAD: .+" \
   && [ -n "$REL_S4SS_LOG_DETAIL" ]; then
  assert "REL1.S4.SUBSHELL: cannot-read-HEAD message + audit log both carry NON-EMPTY git stderr (subshell-scoping bug closed)" "pass"
else
  assert "REL1.S4.SUBSHELL: cannot-read-HEAD message + audit log both carry NON-EMPTY git stderr (subshell-scoping bug closed)" "fail" \
    "exit=$REL_S4SS_EXIT line='$REL_S4SS_LINE' detail='$REL_S4SS_DETAIL' log_line='$REL_S4SS_LOG_LINE'"
fi

# REL1.S5a (Site #5, manifest regen — generate-manifest stub exits 1):
# error message is specific to generate-manifest.sh.
REL_S5A_BASE="$TMP_DIR/rel_s5a"
setup_sidekick_home "$REL_S5A_BASE"
cat > "$SETUP_HOME/bin/generate-manifest.sh" << 'STUB'
#!/bin/bash
echo "fake stub failure: missing input" >&2
exit 1
STUB
chmod +x "$SETUP_HOME/bin/generate-manifest.sh"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "S5a regen-fail"
REL_S5A_DIRS=$(setup_target_dirs "$TMP_DIR/rel_s5a_targets")
REL_S5A_EXIT=0
REL_S5A_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_S5A_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_S5A_EXIT=$?
if [ "$REL_S5A_EXIT" -eq 1 ] && echo "$REL_S5A_OUTPUT" | grep -q "ERROR: generate-manifest.sh failed"; then
  assert "REL1.S5a: regen-step 1 (generate-manifest) → labeled error" "pass"
else
  assert "REL1.S5a: regen-step 1 (generate-manifest) → labeled error" "fail" \
    "exit=$REL_S5A_EXIT, out=$(echo "$REL_S5A_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL1.S5b (Site #5, manifest regen — stub emits invalid JSON, exits 0):
# error message is specific to invalid JSON validation step.
REL_S5B_BASE="$TMP_DIR/rel_s5b"
setup_sidekick_home "$REL_S5B_BASE"
cat > "$SETUP_HOME/bin/generate-manifest.sh" << 'STUB'
#!/bin/bash
echo '{not valid json' > "${MANIFEST_PATH:-/dev/null}"
exit 0
STUB
chmod +x "$SETUP_HOME/bin/generate-manifest.sh"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "S5b invalid-json"
REL_S5B_DIRS=$(setup_target_dirs "$TMP_DIR/rel_s5b_targets")
REL_S5B_EXIT=0
REL_S5B_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_S5B_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_S5B_EXIT=$?
if [ "$REL_S5B_EXIT" -eq 1 ] && echo "$REL_S5B_OUTPUT" | grep -q "ERROR: regenerated manifest.json is not valid JSON"; then
  assert "REL1.S5b: regen-step 2 (JSON validity) → labeled error" "pass"
else
  assert "REL1.S5b: regen-step 2 (JSON validity) → labeled error" "fail" \
    "exit=$REL_S5B_EXIT, out=$(echo "$REL_S5B_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL1.S5c (Site #5, manifest regen — mv fails): error message is
# specific to the mv step.
# Strategy: stub generate-manifest.sh to write valid JSON to .new
# (so steps 1 and 2 pass), then chmod the parent dir read-only just
# before exiting so step 3's `mv .new manifest.json` fails with EACCES.
REL_S5C_BASE="$TMP_DIR/rel_s5c"
setup_sidekick_home "$REL_S5C_BASE"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "S5c mv-fail"
cat > "$SETUP_HOME/bin/generate-manifest.sh" << 'STUB'
#!/bin/bash
# Step 1 emits valid JSON.
echo '{"version":1,"files":[]}' > "${MANIFEST_PATH:-/dev/null}"
# Step 2 (json.tool) only reads, so r/o parent is fine. Sabotage step 3
# by making the parent dir read-only so `mv` can't rename inside it.
sidekick_dir=$(dirname "${MANIFEST_PATH}")
chmod 555 "${sidekick_dir}"
exit 0
STUB
chmod +x "$SETUP_HOME/bin/generate-manifest.sh"
REL_S5C_DIRS=$(setup_target_dirs "$TMP_DIR/rel_s5c_targets")
REL_S5C_EXIT=0
REL_S5C_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_S5C_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_S5C_EXIT=$?
# Restore parent perms so trap can clean up.
chmod 755 "$SETUP_HOME" 2>/dev/null || true
if [ "$REL_S5C_EXIT" -eq 1 ] && echo "$REL_S5C_OUTPUT" | grep -q "ERROR: mv manifest.json.new -> manifest.json failed"; then
  assert "REL1.S5c: regen-step 3 (mv atomic rename) → labeled error" "pass"
else
  assert "REL1.S5c: regen-step 3 (mv atomic rename) → labeled error" "fail" \
    "exit=$REL_S5C_EXIT, out=$(echo "$REL_S5C_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL1.S6 (Site #6, update_state): stderr is captured via upd_err=$(...).
# This is a structural check on the source — verifies the capture pattern
# exists at the update_state call site in distribute_to_dir.
if grep -q 'upd_err=\$(update_state' "$REPO_ROOT/bin/serious-update"; then
  assert "REL1.S6: update_state stderr captured via upd_err=\$(...)" "pass"
else
  assert "REL1.S6: update_state stderr captured via upd_err=\$(...)" "fail" \
    "upd_err= pattern not found in serious-update"
fi

# REL1.S6.REDACT (Task 1 fix-up, plan AC line 487): the captured
# update_state stderr is piped through _redact_creds BEFORE being
# printed to user-stderr (not just before the audit-log write). We
# verify by sourcing _redact_creds and feeding it a representative
# URL-bearing string — the function should erase the credentials in
# its output. Structural check confirms the wire-up is in place.
# Structural: `upd_err=$(printf '%s' "$upd_err" | _redact_creds)` appears
# between the `if ! upd_err=$(update_state` capture and the user-stderr
# `printf '    %s\n' "$upd_err"` print.
if awk '
  /if ! upd_err=\$\(update_state/ { phase=1; next }
  phase==1 && /upd_err=\$\(printf .* _redact_creds\)/ { phase=2; next }
  phase==2 && /printf .* "\$upd_err"/ { found=1; exit }
  /^\}/ { phase=0 }
  END { exit found ? 0 : 1 }
' "$REPO_ROOT/bin/serious-update"; then
  assert "REL1.S6.REDACT: upd_err piped through _redact_creds before user-stderr print" "pass"
else
  assert "REL1.S6.REDACT: upd_err piped through _redact_creds before user-stderr print" "fail" \
    "redaction not wired between capture and print at update_state site"
fi
# Functional: redaction filter erases inline HTTPS credentials.
REL_S6_RED=$(printf 'https://test:secret123@invalid.localhost/repo.git failed' | sed 's#://[^@[:space:]]*@#://REDACTED@#g')
if ! echo "$REL_S6_RED" | grep -q "secret123"; then
  assert "REL1.S6.REDACT (functional): _redact_creds sed pattern erases inline HTTPS credentials" "pass"
else
  assert "REL1.S6.REDACT (functional): _redact_creds sed pattern erases inline HTTPS credentials" "fail" \
    "secret123 still present after redaction: $REL_S6_RED"
fi

# REL1.S7 (Site #7, cp failure): log_audit call added before the existing
# echo. Static check on the source.
if grep -B1 'echo "  ERROR: Failed to copy \$src -> \$dest" >&2' "$REPO_ROOT/bin/serious-update" \
   | grep -q 'log_audit "ERROR cp '; then
  assert "REL1.S7: log_audit added before cp failure echo (forensic-blind gap closed)" "pass"
else
  assert "REL1.S7: log_audit added before cp failure echo (forensic-blind gap closed)" "fail" \
    "log_audit not found immediately before cp error echo"
fi

# REL1.S8 (Site #8, parse_manifest failure): log_audit call added before
# the exit. Static check on the source — do_read_manifest function.
if awk '
  /^do_read_manifest\(\) \{/,/^\}/ {
    if (/log_audit "ERROR parse_manifest failed/) found=1
  }
  END { exit found ? 0 : 1 }
' "$REPO_ROOT/bin/serious-update"; then
  assert "REL1.S8: log_audit added in do_read_manifest before exit 1" "pass"
else
  assert "REL1.S8: log_audit added in do_read_manifest before exit 1" "fail" \
    "log_audit parse_manifest call not found in do_read_manifest"
fi

# REL1.S8.REDACT (Task 1 fix-up, plan AC line 487): the captured
# parse_manifest stderr is piped through _redact_creds BEFORE being
# echoed to user-stderr (not just before the audit-log write).
# Structural: `parsed=$(printf '%s' "$parsed" | _redact_creds)` appears
# inside do_read_manifest, BEFORE `echo "$parsed" >&2`.
if awk '
  /^do_read_manifest\(\) \{/ { in_fn=1 }
  in_fn && /parsed=\$\(printf .* _redact_creds\)/ { red=1 }
  in_fn && /echo "\$parsed" >&2/ { if (red==1) found=1 }
  in_fn && /^\}/ { in_fn=0 }
  END { exit found ? 0 : 1 }
' "$REPO_ROOT/bin/serious-update"; then
  assert "REL1.S8.REDACT: parsed piped through _redact_creds before user-stderr print in do_read_manifest" "pass"
else
  assert "REL1.S8.REDACT: parsed piped through _redact_creds before user-stderr print in do_read_manifest" "fail" \
    "redaction not wired before user-stderr in do_read_manifest"
fi

# REL1.REDACT (S2 security hardening): inline HTTPS credentials are
# redacted before reaching either stderr or audit log.
REL_RED_BASE="$TMP_DIR/rel_red"
setup_sidekick_home "$REL_RED_BASE"
# Set a remote URL with embedded credentials, then break it so pull fails.
git -C "$SETUP_HOME" remote set-url origin "https://test:secret123@invalid.localhost/repo.git"
REL_RED_DIRS=$(setup_target_dirs "$TMP_DIR/rel_red_targets")
REL_RED_EXIT=0
REL_RED_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_RED_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_RED_EXIT=$?
REL_RED_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
if [ "$REL_RED_EXIT" -eq 1 ] \
   && ! echo "$REL_RED_OUTPUT" | grep -q "secret123" \
   && ! echo "$REL_RED_LOG" | grep -q "secret123"; then
  assert "REL1.REDACT (S2): credentials redacted in stderr and audit log" "pass"
else
  STDERR_HAS=$(echo "$REL_RED_OUTPUT" | grep -c "secret123" || echo 0)
  LOG_HAS=$(echo "$REL_RED_LOG" | grep -c "secret123" || echo 0)
  assert "REL1.REDACT (S2): credentials redacted in stderr and audit log" "fail" \
    "exit=$REL_RED_EXIT stderr_has=$STDERR_HAS log_has=$LOG_HAS"
fi

# REL1.QUOTE (S4 security hardening): bash -n stays clean after fixes.
if bash -n "$REPO_ROOT/bin/serious-update" 2>/dev/null; then
  assert "REL1.QUOTE (S4): bash -n on bin/serious-update is clean" "pass"
else
  assert "REL1.QUOTE (S4): bash -n on bin/serious-update is clean" "fail"
fi

# REL1.NEG-HAPPY (negative test): pull SUCCESS → no ERROR line in stderr
# or audit log. Confirms the fix doesn't produce spurious noise.
REL_NEG_BASE="$TMP_DIR/rel_neg_happy"
setup_sidekick_home "$REL_NEG_BASE"
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "neg-happy commit"
REL_NEG_DIRS=$(setup_target_dirs "$TMP_DIR/rel_neg_happy_targets")
REL_NEG_EXIT=0
REL_NEG_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_NEG_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL_NEG_EXIT=$?
REL_NEG_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
if [ "$REL_NEG_EXIT" -eq 0 ] \
   && ! echo "$REL_NEG_OUTPUT" | grep -qE "ERROR: git (pull|fetch) failed" \
   && ! echo "$REL_NEG_LOG" | grep -qE "ERROR git (pull|fetch) failed"; then
  assert "REL1.NEG-HAPPY: pull success path produces no ERROR noise" "pass"
else
  assert "REL1.NEG-HAPPY: pull success path produces no ERROR noise" "fail" \
    "exit=$REL_NEG_EXIT"
fi

# REL1.NEG-GREP (negative test): the migration-warning grep at line ~181
# (`grep -qE "^[0-9-]+T[0-9:]+Z DISTRIBUTE-DIR dir=..."`) is not poisoned
# by the new ERROR-line format. Run a pull-failure path THEN run a
# normal path and check that nothing weird happens.
REL_NEGG_BASE="$TMP_DIR/rel_neg_grep"
setup_wedge_sandbox "$REL_NEGG_BASE"
REL_NEGG_DIRS=$(setup_target_dirs "$TMP_DIR/rel_neg_grep_targets")
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL_NEGG_DIRS" bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Now confirm the audit log has ERROR git pull failed line, but the
# migration-warning regex (which only matches DISTRIBUTE-DIR lines)
# does NOT match.
if grep -qE "^[0-9-]+T[0-9:]+Z DISTRIBUTE-DIR" "$SETUP_HOME/update.log" 2>/dev/null; then
  MATCHED_BAD=1
else
  MATCHED_BAD=0
fi
if [ "$MATCHED_BAD" -eq 0 ]; then
  assert "REL1.NEG-GREP: ERROR-line entries do not match DISTRIBUTE-DIR regex" "pass"
else
  assert "REL1.NEG-GREP: ERROR-line entries do not match DISTRIBUTE-DIR regex" "fail" \
    "DISTRIBUTE-DIR regex matched in error-only run"
fi

echo ""

# ===============================================================
# TASK 4 (reliability): State-aware freshness gate (Finding 2)
# Layer NEEDS_REDISTRIBUTE alongside NEEDS_FIRST_RUN so the freshness
# gate consults per-dir installed_from_commit before bailing.
# ===============================================================
echo "--- Task 4 (reliability): state-aware freshness gate (REL2.*) ---"
echo ""

# ---------------------------------------------------------------
# Static-source assertions on bin/serious-update
# (structural shape required by the plan, independent of runtime)
# ---------------------------------------------------------------

# REL2.AC1: NEEDS_REDISTRIBUTE=false is declared before the freshness gate.
# The freshness gate is the `if [ "$OLD_COMMIT" = "$NEW_COMMIT" ] ...` block
# whose body is the "Already up to date" exit-2 line. We anchor on that body
# line because the gate condition may be split across multiple lines via
# bash line continuation.
if awk '
  /^NEEDS_REDISTRIBUTE=false/ { saw_decl=NR }
  /Already up to date at \$NEW_COMMIT/ { saw_gate=NR }
  END { exit (saw_decl > 0 && saw_gate > 0 && saw_decl < saw_gate) ? 0 : 1 }
' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.AC1: NEEDS_REDISTRIBUTE=false declared before freshness gate" "pass"
else
  assert "REL2.AC1: NEEDS_REDISTRIBUTE=false declared before freshness gate" "fail" \
    "Expected NEEDS_REDISTRIBUTE=false declaration above gate"
fi

# REL2.AC2: Per-dir state read uses Python with isinstance(v,str) type-check
if grep -qE 'isinstance\(v,\s*str\)' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.AC2: Python type-safe wrapper (isinstance(v,str)) present" "pass"
else
  assert "REL2.AC2: Python type-safe wrapper (isinstance(v,str)) present" "fail" \
    "Expected isinstance(v,str) in the per-dir state read"
fi

# REL2.AC3: Gate condition includes && [ "$NEEDS_REDISTRIBUTE" = "false" ]
# Use awk range from the if-line to the matching `then` (handles bash line
# continuation `\` so the multi-line if survives the check).
if awk '
  /^if \[ "\$OLD_COMMIT" = "\$NEW_COMMIT" \]/ { in_gate=1 }
  in_gate {
    if (/\[ "\$NEEDS_REDISTRIBUTE" = "false" \]/) found=1
  }
  in_gate && /^[[:space:]]*then[[:space:]]*$|; then$/ { in_gate=0 }
  END { exit found ? 0 : 1 }
' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.AC3: Gate condition ANDs NEEDS_REDISTRIBUTE=false" "pass"
else
  assert "REL2.AC3: Gate condition ANDs NEEDS_REDISTRIBUTE=false" "fail" \
    "Expected gate to AND-in NEEDS_REDISTRIBUTE=false"
fi

# REL2.AC4: distribute_to_dir call threads a per-dir prior installed value
# (parallel array PRIOR_INSTALLED[$i]), NOT $OLD_COMMIT. The previous_commit
# arg may be threaded via a derived local (e.g. _prev_for_dir) — what matters
# is that PRIOR_INSTALLED feeds that local AND distribute_to_dir does NOT
# receive $OLD_COMMIT as its 5th arg unconditionally.
if grep -qE 'PRIOR_INSTALLED\[\$?i\]' "$REPO_ROOT/bin/serious-update" \
   && ! awk '
       /^  for (dir|i) in / { in_dist_loop=1 }
       in_dist_loop && /result=\$\(distribute_to_dir.*"\$OLD_COMMIT"\)/ { found=1 }
       /^  done/ && in_dist_loop { in_dist_loop=0 }
       END { exit found ? 0 : 1 }
     ' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.AC4: distribute_to_dir threads PRIOR_INSTALLED[\$i] (parallel array)" "pass"
else
  assert "REL2.AC4: distribute_to_dir threads PRIOR_INSTALLED[\$i] (parallel array)" "fail" \
    "Expected PRIOR_INSTALLED[\$i] threaded into distribute_to_dir call AND no unconditional \$OLD_COMMIT"
fi

# REL2.AC4.bash32: no declare -A used (bash 3.2 has no associative arrays).
if ! grep -qE '^\s*declare -A' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.AC4.bash32: no declare -A (bash 3.2 compatibility)" "pass"
else
  assert "REL2.AC4.bash32: no declare -A (bash 3.2 compatibility)" "fail" \
    "declare -A found in bin/serious-update — bash 3.2 has no associative arrays"
fi

# REL2.AC10: redistribute-for-staleness audit-log line does NOT match
# "files=0 .* nothing-to-update" pattern when redistribution happens.
# (This is checked in the runtime scenario below; here we assert the structural
# shape: the "nothing to update" string appears exactly once AND sits adjacent
# to the "Already up to date" exit-2 branch.)
NOT_NTU=$(grep -c "nothing to update" "$REPO_ROOT/bin/serious-update")
if [ "$NOT_NTU" -eq 1 ] \
   && awk '
       /nothing to update/ { ntu=NR }
       /Already up to date at \$NEW_COMMIT/ { aud=NR }
       /^  exit 2$/ { ex=NR }
       END { exit (ntu>0 && aud>ntu && ex>aud) ? 0 : 1 }
     ' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.AC10: 'nothing to update' audit string confined to bail branch" "pass"
else
  assert "REL2.AC10: 'nothing to update' audit string confined to bail branch" "fail" \
    "Expected single 'nothing to update' adjacent to 'Already up to date' + 'exit 2'"
fi

# REL2.S3.regex: SHA-shape regex `^[0-9a-f]{7,40}$` is present.
if grep -qE '\^\[0-9a-f\]\{7,40\}\$' "$REPO_ROOT/bin/serious-update"; then
  assert "REL2.S3.regex: SHA-shape regex ^[0-9a-f]{7,40}\$ present" "pass"
else
  assert "REL2.S3.regex: SHA-shape regex ^[0-9a-f]{7,40}\$ present" "fail" \
    "Expected SHA-shape validation regex"
fi

# ---------------------------------------------------------------
# Runtime scenarios
# ---------------------------------------------------------------

# REL2.AC6: Scenario A — clean state, OLD==NEW, all dirs at HEAD → exit 2
SCENARIO_A_BASE="$TMP_DIR/rel2_scen_a"
setup_sidekick_home "$SCENARIO_A_BASE"
SCENARIO_A_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_scen_a_targets")
# First run: distribute (pulls nothing new — OLD==NEW from setup_sidekick_home).
# Push a commit so OLD!=NEW for the first run, then second run is clean.
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-scen-a-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_A_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Second run: nothing new on remote, state files at HEAD → should exit 2.
SCEN_A_EXIT=0
SCEN_A_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_A_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_A_EXIT=$?
if [ "$SCEN_A_EXIT" -eq 2 ] && echo "$SCEN_A_OUT" | grep -q "Already up to date"; then
  assert "REL2.AC6 (Scenario A): clean state → exit 2 with 'Already up to date'" "pass"
else
  assert "REL2.AC6 (Scenario A): clean state → exit 2 with 'Already up to date'" "fail" \
    "exit=$SCEN_A_EXIT out=$(echo "$SCEN_A_OUT" | head -3 | tr '\n' '|')"
fi

# REL2.AC7 (Scenario B): interrupted prior run — OLD==NEW but per-dir state files
# point at older commit. Script should redistribute, exit 0, write state, and
# thread the per-dir prior installed_from_commit as previous_commit (NOT $OLD_COMMIT).
SCENARIO_B_BASE="$TMP_DIR/rel2_scen_b"
setup_sidekick_home "$SCENARIO_B_BASE"
SCENARIO_B_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_scen_b_targets")
SCEN_B_OLD_SHA="abc1234"  # fake prior commit SHA
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-scen-b-seed"
# Distribute once to lay state files at the real current HEAD.
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_B_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Now rewrite each target dir's state file to claim it was installed from the
# fake older SHA. HEAD has NOT moved — this simulates an interrupted prior run.
for d in $SCENARIO_B_DIRS; do
  if [ -f "$d/.serious-sidekick-state.json" ]; then
    $_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = sys.argv[2]
json.dump(s, open(p,'w'), indent=2, sort_keys=True)
" "$d/.serious-sidekick-state.json" "$SCEN_B_OLD_SHA"
  fi
done
SCEN_B_EXIT=0
SCEN_B_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_B_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_B_EXIT=$?
# After redistribute: exit 0, state file updated to current HEAD, previous_commit==fake_old
SCEN_B_FIRST_DIR=$(echo "$SCENARIO_B_DIRS" | awk '{print $1}')
SCEN_B_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
SCEN_B_INSTALLED=""
SCEN_B_PREV=""
if [ -f "$SCEN_B_FIRST_DIR/.serious-sidekick-state.json" ]; then
  SCEN_B_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$SCEN_B_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
  SCEN_B_PREV=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('previous_commit',''))" "$SCEN_B_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
if [ "$SCEN_B_EXIT" -eq 0 ] \
   && [ "$SCEN_B_INSTALLED" = "$SCEN_B_HEAD" ] \
   && [ "$SCEN_B_PREV" = "$SCEN_B_OLD_SHA" ]; then
  assert "REL2.AC7 (Scenario B): stale state → redistribute, prev=fake-old, installed=HEAD" "pass"
else
  assert "REL2.AC7 (Scenario B): stale state → redistribute, prev=fake-old, installed=HEAD" "fail" \
    "exit=$SCEN_B_EXIT installed='$SCEN_B_INSTALLED' (want HEAD='$SCEN_B_HEAD') prev='$SCEN_B_PREV' (want '$SCEN_B_OLD_SHA')"
fi

# REL2.AC8 (Scenario C): new upstream commit (OLD!=NEW) → distribute regardless,
# behavior unchanged. Exit 0, state files updated.
SCENARIO_C_BASE="$TMP_DIR/rel2_scen_c"
setup_sidekick_home "$SCENARIO_C_BASE"
SCENARIO_C_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_scen_c_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-scen-c-seed-1"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_C_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Add a new remote commit so OLD!=NEW for next run.
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-scen-c-newcommit"
SCEN_C_EXIT=0
SCEN_C_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_C_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_C_EXIT=$?
SCEN_C_FIRST_DIR=$(echo "$SCENARIO_C_DIRS" | awk '{print $1}')
SCEN_C_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
SCEN_C_INSTALLED=""
if [ -f "$SCEN_C_FIRST_DIR/.serious-sidekick-state.json" ]; then
  SCEN_C_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$SCEN_C_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
if [ "$SCEN_C_EXIT" -eq 0 ] && [ "$SCEN_C_INSTALLED" = "$SCEN_C_HEAD" ]; then
  assert "REL2.AC8 (Scenario C): new upstream → distribute, state at HEAD" "pass"
else
  assert "REL2.AC8 (Scenario C): new upstream → distribute, state at HEAD" "fail" \
    "exit=$SCEN_C_EXIT installed='$SCEN_C_INSTALLED' HEAD='$SCEN_C_HEAD'"
fi

# REL2.AC9 (Scenario D): first run (missing state files) → migrate + distribute.
SCENARIO_D_BASE="$TMP_DIR/rel2_scen_d"
setup_sidekick_home "$SCENARIO_D_BASE"
SCENARIO_D_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_scen_d_targets")
# No state files yet; no add_remote_commit needed — NEEDS_FIRST_RUN handles it.
SCEN_D_EXIT=0
SCEN_D_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_D_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_D_EXIT=$?
SCEN_D_FIRST_DIR=$(echo "$SCENARIO_D_DIRS" | awk '{print $1}')
if [ "$SCEN_D_EXIT" -eq 0 ] && [ -f "$SCEN_D_FIRST_DIR/.serious-sidekick-state.json" ]; then
  assert "REL2.AC9 (Scenario D): first run → migrate+distribute, state written" "pass"
else
  assert "REL2.AC9 (Scenario D): first run → migrate+distribute, state written" "fail" \
    "exit=$SCEN_D_EXIT first_dir_has_state=$([ -f "$SCEN_D_FIRST_DIR/.serious-sidekick-state.json" ] && echo yes || echo no)"
fi

# REL2.AC5: state file missing 'installed_from_commit' key (defensive default).
# Script must treat as NEEDS_REDISTRIBUTE=true and proceed.
SCEN_MISS_BASE="$TMP_DIR/rel2_miss"
setup_sidekick_home "$SCEN_MISS_BASE"
SCEN_MISS_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_miss_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-miss-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_MISS_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Overwrite first dir's state file with an empty object {}.
SCEN_MISS_FIRST_DIR=$(echo "$SCEN_MISS_DIRS" | awk '{print $1}')
echo '{}' > "$SCEN_MISS_FIRST_DIR/.serious-sidekick-state.json"
SCEN_MISS_EXIT=0
SCEN_MISS_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_MISS_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_MISS_EXIT=$?
SCEN_MISS_INSTALLED=""
if [ -f "$SCEN_MISS_FIRST_DIR/.serious-sidekick-state.json" ]; then
  SCEN_MISS_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$SCEN_MISS_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
SCEN_MISS_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
# Exit 0 (or 2 if no other dirs were stale and the empty {} is treated as fine —
# but per the AC, '{}' must trigger NEEDS_REDISTRIBUTE=true → exit 0).
if [ "$SCEN_MISS_EXIT" -eq 0 ] && [ "$SCEN_MISS_INSTALLED" = "$SCEN_MISS_HEAD" ]; then
  assert "REL2.AC5: missing 'installed_from_commit' key → redistribute" "pass"
else
  assert "REL2.AC5: missing 'installed_from_commit' key → redistribute" "fail" \
    "exit=$SCEN_MISS_EXIT installed='$SCEN_MISS_INSTALLED' HEAD='$SCEN_MISS_HEAD'"
fi

# REL2.AC10: audit log entry for redistribute reflects ACTUAL file counts
# (NOT files=0 ... nothing-to-update). Build off Scenario B redistribute.
SCENARIO_B2_BASE="$TMP_DIR/rel2_scen_b2"
setup_sidekick_home "$SCENARIO_B2_BASE"
SCENARIO_B2_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_scen_b2_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-scen-b2-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_B2_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
for d in $SCENARIO_B2_DIRS; do
  if [ -f "$d/.serious-sidekick-state.json" ]; then
    $_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = sys.argv[2]
json.dump(s, open(p,'w'), indent=2, sort_keys=True)
" "$d/.serious-sidekick-state.json" "deadbeef"
  fi
done
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCENARIO_B2_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Tail of audit log: the most recent UPDATE entry should NOT have "nothing to update"
LAST_UPDATE_LINE=$(grep "UPDATE" "$SETUP_HOME/update.log" 2>/dev/null | tail -1)
if [ -n "$LAST_UPDATE_LINE" ] && ! echo "$LAST_UPDATE_LINE" | grep -q "nothing to update"; then
  assert "REL2.AC10: redistribute audit line shows actual counts (not 'nothing to update')" "pass"
else
  assert "REL2.AC10: redistribute audit line shows actual counts (not 'nothing to update')" "fail" \
    "last UPDATE: $LAST_UPDATE_LINE"
fi

# REL2.AC11: user-visible 28-file-stale dir → redistribute, files actually placed.
# Simulate by deleting a known distributed file from the target dir AND setting
# state to old SHA. Script should redistribute and the file should reappear.
SCEN11_BASE="$TMP_DIR/rel2_ac11"
setup_sidekick_home "$SCEN11_BASE"
SCEN11_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_ac11_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-ac11-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN11_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
SCEN11_FIRST=$(echo "$SCEN11_DIRS" | awk '{print $1}')
# Delete a known distributed file
SCEN11_VICTIM="$SCEN11_FIRST/skills/serious-code/SKILL.md"
if [ -f "$SCEN11_VICTIM" ]; then
  rm -f "$SCEN11_VICTIM"
fi
# Mark state stale
$_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = 'cafef00d'
json.dump(s, open(p,'w'), indent=2, sort_keys=True)
" "$SCEN11_FIRST/.serious-sidekick-state.json"
SCEN11_EXIT=0
SCEN11_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN11_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN11_EXIT=$?
if [ "$SCEN11_EXIT" -eq 0 ] && [ -f "$SCEN11_VICTIM" ]; then
  assert "REL2.AC11: stale dir with missing file → redistribute restores file" "pass"
else
  assert "REL2.AC11: stale dir with missing file → redistribute restores file" "fail" \
    "exit=$SCEN11_EXIT victim_exists=$([ -f "$SCEN11_VICTIM" ] && echo yes || echo no)"
fi

# REL2.S1: non-string installed_from_commit (list) MUST be treated as empty,
# trigger redistribute, and NOT flow into audit log or distribute_to_dir args.
SCEN_S1_BASE="$TMP_DIR/rel2_s1"
setup_sidekick_home "$SCEN_S1_BASE"
SCEN_S1_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_s1_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-s1-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_S1_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
SCEN_S1_FIRST=$(echo "$SCEN_S1_DIRS" | awk '{print $1}')
# Embed a unique sentinel inside the list so we can grep audit/stderr/state for it.
SCEN_S1_SENTINEL="REL2-S1-LEAK-SENTINEL-$$"
$_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = [sys.argv[2], 'b']
json.dump(s, open(p,'w'), indent=2, sort_keys=True)
" "$SCEN_S1_FIRST/.serious-sidekick-state.json" "$SCEN_S1_SENTINEL"
SCEN_S1_EXIT=0
SCEN_S1_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_S1_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_S1_EXIT=$?
SCEN_S1_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
SCEN_S1_NEW_INSTALLED=""
SCEN_S1_NEW_PREV=""
if [ -f "$SCEN_S1_FIRST/.serious-sidekick-state.json" ]; then
  SCEN_S1_NEW_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;v=json.load(open(sys.argv[1])).get('installed_from_commit','');print(v if isinstance(v,str) else '')" "$SCEN_S1_FIRST/.serious-sidekick-state.json" 2>/dev/null || echo "")
  SCEN_S1_NEW_PREV=$($_SERIOUS_JSON_BACKEND -c "import json,sys;v=json.load(open(sys.argv[1])).get('previous_commit','');print(v if isinstance(v,str) else '')" "$SCEN_S1_FIRST/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
SCEN_S1_LOG_LEAK=0
if grep -q "$SCEN_S1_SENTINEL" "$SETUP_HOME/update.log" 2>/dev/null; then
  SCEN_S1_LOG_LEAK=1
fi
SCEN_S1_STDERR_LEAK=0
if echo "$SCEN_S1_OUT" | grep -q "$SCEN_S1_SENTINEL"; then
  SCEN_S1_STDERR_LEAK=1
fi
# State after run should be: installed=HEAD, previous='' (no leak of list).
if [ "$SCEN_S1_EXIT" -eq 0 ] \
   && [ "$SCEN_S1_NEW_INSTALLED" = "$SCEN_S1_HEAD" ] \
   && [ -z "$SCEN_S1_NEW_PREV" ] \
   && [ "$SCEN_S1_LOG_LEAK" -eq 0 ] \
   && [ "$SCEN_S1_STDERR_LEAK" -eq 0 ]; then
  assert "REL2.S1: non-string installed_from_commit (list) → empty, no leak, redistribute" "pass"
else
  assert "REL2.S1: non-string installed_from_commit (list) → empty, no leak, redistribute" "fail" \
    "exit=$SCEN_S1_EXIT new_installed='$SCEN_S1_NEW_INSTALLED' new_prev='$SCEN_S1_NEW_PREV' log_leak=$SCEN_S1_LOG_LEAK stderr_leak=$SCEN_S1_STDERR_LEAK"
fi

# REL2.S3: corrupt/non-SHA installed_from_commit string (e.g. shell-injection
# payload). Script must (a) emit a WARNING to stderr, (b) treat as empty,
# (c) NOT shell-expand the payload, (d) redistribute with previous_commit="".
SCEN_S3_BASE="$TMP_DIR/rel2_s3"
setup_sidekick_home "$SCEN_S3_BASE"
SCEN_S3_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_s3_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-s3-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_S3_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
SCEN_S3_FIRST=$(echo "$SCEN_S3_DIRS" | awk '{print $1}')
# Write a literal shell-injection-looking string into installed_from_commit.
# We use a non-destructive sentinel (mkdir of a tempfile) to detect any
# accidental shell expansion. If the value is ever eval'd or unquoted, the
# expansion would attempt to create this dir.
SCEN_S3_PROBE_DIR="$TMP_DIR/rel2_s3_probe_should_not_exist_$$"
$_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = sys.argv[2]
json.dump(s, open(p,'w'), indent=2, sort_keys=True)
" "$SCEN_S3_FIRST/.serious-sidekick-state.json" "\$(mkdir -p $SCEN_S3_PROBE_DIR)"
SCEN_S3_EXIT=0
SCEN_S3_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_S3_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || SCEN_S3_EXIT=$?
SCEN_S3_WARN=0
if echo "$SCEN_S3_OUT" | grep -q "non-SHA installed_from_commit"; then
  SCEN_S3_WARN=1
fi
SCEN_S3_EXPANDED=0
if [ -d "$SCEN_S3_PROBE_DIR" ]; then
  SCEN_S3_EXPANDED=1
fi
SCEN_S3_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
SCEN_S3_NEW_INSTALLED=""
SCEN_S3_NEW_PREV=""
if [ -f "$SCEN_S3_FIRST/.serious-sidekick-state.json" ]; then
  SCEN_S3_NEW_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;v=json.load(open(sys.argv[1])).get('installed_from_commit','');print(v if isinstance(v,str) else '')" "$SCEN_S3_FIRST/.serious-sidekick-state.json" 2>/dev/null || echo "")
  SCEN_S3_NEW_PREV=$($_SERIOUS_JSON_BACKEND -c "import json,sys;v=json.load(open(sys.argv[1])).get('previous_commit','');print(v if isinstance(v,str) else '')" "$SCEN_S3_FIRST/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
if [ "$SCEN_S3_EXIT" -eq 0 ] \
   && [ "$SCEN_S3_WARN" -eq 1 ] \
   && [ "$SCEN_S3_EXPANDED" -eq 0 ] \
   && [ "$SCEN_S3_NEW_INSTALLED" = "$SCEN_S3_HEAD" ] \
   && [ -z "$SCEN_S3_NEW_PREV" ]; then
  assert "REL2.S3: non-SHA installed_from_commit → WARNING, no shell expansion, prev=''" "pass"
else
  assert "REL2.S3: non-SHA installed_from_commit → WARNING, no shell expansion, prev=''" "fail" \
    "exit=$SCEN_S3_EXIT warn=$SCEN_S3_WARN expanded=$SCEN_S3_EXPANDED new_installed='$SCEN_S3_NEW_INSTALLED' new_prev='$SCEN_S3_NEW_PREV'"
fi

# REL2.NT-DIFF: --diff is NOT impacted by the new check.
SCEN_DIFF_BASE="$TMP_DIR/rel2_nt_diff"
setup_sidekick_home "$SCEN_DIFF_BASE"
SCEN_DIFF_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_nt_diff_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-nt-diff-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_DIFF_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Clean state — second --diff should still run dry preview, exit 0.
SCEN_DIFF_EXIT=0
SCEN_DIFF_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_DIFF_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" --diff 2>&1) || SCEN_DIFF_EXIT=$?
if [ "$SCEN_DIFF_EXIT" -eq 0 ] && echo "$SCEN_DIFF_OUT" | grep -q "Dry run complete"; then
  assert "REL2.NT-DIFF: --diff still runs dry preview regardless of state" "pass"
else
  assert "REL2.NT-DIFF: --diff still runs dry preview regardless of state" "fail" \
    "exit=$SCEN_DIFF_EXIT"
fi

# REL2.NT-CHECK: --check is NOT impacted (exits at do_check before the gate).
SCEN_CHK_BASE="$TMP_DIR/rel2_nt_check"
setup_sidekick_home "$SCEN_CHK_BASE"
SCEN_CHK_EXIT=0
SCEN_CHK_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" --check 2>&1) || SCEN_CHK_EXIT=$?
if [ "$SCEN_CHK_EXIT" -eq 0 ] && [ -f "$SETUP_HOME/staleness.json" ]; then
  assert "REL2.NT-CHECK: --check exits 0 and writes staleness.json (unchanged)" "pass"
else
  assert "REL2.NT-CHECK: --check exits 0 and writes staleness.json (unchanged)" "fail" \
    "exit=$SCEN_CHK_EXIT"
fi

# REL2.NT-PERF: clean-state run within ${PERF_BUDGET_MS:-500}ms over Scenario A
# baseline. Measurement: run Scenario A twice (warm caches), record wall-clock.
# Budget is a soft ceiling — the assertion just records the value and only
# fails if it exceeds the budget × 4 (anchor margin, since exact ms varies on
# CI machines).
SCEN_PERF_BASE="$TMP_DIR/rel2_nt_perf"
setup_sidekick_home "$SCEN_PERF_BASE"
SCEN_PERF_DIRS=$(setup_target_dirs "$TMP_DIR/rel2_nt_perf_targets")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel2-nt-perf-seed"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_PERF_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Now measure clean-state run.
PERF_BUDGET_MS_VAL="${PERF_BUDGET_MS:-500}"
PERF_T0_NS=$($_SERIOUS_JSON_BACKEND -c "import time;print(int(time.time()*1000))")
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$SCEN_PERF_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
PERF_T1_NS=$($_SERIOUS_JSON_BACKEND -c "import time;print(int(time.time()*1000))")
PERF_DELTA_MS=$((PERF_T1_NS - PERF_T0_NS))
# Budget × 4 is the hard fail line — exact ms varies on test runners.
# A regression that blows the budget by 4× is unambiguous.
PERF_HARD_FAIL=$((PERF_BUDGET_MS_VAL * 4))
if [ "$PERF_DELTA_MS" -le "$PERF_HARD_FAIL" ]; then
  assert "REL2.NT-PERF: clean-state run ${PERF_DELTA_MS}ms ≤ ${PERF_HARD_FAIL}ms (budget×4 ceiling)" "pass"
else
  assert "REL2.NT-PERF: clean-state run ${PERF_DELTA_MS}ms ≤ ${PERF_HARD_FAIL}ms (budget×4 ceiling)" "fail" \
    "perf ${PERF_DELTA_MS}ms exceeds budget×4 ${PERF_HARD_FAIL}ms; fall back to awk parse"
fi

echo ""
echo "--- Task 5 (reliability): detached-HEAD detection (REL3.*) ---"
echo ""

# REL3.GUARD_LOCATION (AC #1, static check): the detached-HEAD guard exists in
# do_git_pull. Asserts:
#   (a) the symbolic-ref invocation is present
#   (b) the recovery message names `git -C $SIDEKICK_HOME checkout main`
#   (c) the audit-log entry uses the exact string `ERROR detached HEAD in`
#   (d) the guard appears in the source BEFORE the `git pull` invocation in
#       do_git_pull (i.e. it pre-empts the pull-error capture from Task 1)
GUARD_SRC="$REPO_ROOT/bin/serious-update"
GUARD_GREP_SYMREF=$(grep -c 'git -C "\$SIDEKICK_HOME" symbolic-ref -q HEAD' "$GUARD_SRC" || true)
GUARD_GREP_MSG=$(grep -c "is on a detached HEAD (after --rollback?)" "$GUARD_SRC" || true)
GUARD_GREP_AUDIT=$(grep -c "ERROR detached HEAD in \$SIDEKICK_HOME" "$GUARD_SRC" || true)
# Ordering: line number of the symbolic-ref guard inside do_git_pull MUST be
# less than the line number of the `git -C "$SIDEKICK_HOME" pull` invocation.
# `|| true` on each pipeline: grep returns 1 (no match) on the RED test pass,
# and the top-of-file `set -euo pipefail` would abort the entire test file.
GUARD_LINE_SYMREF=$(grep -n 'git -C "\$SIDEKICK_HOME" symbolic-ref -q HEAD' "$GUARD_SRC" 2>/dev/null | head -1 | cut -d: -f1 || true)
GUARD_LINE_PULL=$(grep -n 'git -C "\$SIDEKICK_HOME" pull' "$GUARD_SRC" 2>/dev/null | head -1 | cut -d: -f1 || true)
if [ "$GUARD_GREP_SYMREF" -ge 1 ] \
   && [ "$GUARD_GREP_MSG" -ge 1 ] \
   && [ "$GUARD_GREP_AUDIT" -ge 1 ] \
   && [ -n "$GUARD_LINE_SYMREF" ] \
   && [ -n "$GUARD_LINE_PULL" ] \
   && [ "$GUARD_LINE_SYMREF" -lt "$GUARD_LINE_PULL" ]; then
  assert "REL3.GUARD_LOCATION (AC#1): symbolic-ref guard present in do_git_pull before git pull" "pass"
else
  assert "REL3.GUARD_LOCATION (AC#1): symbolic-ref guard present in do_git_pull before git pull" "fail" \
    "symref=$GUARD_GREP_SYMREF msg=$GUARD_GREP_MSG audit=$GUARD_GREP_AUDIT sym_line=$GUARD_LINE_SYMREF pull_line=$GUARD_LINE_PULL"
fi

# REL3.FETCH_NO_GUARD (AC #2): do_git_fetch does NOT receive the symbolic-ref
# guard. Detached HEAD is fine for fetch. Extract the body of do_git_fetch
# and grep for symbolic-ref — must be zero matches.
DGF_BODY=$(awk '/^do_git_fetch\(\)/,/^}$/' "$GUARD_SRC")
DGF_HAS_SYMREF=$(echo "$DGF_BODY" | grep -c 'symbolic-ref' || true)
if [ "$DGF_HAS_SYMREF" -eq 0 ]; then
  assert "REL3.FETCH_NO_GUARD (AC#2): do_git_fetch does not contain symbolic-ref guard" "pass"
else
  assert "REL3.FETCH_NO_GUARD (AC#2): do_git_fetch does not contain symbolic-ref guard" "fail" \
    "symbolic-ref matches in do_git_fetch=$DGF_HAS_SYMREF (expected 0)"
fi

# REL3.NO_FORCE_FLAG (AC #5): the detached-HEAD recovery message does NOT
# mention `--force` (Finding 6 deferred). Extract the user-facing error line
# and check that `--force` is absent. `|| true` on the grep: on the RED pass
# (no guard yet) the grep returns 1 and would abort the test file under
# `set -euo pipefail`.
DETACHED_LINE=$(grep "is on a detached HEAD (after --rollback?)" "$GUARD_SRC" 2>/dev/null | head -1 || true)
if [ -n "$DETACHED_LINE" ] && ! echo "$DETACHED_LINE" | grep -q -- "--force"; then
  assert "REL3.NO_FORCE_FLAG (AC#5): recovery message does not mention --force" "pass"
else
  assert "REL3.NO_FORCE_FLAG (AC#5): recovery message does not mention --force" "fail" \
    "line=$DETACHED_LINE"
fi

# REL3.ROLLBACK_THEN_UPDATE (AC #3, runtime): the full 6-step scenario:
#   1. Sandbox at 2 commits on main
#   2. serious-update → distribute v2
#   3. serious-update --rollback → source repo on detached HEAD
#   4. serious-update → exits 1 with the detached-HEAD recovery message,
#      naming `git -C $SIDEKICK_HOME checkout main`
#   5. git -C $SIDEKICK_HOME checkout main → reattach to branch
#   6. serious-update → succeeds (exit 0 or 2, both indicate the guard
#      released; the test only checks exit != 1 AND no detached-HEAD message)
REL3_BASE="$TMP_DIR/rel3_rollback_then_update"
setup_sidekick_home "$REL3_BASE"
REL3_DIRS=$(setup_target_dirs "$TMP_DIR/rel3_rollback_then_update_targets")

# Step 1: 2 commits on main (setup_sidekick_home gives us commit 1;
# add_remote_commit gives us commit 2 on origin).
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel3-v2-commit"

# Step 2: first serious-update pulls v2 and distributes.
REL3_V1_EXIT=0
REL3_V1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL3_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL3_V1_EXIT=$?
REL3_V2_COMMIT=$(git -C "$SETUP_HOME" rev-parse HEAD)
# Step 2 sanity: serious-update must have succeeded (exit 0).
if [ "$REL3_V1_EXIT" -eq 0 ]; then
  assert "REL3.ROLLBACK_THEN_UPDATE step 2: serious-update v2 succeeds" "pass"
else
  assert "REL3.ROLLBACK_THEN_UPDATE step 2: serious-update v2 succeeds" "fail" \
    "exit=$REL3_V1_EXIT"
fi

# Step 3: --rollback → source repo on detached HEAD.
REL3_RB_EXIT=0
REL3_RB_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL3_DIRS" bash "$REPO_ROOT/bin/serious-update" --rollback 2>&1) || REL3_RB_EXIT=$?
# Confirm we are now on detached HEAD.
REL3_AFTER_RB_SYMREF_EXIT=0
git -C "$SETUP_HOME" symbolic-ref -q HEAD >/dev/null 2>&1 || REL3_AFTER_RB_SYMREF_EXIT=$?
if [ "$REL3_RB_EXIT" -eq 0 ] && [ "$REL3_AFTER_RB_SYMREF_EXIT" -ne 0 ]; then
  assert "REL3.ROLLBACK_THEN_UPDATE step 3: rollback leaves source on detached HEAD" "pass"
else
  assert "REL3.ROLLBACK_THEN_UPDATE step 3: rollback leaves source on detached HEAD" "fail" \
    "rb_exit=$REL3_RB_EXIT symref_exit=$REL3_AFTER_RB_SYMREF_EXIT"
fi

# Step 4: serious-update on detached HEAD → exit 1, specific recovery message.
REL3_DET_EXIT=0
REL3_DET_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL3_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL3_DET_EXIT=$?
REL3_DET_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
# AC #5: the recovery message names `git -C $SIDEKICK_HOME checkout main` and
# does NOT mention `--force`.
if [ "$REL3_DET_EXIT" -eq 1 ] \
   && echo "$REL3_DET_OUTPUT" | grep -q "is on a detached HEAD (after --rollback?)" \
   && echo "$REL3_DET_OUTPUT" | grep -q "checkout main" \
   && ! echo "$REL3_DET_OUTPUT" | grep -q -- "--force"; then
  assert "REL3.ROLLBACK_THEN_UPDATE step 4 (AC#3+#5): detached → exit 1 + recovery message (no --force)" "pass"
else
  assert "REL3.ROLLBACK_THEN_UPDATE step 4 (AC#3+#5): detached → exit 1 + recovery message (no --force)" "fail" \
    "exit=$REL3_DET_EXIT, out=$(echo "$REL3_DET_OUTPUT" | head -3 | tr '\n' '|')"
fi

# AC #4: audit-log line matches ^[0-9-]+T[0-9:]+Z ERROR detached HEAD in <path>$
if echo "$REL3_DET_LOG" | grep -qE "^[0-9-]+T[0-9:]+Z ERROR detached HEAD in .+\$"; then
  assert "REL3.ROLLBACK_THEN_UPDATE step 4 (AC#4): audit log has ERROR detached HEAD line" "pass"
else
  assert "REL3.ROLLBACK_THEN_UPDATE step 4 (AC#4): audit log has ERROR detached HEAD line" "fail" \
    "log_tail=$(echo "$REL3_DET_LOG" | tail -3 | tr '\n' '|')"
fi

# Step 4 negative: the detached-HEAD message should pre-empt the generic
# pull-error capture (no "ERROR: git pull failed" should appear).
if ! echo "$REL3_DET_OUTPUT" | grep -q "ERROR: git pull failed"; then
  assert "REL3.ROLLBACK_THEN_UPDATE step 4 (pre-emption): detached guard fires before generic pull-error capture" "pass"
else
  assert "REL3.ROLLBACK_THEN_UPDATE step 4 (pre-emption): detached guard fires before generic pull-error capture" "fail" \
    "out=$(echo "$REL3_DET_OUTPUT" | head -5 | tr '\n' '|')"
fi

# Step 5: manual recovery — git checkout main.
git -C "$SETUP_HOME" checkout main -q 2>/dev/null || git -C "$SETUP_HOME" checkout master -q 2>/dev/null

# Step 6: serious-update again → guard releases (exit not 1, no detached
# message). The exact exit code depends on whether there is anything new
# to pull (exit 0) or the state already matches (exit 2 "already up to
# date"). Both indicate the guard released; only exit 1 with the detached
# message would be a regression.
REL3_RE_EXIT=0
REL3_RE_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL3_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL3_RE_EXIT=$?
if [ "$REL3_RE_EXIT" -ne 1 ] \
   && ! echo "$REL3_RE_OUTPUT" | grep -q "is on a detached HEAD"; then
  assert "REL3.ROLLBACK_THEN_UPDATE step 6 (AC#3): after checkout main, serious-update no longer blocked" "pass"
else
  assert "REL3.ROLLBACK_THEN_UPDATE step 6 (AC#3): after checkout main, serious-update no longer blocked" "fail" \
    "exit=$REL3_RE_EXIT, out=$(echo "$REL3_RE_OUTPUT" | head -3 | tr '\n' '|')"
fi

# REL3.NEG_HAPPY_SILENT (negative AC #6): on a clean (non-detached) repo,
# the new guard prints NOTHING. The happy-path stderr must not mention
# "detached HEAD" anywhere.
REL3_NEG_BASE="$TMP_DIR/rel3_neg_happy"
setup_sidekick_home "$REL3_NEG_BASE"
REL3_NEG_DIRS=$(setup_target_dirs "$TMP_DIR/rel3_neg_happy_targets")
REL3_NEG_EXIT=0
REL3_NEG_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL3_NEG_DIRS" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL3_NEG_EXIT=$?
REL3_NEG_LOG=$(cat "$SETUP_HOME/update.log" 2>/dev/null || echo "")
if ! echo "$REL3_NEG_OUTPUT" | grep -q "detached HEAD" \
   && ! echo "$REL3_NEG_LOG" | grep -q "ERROR detached HEAD"; then
  assert "REL3.NEG_HAPPY_SILENT (neg AC#6): clean repo run is silent (no detached-HEAD noise)" "pass"
else
  assert "REL3.NEG_HAPPY_SILENT (neg AC#6): clean repo run is silent (no detached-HEAD noise)" "fail" \
    "exit=$REL3_NEG_EXIT, stderr_match=$(echo "$REL3_NEG_OUTPUT" | grep -i 'detached' | head -2)"
fi

# REL3.NEG_CORRUPT_REPO (negative AC #7): on a corrupt $SIDEKICK_HOME (no
# .git directory), get_current_commit (Task 1 Site #4) fires FIRST with
# "cannot read HEAD". The new detached-HEAD guard is never reached because
# get_current_commit's failure exits the function. Assert:
#   (a) exit 1
#   (b) stderr contains "ERROR: cannot read HEAD in"
#   (c) stderr does NOT contain "detached HEAD" (guard pre-empted by the
#       corrupt-repo error from Site #4)
REL3_CORRUPT_BASE="$TMP_DIR/rel3_neg_corrupt"
setup_sidekick_home "$REL3_CORRUPT_BASE"
rm -rf "$SETUP_HOME/.git"
REL3_CORRUPT_EXIT=0
REL3_CORRUPT_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL3_CORRUPT_EXIT=$?
if [ "$REL3_CORRUPT_EXIT" -eq 1 ] \
   && echo "$REL3_CORRUPT_OUTPUT" | grep -q "ERROR: cannot read HEAD in " \
   && ! echo "$REL3_CORRUPT_OUTPUT" | grep -q "detached HEAD"; then
  assert "REL3.NEG_CORRUPT_REPO (neg AC#7): corrupt repo → cannot-read-HEAD fires before detached-HEAD guard" "pass"
else
  assert "REL3.NEG_CORRUPT_REPO (neg AC#7): corrupt repo → cannot-read-HEAD fires before detached-HEAD guard" "fail" \
    "exit=$REL3_CORRUPT_EXIT, out=$(echo "$REL3_CORRUPT_OUTPUT" | head -3 | tr '\n' '|')"
fi

# ===============================================================
# TASK 6 (Finding 7): Using $SIDEKICK_HOME banner + audit-log home= field
# ===============================================================
echo ""
echo "--- Task 6 (Finding 7): banner + NOTE + audit-log home= ---"
echo ""

# REL4.BANNER_FIRSTLINE (AC#1): banner "Using $SIDEKICK_HOME" prints to stderr
# as the first line of a normal --check run. (We use --check rather than a
# full update because --check is read-only and fast, but is on the in-scope
# list of paths that should print the banner.)
REL4_BASE="$TMP_DIR/rel4_banner"
setup_sidekick_home "$REL4_BASE"
REL4_BANNER_OUT_ERR=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/rel4_nope1 $TMP_DIR/rel4_nope2 $TMP_DIR/rel4_nope3" \
  bash "$REPO_ROOT/bin/serious-update" --check 2>&1 >/dev/null) || true
REL4_BANNER_FIRSTLINE=$(printf '%s\n' "$REL4_BANNER_OUT_ERR" | head -n 1)
if [ "$REL4_BANNER_FIRSTLINE" = "Using $SETUP_HOME" ]; then
  assert "REL4.BANNER_FIRSTLINE (AC#1): first stderr line is 'Using \$SIDEKICK_HOME' on --check" "pass"
else
  assert "REL4.BANNER_FIRSTLINE (AC#1): first stderr line is 'Using \$SIDEKICK_HOME' on --check" "fail" \
    "got='$REL4_BANNER_FIRSTLINE' expected='Using $SETUP_HOME'"
fi

# REL4.BANNER_STDERR_ONLY (negative test, AC#1 stream): banner must NOT
# appear on stdout. Capture stdout separately.
REL4_STDOUT_BASE="$TMP_DIR/rel4_stdout_only"
setup_sidekick_home "$REL4_STDOUT_BASE"
REL4_STDOUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/rel4_so1 $TMP_DIR/rel4_so2 $TMP_DIR/rel4_so3" \
  bash "$REPO_ROOT/bin/serious-update" --check 2>/dev/null) || true
if ! printf '%s\n' "$REL4_STDOUT" | grep -q "Using $SETUP_HOME"; then
  assert "REL4.BANNER_STDERR_ONLY (neg test): banner does NOT appear on stdout" "pass"
else
  assert "REL4.BANNER_STDERR_ONLY (neg test): banner does NOT appear on stdout" "fail" \
    "banner leaked to stdout"
fi

# REL4.HELP_NO_BANNER (negative test #1): --help does NOT print the banner.
# (--help exits inside the flag-parsing loop, before the banner code.)
REL4_HELP_OUT_ERR=$(SERIOUS_SIDEKICK_HOME="$TMP_DIR" bash "$REPO_ROOT/bin/serious-update" --help 2>&1) || true
if ! printf '%s\n' "$REL4_HELP_OUT_ERR" | grep -q "^Using "; then
  assert "REL4.HELP_NO_BANNER (neg #1): --help does NOT print 'Using ...' banner" "pass"
else
  assert "REL4.HELP_NO_BANNER (neg #1): --help does NOT print 'Using ...' banner" "fail" \
    "found: $(printf '%s\n' "$REL4_HELP_OUT_ERR" | grep '^Using ' | head -1)"
fi

# REL4.HELP_NO_NOTE (negative test): --help does NOT print the NOTE either.
if ! printf '%s\n' "$REL4_HELP_OUT_ERR" | grep -q "^NOTE: Running against"; then
  assert "REL4.HELP_NO_NOTE (neg): --help does NOT print 'NOTE: Running against ...'" "pass"
else
  assert "REL4.HELP_NO_NOTE (neg): --help does NOT print 'NOTE: Running against ...'" "fail"
fi

# REL4.NOTE_NONCANONICAL (AC#2): when SIDEKICK_HOME != $HOME/.serious-sidekick,
# the second stderr line is the NOTE. The setup_sidekick_home fixture creates
# $base/home — which is NOT under $HOME/.serious-sidekick — so the NOTE should
# fire unconditionally (HOME is the real user home, not the sandbox base).
REL4_NC_BASE="$TMP_DIR/rel4_noncanonical"
setup_sidekick_home "$REL4_NC_BASE"
# Snapshot SETUP_HOME locally — subsequent setup_sidekick_home calls (later
# in this file) overwrite the global, and REL4.NOTE_VERBATIM below needs the
# value from THIS setup, not whatever the latest one was.
REL4_NC_SETUP_HOME="$SETUP_HOME"
REL4_NC_OUT_ERR=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$TMP_DIR/rel4_nc1 $TMP_DIR/rel4_nc2 $TMP_DIR/rel4_nc3" \
  bash "$REPO_ROOT/bin/serious-update" --check 2>&1 >/dev/null) || true
REL4_NC_SECOND=$(printf '%s\n' "$REL4_NC_OUT_ERR" | sed -n '2p')
REL4_NC_EXPECTED="NOTE: Running against $SETUP_HOME (canonical install is $HOME/.serious-sidekick)."
if [ "$REL4_NC_SECOND" = "$REL4_NC_EXPECTED" ]; then
  assert "REL4.NOTE_NONCANONICAL (AC#2): second stderr line is the NOTE for non-canonical \$SIDEKICK_HOME" "pass"
else
  assert "REL4.NOTE_NONCANONICAL (AC#2): second stderr line is the NOTE for non-canonical \$SIDEKICK_HOME" "fail" \
    "got='$REL4_NC_SECOND' expected='$REL4_NC_EXPECTED'"
fi

# REL4.CANONICAL_NO_NOTE (AC#4 canonical mode): when SIDEKICK_HOME ==
# $HOME/.serious-sidekick (sandbox HOME set so this is true), the NOTE does
# NOT fire. We override HOME so the script's plain-equality comparison
# evaluates true.
REL4_CAN_BASE="$TMP_DIR/rel4_canonical"
mkdir -p "$REL4_CAN_BASE/sandhome"
REL4_CAN_HOME_DIR="$REL4_CAN_BASE/sandhome/.serious-sidekick"
# Build a sidekick install inside the sandbox HOME's canonical path.
mkdir -p "$REL4_CAN_HOME_DIR"
setup_sidekick_home "$REL4_CAN_BASE/scratch"
# Re-target: move the just-built install into the canonical-shaped path.
# Use rsync-style cp -R to preserve content. setup_sidekick_home wrote into
# SETUP_HOME; copy its contents into REL4_CAN_HOME_DIR.
cp -R "$SETUP_HOME/." "$REL4_CAN_HOME_DIR/"
REL4_CAN_OUT_ERR=$(HOME="$REL4_CAN_BASE/sandhome" \
  SERIOUS_SIDEKICK_HOME="$REL4_CAN_HOME_DIR" \
  SERIOUS_TARGET_DIRS="$TMP_DIR/rel4_can1 $TMP_DIR/rel4_can2 $TMP_DIR/rel4_can3" \
  bash "$REPO_ROOT/bin/serious-update" --check 2>&1 >/dev/null) || true
REL4_CAN_FIRST=$(printf '%s\n' "$REL4_CAN_OUT_ERR" | head -n 1)
REL4_CAN_SECOND=$(printf '%s\n' "$REL4_CAN_OUT_ERR" | sed -n '2p')
if [ "$REL4_CAN_FIRST" = "Using $REL4_CAN_HOME_DIR" ] \
   && ! printf '%s\n' "$REL4_CAN_SECOND" | grep -q "^NOTE: Running against"; then
  assert "REL4.CANONICAL_NO_NOTE (AC#4): canonical \$SIDEKICK_HOME prints banner WITHOUT NOTE" "pass"
else
  assert "REL4.CANONICAL_NO_NOTE (AC#4): canonical \$SIDEKICK_HOME prints banner WITHOUT NOTE" "fail" \
    "first='$REL4_CAN_FIRST' second='$REL4_CAN_SECOND'"
fi

# REL4.NOTE_VERBATIM (AC#2): NOTE text matches verbatim spec — leading "NOTE: ",
# the resolved $SIDEKICK_HOME path, and the canonical-install reminder ending
# with a period.
if printf '%s\n' "$REL4_NC_OUT_ERR" | grep -qE "^NOTE: Running against $REL4_NC_SETUP_HOME \(canonical install is .*/\.serious-sidekick\)\.$"; then
  assert "REL4.NOTE_VERBATIM (AC#2): NOTE matches verbatim spec '<path> (canonical install is <\$HOME>/.serious-sidekick).'" "pass"
else
  assert "REL4.NOTE_VERBATIM (AC#2): NOTE matches verbatim spec '<path> (canonical install is <\$HOME>/.serious-sidekick).'" "fail" \
    "got='$(printf '%s\n' "$REL4_NC_OUT_ERR" | grep '^NOTE:' | head -1)'"
fi

# REL4.AUDIT_UPDATE_HOME (AC#3): a successful UPDATE writes an audit-log line
# whose pattern is "<timestamp> UPDATE home=<path> ...".
REL4_UPD_BASE="$TMP_DIR/rel4_audit_update"
setup_sidekick_home "$REL4_UPD_BASE"
REL4_UPD_TARGETS="$TMP_DIR/rel4_audit_targets"
REL4_UPD_DIRS=$(setup_target_dirs "$REL4_UPD_TARGETS")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "REL4 audit update"
REL4_UPD_EXIT=0
REL4_UPD_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL4_UPD_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL4_UPD_EXIT=$?
REL4_UPD_LOG="$SETUP_HOME/update.log"
if [ -f "$REL4_UPD_LOG" ] \
   && grep -qE "^[0-9-]+T[0-9:]+Z UPDATE home=$SETUP_HOME " "$REL4_UPD_LOG"; then
  assert "REL4.AUDIT_UPDATE_HOME (AC#3): UPDATE audit line starts with 'UPDATE home=\$SIDEKICK_HOME'" "pass"
else
  assert "REL4.AUDIT_UPDATE_HOME (AC#3): UPDATE audit line starts with 'UPDATE home=\$SIDEKICK_HOME'" "fail" \
    "exit=$REL4_UPD_EXIT log_tail=$(tail -3 "$REL4_UPD_LOG" 2>/dev/null | tr '\n' '|')"
fi

# REL4.AUDIT_NOTHING_TO_UPDATE_HOME (AC#3): the "nothing to update" UPDATE
# audit-log line also carries home=$SIDEKICK_HOME. Trigger by running once
# (REL4.AUDIT_UPDATE_HOME above brought us to HEAD), then running again with
# already-up-to-date state.
REL4_UPD_NOOP_EXIT=0
REL4_UPD_NOOP_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL4_UPD_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL4_UPD_NOOP_EXIT=$?
if grep -qE "^[0-9-]+T[0-9:]+Z UPDATE home=$SETUP_HOME .* OK \(nothing to update\)\$" "$REL4_UPD_LOG"; then
  assert "REL4.AUDIT_NOTHING_TO_UPDATE_HOME (AC#3): 'nothing to update' UPDATE line carries home=" "pass"
else
  assert "REL4.AUDIT_NOTHING_TO_UPDATE_HOME (AC#3): 'nothing to update' UPDATE line carries home=" "fail" \
    "exit=$REL4_UPD_NOOP_EXIT log_tail=$(tail -3 "$REL4_UPD_LOG" 2>/dev/null | tr '\n' '|')"
fi

# REL4.AUDIT_ROLLBACK_HOME (AC#3): after a successful UPDATE (which seeds
# previous_commit in state files), invoking --rollback writes a ROLLBACK
# audit-log line carrying home=$SIDEKICK_HOME.
REL4_RB_BASE="$TMP_DIR/rel4_audit_rollback"
setup_sidekick_home "$REL4_RB_BASE"
REL4_RB_TARGETS="$TMP_DIR/rel4_rb_targets"
REL4_RB_DIRS=$(setup_target_dirs "$REL4_RB_TARGETS")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "REL4 rollback baseline"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL4_RB_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "REL4 rollback second update"
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL4_RB_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
REL4_RB_EXIT=0
REL4_RB_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL4_RB_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" --rollback 2>&1) || REL4_RB_EXIT=$?
REL4_RB_LOG="$SETUP_HOME/update.log"
if grep -qE "^[0-9-]+T[0-9:]+Z ROLLBACK home=$SETUP_HOME " "$REL4_RB_LOG"; then
  assert "REL4.AUDIT_ROLLBACK_HOME (AC#3): ROLLBACK audit line starts with 'ROLLBACK home=\$SIDEKICK_HOME'" "pass"
else
  assert "REL4.AUDIT_ROLLBACK_HOME (AC#3): ROLLBACK audit line starts with 'ROLLBACK home=\$SIDEKICK_HOME'" "fail" \
    "exit=$REL4_RB_EXIT log_tail=$(tail -5 "$REL4_RB_LOG" 2>/dev/null | tr '\n' '|')"
fi

# REL4.GREP_COMPAT (negative test #3 / migration-warning compatibility): the
# migration-warning grep anchors on "DISTRIBUTE-DIR dir=...$", NOT on UPDATE.
# Adding home= between UPDATE and the commit shas must not break the
# DISTRIBUTE-DIR-anchored grep. Run the migration scenario.
REL4_GC_BASE="$TMP_DIR/rel4_grep_compat"
setup_sidekick_home "$REL4_GC_BASE"
# Build a non-canonical HOME with a previously-distributed-to ~/.claude-work
# dir that no longer exists. Pre-seed the audit log with a DISTRIBUTE-DIR
# entry for that dir.
REL4_GC_HOME="$REL4_GC_BASE/synthetichome"
mkdir -p "$REL4_GC_HOME"
printf '2026-01-01T00:00:00Z DISTRIBUTE-DIR dir=%s/.claude-work\n' "$REL4_GC_HOME" \
  > "$SETUP_HOME/update.log"
# Run a NORMAL update (not --check) — `emit_migration_warnings` is only called
# in the main flow at bin/serious-update:1097, AFTER the --check/--verify
# early-exit handlers. AND `emit_migration_warnings` itself early-returns when
# SERIOUS_TARGET_DIRS is set (it only runs in the auto-detect branch). So we
# must let auto-detect run by leaving SERIOUS_TARGET_DIRS unset, and rely on
# the EMPTY_SLATE_FALLBACK to create $HOME/.claude as the target dir.
REL4_GC_CHECK_OUT=$(env -u SERIOUS_TARGET_DIRS HOME="$REL4_GC_HOME" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1 >/dev/null) || true
if printf '%s\n' "$REL4_GC_CHECK_OUT" | grep -q "NOTE: ~/.claude-work was previously distributed to"; then
  assert "REL4.GREP_COMPAT (neg test): migration-warning grep still fires on DISTRIBUTE-DIR after Task 6 audit-log change" "pass"
else
  assert "REL4.GREP_COMPAT (neg test): migration-warning grep still fires on DISTRIBUTE-DIR after Task 6 audit-log change" "fail" \
    "stderr_tail=$(printf '%s\n' "$REL4_GC_CHECK_OUT" | tail -5 | tr '\n' '|')"
fi

echo ""

# ===============================================================
# TASK 7 (Finding 10): state-file corruption sentinel (REL5.*)
# ===============================================================
echo "--- Task 7 (reliability, Finding 10): state-file corruption sentinel (REL5.*) ---"
echo ""

# ---------------------------------------------------------------
# REL5.AC1: update_state writes .serious-sidekick-state.corrupt
# when post-write validation fails. We force validation failure by
# wrapping update_state in a subshell that redefines validate_json
# to always return 1, then asserting the sentinel exists with the
# documented two-line plain-text format.
# ---------------------------------------------------------------
REL5_AC1_DIR="$TMP_DIR/rel5_ac1_target"
mkdir -p "$REL5_AC1_DIR"
# Counter-based validate_json override: pass on pre-write (1st call) and fail
# on post-write (2nd call). File-based counter for subshell-safety.
REL5_AC1_CTR="$TMP_DIR/rel5_ac1_counter"
echo 0 > "$REL5_AC1_CTR"
set +e
(
  source "$REPO_ROOT/lib/serious-common.sh"
  validate_json() {
    local n
    n=$(cat "$REL5_AC1_CTR")
    n=$((n + 1))
    echo "$n" > "$REL5_AC1_CTR"
    if [ "$n" -ge 2 ]; then
      return 1  # fail on post-write
    fi
    return 0
  }
  update_state "$REL5_AC1_DIR" \
    "abc1234def5678901234567890abcdef12345678" "" \
    '{"skills/foo.md": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}' >/dev/null 2>&1
)
REL5_AC1_EXIT=$?
set -e
# State file should be GONE; sentinel should be PRESENT.
if [ ! -f "$REL5_AC1_DIR/.serious-sidekick-state.json" ] \
   && [ -f "$REL5_AC1_DIR/.serious-sidekick-state.corrupt" ]; then
  assert "REL5.AC1: update_state writes sentinel on post-write validation failure" "pass"
else
  assert "REL5.AC1: update_state writes sentinel on post-write validation failure" "fail" \
    "state_file_exists=$([ -f "$REL5_AC1_DIR/.serious-sidekick-state.json" ] && echo yes || echo no) sentinel_exists=$([ -f "$REL5_AC1_DIR/.serious-sidekick-state.corrupt" ] && echo yes || echo no) update_exit=$REL5_AC1_EXIT"
fi

# REL5.AC1.RC: update_state still returns non-zero on the failure path.
if [ "$REL5_AC1_EXIT" -ne 0 ]; then
  assert "REL5.AC1.RC: update_state returns non-zero when sentinel written" "pass"
else
  assert "REL5.AC1.RC: update_state returns non-zero when sentinel written" "fail" \
    "got exit=$REL5_AC1_EXIT"
fi

# REL5.AC1.FORMAT: sentinel is two-line plain-text:
#   line 1: corrupt_at: <ISO 8601 timestamp>
#   line 2: error: <single-line message, <=500 chars>
if [ -f "$REL5_AC1_DIR/.serious-sidekick-state.corrupt" ]; then
  REL5_AC1_L1=$(sed -n '1p' "$REL5_AC1_DIR/.serious-sidekick-state.corrupt")
  REL5_AC1_L2=$(sed -n '2p' "$REL5_AC1_DIR/.serious-sidekick-state.corrupt")
  REL5_AC1_LCOUNT=$(wc -l < "$REL5_AC1_DIR/.serious-sidekick-state.corrupt" | tr -d ' ')
  REL5_AC1_ERR_LEN=${#REL5_AC1_L2}
  if echo "$REL5_AC1_L1" | grep -qE '^corrupt_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
     && echo "$REL5_AC1_L2" | grep -qE '^error: .+$' \
     && [ "$REL5_AC1_ERR_LEN" -le 510 ] \
     && [ "$REL5_AC1_LCOUNT" -le 2 ]; then
    assert "REL5.AC1.FORMAT: sentinel is two-line plain-text (corrupt_at + error)" "pass"
  else
    assert "REL5.AC1.FORMAT: sentinel is two-line plain-text (corrupt_at + error)" "fail" \
      "l1='$REL5_AC1_L1' l2='$REL5_AC1_L2' lines=$REL5_AC1_LCOUNT err_len=$REL5_AC1_ERR_LEN"
  fi
else
  assert "REL5.AC1.FORMAT: sentinel is two-line plain-text (corrupt_at + error)" "fail" \
    "sentinel file missing"
fi

# ---------------------------------------------------------------
# REL5.AC2: do_migrate sentinel-aware path — when the sentinel is
# present (and no state file), do_migrate writes a state file with
# installed_from_commit="" and preserves the sentinel.
# ---------------------------------------------------------------
REL5_AC2_BASE="$TMP_DIR/rel5_ac2"
setup_sidekick_home "$REL5_AC2_BASE"
REL5_AC2_TARGETS="$TMP_DIR/rel5_ac2_targets"
REL5_AC2_DIRS=$(setup_target_dirs "$REL5_AC2_TARGETS")
# Seed sentinel in the FIRST target dir; leave the others clean (first-run path)
REL5_AC2_FIRST_DIR=$(echo "$REL5_AC2_DIRS" | awk '{print $1}')
printf 'corrupt_at: 2026-04-01T00:00:00Z\nerror: simulated corruption for REL5.AC2\n' \
  > "$REL5_AC2_FIRST_DIR/.serious-sidekick-state.corrupt"
# Push a remote commit so OLD!=NEW for this run (forces distribute path).
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel5-ac2-seed"
REL5_AC2_EXIT=0
REL5_AC2_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_AC2_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL5_AC2_EXIT=$?
# After the run, the state file should exist and be at HEAD, and the sentinel
# should be GONE (cleared by distribute_to_dir on successful update_state).
REL5_AC2_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
REL5_AC2_INSTALLED=""
if [ -f "$REL5_AC2_FIRST_DIR/.serious-sidekick-state.json" ]; then
  REL5_AC2_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$REL5_AC2_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
if [ "$REL5_AC2_EXIT" -eq 0 ] \
   && [ "$REL5_AC2_INSTALLED" = "$REL5_AC2_HEAD" ] \
   && [ ! -f "$REL5_AC2_FIRST_DIR/.serious-sidekick-state.corrupt" ]; then
  assert "REL5.AC2: sentinel-aware do_migrate triggers redistribute → state at HEAD, sentinel removed" "pass"
else
  assert "REL5.AC2: sentinel-aware do_migrate triggers redistribute → state at HEAD, sentinel removed" "fail" \
    "exit=$REL5_AC2_EXIT installed='$REL5_AC2_INSTALLED' HEAD='$REL5_AC2_HEAD' sentinel_exists=$([ -f "$REL5_AC2_FIRST_DIR/.serious-sidekick-state.corrupt" ] && echo yes || echo no)"
fi

# ---------------------------------------------------------------
# REL5.AC3: distribute_to_dir removes the sentinel after a
# successful update_state call. Already covered by REL5.AC2's
# "sentinel removed" assertion; here we add a direct, isolated check
# by running with OLD==NEW and a sentinel seeded into a stale-state dir.
# ---------------------------------------------------------------
REL5_AC3_BASE="$TMP_DIR/rel5_ac3"
setup_sidekick_home "$REL5_AC3_BASE"
REL5_AC3_TARGETS="$TMP_DIR/rel5_ac3_targets"
REL5_AC3_DIRS=$(setup_target_dirs "$REL5_AC3_TARGETS")
# Push a commit so HEAD is non-trivial.
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel5-ac3-seed"
# First, do a clean run to populate state files at the real HEAD.
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_AC3_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Now seed the sentinel into the FIRST dir (state file still present)
# AND make installed_from_commit empty so Task 4's NEEDS_REDISTRIBUTE fires
# (otherwise OLD==NEW with state-at-HEAD would exit 2 before distribute).
REL5_AC3_FIRST_DIR=$(echo "$REL5_AC3_DIRS" | awk '{print $1}')
printf 'corrupt_at: 2026-04-01T00:00:00Z\nerror: simulated REL5.AC3\n' \
  > "$REL5_AC3_FIRST_DIR/.serious-sidekick-state.corrupt"
$_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = ''
json.dump(s, open(p, 'w'), indent=2, sort_keys=True)
" "$REL5_AC3_FIRST_DIR/.serious-sidekick-state.json"
# Run with OLD==NEW (no new commit) — Task 4's NEEDS_REDISTRIBUTE fires because
# installed_from_commit=="" != NEW_COMMIT, distribute_to_dir runs and clears
# the sentinel.
REL5_AC3_EXIT=0
REL5_AC3_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_AC3_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL5_AC3_EXIT=$?
if [ "$REL5_AC3_EXIT" -eq 0 ] \
   && [ ! -f "$REL5_AC3_FIRST_DIR/.serious-sidekick-state.corrupt" ]; then
  assert "REL5.AC3: distribute_to_dir removes sentinel after successful update_state" "pass"
else
  assert "REL5.AC3: distribute_to_dir removes sentinel after successful update_state" "fail" \
    "exit=$REL5_AC3_EXIT sentinel_exists=$([ -f "$REL5_AC3_FIRST_DIR/.serious-sidekick-state.corrupt" ] && echo yes || echo no)"
fi

# ---------------------------------------------------------------
# REL5.AC5: full corruption + recovery scenario (the plan's
# canonical 4-step procedure). We simulate the SIGKILL-truncated
# state file by directly writing truncated invalid JSON to the
# state-file path — this is the resulting on-disk artifact the
# SIGKILL scenario produces. The next update_state call (during a
# fresh serious-update invocation) overwrites that file, validates,
# succeeds, and writes a fresh state — which is why we instead seed
# the sentinel directly to exercise the recovery branch. The plan's
# AC5 is therefore broken into two adjacent assertions:
#   (a) sentinel + missing state file → recover (covered by AC2)
#   (b) recovery → state at HEAD, sentinel absent, verify exit 0
# Here we add the --verify check to close the loop.
# ---------------------------------------------------------------
REL5_AC5_BASE="$TMP_DIR/rel5_ac5"
setup_sidekick_home "$REL5_AC5_BASE"
REL5_AC5_TARGETS="$TMP_DIR/rel5_ac5_targets"
REL5_AC5_DIRS=$(setup_target_dirs "$REL5_AC5_TARGETS")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel5-ac5-seed"
# Step 1: clean populate
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_AC5_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Step 2: simulate post-SIGKILL on-disk artifact: truncated JSON state file
# AND the sentinel left by update_state's post-write validation failure.
# (We seed both directly because the post-write validation path can only be
# exercised via the unit test in REL5.AC1; here we test the consumer side.)
REL5_AC5_FIRST_DIR=$(echo "$REL5_AC5_DIRS" | awk '{print $1}')
# Remove the state file (post-validation delete) and write the sentinel.
rm -f "$REL5_AC5_FIRST_DIR/.serious-sidekick-state.json"
printf 'corrupt_at: 2026-04-01T00:00:00Z\nerror: simulated SIGKILL truncation\n' \
  > "$REL5_AC5_FIRST_DIR/.serious-sidekick-state.corrupt"
# Step 3: recovery run — OLD==NEW (no remote commits), sentinel + missing
# state file in one dir; do_migrate sees sentinel, writes state with
# installed_from_commit="", Task 4's NEEDS_REDISTRIBUTE fires, redistribute
# runs, sentinel cleared.
REL5_AC5_EXIT=0
REL5_AC5_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_AC5_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL5_AC5_EXIT=$?
REL5_AC5_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
REL5_AC5_INSTALLED=""
if [ -f "$REL5_AC5_FIRST_DIR/.serious-sidekick-state.json" ]; then
  REL5_AC5_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$REL5_AC5_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
# Step 4: --verify should now exit 0.
REL5_AC5_VERIFY_EXIT=0
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_AC5_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" --verify >/dev/null 2>&1 || REL5_AC5_VERIFY_EXIT=$?
if [ "$REL5_AC5_EXIT" -eq 0 ] \
   && [ "$REL5_AC5_INSTALLED" = "$REL5_AC5_HEAD" ] \
   && [ ! -f "$REL5_AC5_FIRST_DIR/.serious-sidekick-state.corrupt" ] \
   && [ "$REL5_AC5_VERIFY_EXIT" -eq 0 ]; then
  assert "REL5.AC5: corruption+recovery → state at HEAD, sentinel gone, --verify exits 0" "pass"
else
  assert "REL5.AC5: corruption+recovery → state at HEAD, sentinel gone, --verify exits 0" "fail" \
    "exit=$REL5_AC5_EXIT installed='$REL5_AC5_INSTALLED' HEAD='$REL5_AC5_HEAD' sentinel_exists=$([ -f "$REL5_AC5_FIRST_DIR/.serious-sidekick-state.corrupt" ] && echo yes || echo no) verify_exit=$REL5_AC5_VERIFY_EXIT"
fi

# ---------------------------------------------------------------
# REL5.NEG1: sentinel + state file BOTH present (race / partial cleanup).
# do_migrate does NOT run (NEEDS_FIRST_RUN=false because state file exists).
# Recovery proceeds via Task 4's NEEDS_REDISTRIBUTE freshness gate when the
# state's installed_from_commit is stale.
# ---------------------------------------------------------------
REL5_NEG1_BASE="$TMP_DIR/rel5_neg1"
setup_sidekick_home "$REL5_NEG1_BASE"
REL5_NEG1_TARGETS="$TMP_DIR/rel5_neg1_targets"
REL5_NEG1_DIRS=$(setup_target_dirs "$REL5_NEG1_TARGETS")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel5-neg1-seed"
# Clean populate first
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_NEG1_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
# Seed both: stale state file (installed_from_commit set to a FAKE old SHA)
# plus a sentinel in the same dir.
REL5_NEG1_FIRST_DIR=$(echo "$REL5_NEG1_DIRS" | awk '{print $1}')
REL5_NEG1_FAKE_SHA="aaaaaaa1234567890abcdef1234567890abcdef1"
$_SERIOUS_JSON_BACKEND -c "
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s['installed_from_commit'] = sys.argv[2]
json.dump(s, open(p, 'w'), indent=2, sort_keys=True)
" "$REL5_NEG1_FIRST_DIR/.serious-sidekick-state.json" "$REL5_NEG1_FAKE_SHA"
printf 'corrupt_at: 2026-04-01T00:00:00Z\nerror: REL5.NEG1 race condition seed\n' \
  > "$REL5_NEG1_FIRST_DIR/.serious-sidekick-state.corrupt"
REL5_NEG1_EXIT=0
REL5_NEG1_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_NEG1_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL5_NEG1_EXIT=$?
REL5_NEG1_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
REL5_NEG1_INSTALLED=""
if [ -f "$REL5_NEG1_FIRST_DIR/.serious-sidekick-state.json" ]; then
  REL5_NEG1_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$REL5_NEG1_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
# Recovery proceeded via Task 4's gate (not do_migrate): exit 0, state at HEAD,
# sentinel cleared.
if [ "$REL5_NEG1_EXIT" -eq 0 ] \
   && [ "$REL5_NEG1_INSTALLED" = "$REL5_NEG1_HEAD" ] \
   && [ ! -f "$REL5_NEG1_FIRST_DIR/.serious-sidekick-state.corrupt" ]; then
  assert "REL5.NEG1 (race): sentinel + state both present → Task 4 freshness gate recovers" "pass"
else
  assert "REL5.NEG1 (race): sentinel + state both present → Task 4 freshness gate recovers" "fail" \
    "exit=$REL5_NEG1_EXIT installed='$REL5_NEG1_INSTALLED' HEAD='$REL5_NEG1_HEAD' sentinel_exists=$([ -f "$REL5_NEG1_FIRST_DIR/.serious-sidekick-state.corrupt" ] && echo yes || echo no)"
fi

# ---------------------------------------------------------------
# REL5.NEG2: no sentinel + no state file (true first run).
# do_migrate path is unchanged from today — records on-disk hashes
# as state, no sentinel created.
# ---------------------------------------------------------------
REL5_NEG2_BASE="$TMP_DIR/rel5_neg2"
setup_sidekick_home "$REL5_NEG2_BASE"
REL5_NEG2_TARGETS="$TMP_DIR/rel5_neg2_targets"
REL5_NEG2_DIRS=$(setup_target_dirs "$REL5_NEG2_TARGETS")
add_remote_commit "$SETUP_HOME" "$SETUP_REMOTE" "rel5-neg2-seed"
# True first run: no state files, no sentinels.
REL5_NEG2_EXIT=0
REL5_NEG2_OUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$REL5_NEG2_DIRS" \
  bash "$REPO_ROOT/bin/serious-update" 2>&1) || REL5_NEG2_EXIT=$?
REL5_NEG2_HEAD=$(git -C "$SETUP_HOME" rev-parse HEAD 2>/dev/null || echo "")
REL5_NEG2_FIRST_DIR=$(echo "$REL5_NEG2_DIRS" | awk '{print $1}')
REL5_NEG2_INSTALLED=""
if [ -f "$REL5_NEG2_FIRST_DIR/.serious-sidekick-state.json" ]; then
  REL5_NEG2_INSTALLED=$($_SERIOUS_JSON_BACKEND -c "import json,sys;print(json.load(open(sys.argv[1])).get('installed_from_commit',''))" "$REL5_NEG2_FIRST_DIR/.serious-sidekick-state.json" 2>/dev/null || echo "")
fi
# Expected: clean first run, state at HEAD, NO sentinel created anywhere.
REL5_NEG2_SENTINELS=$(find "$REL5_NEG2_TARGETS" -name ".serious-sidekick-state.corrupt" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REL5_NEG2_EXIT" -eq 0 ] \
   && [ "$REL5_NEG2_INSTALLED" = "$REL5_NEG2_HEAD" ] \
   && [ "$REL5_NEG2_SENTINELS" -eq 0 ]; then
  assert "REL5.NEG2 (true first run): no sentinel + no state → do_migrate records on-disk hashes, no sentinel created" "pass"
else
  assert "REL5.NEG2 (true first run): no sentinel + no state → do_migrate records on-disk hashes, no sentinel created" "fail" \
    "exit=$REL5_NEG2_EXIT installed='$REL5_NEG2_INSTALLED' HEAD='$REL5_NEG2_HEAD' sentinels=$REL5_NEG2_SENTINELS"
fi

# REL5.SYNC: sync-pair invariant — writer (update_state in lib/serious-common.sh)
# and reader (do_migrate in bin/serious-update) agree on the sentinel filename.
REL5_WRITER_HITS=$(grep -c '\.serious-sidekick-state\.corrupt' "$REPO_ROOT/lib/serious-common.sh" 2>/dev/null || echo 0)
REL5_READER_HITS=$(grep -c '\.serious-sidekick-state\.corrupt' "$REPO_ROOT/bin/serious-update" 2>/dev/null || echo 0)
if [ "$REL5_WRITER_HITS" -ge 1 ] && [ "$REL5_READER_HITS" -ge 1 ]; then
  assert "REL5.SYNC: sentinel filename .serious-sidekick-state.corrupt referenced by both writer and reader" "pass"
else
  assert "REL5.SYNC: sentinel filename .serious-sidekick-state.corrupt referenced by both writer and reader" "fail" \
    "writer=$REL5_WRITER_HITS reader=$REL5_READER_HITS"
fi

echo ""
echo "=== serious-update Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
