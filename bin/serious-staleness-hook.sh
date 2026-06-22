#!/bin/bash
# serious-staleness-hook.sh — Session-start hook for staleness nudge
#
# Reads ~/.serious-sidekick/staleness.json (no network calls).
# Prints a one-liner nudge if components are behind.
# Prints a warning if staleness data is older than 48 hours.
#
# Exit 0 always — this is advisory, never blocks.
#
# Environment overrides:
#   SERIOUS_SIDEKICK_HOME — override ~/.serious-sidekick/ (for testing)

SIDEKICK_HOME="${SERIOUS_SIDEKICK_HOME:-$HOME/.serious-sidekick}"
STALENESS_FILE="$SIDEKICK_HOME/staleness.json"

# Source shared library for JSON backend detection
if [ -f "$SIDEKICK_HOME/lib/serious-common.sh" ]; then
  source "$SIDEKICK_HOME/lib/serious-common.sh"
else
  # Fallback: detect python inline (advisory hook, never block)
  if command -v python3 >/dev/null 2>&1 \
     && [ "$(python3 -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
    _SERIOUS_JSON_BACKEND="python3"
  elif command -v python >/dev/null 2>&1 \
     && [ "$(python -c "import json,sys; print('ok')" 2>/dev/null)" = "ok" ]; then
    _SERIOUS_JSON_BACKEND="python"
  else
    exit 0  # Advisory hook — no python, no nudge, no block
  fi
fi

# If no staleness file, exit silently
if [ ! -f "$STALENESS_FILE" ]; then
  exit 0
fi

# Read stale_count from JSON
STALE_COUNT=$($_SERIOUS_JSON_BACKEND -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    print(data.get('stale_count', 0))
except Exception:
    print(0)
" "$STALENESS_FILE" 2>/dev/null || echo "0")

# Print nudge if stale
if [ "$STALE_COUNT" -gt 0 ]; then
  echo "Serious Sidekick: ${STALE_COUNT} components behind. Run \`serious-update\` to catch up."
fi

# Check file mtime — warn if older than 48 hours
FILE_AGE_SECONDS=0
if [ "$(uname -s)" = "Darwin" ]; then
  # macOS: stat -f %m gives mtime as epoch seconds
  FILE_MTIME=$(stat -f %m "$STALENESS_FILE" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  FILE_AGE_SECONDS=$((NOW - FILE_MTIME))
else
  # Linux: stat -c %Y gives mtime as epoch seconds
  FILE_MTIME=$(stat -c %Y "$STALENESS_FILE" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  FILE_AGE_SECONDS=$((NOW - FILE_MTIME))
fi

THRESHOLD=$((48 * 60 * 60))  # 48 hours in seconds

if [ "$FILE_AGE_SECONDS" -gt "$THRESHOLD" ]; then
  echo "Staleness info may be outdated. Run \`serious-update --check\`."
fi

exit 0
