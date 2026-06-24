#!/bin/bash
# test_simple_plan_skill.sh — Verify the serious-simple-plan overlay SKILL.md
# contains every restraint content contract (grep-based content tests, per
# implementation_plan.md Task 1), AND that the working /serious-plan SKILL.md
# is left byte-for-byte unchanged.
#
# Style mirrors tests/test_skillmd_taskid.sh (assert() pattern) and sources the
# cross-platform helper tests/lib/portable.sh after computing REPO_ROOT, then
# normalizes REPO_ROOT via winpath (matches tests/test_merge_settings.sh:5-8).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# cross-platform: paths handed to native exes / used on Windows must be readable; no-op on macOS/Linux
source "$REPO_ROOT/tests/lib/portable.sh"
REPO_ROOT="$(winpath "$REPO_ROOT")"

SKILLMD="$REPO_ROOT/.claude/skills/serious-simple-plan/SKILL.md"
PLAN_SKILLMD="$REPO_ROOT/.claude/skills/serious-plan/SKILL.md"
HEDGE_GATE="$REPO_ROOT/.claude/skills/serious-plan/hooks/hedge-language-gate.sh"

PASS=0
FAIL=0
TOTAL=0

assert() {
  local description="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $description"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $description"
  fi
}

echo "=== Test: serious-simple-plan overlay SKILL.md ==="
echo ""

# --- Precondition: the SKILL.md exists ---
if [ -f "$SKILLMD" ]; then
  assert "SKILL.md exists at .claude/skills/serious-simple-plan/SKILL.md" 0
  SKILL_CONTENT="$(cat "$SKILLMD")"
else
  assert "SKILL.md exists at .claude/skills/serious-simple-plan/SKILL.md" 1
  SKILL_CONTENT=""
fi

# --- Frontmatter: name ---
if echo "$SKILL_CONTENT" | grep -qE '^name:[[:space:]]*serious-simple-plan[[:space:]]*$'; then
  assert "Frontmatter: name is serious-simple-plan" 0
else
  assert "Frontmatter: name is serious-simple-plan" 1
fi

# --- Frontmatter: description mentions restraint-focused alternative to /serious-plan ---
fm_desc=$(echo "$SKILL_CONTENT" | grep -E '^description:')
if echo "$fm_desc" | grep -qi 'restraint' && echo "$fm_desc" | grep -qi 'alternative' && echo "$fm_desc" | grep -q '/serious-plan'; then
  assert "Frontmatter: description names a restraint-focused alternative to /serious-plan" 0
else
  assert "Frontmatter: description names a restraint-focused alternative to /serious-plan" 1
fi

# --- Frontmatter: user-invocable: true ---
if echo "$SKILL_CONTENT" | grep -qE '^user-invocable:[[:space:]]*true[[:space:]]*$'; then
  assert "Frontmatter: user-invocable: true" 0
else
  assert "Frontmatter: user-invocable: true" 1
fi

# --- AC1: follows /serious-plan Phases 0-3 by reference (literal path, no duplication) ---
if echo "$SKILL_CONTENT" | grep -qF '.claude/skills/serious-plan/SKILL.md'; then
  assert "AC1: references the literal path .claude/skills/serious-plan/SKILL.md" 0
else
  assert "AC1: references the literal path .claude/skills/serious-plan/SKILL.md" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'Phases?[[:space:]]+0[[:space:]]*-[[:space:]]*3'; then
  assert "AC1: instructs following Phases 0-3" 0
else
  assert "AC1: instructs following Phases 0-3" 1
fi

# --- AC2: documents --avoid argument and records resolved list in Appendix -> Out of Scope ---
if echo "$SKILL_CONTENT" | grep -qF -- '--avoid'; then
  assert "AC2: documents the --avoid argument" 0
else
  assert "AC2: documents the --avoid argument" 1
fi
if echo "$SKILL_CONTENT" | grep -qF '"<glob,glob>"'; then
  assert 'AC2: documents --avoid "<glob,glob>" form' 0
else
  assert 'AC2: documents --avoid "<glob,glob>" form' 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'Out of Scope' && echo "$SKILL_CONTENT" | grep -qi 'verbatim'; then
  assert "AC2: instructs recording the resolved list verbatim in Appendix -> Out of Scope" 0
else
  assert "AC2: instructs recording the resolved list verbatim in Appendix -> Out of Scope" 1
fi

# --- AC3: sanitize each --avoid value before writing ---
if echo "$SKILL_CONTENT" | grep -qiE 'strip.*(CR/LF|control)'; then
  assert "AC3: instructs stripping CR/LF and control characters" 0
else
  assert "AC3: instructs stripping CR/LF and control characters" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'reject.*\.\.' && echo "$SKILL_CONTENT" | grep -qiE 'leading.*(/|slash)'; then
  assert "AC3: rejects entries with .. segments or a leading /" 0
else
  assert "AC3: rejects entries with .. segments or a leading /" 1
fi
if echo "$SKILL_CONTENT" | grep -qF "printf '%s\\n'"; then
  assert "AC3: writes one glob per line via printf '%s\\n'" 0
else
  assert "AC3: writes one glob per line via printf '%s\\n'" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'stops? generation' && echo "$SKILL_CONTENT" | grep -qi 'silent'; then
  assert "AC3: a rejected entry stops generation with an error (no silent drop)" 0
else
  assert "AC3: a rejected entry stops generation with an error (no silent drop)" 1
fi

# --- AC4: protected-paths.txt sidecar + protected-paths.sha256 companion ---
if echo "$SKILL_CONTENT" | grep -qF 'protected-paths.txt'; then
  assert "AC4: instructs writing protected-paths.txt sidecar" 0
else
  assert "AC4: instructs writing protected-paths.txt sidecar" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'one .*glob per line' && echo "$SKILL_CONTENT" | grep -qi 'repo-root-relative' && echo "$SKILL_CONTENT" | grep -qi 'forward-slash'; then
  assert "AC4: sidecar is one repo-root-relative forward-slash glob per line" 0
else
  assert "AC4: sidecar is one repo-root-relative forward-slash glob per line" 1
fi
if echo "$SKILL_CONTENT" | grep -qF 'protected-paths.sha256' && echo "$SKILL_CONTENT" | grep -qi 'SHA-256'; then
  assert "AC4: instructs writing protected-paths.sha256 companion (SHA-256)" 0
else
  assert "AC4: instructs writing protected-paths.sha256 companion (SHA-256)" 1
fi

# --- AC5: reuse-scan step before drafting tasks, feeding Key components ---
if echo "$SKILL_CONTENT" | grep -qi 'reuse.scan'; then
  assert "AC5: contains a reuse-scan step" 0
else
  assert "AC5: contains a reuse-scan step" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'before drafting'; then
  assert "AC5: reuse-scan runs before drafting tasks" 0
else
  assert "AC5: reuse-scan runs before drafting tasks" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'Grep' && echo "$SKILL_CONTENT" | grep -qi 'Explore'; then
  assert "AC5: reuse-scan uses Grep + optional Explore sub-agent" 0
else
  assert "AC5: reuse-scan uses Grep + optional Explore sub-agent" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'Key components'; then
  assert "AC5: feeds results into each task's Key components" 0
else
  assert "AC5: feeds results into each task's Key components" 1
fi

# --- AC6: restraint yardstick (OR of three justifications) ---
if echo "$SKILL_CONTENT" | grep -qi 'restraint yardstick'; then
  assert "AC6: contains a restraint yardstick" 0
else
  assert "AC6: contains a restraint yardstick" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'breaks-today' \
   && echo "$SKILL_CONTENT" | grep -qi 'named-and-dated-future-need' \
   && echo "$SKILL_CONTENT" | grep -qi 'named-user-or-business-outcome'; then
  assert "AC6: yardstick lists the three justifications" 0
else
  assert "AC6: yardstick lists the three justifications" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'at least one'; then
  assert "AC6: complexity allowed only if at least one justification holds" 0
else
  assert "AC6: complexity allowed only if at least one justification holds" 1
fi

# --- AC7: Conflict Gate (one conflict per message, three-option ask) ---
if echo "$SKILL_CONTENT" | grep -qi 'Conflict Gate'; then
  assert "AC7: contains a Conflict Gate" 0
else
  assert "AC7: contains a Conflict Gate" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'intersect'; then
  assert "AC7: surfaces tasks whose foreseeable files intersect the avoid-list" 0
else
  assert "AC7: surfaces tasks whose foreseeable files intersect the avoid-list" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'approve-cross' \
   && echo "$SKILL_CONTENT" | grep -qi 'force-in-boundary-workaround' \
   && echo "$SKILL_CONTENT" | grep -qi 'cancel'; then
  assert "AC7: asks approve-cross / force-in-boundary-workaround / cancel" 0
else
  assert "AC7: asks approve-cross / force-in-boundary-workaround / cancel" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'one conflict per message'; then
  assert "AC7: ONE conflict per message" 0
else
  assert "AC7: ONE conflict per message" 1
fi

# --- AC8: Conflict Gate is explicitly best-effort and non-exhaustive ---
if echo "$SKILL_CONTENT" | grep -qi 'best-effort' && echo "$SKILL_CONTENT" | grep -qi 'non-exhaustive'; then
  assert "AC8: Conflict Gate labelled best-effort and non-exhaustive" 0
else
  assert "AC8: Conflict Gate labelled best-effort and non-exhaustive" 1
fi
if echo "$SKILL_CONTENT" | grep -qiE 'binding enforcement.*code time|code time.*binding'; then
  assert "AC8: binding enforcement is at code time" 0
else
  assert "AC8: binding enforcement is at code time" 1
fi

# --- AC9: write the `plan` breadcrumb slot via breadcrumb_path plan, emit implementation_plan.md ---
if echo "$SKILL_CONTENT" | grep -qF 'breadcrumb_path plan'; then
  assert "AC9: writes the plan breadcrumb slot via breadcrumb_path plan" 0
else
  assert "AC9: writes the plan breadcrumb slot via breadcrumb_path plan" 1
fi
if echo "$SKILL_CONTENT" | grep -qi 'not a new' && echo "$SKILL_CONTENT" | grep -qi 'simple-plan'; then
  assert "AC9: explicitly NOT a new simple-plan breadcrumb name" 0
else
  assert "AC9: explicitly NOT a new simple-plan breadcrumb name" 1
fi
if echo "$SKILL_CONTENT" | grep -qF 'implementation_plan.md'; then
  assert "AC9: emits the output file named exactly implementation_plan.md" 0
else
  assert "AC9: emits the output file named exactly implementation_plan.md" 1
fi

# --- AC10: state restraint intent in the generated plan (so /serious-review doesn't read omissions as gaps) ---
if echo "$SKILL_CONTENT" | grep -qi 'restraint intent'; then
  assert "AC10: instructs stating the restraint intent in the generated plan" 0
else
  assert "AC10: instructs stating the restraint intent in the generated plan" 1
fi
if echo "$SKILL_CONTENT" | grep -qi '/serious-review' && echo "$SKILL_CONTENT" | grep -qiE 'omissions?.*(gap|not.*read)|not.*read.*gap'; then
  assert "AC10: deliberate omissions are not read as gaps by /serious-review" 0
else
  assert "AC10: deliberate omissions are not read as gaps by /serious-review" 1
fi

# --- AC11: annotate agent-invented restraint criterion with [NO SOURCE: reason] ---
if echo "$SKILL_CONTENT" | grep -qF '[NO SOURCE: reason]'; then
  assert "AC11: instructs annotating invented restraint criteria with [NO SOURCE: reason]" 0
else
  assert "AC11: instructs annotating invented restraint criteria with [NO SOURCE: reason]" 1
fi

# --- NEGATIVE: working planner untouched (vs committed HEAD — catches staged + unstaged) ---
if git -C "$REPO_ROOT" diff HEAD --exit-code -- .claude/skills/serious-plan/SKILL.md >/dev/null 2>&1; then
  assert "NEG: .claude/skills/serious-plan/SKILL.md unchanged vs HEAD" 0
else
  assert "NEG: .claude/skills/serious-plan/SKILL.md unchanged vs HEAD" 1
fi

# --- NEGATIVE: no stub patterns ---
STUB_HIT=""
for pat in TODO FIXME TBD placeholder XXX; do
  if echo "$SKILL_CONTENT" | grep -qF "$pat"; then
    STUB_HIT="$STUB_HIT $pat"
  fi
done
if [ -z "$STUB_HIT" ]; then
  assert "NEG: SKILL.md contains no stub patterns (TODO/FIXME/TBD/placeholder/XXX)" 0
else
  assert "NEG: SKILL.md contains no stub patterns (found:$STUB_HIT)" 1
fi

# --- NEGATIVE: no hedge phrases banned by hedge-language-gate.sh ---
# Mirror the exact wordlist from hedge-language-gate.sh:68
HEDGE=$(echo "$SKILL_CONTENT" | grep -ioE 'consider whether|you might want to|think about|it may be worth|as appropriate|optionally')
if [ -z "$HEDGE" ]; then
  assert "NEG: SKILL.md contains no banned hedge phrases" 0
else
  assert "NEG: SKILL.md contains no banned hedge phrases (found: $(echo "$HEDGE" | tr '\n' ',' ))" 1
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
