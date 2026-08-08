#!/bin/bash
# Tests for validate-refs.sh
#
# Run: bash .claude/skills/_shared/validate-refs.test.sh
#
# ⛔ SELF-CONTAINED BY DESIGN. An earlier version of this test asserted against
# real paths in the project it was written in (`lib/features/...`). Ported to any
# other project it would have failed for the wrong reason — a test that fails
# because its fixture is missing tells you nothing about the code under test.
# Every fixture below is created in a temp dir and removed afterwards.
#
# ⛔ Each case asserts the hook's EXIT CODE, which is the only thing Claude Code
# acts on (2 = block, 0 = allow). A test asserting only stderr text would pass
# against a hook that never blocks — the "green test over a broken guard" shape
# this hook exists to prevent.

set -uo pipefail
HOOK="$(cd "$(dirname "$0")" && pwd)/validate-refs.sh"
PASS=0; FAIL=0

# A throwaway project tree: a real file with a known length, in a real subdir.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/lib/sub" "$TMP/Research/bugs/x"
printf 'line\n%.0s' $(seq 1 20) > "$TMP/lib/sub/real.dart"   # exactly 20 lines
REAL="lib/sub/real.dart"

run() { # name, expected_exit, json
  local name="$1" expect="$2" json="$3" out code
  out=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" 2>&1)
  code=$?
  if [ "$code" -eq "$expect" ]; then
    printf '  PASS  %s\n' "$name"; PASS=$((PASS+1))
  else
    printf '  FAIL  %s (expected exit %s, got %s)\n' "$name" "$expect" "$code"
    printf '        %s\n' "$(echo "$out" | head -3)"; FAIL=$((FAIL+1))
  fi
}

j() { jq -nc --arg f "$1" --arg c "$2" '{tool_input:{file_path:$f, content:$c}}'; }

echo "fixture: $REAL has $(wc -l < "$TMP/$REAL" | tr -d ' ') lines, in $TMP"
echo
echo "MUST BLOCK (exit 2):"
run "line number past end of file" 2 \
  "$(j "$TMP/Research/bugs/x/plan.md" "See \`$REAL:999\`.")"
run "file that does not exist" 2 \
  "$(j "$TMP/Research/bugs/x/plan.md" "See \`lib/sub/no_such_file.dart:3\`.")"
run "one good ref and one bad ref together" 2 \
  "$(j "$TMP/Research/bugs/x/plan.md" "Good \`$REAL:5\` and bad \`lib/sub/gone.dart:5\`.")"

run "a python-style src/ dir is checked too, not just Flutter dirs" 2 \
  "$(mkdir -p "$TMP/src" && j "$TMP/Research/bugs/x/plan.md" "See \`src/app/missing.py:9\`.")"

echo
echo "MUST ALLOW (exit 0):"
run "valid ref inside the real range" 0 \
  "$(j "$TMP/Research/bugs/x/plan.md" "See \`$REAL:5\`.")"
FENCE='```'
run "bad ref inside a fenced code block is ignored" 0 \
  "$(j "$TMP/Research/bugs/x/plan.md" "$(printf 'Example:\n%s\nlib/sub/gone.dart:5\n%s\n' "$FENCE" "$FENCE")")"
run "non-Research markdown is out of scope" 0 \
  "$(j "$TMP/docs/notes.md" "Bad \`lib/sub/gone.dart:5\`.")"
run "non-markdown file is out of scope" 0 \
  "$(j "$TMP/Research/bugs/x/thing.dart" "Bad \`lib/sub/gone.dart:5\`.")"
run "prose with no refs" 0 \
  "$(j "$TMP/Research/bugs/x/plan.md" "She walks home and the alarm stops.")"
run "URL is not treated as a path" 0 \
  "$(j "$TMP/Research/bugs/x/plan.md" "See https://example.com/a/b.html:80.")"
run "unknown top-level dir is ignored, not guessed at" 0 \
  "$(j "$TMP/Research/bugs/x/plan.md" "Upstream \`vendor/other/lib/thing.dart:5000\`.")"
run "empty content does not crash" 0 \
  "$(j "$TMP/Research/bugs/x/plan.md" "")"
run "Edit tool payload (new_string) is read, not just Write" 0 \
  "$(jq -nc --arg f "$TMP/Research/bugs/x/plan.md" --arg c "See \`$REAL:5\`." \
      '{tool_input:{file_path:$f, new_string:$c}}')"

echo
echo "MUTATION CHECK — the BLOCK cases must discriminate:"
NEVER=$(mktemp); printf '#!/bin/bash\ncat >/dev/null\nexit 0\n' > "$NEVER"
BAD=$(j "$TMP/Research/bugs/x/plan.md" 'Bad `lib/sub/gone.dart:5`.')
printf '%s' "$BAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$NEVER" >/dev/null 2>&1; m=$?
printf '%s' "$BAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK"  >/dev/null 2>&1; r=$?
rm -f "$NEVER"
if [ "$m" -eq 0 ] && [ "$r" -eq 2 ]; then
  echo "  PASS  no-op hook allows (0) where the real hook blocks (2)"; PASS=$((PASS+1))
else
  echo "  FAIL  no-op exited $m (want 0), real hook exited $r (want 2)"; FAIL=$((FAIL+1))
fi

echo
echo "== $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
