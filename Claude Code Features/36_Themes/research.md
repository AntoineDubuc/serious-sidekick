# Themes

## Overview

Claude Code includes a built-in theming system accessible via the `/theme` command, offering color themes with light and dark variants, colorblind-accessible (daltonized) options, and ANSI-only themes that use your terminal's native color palette. Themes control the visual appearance of Claude Code's interface elements in the terminal, including syntax highlighting for code blocks.

## Key Capabilities

- **Six built-in themes** with variants for different needs:
  - Dark mode
  - Light mode
  - Dark mode (colorblind-friendly) — daltonized color palette for users with color vision deficiencies
  - Light mode (colorblind-friendly) — daltonized color palette in a light variant
  - Dark mode (ANSI colors only) — uses your terminal's 16-color palette instead of hardcoded RGB values
  - Light mode (ANSI colors only) — uses your terminal's 16-color palette in a light variant
- **Syntax highlighting toggle**: Press `Ctrl+T` inside the `/theme` picker menu to toggle syntax highlighting for code blocks in Claude's responses. Note: syntax highlighting is only available in the native build of Claude Code.
- **Terminal color detection**: Claude Code auto-detects your terminal's capabilities based on environment variables. If `COLORTERM` is not set, it may downgrade to ANSI-compatible colors. Setting `COLORTERM=truecolor` signals that the full 24-bit RGB palette can be used.
- **ANSI themes for terminal consistency**: The ANSI-only themes defer to your terminal emulator's color definitions, making them ideal for users who have carefully customized their terminal color schemes and want consistency across all CLI tools.

## Configuration / Setup

### Using the /theme Command
Type `/theme` in Claude Code to open the theme picker. Select from the available themes using arrow keys and Enter.

### Configuration Location
Theme settings are stored in `~/.claude.json` (the user configuration file), not in `settings.json`.

### Setting via /config
You can also access theme settings through the `/config` command, which opens the Settings interface.

### Terminal Setup for Optimal Rendering
- **iTerm2, WezTerm, Ghostty, Kitty**: Full color support works out of the box.
- **VS Code terminal, Alacritty, Zed, Warp**: Run `/terminal-setup` for keybinding configuration.
- **Remote/SSH sessions**: If colors appear flat or washed out, ensure `COLORTERM=truecolor` is set in your remote environment.
- **Option as Meta key (macOS)**: For full keyboard shortcut support, configure Option as Meta in your terminal:
  - iTerm2: Settings > Profiles > Keys > set Left/Right Option key to "Esc+"
  - Terminal.app: Settings > Profiles > Keyboard > check "Use Option as Meta Key"

## Usage Examples

**Switch theme interactively**:
```
/theme
```
Use arrow keys to browse themes and press Enter to select.

**Toggle syntax highlighting** (inside the /theme picker):
Press `Ctrl+T` to enable or disable syntax highlighting for code blocks.

**Force truecolor support for remote sessions**:
```bash
export COLORTERM=truecolor
```

## Important Details

- **No custom theme support yet**: As of the current version, Claude Code does not support user-defined custom themes. You are limited to the 6 built-in presets. There is an open feature request (GitHub issue #1302) for custom theme support including the ability to define color values, import/export configurations, and support popular terminal theme formats (base16, iTerm2 themes, etc.).
- **ANSI themes recommended for custom terminals**: If you have a carefully configured terminal color scheme (e.g., Catppuccin, Dracula, Solarized), the ANSI themes will use your terminal's palette rather than overriding it with hardcoded colors.
- **Colorblind-friendly themes**: The daltonized themes adjust the color palette to improve distinguishability for users with color vision deficiencies, particularly for diff highlighting and status indicators.
- **Hardcoded backgrounds**: The non-ANSI themes use hardcoded background colors that may conflict with transparent terminal backgrounds or bright terminal themes. The ANSI variants avoid this issue.
- **Syntax highlighting availability**: Syntax highlighting in code blocks is only available in the native build of Claude Code, not in all environments.

## References

- [Interactive Mode — Theme and Display](https://code.claude.com/docs/en/interactive-mode) — Official documentation covering the `/theme` command and `Ctrl+T` toggle
- [GitHub Issue #1302: Custom Terminal Themes](https://github.com/anthropics/claude-code/issues/1302) — Feature request for custom theme support, listing the 6 built-in themes
- [Fixing Claude Code's Flat or Washed-Out Remote Colors](https://ranang.medium.com/fixing-claude-codes-flat-or-washed-out-remote-colors-82f8143351ed) — Guide on resolving color rendering issues in remote sessions
