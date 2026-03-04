---
name: status-line
description: "Assist with status line, status bar, customizing the footer, or session info display in Claude Code"
---

# Status Line

## Quick Reference
- Customizable bar at the bottom of Claude Code driven by any shell script (Bash, Python, Node.js)
- Script receives JSON session data on stdin, prints display content to stdout
- Runs locally, does not consume API tokens
- Quick setup: `/statusline show model name and context percentage with a progress bar`
- Manual config: add `statusLine` field to `~/.claude/settings.json`
- Supports ANSI colors (`\033[32m` for green), OSC 8 clickable links, and multi-line output
- Updates are debounced at 300ms; in-flight scripts are cancelled if a new update triggers
- Disabled when `disableAllHooks` is `true` in settings
- To remove: `/statusline` and ask it to remove, or delete the `statusLine` field from settings

## Configuration

```json
// ~/.claude/settings.json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2
  }
}
```

Inline command alternative:
```json
{
  "statusLine": {
    "type": "command",
    "command": "jq -r '[\"[\\(.model.display_name)] \\(.context_window.used_percentage // 0)% context\"]'"
  }
}
```

### Script Setup
1. Save script to `~/.claude/statusline.sh`
2. `chmod +x ~/.claude/statusline.sh`
3. Add path to settings

## Common Patterns

### Basic model + context display
```bash
#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
echo "[$MODEL] ${PCT}% context"
```

### Context bar with color thresholds
```bash
#!/bin/bash
input=$(cat)
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
MODEL=$(echo "$input" | jq -r '.model.display_name')
if [ "$PCT" -ge 90 ]; then COLOR="\033[31m"    # Red
elif [ "$PCT" -ge 70 ]; then COLOR="\033[33m"   # Yellow
else COLOR="\033[32m"; fi                         # Green
echo -e "[$MODEL] ${COLOR}${PCT}%\033[0m context"
```

### Git branch + status with colors
```bash
#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name')
BRANCH=$(git branch --show-current 2>/dev/null)
STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
echo -e "[$MODEL] $BRANCH \033[32m+${STAGED}\033[0m"
```

## JSON Data Schema (Key Fields)

| Field | Description |
|:------|:-----------|
| `model.display_name` | Current model name |
| `context_window.used_percentage` | Context usage (input tokens only) |
| `context_window.remaining_percentage` | Context remaining |
| `context_window.context_window_size` | Max size (200k or 1M for extended) |
| `cost.total_cost_usd` | Session cost in USD |
| `cost.total_duration_ms` | Wall-clock time since session start |
| `cost.total_lines_added` / `total_lines_removed` | Code churn |
| `workspace.current_dir` / `cwd` | Current working directory |
| `workspace.project_dir` | Launch directory |
| `session_id` | Unique session ID |
| `vim.mode` | NORMAL/INSERT (only when vim enabled) |
| `output_style.name` | Current output style |
| `version` | Claude Code version |

## Gotchas
- **Script must be executable**: `chmod +x` is required or the status line silently fails
- **`used_percentage` is input-only**: Calculated from input tokens + cache tokens; does NOT include output tokens
- **Cache expensive operations**: Git commands can be slow in large repos -- use a temp file cache with a 5-second TTL
- **Status line hides temporarily**: During autocomplete, help menu, and permission prompts
- **Notifications may truncate**: MCP errors, auto-updates, and token warnings display on the right side of the same row
- **Test with mock data**: `echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":25}}' | ./statusline.sh`
- **`disableAllHooks` disables it**: If hooks are globally disabled in settings, the status line is also disabled

@../../Claude Code Features/24_Status_Line/research.md
