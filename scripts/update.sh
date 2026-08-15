#!/bin/bash
# update.sh — Sync every Serious Sidekick installation on this machine from the manifest.
#
# Usage:
#   ./scripts/update.sh                 # pull, then sync every installation found
#   ./scripts/update.sh --dry-run       # report what would change, copy nothing
#   ./scripts/update.sh --no-pull       # skip git pull (offline / testing)
#   ./scripts/update.sh --root DIR ...  # sync only these installation roots
#
# What it does:
#   1. Pulls the latest from git (unless --no-pull)
#   2. Discovers every installation on this machine — profile dirs (~/.claude, ~/.claude-*)
#      AND project installs (any */.claude carrying the toolkit)
#   3. Copies every template-owned file from manifest.json into each one
#   4. Backs up anything it overwrites, then reports what changed
#
# WHY MANIFEST-DRIVEN (2026-08-15): the previous version copied only
# .claude/skills/serious-*/ into ~/.claude/skills. It therefore missed AGENTS entirely,
# missed every profile except ~/.claude, and missed every project install. Measured when
# this rewrite landed: four of six installations on this machine were stale, one was
# missing five files outright — including two reviewer agents and a hook — while
# update.sh reported success. The manifest already encodes the full file set and its
# ownership tiers, and /serious-init already uses it. This now uses the same source.
#
# OWNERSHIP IS RESPECTED: only ownership=template files are synced. settings.json (merge)
# and CLAUDE.md (user-init) are NEVER touched here — they belong to the user, and merging
# them is /serious-init's job.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_DIR/manifest.json"

DRY_RUN=0
DO_PULL=1
EXPLICIT_ROOTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --no-pull) DO_PULL=0; shift ;;
    --root)    shift; [ $# -gt 0 ] || { echo "ERROR: --root needs a directory" >&2; exit 2; }
               EXPLICIT_ROOTS+=("$1"); shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
done

[ -f "$MANIFEST" ] || { echo "ERROR: manifest.json not found at $MANIFEST" >&2; exit 1; }

echo "=== Serious Sidekick Update ==="
echo ""

# ---------------------------------------------------------------- step 1: pull
if [ "$DO_PULL" -eq 1 ]; then
  echo "Pulling latest..."
  (cd "$REPO_DIR" && git pull --ff-only) || {
    echo "WARNING: git pull failed — syncing the working tree as it stands." >&2
  }
  echo ""
fi

# ⛔ The manifest must describe the tree we are about to copy FROM. If a file has been
# edited without regenerating, syncing would push content the manifest does not vouch
# for — the exact "record disagrees with the artifact" defect this toolkit exists to catch.
STALE=$(cd "$REPO_DIR" && python3 - "$MANIFEST" <<'PYEOF'
import json,hashlib,pathlib,sys
files=json.load(open(sys.argv[1]))['files']
bad=[p for p,m in files.items()
     if pathlib.Path(p).exists() and m.get('sha256')
     and hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()!=m['sha256']]
print("\n".join(bad))
PYEOF
)
if [ -n "$STALE" ]; then
  echo "ERROR: manifest.json is stale — these tracked files differ from their recorded checksum:" >&2
  echo "$STALE" | sed 's/^/  /' >&2
  echo "" >&2
  echo "Run bin/generate-manifest.sh and commit, then re-run this script." >&2
  exit 1
fi

# ------------------------------------------------------- step 2: find installs
if [ ${#EXPLICIT_ROOTS[@]} -gt 0 ]; then
  ROOTS=("${EXPLICIT_ROOTS[@]}")
else
  ROOTS=()
  # Profile directories: ~/.claude and ~/.claude-<name>
  for p in "$HOME"/.claude "$HOME"/.claude-*; do
    [ -d "$p/skills" ] || [ -d "$p/agents" ] || continue
    case "$p" in *".backup"*|*"-active"*) continue ;; esac
    ROOTS+=("$p")
  done
  # Project installs: any .claude directory already carrying a serious-* skill.
  # Bounded depth so this cannot walk the whole disk.
  #
  # ⛔ INSTALL PATHS CONTAIN SPACES. Every read here is `IFS= read -r`, and the
  # de-duplication below rebuilds the array line by line. The obvious idiom
  # `ROOTS=($(... | awk ...))` word-splits, turning
  # "~/Desktop/AI Projects/Grokkett/.claude" into two bogus roots — caught on a real
  # dry run, where two installs on the author's machine have spaces in their paths.
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$d" in
      *"/.backup"*)  continue ;;
      "$REPO_DIR"/*) continue ;;   # never sync the source repo onto itself
    esac
    ROOTS+=("$d")
  done < <(find "$HOME" -maxdepth 6 -type d -name ".claude" \
             -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null \
           | while IFS= read -r c; do [ -d "$c/skills/serious-plan" ] && printf '%s\n' "$c"; done)

  # De-duplicate, preserving order AND spaces.
  DEDUP=$(printf '%s\n' "${ROOTS[@]}" | awk '!seen[$0]++')
  ROOTS=()
  while IFS= read -r line; do [ -n "$line" ] && ROOTS+=("$line"); done <<< "$DEDUP"
fi

[ ${#ROOTS[@]} -gt 0 ] || { echo "No installations found. Run /serious-init in a project first."; exit 0; }

echo "Found ${#ROOTS[@]} installation(s):"
printf '  %s\n' "${ROOTS[@]//$HOME/\~}"
echo ""

# ------------------------------------------------------------- step 3: sync
TS=$(date +%Y%m%d-%H%M%S)
TOTAL_U=0; TOTAL_A=0; TOTAL_SKIP=0

for root in "${ROOTS[@]}"; do
  OUT=$(REPO_DIR="$REPO_DIR" ROOT="$root" TS="$TS" DRY_RUN="$DRY_RUN" \
        python3 - "$MANIFEST" <<'PYEOF'
import json,hashlib,pathlib,shutil,os,sys
repo=pathlib.Path(os.environ['REPO_DIR']); root=pathlib.Path(os.environ['ROOT'])
ts=os.environ['TS']; dry=os.environ['DRY_RUN']=='1'
files=json.load(open(sys.argv[1]))['files']
def h(b): return hashlib.sha256(b).hexdigest()
bk=root/f".backup-update-{ts}"
upd=add=skip=0; lines=[]
for src,meta in sorted(files.items()):
    own=meta.get('ownership')
    if own!='template':
        skip+=1; continue
    s=repo/src
    if not s.exists(): continue
    d=root/meta['dest']; sb=s.read_bytes()
    if d.exists() and h(d.read_bytes())==h(sb): continue
    action='update' if d.exists() else 'add'
    if not dry:
        if d.exists():
            b=bk/meta['dest']; b.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(d,b)
        d.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(s,d)
    lines.append(f"    {action:<6} {meta['dest']}")
    if action=='update': upd+=1
    else: add+=1
print(f"COUNTS {upd} {add} {skip}")
print("\n".join(lines))
PYEOF
)
  COUNTS=$(echo "$OUT" | head -1)
  U=$(echo "$COUNTS" | awk '{print $2}'); A=$(echo "$COUNTS" | awk '{print $3}'); S=$(echo "$COUNTS" | awk '{print $4}')
  BODY=$(echo "$OUT" | tail -n +2)
  DISP="${root/#$HOME/\~}"
  if [ "$U" -eq 0 ] && [ "$A" -eq 0 ]; then
    echo "  $DISP — already up to date"
  else
    echo "  $DISP — updated $U, added $A$([ "$DRY_RUN" -eq 1 ] && echo '  (dry run)' || echo "  (backup: .backup-update-$TS)")"
    [ -n "$BODY" ] && echo "$BODY"
  fi
  TOTAL_U=$((TOTAL_U+U)); TOTAL_A=$((TOTAL_A+A)); TOTAL_SKIP=$S
done

# ------------------------------------------------------------ step 4: report
echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN — nothing was copied. $TOTAL_U file(s) would be updated, $TOTAL_A added."
else
  echo "Done. $TOTAL_U file(s) updated, $TOTAL_A added across ${#ROOTS[@]} installation(s)."
  [ "$TOTAL_U" -eq 0 ] && [ "$TOTAL_A" -eq 0 ] && echo "Everything was already up to date."
fi
echo "$TOTAL_SKIP user-owned file(s) left untouched (settings.json, CLAUDE.md) — those are /serious-init's job."
