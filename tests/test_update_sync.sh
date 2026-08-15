#!/bin/bash
# test_update_sync.sh — Tests for scripts/update.sh (manifest-driven multi-install sync)
#
# Every assertion runs against a SANDBOX of fake installations in a temp dir, never against
# the real ones. The script is pointed at them with --root, and --no-pull keeps it offline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE="$REPO_ROOT/scripts/update.sh"

ERRORS=0
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert() {
  local desc="$1" result="$2" detail="${3:-}"
  if [ "$result" = "pass" ]; then echo "  PASS: $desc"
  else echo "  FAIL: $desc"; [ -n "$detail" ] && echo "        $detail"; ERRORS=$((ERRORS+1)); fi
}

# A tracked template file and its destination, read from the real manifest.
read -r SRC DEST < <(python3 - "$REPO_ROOT/manifest.json" <<'PY'
import json,sys
for p,m in sorted(json.load(open(sys.argv[1]))['files'].items()):
    if m.get('ownership')=='template' and p.endswith('serious-review-anti-slop.md'):
        print(p, m['dest']); break
PY
)

make_install() {           # $1=root  $2=mode(stale|missing|current)
  local root="$1" mode="$2"
  mkdir -p "$root/skills/serious-plan" "$root/agents"
  # user-owned files that must NEVER be touched
  printf '{"mine":true}\n' > "$root/settings.json"
  printf '# my rules\n'     > "$root/CLAUDE.md"
  case "$mode" in
    stale)   printf 'OLD CONTENT — must be replaced\n' > "$root/$DEST" ;;
    missing) : ;;
    current) cp "$REPO_ROOT/$SRC" "$root/$DEST" ;;
  esac
}

echo "=== Test: update.sh ==="

# ---------------------------------------------------------------- 1. dry run
R1="$TMP_DIR/dry"; make_install "$R1" stale
OUT=$(bash "$UPDATE" --no-pull --dry-run --root "$R1" 2>&1)
grep -q "DRY RUN" <<<"$OUT" && r=pass || r=fail
assert "dry run announces itself" "$r"
grep -q "OLD CONTENT" "$R1/$DEST" && r=pass || r=fail
assert "dry run copies NOTHING" "$r" "file was modified by a dry run"
[ -z "$(find "$R1" -name '.backup-update-*' -maxdepth 1)" ] && r=pass || r=fail
assert "dry run creates no backup" "$r"

# ------------------------------------------------------- 2. stale gets updated
R2="$TMP_DIR/stale"; make_install "$R2" stale
bash "$UPDATE" --no-pull --root "$R2" >/dev/null 2>&1
cmp -s "$R2/$DEST" "$REPO_ROOT/$SRC" && r=pass || r=fail
assert "stale file is updated to canonical" "$r"
BK=$(find "$R2" -maxdepth 1 -name '.backup-update-*' -type d | head -1)
[ -n "$BK" ] && grep -q "OLD CONTENT" "$BK/$DEST" && r=pass || r=fail
assert "the overwritten version is backed up verbatim" "$r"

# ------------------------------------------------------ 3. missing gets added
R3="$TMP_DIR/missing"; make_install "$R3" missing
bash "$UPDATE" --no-pull --root "$R3" >/dev/null 2>&1
cmp -s "$R3/$DEST" "$REPO_ROOT/$SRC" && r=pass || r=fail
assert "missing file is added" "$r"

# ------------------------------------------- 4. user-owned files never touched
grep -q '"mine":true' "$R2/settings.json" && r=pass || r=fail
assert "settings.json (merge-owned) untouched" "$r"
grep -q '# my rules' "$R2/CLAUDE.md" && r=pass || r=fail
assert "CLAUDE.md (user-init-owned) untouched" "$r"

# ------------------------------------------------------------ 5. idempotence
OUT=$(bash "$UPDATE" --no-pull --root "$R2" 2>&1)
grep -q "already up to date" <<<"$OUT" && r=pass || r=fail
assert "second run is a no-op" "$r" "$OUT"
N=$(find "$R2" -maxdepth 1 -name '.backup-update-*' -type d | wc -l | tr -d ' ')
[ "$N" -eq 1 ] && r=pass || r=fail
assert "no-op run creates no second backup" "$r" "found $N backup dirs"

# --------------------------------------------------- 6. multiple roots at once
R4="$TMP_DIR/multi-a"; R5="$TMP_DIR/multi-b"
make_install "$R4" stale; make_install "$R5" missing
bash "$UPDATE" --no-pull --root "$R4" --root "$R5" >/dev/null 2>&1
cmp -s "$R4/$DEST" "$REPO_ROOT/$SRC" && cmp -s "$R5/$DEST" "$REPO_ROOT/$SRC" && r=pass || r=fail
assert "several roots sync in one invocation" "$r"

# ------------------------------------------- 7. refuses to run on a stale manifest
FAKE="$TMP_DIR/fakerepo"
mkdir -p "$FAKE/scripts"
cp -R "$REPO_ROOT/.claude" "$FAKE/.claude"
cp "$REPO_ROOT/manifest.json" "$FAKE/manifest.json"
cp "$UPDATE" "$FAKE/scripts/update.sh"
printf '\n# tampered\n' >> "$FAKE/$SRC"          # content now disagrees with the manifest
R6="$TMP_DIR/guard"; make_install "$R6" stale
set +e
OUT=$(bash "$FAKE/scripts/update.sh" --no-pull --root "$R6" 2>&1); RC=$?
set -e
[ "$RC" -ne 0 ] && grep -q "manifest.json is stale" <<<"$OUT" && r=pass || r=fail
assert "ABORTS when a tracked file disagrees with the manifest" "$r" "rc=$RC"
grep -q "OLD CONTENT" "$R6/$DEST" && r=pass || r=fail
assert "aborted run copied nothing" "$r"

# ------------------------------------------- 8. paths with spaces (regression)
# A real dry run found two installs on the author's machine with spaces in their paths
# ("AI Projects", "AI Entourage/mobile app"). The de-duplication word-split them into
# bogus roots. This test fails against that bug.
R7="$TMP_DIR/with space/deep dir"; make_install "$R7" stale
bash "$UPDATE" --no-pull --root "$R7" >/dev/null 2>&1
cmp -s "$R7/$DEST" "$REPO_ROOT/$SRC" && r=pass || r=fail
assert "root path containing spaces syncs correctly" "$r"
[ -d "$TMP_DIR/with" ] && r=fail || r=pass
assert "no bogus root created by word-splitting" "$r" "a split fragment was treated as a path"

# ---------------------------- 9. AUTO-DISCOVERY over a path containing spaces
# ⛔ This must exercise the script's OWN discovery code, so it runs with NO --root and a
# sandboxed HOME. An earlier version of this test used --root and an inline copy of the
# de-duplication logic; both passed against the buggy script, because --root bypasses
# discovery entirely and a re-implementation tests nothing. A test that cannot go red is
# not a test.
FAKEHOME="$TMP_DIR/fakehome"
D1="$FAKEHOME/.claude"                       # profile
D2="$FAKEHOME/Desktop/AI Projects/proj/.claude"   # project, SPACE in path
make_install "$D1" stale
make_install "$D2" stale
OUT=$(HOME="$FAKEHOME" bash "$UPDATE" --no-pull 2>&1)

cmp -s "$D2/$DEST" "$REPO_ROOT/$SRC" && r=pass || r=fail
assert "auto-discovered install with a SPACE in its path is synced" "$r" "$OUT"

# word-splitting would have produced roots like ".../AI" and "Projects/proj/.claude"
[ -e "$FAKEHOME/Desktop/AI/.claude" ] && r=fail || r=pass
assert "no bogus root created by word-splitting during discovery" "$r"

grep -qE "Found 2 installation" <<<"$OUT" && r=pass || r=fail
assert "discovery counts 2 installs, not 3 fragments" "$r" "$(grep -E '^  ~|^Found' <<<"$OUT" | head -5)"

# --------------------------------------------------------- 10. bad args rejected
set +e
bash "$UPDATE" --no-pull --bogus >/dev/null 2>&1; RC=$?
set -e
[ "$RC" -eq 2 ] && r=pass || r=fail
assert "unknown argument exits 2" "$r" "rc=$RC"

echo ""
if [ "$ERRORS" -eq 0 ]; then echo "All update.sh tests passed."; exit 0
else echo "$ERRORS test(s) FAILED."; exit 1; fi
