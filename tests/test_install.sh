#!/bin/bash
# test_install.sh — Tests for install.sh
#
# Uses SERIOUS_SIDEKICK_HOME, SERIOUS_LOCAL_BIN, and SERIOUS_REPO_URL overrides.
# Never touches real ~/.serious-sidekick/ or ~/.local/bin/.
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
# Helper: Create a simulated remote repo to clone from
# Sets SETUP_REMOTE to the bare repo path
# ---------------------------------------------------------------
setup_remote_repo() {
  local base_dir="$1"
  local staging_dir="$base_dir/staging"
  local remote_dir="$base_dir/remote.git"

  mkdir -p "$staging_dir"
  cd "$staging_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  # Copy real files from the template repo
  cp "$REPO_ROOT/manifest.json" "$staging_dir/manifest.json"
  cp "$REPO_ROOT/install.sh" "$staging_dir/install.sh"
  chmod +x "$staging_dir/install.sh"
  mkdir -p "$staging_dir/lib"
  cp "$REPO_ROOT/lib/serious-common.sh" "$staging_dir/lib/serious-common.sh"
  cp "$REPO_ROOT/lib/serious-cron.sh" "$staging_dir/lib/serious-cron.sh"
  mkdir -p "$staging_dir/bin"
  cp "$REPO_ROOT/bin/serious-update" "$staging_dir/bin/serious-update"
  chmod +x "$staging_dir/bin/serious-update"

  # Copy .claude directory
  if [ -d "$REPO_ROOT/.claude" ]; then
    cp -R "$REPO_ROOT/.claude" "$staging_dir/.claude"
  fi

  # Copy root-level template files
  for f in CLAUDE.md _anti-rationalization-core.md _implementation_plan_template_v6.md; do
    [ -f "$REPO_ROOT/$f" ] && cp "$REPO_ROOT/$f" "$staging_dir/$f"
  done

  git add -A
  git commit -q -m "Initial commit"

  # Create bare remote
  git clone -q --bare "$staging_dir" "$remote_dir"

  cd "$REPO_ROOT"
  rm -rf "$staging_dir"

  SETUP_REMOTE="$remote_dir"
}

# Helper: run install.sh with overrides
run_install() {
  local home="$1"
  local bin="$2"
  local remote="$3"
  shift 3
  # Remaining args passed to install.sh
  SERIOUS_SIDEKICK_HOME="$home" \
  SERIOUS_LOCAL_BIN="$bin" \
  SERIOUS_REPO_URL="$remote" \
    bash "$REPO_ROOT/install.sh" "$@" 2>&1
}

echo "=== Test: install.sh ==="
echo ""

# ---------------------------------------------------------------
# Test 1: Prerequisites check — git detection
# ---------------------------------------------------------------
echo "--- Prerequisites: git detection ---"
echo ""

T1_BASE="$TMP_DIR/t1"
setup_remote_repo "$T1_BASE"
T1_HOME="$TMP_DIR/t1_home"
T1_BIN="$TMP_DIR/t1_bin"

T1_OUTPUT=$(run_install "$T1_HOME" "$T1_BIN" "$SETUP_REMOTE" --no-cron 2>&1) || true

if echo "$T1_OUTPUT" | grep -q "git"; then
  assert "Prerequisites: reports git status" "pass"
else
  assert "Prerequisites: reports git status" "fail" "output: $(echo "$T1_OUTPUT" | head -5)"
fi

echo ""

# ---------------------------------------------------------------
# Test 2: Prerequisites check — python3/jq detection
# ---------------------------------------------------------------
echo "--- Prerequisites: python3/jq detection ---"
echo ""

if echo "$T1_OUTPUT" | grep -qE "python3|jq"; then
  assert "Prerequisites: reports python3 or jq status" "pass"
else
  assert "Prerequisites: reports python3 or jq status" "fail"
fi

echo ""

# ---------------------------------------------------------------
# Test 3: Clone to temp dir
# ---------------------------------------------------------------
echo "--- Clone to temp dir ---"
echo ""

T3_BASE="$TMP_DIR/t3"
setup_remote_repo "$T3_BASE"
T3_HOME="$TMP_DIR/t3_home"
T3_BIN="$TMP_DIR/t3_bin"

T3_OUTPUT=$(run_install "$T3_HOME" "$T3_BIN" "$SETUP_REMOTE" --no-cron 2>&1) || true

# AC: Directory created
if [ -d "$T3_HOME" ]; then
  assert "Clone: creates SIDEKICK_HOME directory" "pass"
else
  assert "Clone: creates SIDEKICK_HOME directory" "fail"
fi

# AC: It's a git repo
if [ -d "$T3_HOME/.git" ]; then
  assert "Clone: SIDEKICK_HOME is a git repo" "pass"
else
  assert "Clone: SIDEKICK_HOME is a git repo" "fail"
fi

# AC: manifest.json present
if [ -f "$T3_HOME/manifest.json" ]; then
  assert "Clone: manifest.json present" "pass"
else
  assert "Clone: manifest.json present" "fail"
fi

# AC: bin/serious-update present
if [ -f "$T3_HOME/bin/serious-update" ]; then
  assert "Clone: bin/serious-update present" "pass"
else
  assert "Clone: bin/serious-update present" "fail"
fi

echo ""

# ---------------------------------------------------------------
# Test 4: Symlink creation
# ---------------------------------------------------------------
echo "--- Symlink creation ---"
echo ""

# AC: LOCAL_BIN directory created
if [ -d "$T3_BIN" ]; then
  assert "Symlink: LOCAL_BIN directory created" "pass"
else
  assert "Symlink: LOCAL_BIN directory created" "fail"
fi

# AC: Symlink exists
if [ -L "$T3_BIN/serious-update" ]; then
  assert "Symlink: serious-update symlink exists" "pass"
else
  assert "Symlink: serious-update symlink exists" "fail"
fi

# AC: Symlink points to the right place
LINK_TARGET=$(readlink "$T3_BIN/serious-update" 2>/dev/null || echo "")
if [ "$LINK_TARGET" = "$T3_HOME/bin/serious-update" ]; then
  assert "Symlink: points to correct target" "pass"
else
  assert "Symlink: points to correct target" "fail" "target: $LINK_TARGET"
fi

echo ""

# ---------------------------------------------------------------
# Test 5: Already-exists handling (pull instead of clone)
# ---------------------------------------------------------------
echo "--- Already-exists: pull instead of clone ---"
echo ""

T5_BASE="$TMP_DIR/t5"
setup_remote_repo "$T5_BASE"
T5_HOME="$TMP_DIR/t5_home"
T5_BIN="$TMP_DIR/t5_bin"

# First install
T5_OUT1=$(run_install "$T5_HOME" "$T5_BIN" "$SETUP_REMOTE" --no-cron 2>&1) || true

# Second install (should update, not re-clone)
T5_OUT2=$(run_install "$T5_HOME" "$T5_BIN" "$SETUP_REMOTE" --no-cron 2>&1) || true

# AC: Second run detects existing installation
if echo "$T5_OUT2" | grep -q "Existing installation found"; then
  assert "Already-exists: detects existing installation" "pass"
else
  assert "Already-exists: detects existing installation" "fail" "output: $(echo "$T5_OUT2" | head -10)"
fi

# AC: Second run succeeds (shows "installed" at end)
if echo "$T5_OUT2" | grep -q "Serious Sidekick installed"; then
  assert "Already-exists: second run completes successfully" "pass"
else
  assert "Already-exists: second run completes successfully" "fail"
fi

# AC: Still a valid git repo
if [ -d "$T5_HOME/.git" ]; then
  assert "Already-exists: still a valid git repo" "pass"
else
  assert "Already-exists: still a valid git repo" "fail"
fi

echo ""

# ---------------------------------------------------------------
# Test 6: --no-cron flag
# ---------------------------------------------------------------
echo "--- --no-cron flag ---"
echo ""

# Reuse T3 output (which used --no-cron)
# AC: Output mentions cron was skipped
if echo "$T3_OUTPUT" | grep -qE "SKIP.*Cron|skipped.*no-cron"; then
  assert "--no-cron: reports cron skipped" "pass"
else
  assert "--no-cron: reports cron skipped" "fail" "output: $(echo "$T3_OUTPUT" | grep -i cron | head -3)"
fi

# AC: Completion receipt mentions cron was skipped
if echo "$T3_OUTPUT" | grep -q "skipped"; then
  assert "--no-cron: receipt shows cron skipped" "pass"
else
  assert "--no-cron: receipt shows cron skipped" "fail"
fi

echo ""

# ---------------------------------------------------------------
# Test 7: Completion receipt
# ---------------------------------------------------------------
echo "--- Completion receipt ---"
echo ""

# Reuse T3 output (successful install)
if echo "$T3_OUTPUT" | grep -q "Serious Sidekick installed"; then
  assert "Receipt: shows installed message" "pass"
else
  assert "Receipt: shows installed message" "fail"
fi

if echo "$T3_OUTPUT" | grep -q "Home:"; then
  assert "Receipt: shows home path" "pass"
else
  assert "Receipt: shows home path" "fail"
fi

if echo "$T3_OUTPUT" | grep -q "Binary:"; then
  assert "Receipt: shows binary path" "pass"
else
  assert "Receipt: shows binary path" "fail"
fi

if echo "$T3_OUTPUT" | grep -q "serious-update"; then
  assert "Receipt: mentions serious-update for next steps" "pass"
else
  assert "Receipt: mentions serious-update for next steps" "fail"
fi

if echo "$T3_OUTPUT" | grep -q "uninstall"; then
  assert "Receipt: shows uninstall instructions" "pass"
else
  assert "Receipt: shows uninstall instructions" "fail"
fi

echo ""
echo "=== install.sh Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
