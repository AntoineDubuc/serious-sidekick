# Vim Mode

## Overview

Vim Mode provides vim-style editing capabilities for the Claude Code input area. It brings familiar modal editing from Vim/Neovim into the CLI prompt, allowing developers who are comfortable with Vim keybindings to navigate and edit their prompts efficiently. Vim Mode operates at the text input level and works independently from the keybindings system, handling cursor movement, text manipulation, and modal switching while keybindings handle application-level actions.

## Key Capabilities

- **Three editing modes**: NORMAL, INSERT, and VISUAL modes with standard Vim behavior
- **Comprehensive navigation motions**: Character, word, line, and document-level movement including `hjkl`, `w`, `b`, `e`, `f{char}`, `t{char}`, and more
- **Text objects**: Full support for word, WORD, quote, parenthesis, bracket, and brace text objects with inner/around variants
- **Operators**: Standard `d` (delete), `c` (change), and `y` (yank) operators that combine with motions and text objects
- **Dot-repeat**: The `.` command repeats the last change operation
- **Visual mode selection**: Select text with navigation keys, then operate on selections
- **History navigation**: In NORMAL mode, arrow keys at document boundaries navigate command history
- **Independent from keybindings**: Vim mode handles text input while keybindings handle application actions

## Configuration / Setup

### Enabling Vim Mode

Toggle Vim mode using the `/vim` command during a session:
```
/vim
```

To configure Vim mode permanently, use `/config` to access settings and enable it as the default editing mode.

### How Vim Mode Interacts with Keybindings

When Vim mode is enabled:
- **Vim mode** handles input at the text input level (cursor movement, modes, motions, text objects)
- **Keybindings** handle actions at the component level (toggle todos, submit, etc.)
- The `Escape` key in Vim mode switches from INSERT to NORMAL mode; it does **not** trigger `chat:cancel`
- Most `Ctrl+key` shortcuts pass through Vim mode to the keybinding system
- In Vim NORMAL mode, `?` shows the help menu (standard Vim behavior)

## Usage Examples

### Mode Switching

| Command | Action                      | From Mode |
|:--------|:----------------------------|:----------|
| `Esc`   | Enter NORMAL mode           | INSERT    |
| `i`     | Insert before cursor        | NORMAL    |
| `I`     | Insert at beginning of line | NORMAL    |
| `a`     | Insert after cursor         | NORMAL    |
| `A`     | Insert at end of line       | NORMAL    |
| `o`     | Open line below             | NORMAL    |
| `O`     | Open line above             | NORMAL    |

### Navigation (NORMAL Mode)

| Command     | Action                                              |
|:------------|:----------------------------------------------------|
| `h/j/k/l`  | Move left/down/up/right                             |
| `w`         | Next word                                           |
| `e`         | End of word                                         |
| `b`         | Previous word                                       |
| `0`         | Beginning of line                                   |
| `$`         | End of line                                         |
| `^`         | First non-blank character                           |
| `gg`        | Beginning of input                                  |
| `G`         | End of input                                        |
| `f{char}`   | Jump to next occurrence of character                |
| `F{char}`   | Jump to previous occurrence of character            |
| `t{char}`   | Jump to just before next occurrence of character    |
| `T{char}`   | Jump to just after previous occurrence of character |
| `;`         | Repeat last f/F/t/T motion                          |
| `,`         | Repeat last f/F/t/T motion in reverse               |

When the cursor is at the beginning or end of input and cannot move further, arrow keys navigate command history instead.

### Editing (NORMAL Mode)

| Command        | Action                  |
|:---------------|:------------------------|
| `x`            | Delete character        |
| `dd`           | Delete line             |
| `D`            | Delete to end of line   |
| `dw`/`de`/`db` | Delete word/to end/back |
| `cc`           | Change line             |
| `C`            | Change to end of line   |
| `cw`/`ce`/`cb` | Change word/to end/back |
| `yy`/`Y`       | Yank (copy) line        |
| `yw`/`ye`/`yb` | Yank word/to end/back   |
| `p`            | Paste after cursor      |
| `P`            | Paste before cursor     |
| `>>`           | Indent line             |
| `<<`           | Dedent line             |
| `J`            | Join lines              |
| `.`            | Repeat last change      |

### Text Objects (NORMAL Mode)

Text objects work with operators `d`, `c`, and `y`:

| Command   | Action                                   |
|:----------|:-----------------------------------------|
| `iw`/`aw` | Inner/around word                        |
| `iW`/`aW` | Inner/around WORD (whitespace-delimited) |
| `i"`/`a"` | Inner/around double quotes               |
| `i'`/`a'` | Inner/around single quotes               |
| `i(`/`a(` | Inner/around parentheses                 |
| `i[`/`a[` | Inner/around brackets                    |
| `i{`/`a{` | Inner/around braces                      |

### Visual Mode

Press `v` in NORMAL mode to enter VISUAL mode, then:
- Use navigation keys to select text
- `d` to delete selection
- `y` to yank selection
- `c` to change selection

### Common Editing Workflows

- `ciw` -- Change inner word (delete word and enter insert mode)
- `ci"` -- Change inside double quotes
- `di(` -- Delete inside parentheses
- `yaw` -- Yank around word (including surrounding spaces)
- `dw` -- Delete from cursor to next word
- `dd` -- Delete entire line
- `p` -- Paste after cursor

## Important Details

### Vim Mode in Status Line

When Vim mode is enabled, the status line JSON data includes the current Vim mode in the `vim.mode` field, which can be either `NORMAL` or `INSERT`. This can be used in custom status line scripts to display the current editing mode.

### Limitations and Missing Features

Based on GitHub issues, some advanced Vim features have been requested but may not be fully available:
- Some advanced motions and shortcuts were added over time (e.g., `f`, `t` motions were added in response to community requests)
- Text objects and more complete Vim command sets continue to be enhanced

### Integration with Terminal

Vim mode operates entirely within the Claude Code input area. It does not affect terminal behavior outside of the prompt input. Standard terminal shortcuts like `Ctrl+C`, `Ctrl+D`, and other system-level bindings continue to work normally.

### Escape Key Behavior

A critical distinction: in Vim mode, pressing `Escape` switches from INSERT to NORMAL mode. It does **not** trigger the `chat:cancel` action that Escape normally performs. This prevents accidental cancellation while editing in Vim style.

## References

- [Interactive Mode - Claude Code Docs](https://code.claude.com/docs/en/interactive-mode) -- Official documentation covering Vim editor mode, all motions, text objects, and keybinding interactions
- [Implement more Vim motions and shortcuts - GitHub Issue #1204](https://github.com/anthropics/claude-code/issues/1204) -- Community discussion on expanding Vim motion support
- [Enhanced Vim Mode: Support for Text Objects - GitHub Issue #10016](https://github.com/anthropics/claude-code/issues/10016) -- Feature request for text objects and complete Vim command set
- [Claude Code Keybindings Guide](https://claudefa.st/blog/tools/keybindings-guide) -- Community guide on keybindings including Vim mode interaction
