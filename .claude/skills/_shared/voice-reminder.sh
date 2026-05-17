#!/bin/bash
# voice-reminder.sh — UserPromptSubmit hook that injects a one-line voice reminder
# as factual project state (NOT imperative commands).
#
# Reads a UserPromptSubmit JSON event on stdin. Emits stdout containing a JSON object
# with `hookSpecificOutput.additionalContext` — Claude Code wraps that string as a
# <system-reminder> in the next assistant turn.
#
# Per Anthropic's prompt-injection-defenses guidance, the reminder phrases the rule
# as factual project state ("User prefers X") rather than imperative ("Always do Y").
# Imperative system reminders trigger Claude's prompt-injection resistance and are
# discarded or contested.
#
# Security: the reminder string is HARDCODED in this script (no file reads). This
# closes the indirect-prompt-injection vector where a tampered file could land
# arbitrary content inside <system-reminder> tags.
#
# Source: implementation_plan.md Task 5 AC1-7.

# Fail open: any error → exit 0 silently, the turn proceeds without the reminder.
# The Output Style baseline still applies; the reminder is belt-and-suspenders.

# Hardcoded reminder string. DO NOT replace with a file read.
# This literal MUST match the spirit of .claude/skills/_shared/voice-card.md.
# If the canonical voice card is updated, this string MUST be updated too.
# verify-voice-card-sync.sh will not catch divergence here (it checks the canonical
# block in 25 surfaces; this script's hardcoded reminder is a single-line summary,
# not the full block). Update by hand.
REMINDER='User prefers PM voice for chat replies: What this does / What I need from you / What you need to set up first / Question. ~10 lines, plain English, no internal task labels, no file paths, no bare ordinal options. Voice card lives at .claude/skills/_shared/voice-card.md.'

# Read stdin (the UserPromptSubmit event). Discard it — we do not act on the user's
# prompt content. We unconditionally inject the reminder for every turn.
_INPUT=$(cat 2>/dev/null || printf '')
# Discard variable for shellcheck (we don't act on input)
: "$_INPUT"

# Compose the JSON output. Use python3 for safe JSON encoding (no jq dependency).
# Fail open: if python3 is missing or encoding fails, exit 0 silently.
if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

python3 -c "
import json, sys
reminder = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': reminder,
    }
}))
" "$REMINDER" 2>/dev/null || exit 0

exit 0
