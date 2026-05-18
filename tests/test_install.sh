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

# ---------------------------------------------------------------
# Test 8 (reliability Task 1, Site #9): install.sh git pull
# surfaces real stderr instead of swallowing it.
# ---------------------------------------------------------------
echo ""
echo "--- reliability-task1 Site #9: install.sh git pull error transparency ---"
echo ""

T8_BASE="$TMP_DIR/t8"
setup_remote_repo "$T8_BASE"
T8_HOME="$TMP_DIR/t8_home"
T8_BIN="$TMP_DIR/t8_bin"

# First install: a clean clone to T8_HOME.
T8_FIRST=$(run_install "$T8_HOME" "$T8_BIN" "$SETUP_REMOTE" --no-cron 2>&1) || true

# Push a new commit to remote that changes _anti-rationalization-core.md.
T8_STAGE="$TMP_DIR/t8_stage"
git clone -q "$SETUP_REMOTE" "$T8_STAGE"
cd "$T8_STAGE"
git config user.email "test@test.com"
git config user.name "Test"
echo "# upstream change" >> "_anti-rationalization-core.md"
git add -A
git commit -q -m "T8 upstream"
git push -q origin 2>/dev/null
cd "$REPO_ROOT"

# Wedge: dirty the SAME file the upstream commit changed so `git pull`
# refuses to fast-forward.
echo "# local wedge" >> "$T8_HOME/_anti-rationalization-core.md"

# Run install.sh again — pull should fail with the dirty working tree.
T8_SECOND=$(run_install "$T8_HOME" "$T8_BIN" "$SETUP_REMOTE" --no-cron 2>&1) || true

# AC: install.sh prints real git error (not opaque "git pull failed")
if echo "$T8_SECOND" | grep -q "ERROR: git pull failed in " \
   && echo "$T8_SECOND" | grep -q "local changes"; then
  assert "Site #9: install.sh pull failure shows real git stderr" "pass"
else
  assert "Site #9: install.sh pull failure shows real git stderr" "fail" \
    "output: $(echo "$T8_SECOND" | head -10 | tr '\n' '|')"
fi

# AC: legacy opaque message removed.
if echo "$T8_SECOND" | grep -qE "ERROR: git pull failed in [^:]+$"; then
  # The legacy form ends with the path and no colon-detail. The new form
  # ends with a colon and the captured stderr follows on subsequent lines.
  # If we still see exactly "ERROR: git pull failed in <path>" (no colon),
  # the old swallow-and-guess remains.
  assert "Site #9: legacy opaque 'git pull failed in <path>' (no detail) removed" "fail" \
    "old form present"
else
  assert "Site #9: legacy opaque 'git pull failed in <path>' (no detail) removed" "pass"
fi

# AC: S4 — bash -n on install.sh is clean after the fix.
if bash -n "$REPO_ROOT/install.sh" 2>/dev/null; then
  assert "Site #9 (S4): bash -n on install.sh is clean" "pass"
else
  assert "Site #9 (S4): bash -n on install.sh is clean" "fail"
fi

# AC: S2 — credentials in remote URLs are redacted from install.sh stderr.
T8R_BASE="$TMP_DIR/t8r"
setup_remote_repo "$T8R_BASE"
T8R_HOME="$TMP_DIR/t8r_home"
T8R_BIN="$TMP_DIR/t8r_bin"
run_install "$T8R_HOME" "$T8R_BIN" "$SETUP_REMOTE" --no-cron >/dev/null 2>&1 || true
# Swap remote URL to one with embedded creds AND a host that won't resolve.
git -C "$T8R_HOME" remote set-url origin "https://test:secret123@invalid.localhost/repo.git"
T8R_OUT=$(run_install "$T8R_HOME" "$T8R_BIN" "https://test:secret123@invalid.localhost/repo.git" --no-cron 2>&1) || true
if ! echo "$T8R_OUT" | grep -q "secret123"; then
  assert "Site #9 (S2): credentials redacted from install.sh stderr" "pass"
else
  assert "Site #9 (S2): credentials redacted from install.sh stderr" "fail" \
    "'secret123' leaked to stderr"
fi

echo ""
echo "=== install.sh Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
