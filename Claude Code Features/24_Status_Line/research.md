# Status Line

## Overview

The Status Line is a customizable bar at the bottom of Claude Code that runs any shell script you configure. It receives JSON session data on stdin and displays whatever your script prints to stdout. This gives you a persistent, at-a-glance view of context usage, costs, git status, model information, vim mode, or anything else you want to track. The status line runs locally and does not consume API tokens.

## Key Capabilities

- **Shell-script-driven**: Any executable script (Bash, Python, Node.js, or other) can power the status line
- **Rich JSON session data**: Scripts receive comprehensive session information including model, context window, costs, git info, vim mode, and more
- **ANSI color support**: Use ANSI escape codes for colored output (e.g., `\033[32m` for green)
- **OSC 8 clickable links**: Make text clickable using OSC 8 escape sequences (Cmd+click on macOS, Ctrl+click on Windows/Linux)
- **Multi-line output**: Each `echo` or `print` statement displays as a separate row
- **Auto-generation via /statusline**: Natural language descriptions can auto-generate status line scripts
- **Debounced updates**: Updates are debounced at 300ms to batch rapid changes
- **Optional padding**: The `padding` field adds extra horizontal spacing to content

## Configuration / Setup

### Quick Setup with /statusline

The `/statusline` command accepts natural language instructions and generates a script automatically:

```
/statusline show model name and context percentage with a progress bar
```

Claude Code generates a script file in `~/.claude/` and updates your settings.

### Manual Configuration

Add a `statusLine` field to your user settings (`~/.claude/settings.json`) or project settings:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2
  }
}
```

The `command` field can also be an inline shell command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "jq -r '[\"[\\(.model.display_name)] \\(.context_window.used_percentage // 0)% context\"]'"
  }
}
```

The optional `padding` field adds extra horizontal spacing (in characters) to the status line content. Defaults to `0`.

### Script Requirements

1. Save the script to a file (e.g., `~/.claude/statusline.sh`)
2. Make it executable: `chmod +x ~/.claude/statusline.sh`
3. Add the path to your settings

### Disabling the Status Line

Run `/statusline` and ask it to remove/clear/delete. You can also manually delete the `statusLine` field from settings.json. Note: if `disableAllHooks` is set to `true` in your settings, the status line is also disabled.

## Usage Examples

### Basic Status Line Script (Bash)

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

echo "[$MODEL] ${DIR##*/} | ${PCT}% context"
```

### Context Window with Progress Bar

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '▓')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

echo "[$MODEL] $BAR $PCT%"
```

### Git Status with Colors

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')

GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    GIT_STATUS=""
    [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
    echo -e "[$MODEL] ${DIR##*/} | $BRANCH $GIT_STATUS"
else
    echo "[$MODEL] ${DIR##*/}"
fi
```

### Clickable GitHub Link

```bash
#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name')
REMOTE=$(git remote get-url origin 2>/dev/null | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
if [ -n "$REMOTE" ]; then
    REPO_NAME=$(basename "$REMOTE")
    printf '%b' "[$MODEL] \e]8;;${REMOTE}\a${REPO_NAME}\e]8;;\a\n"
else
    echo "[$MODEL]"
fi
```

### Multi-line with Threshold Colors

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# Pick color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="\033[31m"  # Red
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="\033[33m"  # Yellow
else BAR_COLOR="\033[32m"; fi  # Green

RESET='\033[0m'
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# Line 1: model and git info
echo -e "[$MODEL] ${DIR##*/}"
# Line 2: context bar with cost
echo -e "${BAR_COLOR}${PCT}%${RESET} | \$$(printf '%.2f' $COST) | ${MINS}m ${SECS}s"
```

## Important Details

### Available JSON Data Fields

| Field                                        | Description                                                        |
|:---------------------------------------------|:-------------------------------------------------------------------|
| `model.id`, `model.display_name`             | Current model identifier and display name                          |
| `cwd`, `workspace.current_dir`               | Current working directory (both contain same value)                |
| `workspace.project_dir`                      | Directory where Claude Code was launched                           |
| `cost.total_cost_usd`                        | Total session cost in USD                                          |
| `cost.total_duration_ms`                     | Total wall-clock time since session started (ms)                   |
| `cost.total_api_duration_ms`                 | Total time waiting for API responses (ms)                          |
| `cost.total_lines_added`                     | Lines of code added                                                |
| `cost.total_lines_removed`                   | Lines of code removed                                              |
| `context_window.total_input_tokens`          | Cumulative input token count                                       |
| `context_window.total_output_tokens`         | Cumulative output token count                                      |
| `context_window.context_window_size`         | Max context window size (200000 or 1000000 for extended)           |
| `context_window.used_percentage`             | Pre-calculated percentage of context window used                   |
| `context_window.remaining_percentage`        | Pre-calculated percentage remaining                                |
| `context_window.current_usage`               | Token counts from last API call (null before first call)           |
| `context_window.current_usage.input_tokens`  | Input tokens in current context                                    |
| `context_window.current_usage.output_tokens` | Output tokens generated                                            |
| `context_window.current_usage.cache_creation_input_tokens` | Tokens written to cache                      |
| `context_window.current_usage.cache_read_input_tokens`     | Tokens read from cache                        |
| `exceeds_200k_tokens`                        | Whether total tokens from last response exceeds 200k              |
| `session_id`                                 | Unique session identifier                                          |
| `transcript_path`                            | Path to conversation transcript file                               |
| `version`                                    | Claude Code version                                                |
| `output_style.name`                          | Name of current output style                                       |
| `vim.mode`                                   | Current vim mode (NORMAL/INSERT) -- only present when vim enabled  |
| `agent.name`                                 | Agent name -- only present when running with --agent flag          |

### When Scripts Run

- After each new assistant message
- When the permission mode changes
- When vim mode toggles
- Updates are **debounced at 300ms** (rapid changes batch together)
- If a new update triggers while a script is still running, the in-flight execution is cancelled
- If you edit your script, changes appear on the next interaction that triggers an update

### Context Window Percentage Calculation

The `used_percentage` field is calculated from input tokens only: `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`. It does **not** include `output_tokens`.

### Performance Tips

- **Cache expensive operations**: Commands like `git status` or `git diff` can be slow in large repos. Use a temp file cache with a 5-second TTL to avoid running them on every update.
- **Keep output short**: The status bar has limited width; long output may be truncated or wrap
- **Test with mock input**: `echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":25}}' | ./statusline.sh`

### Status Line Visibility

The status line temporarily hides during:
- Autocomplete suggestions
- The help menu
- Permission prompts

Notifications (MCP server errors, auto-updates, token warnings) display on the right side of the same row and may truncate status line output on narrow terminals.

### Community Projects

Pre-built status line configurations are available:
- [ccstatusline](https://github.com/sirmalloc/ccstatusline) -- Customizable statusline with powerline support and themes
- [starship-claude](https://github.com/martinemde/starship-claude) -- Starship-integrated status line

## References

- [Customize Your Status Line - Claude Code Docs](https://code.claude.com/docs/en/statusline) -- Official documentation with full JSON schema, examples in Bash/Python/Node.js, and troubleshooting guide
- [Claude Code Status Line Script](https://www.andreagrandi.it/posts/claude-code-status-line-script/) -- Community blog post with practical examples
- [Adding a Custom Status Line to Claude Code](https://freek.dev/3028-adding-a-custom-status-line-to-claude-code) -- Step-by-step setup guide
- [How to Customize Your Claude Code Status Line](https://alexop.dev/posts/customize_claude_code_status_line/) -- Community customization guide
- [Creating The Perfect Claude Code Status Line](https://www.aihero.dev/creating-the-perfect-claude-code-status-line) -- Advanced status line configuration
