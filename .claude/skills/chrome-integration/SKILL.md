---
name: chrome-integration
description: "Auto-load when user asks about Chrome integration, browser automation, browser testing, web debugging, or the --chrome flag"
---

# Chrome Integration (Beta)

## Quick Reference
- Enables browser automation directly from Claude Code CLI or VS Code extension.
- Start with `claude --chrome` or run `/chrome` in an existing session.
- **Prerequisites**: Google Chrome or Microsoft Edge, Claude in Chrome extension v1.0.36+, Claude Code v2.0.73+, direct Anthropic plan (Pro/Max/Teams/Enterprise).
- Claude opens **new tabs** for browser tasks and shares your browser's login state.
- Browser actions run in a **visible Chrome window** in real time.
- Capabilities: live debugging, console reading, design verification, form filling, data extraction, authenticated web app interaction, GIF recording.
- Site permissions are inherited from the Chrome extension settings.
- **Not available** through third-party providers (Bedrock, Vertex AI, Azure Foundry).
- **Not supported** on Brave, Arc, other Chromium browsers, or WSL.

## Configuration

**Start with Chrome:**
```bash
claude --chrome
```

**Enable by default** (increases context usage): run `/chrome` and select "Enabled by default".

**Disable for a session:**
```bash
claude --no-chrome
```

**VS Code**: Chrome is available automatically when the extension is installed -- no flag needed.

**Check connection status**: run `/chrome` at any time.

**View available browser tools**: run `/mcp` and select `claude-in-chrome`.

**Native messaging host locations (installed automatically on first enable):**
- Chrome macOS: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`
- Chrome Linux: `~/.config/google-chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`
- Edge macOS: `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`

## Common Patterns

1. **Test a local web app:**
   ```
   Open localhost:3000, try submitting the form with invalid data,
   and check if the error messages appear correctly.
   ```

2. **Debug with console logs:**
   ```
   Open the dashboard page and check the console for any errors
   when the page loads.
   ```

3. **Authenticated web app interaction (uses your login state):**
   ```
   Draft a project update based on recent commits and add it to my
   Google Doc at docs.google.com/document/d/abc123
   ```

## Gotchas
- **Login pages and CAPTCHAs**: Claude pauses and asks you to handle them manually.
- **Connection drops during long sessions**: the extension's service worker can go idle. Fix with `/chrome` > "Reconnect extension".
- **JavaScript dialogs (alert/confirm/prompt)** block browser events -- dismiss manually, then tell Claude to continue.
- **Enabling Chrome by default increases context usage** since browser tools are always loaded. Use `--chrome` on demand if context consumption is a concern.
- **First-time setup**: if the extension is not detected, restart Chrome to pick up the native messaging host config.
- **Windows named pipe conflicts (EADDRINUSE)**: close other Claude Code sessions using Chrome, then restart.

### Troubleshooting Quick Reference

| Error | Fix |
|-------|-----|
| "Browser extension is not connected" | Restart Chrome and Claude Code, run `/chrome` to reconnect |
| "Extension not detected" | Install/enable extension in `chrome://extensions` |
| "No tab available" | Ask Claude to create a new tab and retry |
| "Receiving end does not exist" | Run `/chrome` > "Reconnect extension" |

@./Claude Code Features/25_Chrome_Integration/research.md
