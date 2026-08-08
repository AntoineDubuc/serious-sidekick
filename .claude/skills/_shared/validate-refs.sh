#!/bin/bash
# Reference Validator Hook — blocks writing a research/plan artifact that cites a
# file:line reference which does not exist.
#
# WHY THIS EXISTS (2026-08-07): five plan drafts and nine review rounds were spent
# largely on acceptance criteria that named files, symbols and line ranges the
# author had never opened. The reviewer caught them one at a time, hours apart.
# A phantom reference is cheap to create and expensive to catch, so it is blocked
# at write time instead.
#
# Fires on PreToolUse for Edit/Write. Reads JSON from stdin. Exit 2 blocks.
#
# SCOPE — deliberately narrow, so it can never block real engineering work:
#   * ONLY .md files under Research/ (plans, research, reviews, notebooks).
#   * ONLY references of the shape  <path-with-a-slash-and-extension>:<line>
#   * A reference is bad if the path does not exist, OR the line number exceeds
#     the file's line count.
#
# DELIBERATE NON-GOALS (documented so nobody "fixes" them later):
#   * It does NOT validate that the cited line says what the prose claims. That
#     needs a reader, not a hook.
#   * It does NOT police prose in chat — only what lands on disk.
#   * It does NOT resolve paths outside the repo, URLs, or bare filenames without
#     a directory part. Those are ignored rather than guessed at.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

# Only guard research artifacts.
case "$FILE" in
  *Research/*.md) ;;
  *) exit 0 ;;
esac

# The content about to be written. Write gives `content`; Edit gives `new_string`.
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')
[ -z "$CONTENT" ] && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Strip fenced code blocks before scanning: a ``` block may legitimately quote a
# snippet from another repo, an example, or a line that no longer exists. Only
# prose citations are the agent asserting a fact about THIS tree.
STRIPPED=$(echo "$CONTENT" | awk '/^[[:space:]]*```/{f=!f; next} !f')

# Extract candidate refs: a path containing a slash and a dot-extension, then :N
CANDIDATES=$(echo "$STRIPPED" \
  | grep -oE '[A-Za-z0-9_./-]+/[A-Za-z0-9_.-]+\.[A-Za-z0-9]+:[0-9]+' \
  | sort -u)

[ -z "$CANDIDATES" ] && exit 0

BAD=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  path="${ref%:*}"
  line="${ref##*:}"

  # Ignore anything that isn't a real path in this repo (URLs, other repos,
  # illustrative names). Resolve relative to the repo root.
  target="$REPO_ROOT/$path"
  [ -f "$target" ] || { [ -f "$path" ] && target="$path" || continue; }

  total=$(wc -l < "$target" 2>/dev/null | tr -d ' ')
  [ -z "$total" ] && continue

  if [ "$line" -gt "$total" ] 2>/dev/null; then
    BAD="${BAD}  ${ref}  — file has only ${total} lines"$'\n'
  fi
done <<< "$CANDIDATES"

# Second pass: refs whose path looks like this repo but does not exist at all.
MISSING=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  path="${ref%:*}"
  # PROJECT-AGNOSTIC: a ref is "claimed by this project" when its FIRST path
  # segment is a real directory at the project root (lib/, src/, backend/, app/,
  # pkg/ — whatever this project happens to use). An earlier version hardcoded a
  # Flutter-specific list, which silently skipped every check in a Python or JS
  # project while still reporting a pass.
  first="${path%%/*}"
  if [ -n "$first" ] && [ "$first" != "$path" ] && [ -d "$REPO_ROOT/$first" ]; then
    if [ ! -f "$REPO_ROOT/$path" ] && [ ! -f "$path" ]; then
      MISSING="${MISSING}  ${ref}  — no such file"$'\n'
    fi
  fi
done <<< "$CANDIDATES"

if [ -n "$BAD" ] || [ -n "$MISSING" ]; then
  {
    echo "PHANTOM REFERENCE — write blocked."
    echo ""
    echo "This artifact cites file:line references that do not resolve in this tree:"
    echo ""
    [ -n "$MISSING" ] && printf '%s' "$MISSING"
    [ -n "$BAD" ] && printf '%s' "$BAD"
    echo ""
    echo "Open the file and read the line before citing it. A reference in this repo"
    echo "is a timestamp, not a contract — if the code moved, re-derive the ref."
    echo "If the citation is illustrative rather than a claim about this tree, put it"
    echo "in a fenced code block, which this hook ignores."
  } >&2
  exit 2
fi

exit 0
