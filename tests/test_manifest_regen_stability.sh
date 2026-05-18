#!/bin/bash
# test_manifest_regen_stability.sh — Tests for Task 3 (Finding 4) of the
# serious-update-reliability plan: manifest regen byte-stability + skip-mv
# guard in bin/serious-update.
#
# Covers:
#   T3.A  generate-manifest.sh is byte-stable across two consecutive runs
#         (same input → same bytes). This is the byte-stability requirement.
#   T3.B  Hash-equal path: when regen output content == committed manifest.json,
#         serious-update no-ops the mv (manifest.json.new is removed,
#         manifest.json mtime is preserved, working tree stays clean).
#   T3.C  Hash-diverge path: when regen output != committed (legitimate
#         override case), the script still completes the mv AND emits the
#         user-visible NOTE on stderr AND writes the audit line
#         "MANIFEST-REGEN-OVERRIDE committed=<short> regen=<short>".
#   T3.D  Final state: after a successful serious-update against a sandbox
#         where committed == regen, `git status --porcelain manifest.json`
#         produces empty output (canonical no-self-defeating-loop check).
#   T3.E  Negative: legitimate user edit to manifest.json is NOT silently
#         reverted — it triggers the diverge path with NOTE + audit.
#   T3.F  Negative: the existing `[ -x generate-manifest.sh ]` guard still
#         fires unchanged when the script is missing/non-executable.
#
# Test fixtures: each scenario builds an isolated sandbox via
# setup_sandbox() so we never depend on the host repo's manifest staleness.
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
# Helper: build a sandboxed sidekick home with bare remote.
# After this:
#   - $SANDBOX_HOME/manifest.json reflects the CURRENT regenerated output
#     of the host repo's sources at HEAD (so committed == regen on clean).
#   - origin remote is in $SANDBOX_REMOTE.
#   - main branch tracks origin/main.
# ---------------------------------------------------------------
setup_sandbox() {
  local base_dir="$1"
  local home_dir="$base_dir/home"
  local remote_dir="$base_dir/remote.git"

  mkdir -p "$home_dir/lib" "$home_dir/bin"

  # Copy source files
  cp "$REPO_ROOT/lib/serious-common.sh" "$home_dir/lib/"
  cp "$REPO_ROOT/bin/serious-update" "$home_dir/bin/"
  cp "$REPO_ROOT/bin/generate-manifest.sh" "$home_dir/bin/"
  chmod +x "$home_dir/bin/serious-update" "$home_dir/bin/generate-manifest.sh"

  # Copy .claude and root-level templates
  cp -R "$REPO_ROOT/.claude" "$home_dir/.claude"
  for f in CLAUDE.md _anti-rationalization-core.md _implementation_plan_template_v6.md; do
    [ -f "$REPO_ROOT/$f" ] && cp "$REPO_ROOT/$f" "$home_dir/$f"
  done

  # Initial git init + commit so we can derive a HEAD sha for regen
  ( cd "$home_dir" \
    && git init -q \
    && git config user.email "t@t" \
    && git config user.name "t" \
    && git config commit.gpgsign false \
    && git add -A \
    && git commit -q -m "init" )

  # Regen against the sandbox sources so committed == regen output.
  # (Without this, the host repo's stale committed manifest would carry over.)
  MANIFEST_PATH="$home_dir/manifest.json" bash "$home_dir/bin/generate-manifest.sh" "$home_dir" >/dev/null 2>&1
  ( cd "$home_dir" && git add manifest.json && git commit -q -m "regen manifest" )

  # Bare remote + tracking
  git clone -q --bare "$home_dir" "$remote_dir"
  ( cd "$home_dir" \
    && git remote add origin "$remote_dir" 2>/dev/null \
    && git fetch -q origin \
    && git branch -M main \
    && git push -q -u origin main 2>/dev/null || true )

  SANDBOX_HOME="$home_dir"
  SANDBOX_REMOTE="$remote_dir"
}

# Push an upstream commit so serious-update finds something to pull.
add_remote_commit_helper() {
  local home_dir="$1"
  local remote_dir="$2"
  local msg="${3:-Update}"
  local clone_dir="$TMP_DIR/clone_$$_$RANDOM"
  git clone -q "$remote_dir" "$clone_dir"
  ( cd "$clone_dir" \
    && git config user.email "t@t" \
    && git config user.name "t" \
    && git config commit.gpgsign false \
    && echo "# touch $(date +%s%N)" >> "_anti-rationalization-core.md" \
    && git add -A \
    && git commit -q -m "$msg" \
    && git push -q origin )
  rm -rf "$clone_dir"
}

stat_mtime() {
  if stat -f %m "$1" >/dev/null 2>&1; then
    stat -f %m "$1"
  else
    stat -c %Y "$1"
  fi
}

short_sha() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print substr($1,1,8)}'
}

echo "=== Test: manifest regen byte-stability + no-op mv (Task 3 / Finding 4) ==="
echo ""

# ---------------------------------------------------------------
# T3.A — generate-manifest.sh is byte-stable across two consecutive runs
# (same input → same bytes). This is the load-bearing "byte-stable" assertion.
# ---------------------------------------------------------------
echo "--- T3.A: generate-manifest.sh byte-stability (2 consecutive runs) ---"
T3A_BASE="$TMP_DIR/t3a"
setup_sandbox "$T3A_BASE"
T3A_OUT1="$TMP_DIR/t3a_m1.json"
T3A_OUT2="$TMP_DIR/t3a_m2.json"
MANIFEST_PATH="$T3A_OUT1" bash "$SANDBOX_HOME/bin/generate-manifest.sh" "$SANDBOX_HOME" >/dev/null 2>&1
MANIFEST_PATH="$T3A_OUT2" bash "$SANDBOX_HOME/bin/generate-manifest.sh" "$SANDBOX_HOME" >/dev/null 2>&1
if diff -q "$T3A_OUT1" "$T3A_OUT2" >/dev/null 2>&1; then
  assert "T3.A: generate-manifest.sh emits byte-identical output across 2 runs" "pass"
else
  assert "T3.A: generate-manifest.sh emits byte-identical output across 2 runs" "fail" \
    "$(diff "$T3A_OUT1" "$T3A_OUT2" | head -10)"
fi
echo ""

# ---------------------------------------------------------------
# T3.B — Canonical-equal path: regen output equals committed manifest in
# content (file set + per-file hashes; `generated_from_commit` may differ
# because committing the manifest itself moves HEAD forward). serious-update
# must no-op the mv so the working tree stays clean.
#
# Sandbox: setup_sandbox already regenerated + committed manifest at HEAD,
# so committed manifest's `files` map matches what regen at any commit will
# emit for the same sources. The upstream commit we then push only touches
# a non-source file (_anti-rationalization-core.md IS in the manifest — so
# we use a file outside the manifest's scope to keep the comparison
# canonical-equal). serious-update pulls, regenerates, compares — equal
# canonicals → no-op mv → manifest.json mtime + hash preserved.
# ---------------------------------------------------------------
echo "--- T3.B: canonical-equal path no-ops the mv ---"
T3B_BASE="$TMP_DIR/t3b"
setup_sandbox "$T3B_BASE"
# Upstream commit that touches a file NOT in the manifest, so sources tracked
# by the manifest stay byte-identical. README.md is at repo root and is not
# included in generate-manifest.sh's scope (only CLAUDE.md, templates, and
# .claude/* are in scope).
T3B_CLONE="$TMP_DIR/t3b_clone"
git clone -q "$SANDBOX_REMOTE" "$T3B_CLONE"
( cd "$T3B_CLONE" \
  && git config user.email "t@t" && git config user.name "t" \
  && git config commit.gpgsign false \
  && echo "non-manifest change $(date +%s%N)" > README.md \
  && git add README.md \
  && git commit -q -m "non-manifest touch" \
  && git push -q origin )
rm -rf "$T3B_CLONE"

T3B_TARGETS="$T3B_BASE/targets"
mkdir -p "$T3B_TARGETS/claude"

# Capture pre-state
T3B_PRE_MTIME=$(stat_mtime "$SANDBOX_HOME/manifest.json")
T3B_PRE_HASH=$(shasum -a 256 "$SANDBOX_HOME/manifest.json" | awk '{print $1}')
sleep 1  # ensure mtime resolution > 1s so a mv would be detectable
T3B_EXIT=0
T3B_OUT=$(SERIOUS_SIDEKICK_HOME="$SANDBOX_HOME" SERIOUS_TARGET_DIRS="$T3B_TARGETS/claude" \
          bash "$SANDBOX_HOME/bin/serious-update" 2>&1) || T3B_EXIT=$?
T3B_POST_MTIME=$(stat_mtime "$SANDBOX_HOME/manifest.json")
T3B_POST_HASH=$(shasum -a 256 "$SANDBOX_HOME/manifest.json" | awk '{print $1}')

# (1) manifest.json.new is NOT lingering on disk (either removed via no-op or via successful mv).
if [ ! -f "$SANDBOX_HOME/manifest.json.new" ]; then
  assert "T3.B.1: manifest.json.new not lingering after run" "pass"
else
  assert "T3.B.1: manifest.json.new not lingering after run" "fail"
fi

# (2) mtime is unchanged → no mv happened.
if [ "$T3B_PRE_MTIME" = "$T3B_POST_MTIME" ]; then
  assert "T3.B.2: manifest.json mtime unchanged (no-op mv worked)" "pass"
else
  assert "T3.B.2: manifest.json mtime unchanged (no-op mv worked)" "fail" \
    "pre=$T3B_PRE_MTIME post=$T3B_POST_MTIME"
fi

# (3) Hash unchanged (sanity).
if [ "$T3B_PRE_HASH" = "$T3B_POST_HASH" ]; then
  assert "T3.B.3: manifest.json hash unchanged after no-op run" "pass"
else
  assert "T3.B.3: manifest.json hash unchanged after no-op run" "fail"
fi

# (4) No NOTE on stderr (no override happened).
if ! echo "$T3B_OUT" | grep -q "MANIFEST-REGEN-OVERRIDE\|committed manifest.json was overwritten"; then
  assert "T3.B.4: no override NOTE/audit when content matched" "pass"
else
  assert "T3.B.4: no override NOTE/audit when content matched" "fail" "saw override signal in output"
fi

# (5) update.log does NOT contain MANIFEST-REGEN-OVERRIDE.
if ! grep -q "MANIFEST-REGEN-OVERRIDE" "$SANDBOX_HOME/update.log" 2>/dev/null; then
  assert "T3.B.5: audit log does NOT contain MANIFEST-REGEN-OVERRIDE on equal path" "pass"
else
  assert "T3.B.5: audit log does NOT contain MANIFEST-REGEN-OVERRIDE on equal path" "fail"
fi
echo ""

# ---------------------------------------------------------------
# T3.C — Hash-diverge path: committed != regen output → mv proceeds AND
# NOTE on stderr + MANIFEST-REGEN-OVERRIDE in audit.
# ---------------------------------------------------------------
echo "--- T3.C: hash-diverge path emits NOTE + audit + completes mv ---"
T3C_BASE="$TMP_DIR/t3c"
setup_sandbox "$T3C_BASE"
# Make the committed manifest deliberately different from what regen will emit
# (simulating either an upstream that drifted or a user-edited manifest).
# Inject a custom field while leaving JSON valid.
python3 -c "
import json
p = '$SANDBOX_HOME/manifest.json'
with open(p) as f:
    m = json.load(f)
m['_user_custom_field'] = 'will be overwritten'
with open(p, 'w') as f:
    json.dump(m, f, indent=2, sort_keys=True, ensure_ascii=False)
    f.write('\n')
"
( cd "$SANDBOX_HOME" && git add manifest.json && git -c user.email=t@t -c user.name=t commit -q -m "custom edit" && git push -q origin main )
# Capture committed hash short
T3C_COMMITTED_SHORT=$(short_sha "$SANDBOX_HOME/manifest.json")
# Trigger an upstream-driven pull
add_remote_commit_helper "$SANDBOX_HOME" "$SANDBOX_REMOTE" "trigger regen on diverged"

T3C_TARGETS="$T3C_BASE/targets"
mkdir -p "$T3C_TARGETS/claude"
T3C_EXIT=0
T3C_OUT=$(SERIOUS_SIDEKICK_HOME="$SANDBOX_HOME" SERIOUS_TARGET_DIRS="$T3C_TARGETS/claude" \
          bash "$SANDBOX_HOME/bin/serious-update" 2>&1) || T3C_EXIT=$?

# (1) NOTE on stderr.
if echo "$T3C_OUT" | grep -q "NOTE: committed manifest.json was overwritten by regenerated output"; then
  assert "T3.C.1: NOTE emitted to stderr on diverge" "pass"
else
  assert "T3.C.1: NOTE emitted to stderr on diverge" "fail" \
    "output: $(echo "$T3C_OUT" | tail -5)"
fi

# (2) MANIFEST-REGEN-OVERRIDE in audit log.
if grep -q "MANIFEST-REGEN-OVERRIDE" "$SANDBOX_HOME/update.log" 2>/dev/null; then
  assert "T3.C.2: MANIFEST-REGEN-OVERRIDE in audit log on diverge" "pass"
else
  assert "T3.C.2: MANIFEST-REGEN-OVERRIDE in audit log on diverge" "fail" \
    "audit: $(tail -5 "$SANDBOX_HOME/update.log" 2>/dev/null)"
fi

# (3) Audit line includes both short hashes.
if grep -Eq "MANIFEST-REGEN-OVERRIDE committed=[0-9a-f]{8} regen=[0-9a-f]{8}" \
     "$SANDBOX_HOME/update.log" 2>/dev/null; then
  assert "T3.C.3: audit line shape is 'MANIFEST-REGEN-OVERRIDE committed=<8> regen=<8>'" "pass"
else
  assert "T3.C.3: audit line shape is 'MANIFEST-REGEN-OVERRIDE committed=<8> regen=<8>'" "fail"
fi

# (4) The user's custom field was overwritten (so the mv did proceed).
if ! grep -q "_user_custom_field" "$SANDBOX_HOME/manifest.json"; then
  assert "T3.C.4: mv proceeded — committed manifest replaced with regen output" "pass"
else
  assert "T3.C.4: mv proceeded — committed manifest replaced with regen output" "fail" \
    "_user_custom_field still present in manifest.json"
fi

# (5) manifest.json.new cleaned up.
if [ ! -f "$SANDBOX_HOME/manifest.json.new" ]; then
  assert "T3.C.5: manifest.json.new cleaned up after diverge mv" "pass"
else
  assert "T3.C.5: manifest.json.new cleaned up after diverge mv" "fail"
fi
echo ""

# ---------------------------------------------------------------
# T3.D — Final state: after serious-update against clean sandbox (sources
# unchanged upstream), `git status --porcelain manifest.json` produces empty
# output. Upstream change touches a non-manifest file so the only thing that
# would differ between committed and regen is `generated_from_commit` —
# which the canonical comparison now ignores.
# ---------------------------------------------------------------
push_non_manifest_change() {
  # Push a commit that touches README.md only (outside the manifest scope).
  local home="$1" remote="$2" tag="$3"
  local clone="$TMP_DIR/clone_nm_$$_$RANDOM"
  git clone -q "$remote" "$clone"
  ( cd "$clone" \
    && git config user.email "t@t" && git config user.name "t" \
    && git config commit.gpgsign false \
    && echo "$tag $(date +%s%N)" >> README.md \
    && git add README.md \
    && git commit -q -m "$tag" \
    && git push -q origin )
  rm -rf "$clone"
}

echo "--- T3.D: post-run git status manifest.json is clean ---"
T3D_BASE="$TMP_DIR/t3d"
setup_sandbox "$T3D_BASE"
push_non_manifest_change "$SANDBOX_HOME" "$SANDBOX_REMOTE" "T3D trigger"
T3D_TARGETS="$T3D_BASE/targets"
mkdir -p "$T3D_TARGETS/claude"
SERIOUS_SIDEKICK_HOME="$SANDBOX_HOME" SERIOUS_TARGET_DIRS="$T3D_TARGETS/claude" \
  bash "$SANDBOX_HOME/bin/serious-update" >/dev/null 2>&1 || true
T3D_STATUS=$(git -C "$SANDBOX_HOME" status --porcelain manifest.json 2>/dev/null || true)
if [ -z "$T3D_STATUS" ]; then
  assert "T3.D: git status --porcelain manifest.json is empty after serious-update" "pass"
else
  assert "T3.D: git status --porcelain manifest.json is empty after serious-update" "fail" \
    "status=$T3D_STATUS"
fi

# T3.D.2 — repeat 3 times (per plan AC #7 "N consecutive runs"). Already-clean
# manifest should stay clean across multiple successive non-manifest updates.
T3D_CLEAN_RUNS=0
for i in 1 2 3; do
  push_non_manifest_change "$SANDBOX_HOME" "$SANDBOX_REMOTE" "T3D loop $i"
  SERIOUS_SIDEKICK_HOME="$SANDBOX_HOME" SERIOUS_TARGET_DIRS="$T3D_TARGETS/claude" \
    bash "$SANDBOX_HOME/bin/serious-update" >/dev/null 2>&1 || true
  if [ -z "$(git -C "$SANDBOX_HOME" status --porcelain manifest.json 2>/dev/null || true)" ]; then
    T3D_CLEAN_RUNS=$((T3D_CLEAN_RUNS + 1))
  fi
done
if [ "$T3D_CLEAN_RUNS" -eq 3 ]; then
  assert "T3.D.2: manifest.json stays clean across 3 consecutive serious-update runs" "pass"
else
  assert "T3.D.2: manifest.json stays clean across 3 consecutive serious-update runs" "fail" \
    "clean_runs=$T3D_CLEAN_RUNS/3"
fi
echo ""

# ---------------------------------------------------------------
# T3.E — Negative: legitimate user edit triggers diverge path (NOT silent revert).
# ---------------------------------------------------------------
echo "--- T3.E: negative — user edit triggers NOTE + override (no silent revert) ---"
T3E_BASE="$TMP_DIR/t3e"
setup_sandbox "$T3E_BASE"
# User adds a custom field by hand (simulates "I'm experimenting"):
python3 -c "
import json
p = '$SANDBOX_HOME/manifest.json'
with open(p) as f:
    m = json.load(f)
m['_user_experiment'] = 'do not lose silently'
with open(p, 'w') as f:
    json.dump(m, f, indent=2, sort_keys=True, ensure_ascii=False)
    f.write('\n')
"
# Do NOT commit it — leave it as a working-tree edit (matches the real
# "user tweaks manifest.json locally" scenario).
# We need do_git_pull to succeed first though — a dirty manifest blocks git pull.
# So commit the edit, then add an upstream change to force pull+regen.
( cd "$SANDBOX_HOME" && git add manifest.json && git -c user.email=t@t -c user.name=t commit -q -m "user edit" && git push -q origin main )
add_remote_commit_helper "$SANDBOX_HOME" "$SANDBOX_REMOTE" "upstream after user edit"

T3E_TARGETS="$T3E_BASE/targets"
mkdir -p "$T3E_TARGETS/claude"
T3E_EXIT=0
T3E_OUT=$(SERIOUS_SIDEKICK_HOME="$SANDBOX_HOME" SERIOUS_TARGET_DIRS="$T3E_TARGETS/claude" \
          bash "$SANDBOX_HOME/bin/serious-update" 2>&1) || T3E_EXIT=$?

# User sees the NOTE
if echo "$T3E_OUT" | grep -q "NOTE: committed manifest.json was overwritten"; then
  assert "T3.E.1: user edit triggers visible NOTE (no silent revert)" "pass"
else
  assert "T3.E.1: user edit triggers visible NOTE (no silent revert)" "fail"
fi

# Audit line fires
if grep -q "MANIFEST-REGEN-OVERRIDE" "$SANDBOX_HOME/update.log" 2>/dev/null; then
  assert "T3.E.2: user edit logs MANIFEST-REGEN-OVERRIDE to audit" "pass"
else
  assert "T3.E.2: user edit logs MANIFEST-REGEN-OVERRIDE to audit" "fail"
fi
echo ""

# ---------------------------------------------------------------
# T3.F — Negative: missing/non-executable generate-manifest.sh → existing
# `[ -x ]` guard at the start of the block still skips silently.
# ---------------------------------------------------------------
echo "--- T3.F: negative — [ -x ] guard preserved when generate-manifest.sh missing ---"
T3F_BASE="$TMP_DIR/t3f"
setup_sandbox "$T3F_BASE"
rm -f "$SANDBOX_HOME/bin/generate-manifest.sh"
# Don't commit removal — generate-manifest.sh removal is a local install issue.
# Need an upstream commit to trigger do_git_pull. The committed version still
# has the file, so after pull it would come back — instead, use a stub that's
# present but non-executable to exercise the [ -x ] guard.
cat > "$SANDBOX_HOME/bin/generate-manifest.sh" <<'STUB'
#!/bin/bash
echo "should not run" >&2
exit 99
STUB
chmod -x "$SANDBOX_HOME/bin/generate-manifest.sh"
add_remote_commit_helper "$SANDBOX_HOME" "$SANDBOX_REMOTE" "T3.F trigger"

T3F_TARGETS="$T3F_BASE/targets"
mkdir -p "$T3F_TARGETS/claude"
T3F_PRE_MANIFEST_HASH=$(shasum -a 256 "$SANDBOX_HOME/manifest.json" | awk '{print $1}')
T3F_EXIT=0
T3F_OUT=$(SERIOUS_SIDEKICK_HOME="$SANDBOX_HOME" SERIOUS_TARGET_DIRS="$T3F_TARGETS/claude" \
          bash "$SANDBOX_HOME/bin/serious-update" 2>&1) || T3F_EXIT=$?
T3F_POST_MANIFEST_HASH=$(shasum -a 256 "$SANDBOX_HOME/manifest.json" | awk '{print $1}')

# (1) Exit is not the regen-failure path (no "manifest regeneration failed").
if ! echo "$T3F_OUT" | grep -q "manifest regeneration failed"; then
  assert "T3.F.1: missing generate-manifest.sh executable does not trigger regen-failure path" "pass"
else
  assert "T3.F.1: missing generate-manifest.sh executable does not trigger regen-failure path" "fail"
fi

# (2) Stub never ran (its stderr would say "should not run").
if ! echo "$T3F_OUT" | grep -q "should not run"; then
  assert "T3.F.2: non-executable generate-manifest.sh stub was not invoked" "pass"
else
  assert "T3.F.2: non-executable generate-manifest.sh stub was not invoked" "fail"
fi

# (3) Existing manifest.json untouched.
if [ "$T3F_PRE_MANIFEST_HASH" = "$T3F_POST_MANIFEST_HASH" ]; then
  assert "T3.F.3: existing manifest.json untouched when [ -x ] guard skips" "pass"
else
  assert "T3.F.3: existing manifest.json untouched when [ -x ] guard skips" "fail"
fi
echo ""

echo "=== Manifest Regen Stability Tests Complete: $ERRORS error(s) ==="
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
