#!/bin/bash
# test_banned_token_sweep.sh — Task 2 RED test for user-facing-prose token cleanliness.
#
# For each SKILL.md, extracts user-facing prose blocks and sweeps them for banned tokens.
# A "user-facing prose block" is one of:
#   - A quoted-text block (lines starting with `> ` that are inside a markdown blockquote)
#   - A "Present to the user:" / "Tell the user:" / "Display:" / "Show:" / "Report to user"
#     section, body extracted until the next heading or blank-line+heading.
#
# Banned tokens (mirrors voice-gate.sh strong patterns, applied case-insensitively):
#   - Plan [0-9]+[A-Za-z]?
#   - Task [0-9]+v?
#   - T[0-9]+ (anchored)
#   - Option [0-9A-E]
#   - Phase [0-9]+[a-z]?  (allowed only when paired with another strong marker — see voice-gate)
#   - file/dir paths with .md/.sh/.ts/.tsx/.py/.json/.yaml/.yml extensions
#   - Code fences (```)
#
# Lines inside <!-- voice-retrofit: deferred ... --> blocks are excluded.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
assert() {
  local name="$1"; local result="$2"; local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS+1)); echo "  PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $name${detail:+ — $detail}"
  fi
}

# Extract user-facing prose blocks from a SKILL.md per AC2 wording:
# "extract every block between 'Tell the user:' or 'Report to the user:' and the next heading."
# Widened to include the additional user-emission verbs the skill files use in practice:
# "Present to the user:", "Show the user:", "Display:", "Output:", "Report:".
# A block runs from the trigger line until the next blank line followed by a `## ` or `### `
# heading, OR the next blank-line-separator with a non-blank, non-list, non-quote line.
# Lines inside <!-- voice-retrofit: deferred ... --> blocks are excluded.
extract_user_facing() {
  local file="$1"
  awk '
    BEGIN {
      in_deferred = 0
      in_block = 0
    }
    # Track multi-line deferred-comment regions so contents are excluded
    /voice-retrofit: deferred/ { in_deferred = 1 }
    in_deferred && /-->/ { in_deferred = 0; next }
    in_deferred { next }

    # Trigger phrases that start a user-facing block per AC2 (case-insensitive).
    # The trigger line itself plus the body up to the next heading get included.
    /[Tt]ell the user:?|[Rr]eport to (the )?user:?|[Pp]resent to (the )?user:?|[Ss]how (the )?user:?|^[Dd]isplay:|^[Oo]utput:/ {
      in_block = 1
      print
      next
    }
    # End the block at the next markdown heading.
    in_block && /^#+ / {
      in_block = 0
      next
    }
    # While in a block, emit every line (including continuation prose and embedded chat strings).
    in_block { print; next }

    # Always also include the literal verbatim chat strings we previously caught.
    /^> *"[^"]/ { print }
    /^"[^"]+"$/ { print }
  ' "$file"
}

# Banned-token sweep on the extracted text.
banned_sweep() {
  local text="$1"
  local hits=""
  if printf '%s\n' "$text" | grep -Eiq '\bPlan [0-9]+[A-Za-z]?\b'; then
    hits="$hits Plan-N,"
  fi
  if printf '%s\n' "$text" | grep -Eiq '\bTask [0-9]+v?\b'; then
    hits="$hits Task-N,"
  fi
  if printf '%s\n' "$text" | grep -Eiq '(^|[^A-Za-z])T[0-9]+([^A-Za-z]|$)'; then
    hits="$hits T-N,"
  fi
  if printf '%s\n' "$text" | grep -Eiq '(^|[^A-Za-z])Option [0-9A-Ea-e]([^A-Za-z]|$)'; then
    hits="$hits Option-N,"
  fi
  if printf '%s\n' "$text" | grep -Eq '```'; then
    hits="$hits code-fence,"
  fi
  if printf '%s\n' "$text" | grep -Eiq '(^|[^A-Za-z0-9])(/[A-Za-z0-9._/-]+|[A-Za-z0-9_-]+/[A-Za-z0-9._/-]+)\.(md|sh|ts|tsx|py|json|yaml|yml)([^A-Za-z0-9]|$)'; then
    hits="$hits file-path,"
  fi
  echo "${hits%,}"
}

echo "=== Task 2 banned-token sweep (user-facing prose) ==="

for skill_file in "$PROJECT_ROOT"/.claude/skills/serious-*/SKILL.md; do
  skill=$(basename "$(dirname "$skill_file")")
  blocks=$(extract_user_facing "$skill_file")
  if [ -z "$blocks" ]; then
    assert "$skill: no user-facing blocks (vacuously clean)" "pass"
    continue
  fi
  hits=$(banned_sweep "$blocks")
  if [ -z "$hits" ]; then
    assert "$skill: user-facing blocks clean (no banned tokens)" "pass"
  else
    assert "$skill: user-facing blocks clean" "fail" "hits:$hits"
  fi
done

# Negative test: no NEW slop introduced
# Compare git diff main..HEAD for .claude/skills/serious-*/SKILL.md — added lines should not
# contain banned tokens in user-facing blocks.
if git -C "$PROJECT_ROOT" rev-parse --verify main >/dev/null 2>&1; then
  added=$(git -C "$PROJECT_ROOT" diff main..HEAD -- '.claude/skills/serious-*/SKILL.md' 2>/dev/null \
    | grep -E '^\+(> |".*"$)' \
    | sed 's/^+//')
  if [ -n "$added" ]; then
    new_hits=$(banned_sweep "$added")
    if [ -z "$new_hits" ]; then
      assert "no NEW slop in user-facing blocks since main" "pass"
    else
      assert "no NEW slop in user-facing blocks since main" "fail" "hits:$new_hits"
    fi
  else
    assert "no user-facing additions since main (vacuously clean)" "pass"
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
