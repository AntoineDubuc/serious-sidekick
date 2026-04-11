#!/bin/bash
# generate-manifest.sh — Generates manifest.json for Serious Sidekick distribution
#
# Usage: bin/generate-manifest.sh [repo_root]
#   repo_root defaults to current directory
#   Output path can be overridden with MANIFEST_PATH env var
#
# Walks serious-* skills, agents, hooks, templates, settings.json, and CLAUDE.md.
# Computes SHA-256 for each file (except merge-tier). Assigns ownership tiers.
# Writes deterministic manifest.json with sorted keys.

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
MANIFEST_PATH="${MANIFEST_PATH:-$REPO_ROOT/manifest.json}"

# Source the library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
source "$LIB_DIR/serious-common.sh"

# Validate we're in a repo with .claude/
if [ ! -d "$REPO_ROOT/.claude" ]; then
  echo "ERROR: No .claude/ directory found in $REPO_ROOT" >&2
  exit 1
fi

# Validate git repo
HEAD_SHA=$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null) || {
  echo "ERROR: Not a git repository or git rev-parse HEAD failed in $REPO_ROOT" >&2
  exit 1
}

# Collect files and build manifest via python3
python3 -c "
import json, subprocess, sys, os, hashlib

repo_root = sys.argv[1]
head_sha = sys.argv[2]
manifest_path = sys.argv[3]

files = {}

def hash_file(path):
    \"\"\"Compute SHA-256 hex digest of a file.\"\"\"
    h = hashlib.sha256()
    try:
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                h.update(chunk)
        return h.hexdigest()
    except (FileNotFoundError, PermissionError) as e:
        print(f'WARNING: Cannot hash {path}: {e}', file=sys.stderr)
        return None

def add_file(source_rel, ownership, dest, merge_key=None):
    \"\"\"Add a file entry to the manifest.\"\"\"
    full_path = os.path.join(repo_root, source_rel)
    if not os.path.isfile(full_path):
        print(f'WARNING: File disappeared (TOCTOU): {source_rel}', file=sys.stderr)
        return
    entry = {
        'ownership': ownership,
        'dest': dest,
    }
    if ownership != 'merge':
        sha = hash_file(full_path)
        if sha is None:
            print(f'WARNING: Skipping {source_rel} due to hash failure', file=sys.stderr)
            return
        entry['sha256'] = sha
    if merge_key is not None:
        entry['merge_key'] = merge_key
    files[source_rel] = entry

# 1. Walk .claude/skills/serious-*/
skills_dir = os.path.join(repo_root, '.claude', 'skills')
if os.path.isdir(skills_dir):
    for skill_name in sorted(os.listdir(skills_dir)):
        if not skill_name.startswith('serious-'):
            continue
        skill_dir = os.path.join(skills_dir, skill_name)
        if not os.path.isdir(skill_dir):
            continue
        for dirpath, dirnames, filenames in os.walk(skill_dir):
            dirnames.sort()
            for fname in sorted(filenames):
                full = os.path.join(dirpath, fname)
                rel = os.path.relpath(full, repo_root)
                # dest is relative to .claude/ target
                skill_rel = os.path.relpath(full, os.path.join(repo_root, '.claude'))
                add_file(rel, 'template', skill_rel)

# 1b. Walk .claude/skills/_shared/ (shared utilities used by multiple skills)
shared_dir = os.path.join(skills_dir, '_shared')
if os.path.isdir(shared_dir):
    for dirpath, dirnames, filenames in os.walk(shared_dir):
        dirnames.sort()
        for fname in sorted(filenames):
            full = os.path.join(dirpath, fname)
            rel = os.path.relpath(full, repo_root)
            # dest is relative to .claude/ target
            shared_rel = os.path.relpath(full, os.path.join(repo_root, '.claude'))
            add_file(rel, 'template', shared_rel)

# 2. Walk .claude/agents/serious-*.md
agents_dir = os.path.join(repo_root, '.claude', 'agents')
if os.path.isdir(agents_dir):
    for fname in sorted(os.listdir(agents_dir)):
        if fname.startswith('serious-') and fname.endswith('.md'):
            rel = os.path.join('.claude', 'agents', fname)
            add_file(rel, 'template', f'agents/{fname}')

# 3. .claude/settings.json (merge tier)
settings_rel = os.path.join('.claude', 'settings.json')
if os.path.isfile(os.path.join(repo_root, settings_rel)):
    add_file(settings_rel, 'merge', 'settings.json', merge_key='hooks')

# 4. CLAUDE.md (user-init tier)
if os.path.isfile(os.path.join(repo_root, 'CLAUDE.md')):
    add_file('CLAUDE.md', 'user-init', 'CLAUDE.md')

# 5. Template files at repo root
for template_file in ['_implementation_plan_template_v6.md', '_anti-rationalization-core.md']:
    if os.path.isfile(os.path.join(repo_root, template_file)):
        add_file(template_file, 'template', f'../{template_file}')

manifest = {
    'version': 1,
    'generated_from_commit': head_sha,
    'files': dict(sorted(files.items()))
}

output = json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=False)

with open(manifest_path, 'w') as f:
    f.write(output)
    f.write('\n')

print(f'Generated manifest with {len(files)} file entries -> {manifest_path}')
" "$REPO_ROOT" "$HEAD_SHA" "$MANIFEST_PATH"
