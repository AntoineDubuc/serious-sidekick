#!/bin/bash
# install.sh — First-time installer for Serious Sidekick
#
# Usage: curl -fsSL https://raw.githubusercontent.com/AntoineDubuc/serious-sidekick/main/install.sh | bash
#   Or:  bash install.sh [--no-cron]
#
# Environment overrides (for testing):
#   SERIOUS_SIDEKICK_HOME  — override default ~/.serious-sidekick/
#   SERIOUS_LOCAL_BIN       — override default ~/.local/bin/

set -euo pipefail

# --- Defaults ---
SIDEKICK_HOME="${SERIOUS_SIDEKICK_HOME:-$HOME/.serious-sidekick}"
LOCAL_BIN="${SERIOUS_LOCAL_BIN:-$HOME/.local/bin}"
REPO_URL="${SERIOUS_REPO_URL:-https://github.com/AntoineDubuc/serious-sidekick.git}"

# --- Flag parsing ---
NO_CRON=false

while [ $# -gt 0 ]; do
  case "$1" in
    --no-cron) NO_CRON=true ;;
    *)
      echo "ERROR: Unknown flag: $1" >&2
      echo "Usage: install.sh [--no-cron]" >&2
      exit 1
      ;;
  esac
  shift
done

# --- Color output (if terminal) ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RESET='\033[0m'
else
  GREEN=''
  YELLOW=''
  RESET=''
fi

echo ""
echo "=== Serious Sidekick Installer ==="
echo ""

# --- Step 1: Check prerequisites ---

echo "Checking prerequisites..."

# git is required
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required but not found." >&2
  echo "Install git and try again." >&2
  exit 1
fi
echo -e "  ${GREEN}OK${RESET}  git"

# At least one of python3 or jq is required
HAS_PYTHON3=false
HAS_JQ=false
if command -v python3 >/dev/null 2>&1; then
  HAS_PYTHON3=true
  echo -e "  ${GREEN}OK${RESET}  python3"
fi
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=true
  echo -e "  ${GREEN}OK${RESET}  jq"
fi

if [ "$HAS_PYTHON3" = "false" ] && [ "$HAS_JQ" = "false" ]; then
  echo "ERROR: At least one of python3 or jq is required." >&2
  echo "Install python3 or jq and try again." >&2
  exit 1
fi

echo ""

# --- Step 2: Clone or update the repo ---

if [ -d "$SIDEKICK_HOME" ]; then
  echo "Existing installation found at $SIDEKICK_HOME"
  echo "Updating..."

  if [ ! -d "$SIDEKICK_HOME/.git" ]; then
    echo "ERROR: $SIDEKICK_HOME exists but is not a git repository." >&2
    echo "Remove it manually and run install.sh again." >&2
    exit 1
  fi

  if ! git -C "$SIDEKICK_HOME" pull >/dev/null 2>&1; then
    echo "ERROR: git pull failed in $SIDEKICK_HOME" >&2
    exit 1
  fi

  echo -e "  ${GREEN}OK${RESET}  Updated to latest"
else
  echo "Cloning Serious Sidekick to $SIDEKICK_HOME..."

  if ! git clone "$REPO_URL" "$SIDEKICK_HOME" >/dev/null 2>&1; then
    echo "ERROR: git clone failed." >&2
    echo "Check your network connection and try again." >&2
    exit 1
  fi

  echo -e "  ${GREEN}OK${RESET}  Cloned to $SIDEKICK_HOME"
fi

echo ""

# --- Step 3: Symlink serious-update to PATH ---

echo "Setting up serious-update..."

if [ ! -d "$LOCAL_BIN" ]; then
  mkdir -p "$LOCAL_BIN" 2>/dev/null || {
    echo "ERROR: Cannot create $LOCAL_BIN" >&2
    exit 1
  }
  echo -e "  ${GREEN}OK${RESET}  Created $LOCAL_BIN"
fi

UPDATE_SCRIPT="$SIDEKICK_HOME/bin/serious-update"

if [ ! -f "$UPDATE_SCRIPT" ]; then
  echo "ERROR: serious-update not found at $UPDATE_SCRIPT" >&2
  echo "The repository may be corrupt. Try removing $SIDEKICK_HOME and running install.sh again." >&2
  exit 1
fi

chmod +x "$UPDATE_SCRIPT"
ln -sf "$UPDATE_SCRIPT" "$LOCAL_BIN/serious-update"

echo -e "  ${GREEN}OK${RESET}  Symlinked $LOCAL_BIN/serious-update -> $UPDATE_SCRIPT"

echo ""

# --- Step 4: Install cron job (unless --no-cron) ---

CRON_LIB="$SIDEKICK_HOME/lib/serious-cron.sh"

if [ "$NO_CRON" = "true" ]; then
  echo -e "  ${YELLOW}SKIP${RESET}  Cron job (--no-cron flag)"
elif [ ! -f "$CRON_LIB" ]; then
  echo -e "  ${YELLOW}SKIP${RESET}  Cron job (lib/serious-cron.sh not found)"
else
  echo "Installing daily staleness check..."
  # Source common lib first (required by cron lib)
  if [ -f "$SIDEKICK_HOME/lib/serious-common.sh" ]; then
    source "$SIDEKICK_HOME/lib/serious-common.sh"
  fi
  source "$CRON_LIB"
  install_cron "$UPDATE_SCRIPT"
fi

echo ""

# --- Step 5: Run first update in report-only mode ---

echo "Previewing what would be installed..."
echo ""

# Use the local copy of serious-update directly (symlink may not be on PATH yet)
SERIOUS_SIDEKICK_HOME="$SIDEKICK_HOME" bash "$UPDATE_SCRIPT" --diff 2>&1 || true

echo ""

# --- Step 6: Completion receipt ---

echo "========================================"
echo "  Serious Sidekick installed!"
echo "========================================"
echo ""
echo "  Home:    $SIDEKICK_HOME"
echo "  Binary:  $LOCAL_BIN/serious-update"
if [ "$NO_CRON" = "true" ]; then
  echo "  Cron:    skipped (--no-cron)"
else
  echo "  Cron:    daily staleness check at 09:00"
fi
echo ""
echo "Next steps:"
echo "  Run 'serious-update' to apply changes, or 'serious-update --diff' to preview again."
echo ""
echo "Make sure $LOCAL_BIN is on your PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "To uninstall:"
echo "  rm -rf $SIDEKICK_HOME"
echo "  rm $LOCAL_BIN/serious-update"
echo "  serious-update --uninstall-cron  (if cron was installed)"
echo ""
