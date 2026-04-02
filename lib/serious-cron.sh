#!/bin/bash
# serious-cron.sh — Cron management functions for Serious Sidekick
#
# Manages scheduled staleness checks via launchd (macOS) or crontab (Linux).
# The cron job runs `serious-update --check` daily.
#
# Usage: source lib/serious-cron.sh

# --- OS Detection ---

# detect_os
# Returns "macos" or "linux". Exits non-zero for unsupported platforms.
detect_os() {
  local uname_out
  uname_out=$(uname -s 2>/dev/null || echo "unknown")
  case "$uname_out" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)
      echo "ERROR: detect_os: unsupported platform: $uname_out" >&2
      return 1
      ;;
  esac
}

# --- Cron Installation ---

# _plist_path [launch_agents_dir]
# Returns the plist path. Accepts optional override for testing.
_plist_path() {
  local launch_agents="${1:-$HOME/Library/LaunchAgents}"
  echo "$launch_agents/com.serious-sidekick.check.plist"
}

# _cron_marker
# Returns the comment marker used to identify our crontab entry.
_cron_marker() {
  echo "# serious-sidekick-check"
}

# install_cron <serious_update_path> [launch_agents_dir]
# On macOS: writes a launchd plist. On Linux: appends a crontab entry.
# Prints what was installed and how to remove it.
# Pass launch_agents_dir to override ~/Library/LaunchAgents (for testing).
install_cron() {
  local update_path="$1"
  local launch_agents_override="${2:-}"

  if [ ! -f "$update_path" ]; then
    echo "ERROR: install_cron: serious-update not found at: $update_path" >&2
    return 1
  fi

  local os
  os=$(detect_os) || return 1

  case "$os" in
    macos)
      local launch_agents="${launch_agents_override:-$HOME/Library/LaunchAgents}"
      local plist_file
      plist_file=$(_plist_path "$launch_agents")

      mkdir -p "$launch_agents" 2>/dev/null || {
        echo "ERROR: install_cron: cannot create $launch_agents" >&2
        return 1
      }

      cat > "$plist_file" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.serious-sidekick.check</string>
    <key>ProgramArguments</key>
    <array>
        <string>bash</string>
        <string>$update_path</string>
        <string>--check</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/serious-sidekick-check.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/serious-sidekick-check.log</string>
</dict>
</plist>
PLIST

      echo "Installed: launchd plist at $plist_file"
      echo "  Runs daily at 09:00"
      echo "  Command: bash $update_path --check"
      echo ""
      echo "To remove: run 'serious-update --uninstall-cron' or manually:"
      echo "  launchctl unload $plist_file"
      echo "  rm $plist_file"
      ;;

    linux)
      local marker
      marker=$(_cron_marker)
      local cron_line="0 9 * * * bash $update_path --check $marker"

      # Check if already installed
      if crontab -l 2>/dev/null | grep -qF "$marker"; then
        echo "Cron job already installed. Skipping."
        return 0
      fi

      # Append to existing crontab
      (crontab -l 2>/dev/null; echo "$cron_line") | crontab - || {
        echo "ERROR: install_cron: failed to install crontab entry" >&2
        return 1
      }

      echo "Installed: crontab entry"
      echo "  Schedule: daily at 09:00"
      echo "  Command: bash $update_path --check"
      echo ""
      echo "To remove: run 'serious-update --uninstall-cron' or manually:"
      echo "  crontab -l | grep -v '$marker' | crontab -"
      ;;
  esac
}

# --- Cron Uninstallation ---

# uninstall_cron [launch_agents_dir]
# Removes the plist (macOS) or crontab entry (Linux).
uninstall_cron() {
  local launch_agents_override="${1:-}"

  local os
  os=$(detect_os) || return 1

  case "$os" in
    macos)
      local launch_agents="${launch_agents_override:-$HOME/Library/LaunchAgents}"
      local plist_file
      plist_file=$(_plist_path "$launch_agents")

      if [ ! -f "$plist_file" ]; then
        echo "No cron job installed (plist not found)."
        return 0
      fi

      # Try to unload first (may fail if not loaded, that's OK)
      launchctl unload "$plist_file" 2>/dev/null || true

      rm -f "$plist_file"
      echo "Removed: $plist_file"
      ;;

    linux)
      local marker
      marker=$(_cron_marker)

      if ! crontab -l 2>/dev/null | grep -qF "$marker"; then
        echo "No cron job installed (crontab entry not found)."
        return 0
      fi

      crontab -l 2>/dev/null | grep -vF "$marker" | crontab - || {
        echo "ERROR: uninstall_cron: failed to remove crontab entry" >&2
        return 1
      }

      echo "Removed: crontab entry for serious-sidekick-check"
      ;;
  esac
}

# --- Cron Status ---

# cron_status [launch_agents_dir]
# Reports whether the cron job is installed and when it last ran.
cron_status() {
  local launch_agents_override="${1:-}"

  local os
  os=$(detect_os) || return 1

  case "$os" in
    macos)
      local launch_agents="${launch_agents_override:-$HOME/Library/LaunchAgents}"
      local plist_file
      plist_file=$(_plist_path "$launch_agents")

      if [ -f "$plist_file" ]; then
        echo "Cron job: installed (launchd)"
        echo "  Plist: $plist_file"
        # Check log for last run time
        if [ -f /tmp/serious-sidekick-check.log ]; then
          local last_mod
          last_mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" /tmp/serious-sidekick-check.log 2>/dev/null || echo "unknown")
          echo "  Last log activity: $last_mod"
        else
          echo "  Last run: unknown (no log file)"
        fi
      else
        echo "Cron job: not installed"
      fi
      ;;

    linux)
      local marker
      marker=$(_cron_marker)

      if crontab -l 2>/dev/null | grep -qF "$marker"; then
        echo "Cron job: installed (crontab)"
        local entry
        entry=$(crontab -l 2>/dev/null | grep -F "$marker")
        echo "  Entry: $entry"
      else
        echo "Cron job: not installed"
      fi
      ;;
  esac
}
