#!/bin/bash
# serious-common.sh — Shared library for Serious Sidekick foundation
#
# This file is sourced, not executed. All functions use local variables
# to prevent namespace pollution.
#
# Usage: source lib/serious-common.sh

# --- JSON Backend Detection ---
# Detected once at source time. Re-sourcing does not re-detect.
if [ -z "${_SERIOUS_JSON_BACKEND:-}" ]; then
  if command -v python3 >/dev/null 2>&1; then
    _SERIOUS_JSON_BACKEND="python3"
  elif command -v jq >/dev/null 2>&1; then
    _SERIOUS_JSON_BACKEND="jq"
  else
    echo "ERROR: Neither python3 nor jq found. At least one is required." >&2
    return 1 2>/dev/null || exit 1
  fi
fi

# --- Core Utility Functions ---

# hash_file <path>
# Returns the SHA-256 hex digest of the file. Uses shasum or sha256sum directly
# (does NOT depend on JSON backend).
hash_file() {
  local file_path="$1"
  if [ ! -f "$file_path" ]; then
    echo "ERROR: hash_file: file not found: $file_path" >&2
    return 1
  fi
  local hash_output
  if command -v shasum >/dev/null 2>&1; then
    hash_output=$(shasum -a 256 "$file_path" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    hash_output=$(sha256sum "$file_path" | awk '{print $1}')
  else
    echo "ERROR: hash_file: neither shasum nor sha256sum found" >&2
    return 1
  fi
  echo "$hash_output"
}

# validate_json <path>
# Exits 0 if file contains valid JSON, 1 otherwise.
validate_json() {
  local file_path="$1"
  if [ ! -f "$file_path" ]; then
    echo "ERROR: validate_json: file not found: $file_path" >&2
    return 1
  fi
  if [ ! -s "$file_path" ]; then
    return 1
  fi
  case "$_SERIOUS_JSON_BACKEND" in
    python3)
      python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        content = f.read().strip()
        if not content:
            sys.exit(1)
        json.loads(content)
        # Ensure no trailing content: json.loads handles this by only parsing
        # the first valid JSON value. We need strict mode.
except (json.JSONDecodeError, ValueError, FileNotFoundError):
    sys.exit(1)
" "$file_path" 2>/dev/null
      ;;
    jq)
      jq empty < "$file_path" 2>/dev/null
      ;;
    *)
      echo "ERROR: validate_json: unknown backend '$_SERIOUS_JSON_BACKEND'" >&2
      return 1
      ;;
  esac
}

# backup_file <path>
# Creates a backup at <path>.backup.<YYYYMMDD_HHMMSS>.
# Prints the backup path to stdout. Exits non-zero if source doesn't exist.
backup_file() {
  local file_path="$1"
  if [ ! -f "$file_path" ]; then
    echo "ERROR: backup_file: file not found: $file_path" >&2
    return 1
  fi
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_path="${file_path}.backup.${timestamp}"
  cp "$file_path" "$backup_path" || return 1
  echo "$backup_path"
}

# restore_backup <backup_path> <original_path>
# Copies the backup file to the original location. Exits non-zero if backup doesn't exist.
restore_backup() {
  local backup_path="$1"
  local original_path="$2"
  if [ ! -f "$backup_path" ]; then
    echo "ERROR: restore_backup: backup file not found: $backup_path" >&2
    return 1
  fi
  cp "$backup_path" "$original_path" || return 1
}

# --- Manifest Functions ---

# parse_manifest <path>
# Validates a manifest.json file and outputs its entries in a queryable format.
# Output format: one line per file entry:
#   <source_path>\t<ownership>\t<dest>\t<sha256>\t<merge_key>
# (sha256 and merge_key are empty string if not present)
# Exits 0 if valid, 1 if invalid.
parse_manifest() {
  local manifest_path="$1"
  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: parse_manifest: file not found: $manifest_path" >&2
    return 1
  fi
  if ! validate_json "$manifest_path"; then
    echo "ERROR: parse_manifest: invalid JSON in $manifest_path" >&2
    return 1
  fi

  local result
  result=$(python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

errors = []

# Validate top-level fields
if 'version' not in data:
    errors.append('missing required field: version')
elif not isinstance(data['version'], int):
    errors.append('version must be an integer')

if 'generated_from_commit' not in data:
    errors.append('missing required field: generated_from_commit')
elif not isinstance(data['generated_from_commit'], str):
    errors.append('generated_from_commit must be a string')

if 'files' not in data:
    errors.append('missing required field: files')
elif not isinstance(data['files'], dict):
    errors.append('files must be an object')

if errors:
    for e in errors:
        print(f'ERROR: parse_manifest: {e}', file=sys.stderr)
    sys.exit(1)

# Validate each file entry
for source_path, entry in sorted(data['files'].items()):
    if not isinstance(entry, dict):
        print(f'ERROR: parse_manifest: entry {source_path} must be an object', file=sys.stderr)
        sys.exit(1)
    if 'ownership' not in entry:
        print(f'ERROR: parse_manifest: entry {source_path} missing required field: ownership', file=sys.stderr)
        sys.exit(1)
    if 'dest' not in entry:
        print(f'ERROR: parse_manifest: entry {source_path} missing required field: dest', file=sys.stderr)
        sys.exit(1)
    if entry['ownership'] not in ('template', 'merge', 'user-init'):
        print(f'ERROR: parse_manifest: entry {source_path} has invalid ownership: {entry[\"ownership\"]}', file=sys.stderr)
        sys.exit(1)

    sha256 = entry.get('sha256', '')
    merge_key = entry.get('merge_key', '')
    print(f'{source_path}\t{entry[\"ownership\"]}\t{entry[\"dest\"]}\t{sha256}\t{merge_key}')
" "$manifest_path" 2>&1)
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "$result" >&2
    return 1
  fi
  echo "$result"
}

# --- Settings Merge Engine ---

# merge_settings <installed_path> <template_path>
# Merges template hooks into the installed settings.json.
# - Validates both inputs as JSON first
# - Creates backup of installed file before modifying
# - Composite key identity:
#   PreToolUse/PostToolUse: (hook_type, matcher, if_pattern)
#   Stop: (Stop, command_path) since all Stop hooks share empty matcher
# - Serious-owned = command field references serious-*
# - Replace matched serious entries from template
# - Append new serious entries
# - Preserve non-serious entries
# - Non-hook keys are user-owned, never overwritten
# - Validates merged output before writing
# - Restores backup on validation or write failure
merge_settings() {
  local installed_path="$1"
  local template_path="$2"

  # Validate template first — if invalid, do NOT modify or backup installed
  if [ ! -f "$template_path" ]; then
    echo "ERROR: merge_settings: invalid template: file not found: $template_path" >&2
    return 1
  fi
  if ! validate_json "$template_path"; then
    echo "ERROR: merge_settings: invalid template: not valid JSON: $template_path" >&2
    return 1
  fi

  # Validate installed file exists and is valid JSON
  if [ ! -f "$installed_path" ]; then
    echo "ERROR: merge_settings: installed file not found: $installed_path" >&2
    return 1
  fi
  if ! validate_json "$installed_path"; then
    echo "ERROR: merge_settings: installed file is not valid JSON: $installed_path" >&2
    return 1
  fi

  # Create backup of installed file
  local backup_path
  backup_path=$(backup_file "$installed_path") || {
    echo "ERROR: merge_settings: failed to create backup" >&2
    return 1
  }

  # Perform the merge using python3
  local merged_tmp
  merged_tmp=$(mktemp)
  local merge_exit=0
  python3 -c "
import json, sys, re

installed_path = sys.argv[1]
template_path = sys.argv[2]
output_path = sys.argv[3]

with open(installed_path) as f:
    installed = json.load(f)
with open(template_path) as f:
    template = json.load(f)

def is_serious(command_str):
    \"\"\"Check if a hook command references serious-* scripts.\"\"\"
    return bool(re.search(r'serious-', command_str))

def get_composite_key(hook_type, matcher, hook_entry):
    \"\"\"Get the composite identity key for a hook entry.\"\"\"
    if hook_type == 'Stop':
        # For Stop hooks, identity is (Stop, command_path)
        return ('Stop', hook_entry.get('command', ''))
    else:
        # For PreToolUse/PostToolUse: (hook_type, matcher, if_pattern)
        return (hook_type, matcher, hook_entry.get('if', ''))

def merge_hook_type(hook_type, installed_groups, template_groups):
    \"\"\"Merge a single hook type (e.g., PreToolUse, Stop).\"\"\"
    # Build index of ALL serious entries from template by composite key
    template_serious = {}  # composite_key -> (matcher, hook_entry)
    for group in template_groups:
        matcher = group.get('matcher', '')
        for hook in group.get('hooks', []):
            if is_serious(hook.get('command', '')):
                key = get_composite_key(hook_type, matcher, hook)
                template_serious[key] = (matcher, hook)

    # Build index of installed entries
    # We need to: replace matched serious, remove unmatched serious, keep non-serious
    result_groups = {}  # matcher -> list of hooks

    for group in installed_groups:
        matcher = group.get('matcher', '')
        for hook in group.get('hooks', []):
            key = get_composite_key(hook_type, matcher, hook)
            if is_serious(hook.get('command', '')):
                # Serious entry — only keep if still in template (replaced with template version)
                if key in template_serious:
                    _, template_hook = template_serious[key]
                    if matcher not in result_groups:
                        result_groups[matcher] = []
                    result_groups[matcher].append(template_hook)
                    del template_serious[key]  # consumed
                # else: serious entry removed from template, drop it
            else:
                # Non-serious entry — preserve
                if matcher not in result_groups:
                    result_groups[matcher] = []
                result_groups[matcher].append(hook)

    # Append remaining new serious entries from template
    for key, (matcher, hook) in template_serious.items():
        if matcher not in result_groups:
            result_groups[matcher] = []
        result_groups[matcher].append(hook)

    # Convert back to array of group objects
    output_groups = []
    for matcher in sorted(result_groups.keys()):
        hooks = result_groups[matcher]
        if hooks:
            group = {'hooks': hooks}
            if matcher:
                group['matcher'] = matcher
            output_groups.append(group)
    return output_groups

# Start with installed as base — preserve all non-hook keys
merged = {}
for key, value in installed.items():
    if key != 'hooks':
        merged[key] = value

# Merge hooks
installed_hooks = installed.get('hooks', {})
template_hooks = template.get('hooks', {})

merged_hooks = {}

# Process each hook type that exists in either installed or template
all_hook_types = set(list(installed_hooks.keys()) + list(template_hooks.keys()))
for hook_type in sorted(all_hook_types):
    installed_groups = installed_hooks.get(hook_type, [])
    template_groups = template_hooks.get(hook_type, [])
    merged_hooks[hook_type] = merge_hook_type(hook_type, installed_groups, template_groups)

if merged_hooks:
    merged['hooks'] = merged_hooks

output = json.dumps(merged, indent=2, ensure_ascii=False)
with open(output_path, 'w') as f:
    f.write(output)
    f.write('\n')
" "$installed_path" "$template_path" "$merged_tmp" 2>&1 || merge_exit=$?

  if [ "$merge_exit" -ne 0 ]; then
    echo "ERROR: merge_settings: merge computation failed" >&2
    restore_backup "$backup_path" "$installed_path" 2>/dev/null
    rm -f "$merged_tmp"
    return 1
  fi

  # Validate merged output before writing
  if ! validate_json "$merged_tmp"; then
    echo "ERROR: merge_settings: merged output is not valid JSON, restoring backup" >&2
    restore_backup "$backup_path" "$installed_path"
    rm -f "$merged_tmp"
    return 1
  fi

  # Write merged result to installed path
  if ! cp "$merged_tmp" "$installed_path" 2>/dev/null; then
    echo "ERROR: merge_settings: failed to write merged output, restoring backup" >&2
    restore_backup "$backup_path" "$installed_path"
    rm -f "$merged_tmp"
    return 1
  fi

  rm -f "$merged_tmp"
}

# --- State File Management ---

# update_state <target_dir> <commit_sha> <previous_commit> <file_hashes_json>
# Writes .serious-sidekick-state.json to target_dir.
# Schema: installed_from_commit, previous_commit, installed_at (ISO 8601), file_hashes
# Validates file_hashes_json BEFORE writing (pre-write validation).
# Validates written file after writing (post-write validation).
# Deletes invalid state file and exits non-zero on post-write validation failure.
# Does NOT create the target directory.
update_state() {
  local target_dir="$1"
  local commit_sha="$2"
  local previous_commit="$3"
  local file_hashes_json="$4"
  local state_file="$target_dir/.serious-sidekick-state.json"

  # Validate target directory exists
  if [ ! -d "$target_dir" ]; then
    echo "ERROR: update_state: target directory not found: $target_dir" >&2
    return 1
  fi

  # Validate commit_sha is not empty
  if [ -z "$commit_sha" ]; then
    echo "ERROR: update_state: commit_sha is empty" >&2
    return 1
  fi

  # Pre-write validation: validate file_hashes_json
  local hashes_tmp
  hashes_tmp=$(mktemp)
  echo "$file_hashes_json" > "$hashes_tmp"
  if ! validate_json "$hashes_tmp"; then
    echo "ERROR: update_state: file_hashes_json is not valid JSON" >&2
    rm -f "$hashes_tmp"
    return 1
  fi
  rm -f "$hashes_tmp"

  # Generate ISO 8601 timestamp
  local installed_at
  installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Write state file using python3
  python3 -c "
import json, sys

commit_sha = sys.argv[1]
previous_commit = sys.argv[2]
installed_at = sys.argv[3]
file_hashes = json.loads(sys.argv[4])
output_path = sys.argv[5]

state = {
    'installed_from_commit': commit_sha,
    'previous_commit': previous_commit,
    'installed_at': installed_at,
    'file_hashes': file_hashes
}

with open(output_path, 'w') as f:
    json.dump(state, f, indent=2, sort_keys=True, ensure_ascii=False)
    f.write('\n')
" "$commit_sha" "$previous_commit" "$installed_at" "$file_hashes_json" "$state_file" || {
    echo "ERROR: update_state: failed to write state file" >&2
    return 1
  }

  # Post-write validation
  if ! validate_json "$state_file"; then
    echo "ERROR: update_state: post-write validation failed, deleting invalid state file" >&2
    rm -f "$state_file"
    return 1
  fi
}
