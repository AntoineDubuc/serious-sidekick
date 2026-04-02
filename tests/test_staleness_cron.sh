#!/bin/bash
# test_staleness_cron.sh — Tests for lib/serious-cron.sh
#
# Uses temp directories for all cron operations (never installs real cron jobs).
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

# Source the library
source "$REPO_ROOT/lib/serious-cron.sh"

echo "=== Test: serious-cron ==="
echo ""

# ---------------------------------------------------------------
# detect_os
# ---------------------------------------------------------------
echo "--- detect_os ---"
echo ""

# On this machine (macOS), detect_os should return "macos"
OS_RESULT=$(detect_os)
if [ "$OS_RESULT" = "macos" ]; then
  assert "detect_os returns 'macos' on this machine" "pass"
else
  assert "detect_os returns 'macos' on this machine" "fail" "got: $OS_RESULT"
fi

echo ""

# ---------------------------------------------------------------
# install_cron (macOS plist path)
# ---------------------------------------------------------------
echo "--- install_cron ---"
echo ""

# Create a fake serious-update script for the plist to reference
FAKE_UPDATE="$TMP_DIR/bin/serious-update"
mkdir -p "$TMP_DIR/bin"
echo '#!/bin/bash' > "$FAKE_UPDATE"
echo 'echo "fake update"' >> "$FAKE_UPDATE"
chmod +x "$FAKE_UPDATE"

# Test with temp LaunchAgents dir
TEMP_LAUNCH_AGENTS="$TMP_DIR/LaunchAgents"
mkdir -p "$TEMP_LAUNCH_AGENTS"

INSTALL_OUTPUT=$(install_cron "$FAKE_UPDATE" "$TEMP_LAUNCH_AGENTS" 2>&1)
INSTALL_EXIT=$?

# AC: install_cron exits 0
if [ "$INSTALL_EXIT" -eq 0 ]; then
  assert "install_cron exits 0" "pass"
else
  assert "install_cron exits 0" "fail" "exit=$INSTALL_EXIT"
fi

# AC: Plist file created
PLIST_PATH="$TEMP_LAUNCH_AGENTS/com.serious-sidekick.check.plist"
if [ -f "$PLIST_PATH" ]; then
  assert "install_cron creates plist file" "pass"
else
  assert "install_cron creates plist file" "fail" "not found: $PLIST_PATH"
fi

# AC: Plist contains the update command path
if [ -f "$PLIST_PATH" ] && grep -q "$FAKE_UPDATE" "$PLIST_PATH"; then
  assert "Plist references the update script path" "pass"
else
  assert "Plist references the update script path" "fail"
fi

# AC: Plist contains --check flag
if [ -f "$PLIST_PATH" ] && grep -q "\-\-check" "$PLIST_PATH"; then
  assert "Plist includes --check argument" "pass"
else
  assert "Plist includes --check argument" "fail"
fi

# AC: Plist is valid XML
if [ -f "$PLIST_PATH" ] && plutil -lint "$PLIST_PATH" >/dev/null 2>&1; then
  assert "Plist is valid XML" "pass"
else
  assert "Plist is valid XML" "fail"
fi

# AC: Output tells user what was installed
if echo "$INSTALL_OUTPUT" | grep -q "Installed"; then
  assert "install_cron prints installation notice" "pass"
else
  assert "install_cron prints installation notice" "fail"
fi

# AC: Output tells user how to remove
if echo "$INSTALL_OUTPUT" | grep -q "remove"; then
  assert "install_cron prints removal instructions" "pass"
else
  assert "install_cron prints removal instructions" "fail"
fi

echo ""

# ---------------------------------------------------------------
# cron_status (installed)
# ---------------------------------------------------------------
echo "--- cron_status (installed) ---"
echo ""

STATUS_OUTPUT=$(cron_status "$TEMP_LAUNCH_AGENTS" 2>&1)

if echo "$STATUS_OUTPUT" | grep -q "installed"; then
  assert "cron_status reports installed when plist exists" "pass"
else
  assert "cron_status reports installed when plist exists" "fail" "output: $STATUS_OUTPUT"
fi

echo ""

# ---------------------------------------------------------------
# uninstall_cron
# ---------------------------------------------------------------
echo "--- uninstall_cron ---"
echo ""

UNINSTALL_OUTPUT=$(uninstall_cron "$TEMP_LAUNCH_AGENTS" 2>&1)
UNINSTALL_EXIT=$?

# AC: uninstall exits 0
if [ "$UNINSTALL_EXIT" -eq 0 ]; then
  assert "uninstall_cron exits 0" "pass"
else
  assert "uninstall_cron exits 0" "fail" "exit=$UNINSTALL_EXIT"
fi

# AC: Plist file removed
if [ ! -f "$PLIST_PATH" ]; then
  assert "uninstall_cron removes plist file" "pass"
else
  assert "uninstall_cron removes plist file" "fail" "file still exists"
fi

# AC: Output confirms removal
if echo "$UNINSTALL_OUTPUT" | grep -q "Removed"; then
  assert "uninstall_cron prints confirmation" "pass"
else
  assert "uninstall_cron prints confirmation" "fail"
fi

echo ""

# ---------------------------------------------------------------
# cron_status (not installed)
# ---------------------------------------------------------------
echo "--- cron_status (not installed) ---"
echo ""

STATUS_AFTER=$(cron_status "$TEMP_LAUNCH_AGENTS" 2>&1)

if echo "$STATUS_AFTER" | grep -q "not installed"; then
  assert "cron_status reports not installed after uninstall" "pass"
else
  assert "cron_status reports not installed after uninstall" "fail" "output: $STATUS_AFTER"
fi

echo ""

# ---------------------------------------------------------------
# uninstall_cron when nothing installed (idempotent)
# ---------------------------------------------------------------
echo "--- uninstall_cron (idempotent) ---"
echo ""

UNINSTALL2_OUTPUT=$(uninstall_cron "$TEMP_LAUNCH_AGENTS" 2>&1)
UNINSTALL2_EXIT=$?

if [ "$UNINSTALL2_EXIT" -eq 0 ]; then
  assert "uninstall_cron exits 0 when nothing installed" "pass"
else
  assert "uninstall_cron exits 0 when nothing installed" "fail" "exit=$UNINSTALL2_EXIT"
fi

if echo "$UNINSTALL2_OUTPUT" | grep -q "No cron job installed"; then
  assert "uninstall_cron reports nothing to remove" "pass"
else
  assert "uninstall_cron reports nothing to remove" "fail"
fi

echo ""

# ---------------------------------------------------------------
# install_cron with missing script path
# ---------------------------------------------------------------
echo "--- install_cron (error cases) ---"
echo ""

BAD_EXIT=0
BAD_OUTPUT=$(install_cron "/nonexistent/serious-update" "$TEMP_LAUNCH_AGENTS" 2>&1) || BAD_EXIT=$?

if [ "$BAD_EXIT" -ne 0 ]; then
  assert "install_cron fails for missing script" "pass"
else
  assert "install_cron fails for missing script" "fail" "exit=$BAD_EXIT"
fi

echo ""
echo "=== serious-cron Tests Complete: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
