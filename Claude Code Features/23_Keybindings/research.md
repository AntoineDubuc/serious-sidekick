# Keybindings

## Overview

Claude Code supports fully customizable keyboard shortcuts through a configuration file at `~/.claude/keybindings.json`. The system uses a context-based approach where bindings are organized by the UI context they apply to (Chat, Global, Autocomplete, Confirmation, etc.), with support for modifier keys, chord sequences, and automatic hot-reloading when the file changes. The `/keybindings` command creates or opens the configuration file for editing.

## Key Capabilities

- **18 customizable contexts**: Bindings are scoped to specific UI states (Chat, Global, Autocomplete, Confirmation, DiffDialog, ModelPicker, Settings, Plugin, and more)
- **Namespace:action format**: Actions follow a clear pattern like `chat:submit`, `app:toggleTodos`, `confirm:yes`
- **Chord support**: Key sequences like `ctrl+k ctrl+s` (press Ctrl+K, release, then Ctrl+S)
- **Modifier key combinations**: Support for `ctrl`, `alt`/`opt`/`option`, `shift`, and `meta`/`cmd`/`command`
- **Unbinding defaults**: Set any action to `null` to remove a default shortcut
- **Auto-reload**: Changes to the keybindings file are automatically detected and applied without restarting Claude Code
- **Validation**: Claude Code validates keybindings and shows warnings for parse errors, invalid contexts, reserved conflicts, and duplicate bindings
- **JSON Schema support**: Optional `$schema` field for editor autocompletion

## Configuration / Setup

### Configuration File

Create or open the keybindings configuration file using the `/keybindings` command. The file is located at `~/.claude/keybindings.json`.

The file structure uses a `bindings` array where each block specifies a context and a map of keystrokes to actions:

```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "$docs": "https://code.claude.com/docs/en/keybindings",
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+e": "chat:externalEditor",
        "ctrl+u": null
      }
    }
  ]
}
```

### Keystroke Syntax

**Modifiers** use the `+` separator:
- `ctrl` or `control` -- Control key
- `alt`, `opt`, or `option` -- Alt/Option key
- `shift` -- Shift key
- `meta`, `cmd`, or `command` -- Meta/Command key

**Examples**:
```
ctrl+k          Single key with modifier
shift+tab       Shift + Tab
meta+p          Command/Meta + P
ctrl+shift+c    Multiple modifiers
```

**Uppercase letters**: A standalone uppercase letter implies Shift. For example, `K` is equivalent to `shift+k`. With modifiers (e.g., `ctrl+K`), uppercase is stylistic and does not imply Shift.

**Chords**: Key sequences separated by spaces:
```
ctrl+k ctrl+s   Press Ctrl+K, release, then Ctrl+S
```

**Special keys**: `escape`/`esc`, `enter`/`return`, `tab`, `space`, `up`, `down`, `left`, `right`, `backspace`, `delete`

### Unbinding Defaults

Set an action to `null` to remove a default shortcut:

```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+s": null
      }
    }
  ]
}
```

## Usage Examples

### All 18 Contexts

| Context           | Description                                      |
|:------------------|:-------------------------------------------------|
| `Global`          | Applies everywhere in the app                    |
| `Chat`            | Main chat input area                             |
| `Autocomplete`    | Autocomplete menu is open                        |
| `Settings`        | Settings menu (escape-only dismiss)              |
| `Confirmation`    | Permission and confirmation dialogs              |
| `Tabs`            | Tab navigation components                        |
| `Help`            | Help menu is visible                             |
| `Transcript`      | Transcript viewer                                |
| `HistorySearch`   | History search mode (Ctrl+R)                     |
| `Task`            | Background task is running                       |
| `ThemePicker`     | Theme picker dialog                              |
| `Attachments`     | Image/attachment bar navigation                  |
| `Footer`          | Footer indicator navigation (tasks, teams, diff) |
| `MessageSelector` | Rewind and summarize dialog message selection    |
| `DiffDialog`      | Diff viewer navigation                           |
| `ModelPicker`     | Model picker effort level                        |
| `Select`          | Generic select/list components                   |
| `Plugin`          | Plugin dialog (browse, discover, manage)         |

### Key Actions Per Context

**App actions (Global context)**:
| Action                 | Default | Description                 |
|:-----------------------|:--------|:----------------------------|
| `app:interrupt`        | Ctrl+C  | Cancel current operation    |
| `app:exit`             | Ctrl+D  | Exit Claude Code            |
| `app:toggleTodos`      | Ctrl+T  | Toggle task list visibility |
| `app:toggleTranscript` | Ctrl+O  | Toggle verbose transcript   |

**Chat actions**:
| Action                | Default                   | Description              |
|:----------------------|:--------------------------|:-------------------------|
| `chat:cancel`         | Escape                    | Cancel current input     |
| `chat:cycleMode`      | Shift+Tab                 | Cycle permission modes   |
| `chat:modelPicker`    | Cmd+P / Meta+P            | Open model picker        |
| `chat:thinkingToggle` | Cmd+T / Meta+T            | Toggle extended thinking |
| `chat:submit`         | Enter                     | Submit message           |
| `chat:undo`           | Ctrl+_                    | Undo last action         |
| `chat:externalEditor` | Ctrl+G                    | Open in external editor  |
| `chat:stash`          | Ctrl+S                    | Stash current prompt     |
| `chat:imagePaste`     | Ctrl+V (Alt+V on Windows) | Paste image              |

**Autocomplete actions**:
| Action                  | Default | Description         |
|:------------------------|:--------|:--------------------|
| `autocomplete:accept`   | Tab     | Accept suggestion   |
| `autocomplete:dismiss`  | Escape  | Dismiss menu        |
| `autocomplete:previous` | Up      | Previous suggestion |
| `autocomplete:next`     | Down    | Next suggestion     |

**Confirmation actions**:
| Action                      | Default   | Description                   |
|:----------------------------|:----------|:------------------------------|
| `confirm:yes`               | Y, Enter  | Confirm action                |
| `confirm:no`                | N, Escape | Decline action                |
| `confirm:previous`          | Up        | Previous option               |
| `confirm:next`              | Down      | Next option                   |
| `confirm:nextField`         | Tab       | Next field                    |
| `confirm:previousField`     | (unbound) | Previous field                |
| `confirm:cycleMode`         | Shift+Tab | Cycle permission modes        |
| `confirm:toggleExplanation` | Ctrl+E    | Toggle permission explanation |

**Diff actions (DiffDialog context)**:
| Action                | Default | Description            |
|:----------------------|:--------|:-----------------------|
| `diff:dismiss`        | Escape  | Close diff viewer      |
| `diff:previousSource` | Left    | Previous diff source   |
| `diff:nextSource`     | Right   | Next diff source       |
| `diff:previousFile`   | Up      | Previous file in diff  |
| `diff:nextFile`       | Down    | Next file in diff      |
| `diff:viewDetails`    | Enter   | View diff details      |

**Model Picker actions**:
| Action                       | Default | Description           |
|:-----------------------------|:--------|:----------------------|
| `modelPicker:decreaseEffort` | Left    | Decrease effort level |
| `modelPicker:increaseEffort` | Right   | Increase effort level |

**Select actions**:
| Action            | Default         | Description      |
|:------------------|:----------------|:-----------------|
| `select:next`     | Down, J, Ctrl+N | Next option      |
| `select:previous` | Up, K, Ctrl+P   | Previous option  |
| `select:accept`   | Enter           | Accept selection |
| `select:cancel`   | Escape          | Cancel selection |

**Plugin actions**:
| Action           | Default | Description              |
|:-----------------|:--------|:-------------------------|
| `plugin:toggle`  | Space   | Toggle plugin selection  |
| `plugin:install` | I       | Install selected plugins |

**Settings actions**:
| Action            | Default | Description                         |
|:------------------|:--------|:------------------------------------|
| `settings:search` | /       | Enter search mode                   |
| `settings:retry`  | R       | Retry loading usage data (on error) |

## Important Details

### Reserved Shortcuts

These shortcuts cannot be rebound:
| Shortcut | Reason                     |
|:---------|:---------------------------|
| Ctrl+C   | Hardcoded interrupt/cancel |
| Ctrl+D   | Hardcoded exit             |

### Terminal Conflicts

Some shortcuts may conflict with terminal multiplexers:
| Shortcut | Conflict                          |
|:---------|:----------------------------------|
| Ctrl+B   | tmux prefix (press twice to send) |
| Ctrl+A   | GNU screen prefix                 |
| Ctrl+Z   | Unix process suspend (SIGTSTP)    |

### Vim Mode Interaction

When Vim mode is enabled (`/vim`), keybindings and Vim mode operate independently:
- Vim mode handles input at the text input level (cursor movement, modes, motions)
- Keybindings handle actions at the component level (toggle todos, submit, etc.)
- Escape in Vim mode switches INSERT to NORMAL mode; it does not trigger `chat:cancel`
- Most Ctrl+key shortcuts pass through Vim mode to the keybinding system
- In Vim NORMAL mode, `?` shows the help menu

### Validation

Claude Code validates keybindings and shows warnings for:
- Parse errors (invalid JSON or structure)
- Invalid context names
- Reserved shortcut conflicts
- Terminal multiplexer conflicts
- Duplicate bindings in the same context

Run `/doctor` to see any keybinding warnings.

## References

- [Customize Keyboard Shortcuts - Claude Code Docs](https://code.claude.com/docs/en/keybindings) -- Official documentation covering all contexts, actions, keystroke syntax, and configuration
- [Interactive Mode - Claude Code Docs](https://code.claude.com/docs/en/interactive-mode) -- Documentation on keyboard shortcuts and Vim mode interaction
- [Claude Code Keybindings Guide](https://claudefa.st/blog/tools/keybindings-guide) -- Community guide on keybindings configuration
