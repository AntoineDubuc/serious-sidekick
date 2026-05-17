#!/bin/bash
# voice-gate.sh — Stop-hook validator that catches banned PM-voice tokens
# in the assistant's reply and forces a retry via exit-2 + stderr.
#
# Reads a Stop-hook JSON payload on stdin:
#   { "hook_event_name": "Stop",
#     "transcript_path": "<path-to-jsonl>",
#     "stop_hook_active": false,
#     "message": { "content": [{ "type": "text", "text": "<assistant text>" }, ...] } }
#
# Exit codes:
#   0 — clean (or anti-loop skip, or [[ENGINEER]] escape hatch fired)
#   2 — voice-rule violation; stderr contains the rewrite instruction for Claude
#
# Source: implementation_plan.md Task 1 AC4-10, 12.
# Reference: research.md#Finding-3 (exit-2 + stderr is the cleanest retry path)
#            research.md#Finding-7 (regex coverage of 7 patterns)
#
# This file is intentionally DEFENSIVE about assistant-controlled input:
#   - jq -r only (no eval, no raw substitution)
#   - bash variables always quoted; printf '%s' not bare echo
#   - regex matched via grep -E with explicit alternation; no shell expansion
#   - set -euo pipefail; control flow via if/else, not && chains

set -euo pipefail

# Resolve project root from script location (.claude/skills/_shared/voice-gate.sh)
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SHARED_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Source the outcome logger (defensive — fall through to no-op on missing)
if [ -f "$SHARED_DIR/log-outcome.sh" ]; then
  # shellcheck disable=SC1091
  . "$SHARED_DIR/log-outcome.sh"
else
  _log_outcome() { :; }
fi

# Read stdin
INPUT_JSON="$(cat)"

# If input is empty or not valid JSON, fall through silently (ERROR, exit 0)
# Rationale: a malformed Stop-hook payload is a system bug, not a voice issue.
# We must not block the conversation on infrastructure errors.
if ! echo "$INPUT_JSON" | jq -e . >/dev/null 2>&1; then
  _log_outcome ERROR "voice-gate: invalid JSON input"
  exit 0
fi

# Anti-loop guard — AC5
STOP_ACTIVE="$(echo "$INPUT_JSON" | jq -r '.stop_hook_active // false')"
if [ "$STOP_ACTIVE" = "true" ]; then
  echo "voice-gate: stop_hook_active, skipping" >&2
  _log_outcome SKIP "stop_hook_active"
  exit 0
fi

# Extract assistant text — concatenate all text content blocks
# Use jq -r to safely emit without shell expansion.
ASSISTANT_TEXT="$(echo "$INPUT_JSON" | jq -r '
  .message.content // []
  | map(select(.type == "text") | .text // "")
  | join("\n")
')"

# Some Stop-hook implementations put the text under different shapes; try a fallback
if [ -z "$ASSISTANT_TEXT" ]; then
  ASSISTANT_TEXT="$(echo "$INPUT_JSON" | jq -r '.message.content // .text // .assistant_text // ""' 2>/dev/null || printf '')"
fi

# If empty, nothing to validate
if [ -z "$ASSISTANT_TEXT" ]; then
  _log_outcome PASS "empty assistant text"
  exit 0
fi

# Escape-hatch check — AC8
# [[ENGINEER]] is honored ONLY if it appears in the most recent USER-TURN entry
# of the JSONL transcript. Substrings in assistant turns or tool results do NOT
# count (otherwise the assistant could disable the validator by emitting the
# bypass string into its own reply).
TRANSCRIPT_PATH="$(echo "$INPUT_JSON" | jq -r '.transcript_path // ""')"
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Use jq to filter only user-role entries, then grep for the literal escape token.
  # grep -F treats [[ENGINEER]] as literal; no regex metacharacter risk.
  if jq -r 'select(.role == "user") | .content // ""' "$TRANSCRIPT_PATH" 2>/dev/null \
      | grep -qF '[[ENGINEER]]'; then
    _log_outcome SKIP "escape-hatch [[ENGINEER]] in user turn"
    exit 0
  fi
fi

# Voice-rule regex — case-insensitive (AC7).
#
# Patterns split into STRONG (never legitimate English) and WEAK (legitimate
# in normal usage, only flagged when paired with a STRONG signal):
#   STRONG: Option N, Task N, T1, Plan NA, file path, code fence, line-count>15
#   WEAK:   Phase N  — "Phase 2 starts Monday" is legitimate calendar prose;
#                     only fires when the reply ALSO contains a STRONG marker.
#
# This split resolves the plan-internal contradiction between AC7 (Phase is
# banned) and the negative test "Phase 2 starts Monday must NOT fire": Phase
# stays in the banned list, but only fires alongside a strong task-label marker.
STRONG_VIOLATIONS=""
WEAK_VIOLATIONS=""

check_strong() {
  local label="$1"; local pattern="$2"
  if printf '%s' "$ASSISTANT_TEXT" | grep -Eiq "$pattern"; then
    STRONG_VIOLATIONS="$STRONG_VIOLATIONS$label, "
  fi
}
check_weak() {
  local label="$1"; local pattern="$2"
  if printf '%s' "$ASSISTANT_TEXT" | grep -Eiq "$pattern"; then
    WEAK_VIOLATIONS="$WEAK_VIOLATIONS$label, "
  fi
}

# STRONG patterns — fire on first match
check_strong '"Option N" label'       '(^|[^A-Za-z])Option [0-9A-Ea-e]([^A-Za-z]|$)'
check_strong '"T1" or "Task N" label' '(^|[^A-Za-z])T[0-9]+([^A-Za-z]|$)|\bTask [0-9]+v?\b'
check_strong '"Plan NA" label'        '\bPlan [0-9]+[A-Za-z]?\b'
check_strong 'file path'              '(^|[^A-Za-z0-9])(/[A-Za-z0-9._/-]+|[A-Za-z0-9_-]+/[A-Za-z0-9._/-]+)\.(md|sh|ts|tsx|py|json|yaml|yml)([^A-Za-z0-9]|$)'
check_strong 'code fence'             '```'

# WEAK patterns — only counted if STRONG also matched
check_weak '"Phase N" label'          '\bPhase [0-9]+[a-z]?\b'

# Line-count check (AC7 includes "line-count over 15") — STRONG
LINE_COUNT="$(printf '%s' "$ASSISTANT_TEXT" | wc -l | tr -d ' ')"
if [ "$LINE_COUNT" -gt 15 ]; then
  STRONG_VIOLATIONS="${STRONG_VIOLATIONS}line-count over 15, "
fi

# Decide: fire only if STRONG matched. WEAK alone is not a violation.
if [ -z "$STRONG_VIOLATIONS" ]; then
  if [ -n "$WEAK_VIOLATIONS" ]; then
    # Weak-only — log as PASS with the weak label for observability
    _log_outcome PASS "weak-only: ${WEAK_VIOLATIONS%, }"
  else
    _log_outcome PASS "clean"
  fi
  exit 0
fi

# At least one STRONG matched. Combine with any WEAK matches for the stderr message.
VIOLATIONS="${STRONG_VIOLATIONS}${WEAK_VIOLATIONS}"
VIOLATIONS="${VIOLATIONS%, }"

# Redact secrets before any stderr emission — AC12
# Patterns: AWS keys, GitHub tokens, OpenAI/Anthropic keys, PEM headers, JWT prefix.
REDACTED_TEXT="$(printf '%s' "$ASSISTANT_TEXT" | sed -E \
  -e 's/AKIA[0-9A-Z]{16}/[REDACTED-SECRET]/g' \
  -e 's/ghp_[A-Za-z0-9]{36}/[REDACTED-SECRET]/g' \
  -e 's/sk-[a-zA-Z0-9]{48}/[REDACTED-SECRET]/g' \
  -e 's/-----BEGIN [A-Z ]*PRIVATE KEY-----/[REDACTED-SECRET]/g' \
  -e 's/eyJ[A-Za-z0-9_-]{30,}/[REDACTED-SECRET]/g')"

# Verbatim stderr template per AC4
{
  printf 'VOICE-RULE VIOLATION DETECTED: %s. ' "$VIOLATIONS"
  printf 'Rewrite your reply using the PM voice rule. '
  printf 'Structure: What this does → What I need from you → What you need to set up first → Question. '
  printf 'Max ~10 lines. No internal task labels, no file paths, no code fences. '
  printf 'Do not retry without changing the reply structure.\n'
  # Operator-visible context (Claude treats stderr as instruction, but we include
  # the redacted excerpt for human debugging via .claude/logs/outcomes.log)
  printf '\n--- offending reply (first 300 chars, secrets redacted) ---\n'
  printf '%s\n' "${REDACTED_TEXT:0:300}"
} >&2

_log_outcome BLOCK "violation: $VIOLATIONS"
exit 2
