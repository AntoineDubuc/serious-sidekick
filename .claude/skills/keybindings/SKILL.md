---
name: keybindings
description: "Assist with keybindings, keyboard shortcuts, customizing keys, or chord bindings in Claude Code"
---

# Keybindings

## Quick Reference
- Configuration file: `~/.claude/keybindings.json` (create/open via `/keybindings` command)
- 18 contexts scope bindings to specific UI states (Chat, Global, Autocomplete, Confirmation, etc.)
- Actions use `namespace:action` format (e.g., `chat:submit`, `app:toggleTodos`)
- Chord sequences supported: `ctrl+k ctrl+s` (press Ctrl+K, release, then Ctrl+S)
- Set any action to `null` to unbind a default shortcut
- Auto-reloads on file change -- no restart needed
- Run `/doctor` to see keybinding validation warnings
- `Ctrl+C` and `Ctrl+D` are reserved and cannot be rebound

## Configuration

```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "$docs": "https://code.claude.com/docs/en/keybindings",
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+e": "chat:externalEditor",
        "ctrl+u": null,
        "ctrl+k ctrl+s": "chat:stash"
      }
    },
    {
      "context": "Global",
      "bindings": {
        "ctrl+t": "app:toggleTodos"
      }
    }
  ]
}
```

### Keystroke Syntax
- Modifiers: `ctrl`/`control`, `alt`/`opt`/`option`, `shift`, `meta`/`cmd`/`command`
- Combine with `+`: `ctrl+shift+c`
- Chords (sequences): `ctrl+k ctrl+s` (space-separated)
- Special keys: `escape`/`esc`, `enter`/`return`, `tab`, `space`, `up`, `down`, `left`, `right`, `backspace`, `delete`
- Uppercase letter alone implies Shift: `K` = `shift+k`

## Key Default Shortcuts

| Action | Default | Context |
|:-------|:--------|:--------|
| `chat:submit` | Enter | Chat |
| `chat:cancel` | Escape | Chat |
| `chat:cycleMode` | Shift+Tab | Chat |
| `chat:modelPicker` | Cmd+P | Chat |
| `chat:thinkingToggle` | Cmd+T | Chat |
| `chat:externalEditor` | Ctrl+G | Chat |
| `chat:stash` | Ctrl+S | Chat |
| `app:interrupt` | Ctrl+C | Global |
| `app:exit` | Ctrl+D | Global |
| `app:toggleTodos` | Ctrl+T | Global |
| `app:toggleTranscript` | Ctrl+O | Global |

## Common Patterns

### Unbind a default shortcut
```json
{ "context": "Chat", "bindings": { "ctrl+s": null } }
```

### Remap submission to a chord
```json
{ "context": "Chat", "bindings": { "ctrl+k ctrl+enter": "chat:submit" } }
```

### All 18 Contexts
`Global`, `Chat`, `Autocomplete`, `Settings`, `Confirmation`, `Tabs`, `Help`, `Transcript`, `HistorySearch`, `Task`, `ThemePicker`, `Attachments`, `Footer`, `MessageSelector`, `DiffDialog`, `ModelPicker`, `Select`, `Plugin`

## Gotchas
- **Reserved shortcuts**: `Ctrl+C` (interrupt) and `Ctrl+D` (exit) cannot be rebound
- **Terminal multiplexer conflicts**: `Ctrl+B` (tmux prefix), `Ctrl+A` (screen prefix), `Ctrl+Z` (SIGTSTP) may conflict
- **Vim mode interaction**: Vim mode handles text-level input (cursor, modes); keybindings handle component-level actions. Escape in Vim switches to NORMAL mode, not `chat:cancel`. Most Ctrl+key shortcuts pass through Vim to the keybinding system
- **Validation**: Claude Code warns about parse errors, invalid contexts, reserved conflicts, and duplicates -- check with `/doctor`
- **Uppercase with modifiers**: `ctrl+K` is stylistic only (does NOT imply Shift); standalone `K` does imply `shift+k`

@../../Claude Code Features/23_Keybindings/research.md
