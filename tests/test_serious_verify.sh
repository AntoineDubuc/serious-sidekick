#!/bin/bash
# test_serious_verify.sh — Tests for bin/serious-update --verify
#
# Read-only drift detection. Reads per-dir state files, manifest source hashes,
# and on-disk file hashes. Prints a per-dir summary. Exits 0 (in-sync), 1
# (drift), or 2 (missing/unparseable state, or no target dirs configured).
#
# Source: plan.md Task 2 (Finding 5), bin/serious-update do_verify spec.
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

# ---------------------------------------------------------------
# Helper: Create a simulated sidekick home with a bare remote.
# Patterned on tests/test_serious_update.sh::setup_sidekick_home().
# Returns: sets SETUP_HOME and SETUP_REMOTE global vars.
# ---------------------------------------------------------------
setup_sidekick_home() {
  local base_dir="$1"
  local home_dir="$base_dir/home"
  local remote_dir="$base_dir/remote.git"

  mkdir -p "$home_dir"
  cd "$home_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  cp "$REPO_ROOT/manifest.json" "$home_dir/manifest.json"
  mkdir -p "$home_dir/lib"
  cp "$REPO_ROOT/lib/serious-common.sh" "$home_dir/lib/serious-common.sh"
  mkdir -p "$home_dir/bin"
  cp "$REPO_ROOT/bin/serious-update" "$home_dir/bin/serious-update"
  chmod +x "$home_dir/bin/serious-update"
  cp "$REPO_ROOT/bin/generate-manifest.sh" "$home_dir/bin/generate-manifest.sh" 2>/dev/null || true
  chmod +x "$home_dir/bin/generate-manifest.sh" 2>/dev/null || true

  if [ -d "$REPO_ROOT/.claude" ]; then
    cp -R "$REPO_ROOT/.claude" "$home_dir/.claude"
  fi

  for f in CLAUDE.md _anti-rationalization-core.md _implementation_plan_template_v6.md; do
    [ -f "$REPO_ROOT/$f" ] && cp "$REPO_ROOT/$f" "$home_dir/$f"
  done

  git add -A
  git commit -q -m "Initial commit"

  git clone -q --bare "$home_dir" "$remote_dir"
  git -C "$home_dir" remote add origin "$remote_dir" 2>/dev/null || \
    git -C "$home_dir" remote set-url origin "$remote_dir"
  git -C "$home_dir" fetch -q origin 2>/dev/null || true
  git -C "$home_dir" branch --set-upstream-to=origin/main main 2>/dev/null || \
    git -C "$home_dir" branch --set-upstream-to=origin/master master 2>/dev/null || true

  cd "$REPO_ROOT"

  SETUP_HOME="$home_dir"
  SETUP_REMOTE="$remote_dir"
}

# Run a regular `serious-update` once to populate state files for a target dir,
# so subsequent `--verify` has something to compare against.
seed_clean_install() {
  local sidekick_home="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  SERIOUS_SIDEKICK_HOME="$sidekick_home" SERIOUS_TARGET_DIRS="$target_dir" \
    bash "$REPO_ROOT/bin/serious-update" >/dev/null 2>&1 || true
}

echo "=== Test: serious-update --verify ==="
echo ""

# ===============================================================
# AC1: --verify flag parses; existing flags still work
# ===============================================================
echo "--- AC1: --verify flag parses cleanly ---"

# AC1.a: --verify accepted as flag (not "unknown flag")
AC1_BASE="$TMP_DIR/ac1"
setup_sidekick_home "$AC1_BASE"
AC1_TARGET="$TMP_DIR/ac1_target"
mkdir -p "$AC1_TARGET"
AC1_EXIT=0
AC1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC1_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC1_EXIT=$?
if echo "$AC1_OUTPUT" | grep -q "Unknown flag"; then
  assert "AC1.a: --verify is a recognized flag" "fail" "got 'Unknown flag' message"
else
  assert "AC1.a: --verify is a recognized flag" "pass"
fi

# AC1.b: --help still works
HELP_EXIT=0
HELP_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" bash "$REPO_ROOT/bin/serious-update" --help 2>&1) || HELP_EXIT=$?
if [ "$HELP_EXIT" -eq 0 ] && echo "$HELP_OUTPUT" | grep -q "Usage"; then
  assert "AC1.b: --help still works after adding --verify" "pass"
else
  assert "AC1.b: --help still works after adding --verify" "fail" "exit=$HELP_EXIT"
fi

# AC1.c: --check still works
AC1C_BASE="$TMP_DIR/ac1c"
setup_sidekick_home "$AC1C_BASE"
AC1C_TARGET="$TMP_DIR/ac1c_target"
mkdir -p "$AC1C_TARGET"
AC1C_EXIT=0
AC1C_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC1C_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --check 2>&1) || AC1C_EXIT=$?
if [ "$AC1C_EXIT" -eq 0 ] && echo "$AC1C_OUTPUT" | grep -q "Staleness check"; then
  assert "AC1.c: --check still works after adding --verify" "pass"
else
  assert "AC1.c: --check still works after adding --verify" "fail" "exit=$AC1C_EXIT"
fi

# ===============================================================
# AC2: usage() text includes --verify and updated exit-code legend
# ===============================================================
echo ""
echo "--- AC2: usage() text updated ---"

USAGE_TEXT=$(SERIOUS_SIDEKICK_HOME="$TMP_DIR" bash "$REPO_ROOT/bin/serious-update" --help 2>&1)
# AC2.a: includes --verify line in Options
if echo "$USAGE_TEXT" | grep -qE '^\s*--verify\s+Check install integrity'; then
  assert "AC2.a: --help text shows --verify in Options block" "pass"
else
  assert "AC2.a: --help text shows --verify in Options block" "fail"
fi

# AC2.b: exit-code legend mentions drift (exit 1)
if echo "$USAGE_TEXT" | grep -qE 'Drift detected'; then
  assert "AC2.b: --help legend includes 'Drift detected' for exit 1" "pass"
else
  assert "AC2.b: --help legend includes 'Drift detected' for exit 1" "fail"
fi

# AC2.c: exit-code legend mentions missing state (exit 2)
if echo "$USAGE_TEXT" | grep -qE '2\s+.*state files? missing'; then
  assert "AC2.c: --help legend includes 'state files missing' for exit 2" "pass"
else
  assert "AC2.c: --help legend includes 'state files missing' for exit 2" "fail"
fi

# ===============================================================
# AC3: Clean install → exit 0 + per-dir summary block
# ===============================================================
echo ""
echo "--- AC3: clean install exits 0 with per-dir summary ---"

AC3_BASE="$TMP_DIR/ac3"
setup_sidekick_home "$AC3_BASE"
AC3_TARGET="$TMP_DIR/ac3_target"
seed_clean_install "$SETUP_HOME" "$AC3_TARGET"
AC3_EXIT=0
AC3_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC3_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC3_EXIT=$?
if [ "$AC3_EXIT" -eq 0 ]; then
  assert "AC3.a: clean install exits 0 from --verify" "pass"
else
  assert "AC3.a: clean install exits 0 from --verify" "fail" "exit=$AC3_EXIT, output=$(echo "$AC3_OUTPUT" | head -5 | tr '\n' '|')"
fi
# AC3.b: per-dir block printed
if echo "$AC3_OUTPUT" | grep -q "dir: $AC3_TARGET" \
   && echo "$AC3_OUTPUT" | grep -q "installed_from_commit:" \
   && echo "$AC3_OUTPUT" | grep -q "head:" \
   && echo "$AC3_OUTPUT" | grep -q "drift_vs_state:" \
   && echo "$AC3_OUTPUT" | grep -q "drift_vs_manifest:"; then
  assert "AC3.b: per-dir summary block has all 5 keys" "pass"
else
  assert "AC3.b: per-dir summary block has all 5 keys" "fail" "missing keys"
fi

# ===============================================================
# AC4: Drift on either axis → exit 1
# ===============================================================
echo ""
echo "--- AC4: drift detection exits 1 ---"

# AC4.a: drift_vs_state — modify a deployed file after install (so on-disk
# hash differs from what's recorded in the state file).
AC4_BASE="$TMP_DIR/ac4"
setup_sidekick_home "$AC4_BASE"
AC4_TARGET="$TMP_DIR/ac4_target"
seed_clean_install "$SETUP_HOME" "$AC4_TARGET"
# Find a deployed file inside the target and modify it
AC4_FIRST_FILE=$(find "$AC4_TARGET" -type f -name '*.md' | head -1)
if [ -n "$AC4_FIRST_FILE" ]; then
  printf '\n# drift injection\n' >> "$AC4_FIRST_FILE"
fi
AC4_EXIT=0
AC4_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC4_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC4_EXIT=$?
if [ "$AC4_EXIT" -eq 1 ] && echo "$AC4_OUTPUT" | grep -qE 'drift_vs_state: [1-9]'; then
  assert "AC4.a: file-edit drift causes exit 1 + drift_vs_state >0" "pass"
else
  assert "AC4.a: file-edit drift causes exit 1 + drift_vs_state >0" "fail" \
    "exit=$AC4_EXIT, file=$AC4_FIRST_FILE, output=$(echo "$AC4_OUTPUT" | grep drift)"
fi

# AC4.b: commit mismatch — make a NEW local commit AFTER seeding so HEAD moves
# past the state file's installed_from_commit. drift_vs_state will be 0 (state
# is still consistent with deployed files), but the commit-mismatch itself
# must drive exit 1.
AC4B_BASE="$TMP_DIR/ac4b"
setup_sidekick_home "$AC4B_BASE"
AC4B_TARGET="$TMP_DIR/ac4b_target"
seed_clean_install "$SETUP_HOME" "$AC4B_TARGET"
# Advance HEAD past the state file's recorded commit (a no-op file change)
cd "$SETUP_HOME"
echo "# bump" >> _anti-rationalization-core.md
git add -A
git -c user.email=t@t.com -c user.name=Test commit -q -m "bump head"
cd "$REPO_ROOT"
AC4B_EXIT=0
AC4B_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC4B_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC4B_EXIT=$?
if [ "$AC4B_EXIT" -eq 1 ]; then
  assert "AC4.b: commit mismatch (installed_from_commit != HEAD) → exit 1" "pass"
else
  assert "AC4.b: commit mismatch (installed_from_commit != HEAD) → exit 1" "fail" \
    "exit=$AC4B_EXIT, output=$(echo "$AC4B_OUTPUT" | head -10 | tr '\n' '|')"
fi

# ===============================================================
# AC5: Missing state file → exit 2 with WARNING
# ===============================================================
echo ""
echo "--- AC5: missing state file exits 2 ---"

AC5_BASE="$TMP_DIR/ac5"
setup_sidekick_home "$AC5_BASE"
AC5_TARGET="$TMP_DIR/ac5_target"
mkdir -p "$AC5_TARGET"   # exists but no state file
AC5_EXIT=0
AC5_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC5_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC5_EXIT=$?
if [ "$AC5_EXIT" -eq 2 ] && echo "$AC5_OUTPUT" | grep -q "missing state file"; then
  assert "AC5: missing state file exits 2 with WARNING text" "pass"
else
  assert "AC5: missing state file exits 2 with WARNING text" "fail" \
    "exit=$AC5_EXIT, output=$(echo "$AC5_OUTPUT" | head -5 | tr '\n' '|')"
fi

# ===============================================================
# AC6: Unparseable state file → exit 2 with ERROR
# ===============================================================
echo ""
echo "--- AC6: unparseable state file exits 2 ---"

AC6_BASE="$TMP_DIR/ac6"
setup_sidekick_home "$AC6_BASE"
AC6_TARGET="$TMP_DIR/ac6_target"
mkdir -p "$AC6_TARGET"
echo "{ this is not valid json }" > "$AC6_TARGET/.serious-sidekick-state.json"
AC6_EXIT=0
AC6_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC6_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC6_EXIT=$?
if [ "$AC6_EXIT" -eq 2 ] && echo "$AC6_OUTPUT" | grep -qE 'state file unparseable|state file (is )?(not )?(valid )?(JSON|json)'; then
  assert "AC6: unparseable state file exits 2 with ERROR text" "pass"
else
  assert "AC6: unparseable state file exits 2 with ERROR text" "fail" \
    "exit=$AC6_EXIT, output=$(echo "$AC6_OUTPUT" | head -5 | tr '\n' '|')"
fi

# ===============================================================
# AC7: Dirty manifest → WARNING printed; warning alone doesn't change exit
# ===============================================================
echo ""
echo "--- AC7: dirty manifest emits WARNING but doesn't change exit code ---"

AC7_BASE="$TMP_DIR/ac7"
setup_sidekick_home "$AC7_BASE"
AC7_TARGET="$TMP_DIR/ac7_target"
seed_clean_install "$SETUP_HOME" "$AC7_TARGET"
# Append whitespace to manifest.json to dirty it (but keep it valid JSON-wise
# at the parse level; do_verify uses git diff to detect dirtiness).
printf '\n' >> "$SETUP_HOME/manifest.json"
AC7_EXIT=0
AC7_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC7_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || AC7_EXIT=$?
if echo "$AC7_OUTPUT" | grep -qE "WARNING:.+manifest\.json is dirty"; then
  assert "AC7.a: dirty manifest WARNING printed to stderr" "pass"
else
  assert "AC7.a: dirty manifest WARNING printed to stderr" "fail" \
    "output=$(echo "$AC7_OUTPUT" | head -10 | tr '\n' '|')"
fi
# The whitespace edit doesn't change parsed manifest contents (no source
# hash drift), so exit code should still be 0 — the warning alone must not
# drive exit code.
if [ "$AC7_EXIT" -eq 0 ]; then
  assert "AC7.b: dirty-manifest warning alone does NOT change exit code" "pass"
else
  assert "AC7.b: dirty-manifest warning alone does NOT change exit code" "fail" "exit=$AC7_EXIT"
fi

# ===============================================================
# AC8: --verify does NOT modify any file (stat -f %m before/after)
# ===============================================================
echo ""
echo "--- AC8: --verify is read-only (file-modification audit) ---"

AC8_BASE="$TMP_DIR/ac8"
setup_sidekick_home "$AC8_BASE"
AC8_TARGET="$TMP_DIR/ac8_target"
seed_clean_install "$SETUP_HOME" "$AC8_TARGET"

# Snapshot mtime of every file under SETUP_HOME + AC8_TARGET (except update.log,
# which IS expected to be appended to — the VERIFY audit line).
snapshot_mtimes() {
  local root="$1"
  local out="$2"
  find "$root" -type f ! -name 'update.log' -exec stat -f '%m %N' {} \; 2>/dev/null | sort > "$out"
}
AC8_BEFORE_HOME="$TMP_DIR/ac8_before_home.txt"
AC8_AFTER_HOME="$TMP_DIR/ac8_after_home.txt"
AC8_BEFORE_TGT="$TMP_DIR/ac8_before_tgt.txt"
AC8_AFTER_TGT="$TMP_DIR/ac8_after_tgt.txt"

snapshot_mtimes "$SETUP_HOME" "$AC8_BEFORE_HOME"
snapshot_mtimes "$AC8_TARGET" "$AC8_BEFORE_TGT"

# Sleep a moment so the mtime granularity (1 sec) actually catches any write.
sleep 1.1

SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC8_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify >/dev/null 2>&1 || true

snapshot_mtimes "$SETUP_HOME" "$AC8_AFTER_HOME"
snapshot_mtimes "$AC8_TARGET" "$AC8_AFTER_TGT"

if diff -q "$AC8_BEFORE_HOME" "$AC8_AFTER_HOME" >/dev/null 2>&1; then
  assert "AC8.a: --verify does not modify any file in SIDEKICK_HOME (except update.log)" "pass"
else
  AC8_DIFF=$(diff "$AC8_BEFORE_HOME" "$AC8_AFTER_HOME" | head -10 | tr '\n' '|')
  assert "AC8.a: --verify does not modify any file in SIDEKICK_HOME (except update.log)" "fail" "diff: $AC8_DIFF"
fi
if diff -q "$AC8_BEFORE_TGT" "$AC8_AFTER_TGT" >/dev/null 2>&1; then
  assert "AC8.b: --verify does not modify any file in the target dir (incl. state file)" "pass"
else
  AC8_DIFF=$(diff "$AC8_BEFORE_TGT" "$AC8_AFTER_TGT" | head -10 | tr '\n' '|')
  assert "AC8.b: --verify does not modify any file in the target dir (incl. state file)" "fail" "diff: $AC8_DIFF"
fi

# ===============================================================
# AC9: VERIFY audit-log entry written exactly once per invocation
# ===============================================================
echo ""
echo "--- AC9: writes one VERIFY audit-log entry ---"

AC9_BASE="$TMP_DIR/ac9"
setup_sidekick_home "$AC9_BASE"
AC9_TARGET="$TMP_DIR/ac9_target"
seed_clean_install "$SETUP_HOME" "$AC9_TARGET"
AC9_LOG_BEFORE=$(grep -cE '^[0-9-]+T[0-9:]+Z VERIFY ' "$SETUP_HOME/update.log" 2>/dev/null | head -1 || true)
AC9_LOG_BEFORE=${AC9_LOG_BEFORE:-0}
SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$AC9_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify >/dev/null 2>&1 || true
AC9_LOG_AFTER=$(grep -cE '^[0-9-]+T[0-9:]+Z VERIFY ' "$SETUP_HOME/update.log" 2>/dev/null | head -1 || true)
AC9_LOG_AFTER=${AC9_LOG_AFTER:-0}
AC9_DELTA=$((AC9_LOG_AFTER - AC9_LOG_BEFORE))
if [ "$AC9_DELTA" -eq 1 ]; then
  assert "AC9.a: exactly one VERIFY entry appended per invocation" "pass"
else
  assert "AC9.a: exactly one VERIFY entry appended per invocation" "fail" "delta=$AC9_DELTA"
fi
# AC9.b: format check — VERIFY <sha> dirs=N/M drift=N
AC9_LINE=$(grep '^[0-9-]*T[0-9:]*Z VERIFY ' "$SETUP_HOME/update.log" 2>/dev/null | tail -1)
if echo "$AC9_LINE" | grep -qE '^[0-9-]+T[0-9:]+Z VERIFY [0-9a-f]+ dirs=[0-9]+/[0-9]+ drift=[0-9]+$'; then
  assert "AC9.b: VERIFY entry format matches 'VERIFY <sha> dirs=N/M drift=N'" "pass"
else
  assert "AC9.b: VERIFY entry format matches 'VERIFY <sha> dirs=N/M drift=N'" "fail" "line='$AC9_LINE'"
fi

# ===============================================================
# NT1: --verify does NOT call git fetch / git pull (offline-safe)
# ===============================================================
echo ""
echo "--- NT1: --verify works offline (no network calls) ---"

NT1_BASE="$TMP_DIR/nt1"
setup_sidekick_home "$NT1_BASE"
NT1_TARGET="$TMP_DIR/nt1_target"
seed_clean_install "$SETUP_HOME" "$NT1_TARGET"
# Break the remote URL so any fetch/pull would fail loudly.
git -C "$SETUP_HOME" remote set-url origin "http://invalid.localhost:1" 2>/dev/null
NT1_EXIT=0
NT1_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$NT1_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || NT1_EXIT=$?
if [ "$NT1_EXIT" -eq 0 ] && ! echo "$NT1_OUTPUT" | grep -qE 'git (pull|fetch) failed'; then
  assert "NT1: --verify against broken remote still exits 0 (no fetch)" "pass"
else
  assert "NT1: --verify against broken remote still exits 0 (no fetch)" "fail" \
    "exit=$NT1_EXIT, output=$(echo "$NT1_OUTPUT" | head -5 | tr '\n' '|')"
fi

# ===============================================================
# NT2: --verify --diff is rejected (mutually exclusive)
# ===============================================================
echo ""
echo "--- NT2: --verify and --diff are mutually exclusive ---"

NT2_BASE="$TMP_DIR/nt2"
setup_sidekick_home "$NT2_BASE"
NT2_TARGET="$TMP_DIR/nt2_target"
mkdir -p "$NT2_TARGET"
NT2_EXIT=0
NT2_OUTPUT=$(SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS="$NT2_TARGET" \
  bash "$REPO_ROOT/bin/serious-update" --verify --diff 2>&1) || NT2_EXIT=$?
if [ "$NT2_EXIT" -eq 1 ] && echo "$NT2_OUTPUT" | grep -qE 'mutually exclusive'; then
  assert "NT2: --verify --diff rejected with exit 1 + mutually-exclusive error" "pass"
else
  assert "NT2: --verify --diff rejected with exit 1 + mutually-exclusive error" "fail" \
    "exit=$NT2_EXIT, output=$(echo "$NT2_OUTPUT" | head -5 | tr '\n' '|')"
fi

# ===============================================================
# NT3: empty SERIOUS_TARGET_DIRS → "No target directories configured" + exit 2
# ===============================================================
echo ""
echo "--- NT3: empty target dirs list ---"

NT3_BASE="$TMP_DIR/nt3"
setup_sidekick_home "$NT3_BASE"
NT3_EXIT=0
# Use HOME pointing to a dir without ~/.claude* so the auto-detect path also
# yields the empty fallback — and pass an empty SERIOUS_TARGET_DIRS via env.
NT3_HOME_EMPTY="$TMP_DIR/nt3_home_empty"
mkdir -p "$NT3_HOME_EMPTY"
NT3_OUTPUT=$(HOME="$NT3_HOME_EMPTY" SERIOUS_SIDEKICK_HOME="$SETUP_HOME" SERIOUS_TARGET_DIRS=" " \
  bash "$REPO_ROOT/bin/serious-update" --verify 2>&1) || NT3_EXIT=$?
if [ "$NT3_EXIT" -eq 2 ] && echo "$NT3_OUTPUT" | grep -q "No target directories configured"; then
  assert "NT3: empty SERIOUS_TARGET_DIRS → 'No target directories configured' + exit 2" "pass"
else
  assert "NT3: empty SERIOUS_TARGET_DIRS → 'No target directories configured' + exit 2" "fail" \
    "exit=$NT3_EXIT, output=$(echo "$NT3_OUTPUT" | head -5 | tr '\n' '|')"
fi

# ===============================================================
# Summary
# ===============================================================
echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "=== All --verify tests passed ==="
  exit 0
else
  echo "=== $ERRORS test(s) failed ==="
  exit 1
fi
