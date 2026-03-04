# Chrome Integration

## Overview

Claude Code integrates with the Claude in Chrome browser extension to provide browser automation capabilities directly from the CLI or VS Code extension. This allows developers to build code, then test and debug in the browser without switching contexts. Claude opens new tabs for browser tasks and shares your browser's login state, so it can access any site you are already signed into. Browser actions run in a visible Chrome window in real time. The feature is currently in beta.

## Key Capabilities

- **Live debugging**: Read console errors and DOM state directly, then fix the code that caused them
- **Design verification**: Build a UI from a Figma mock, then open it in the browser to verify it matches
- **Web app testing**: Test form validation, check for visual regressions, or verify user flows
- **Authenticated web app interaction**: Interact with Google Docs, Gmail, Notion, or any app you are logged into without API connectors
- **Data extraction**: Pull structured information from web pages and save it locally
- **Task automation**: Automate repetitive browser tasks like data entry, form filling, or multi-site workflows
- **Session recording**: Record browser interactions as GIFs to document or share what happened
- **Console reading**: Read console errors, network requests, and DOM state for debugging

## Configuration / Setup

### Prerequisites

- **Google Chrome** or **Microsoft Edge** browser
- **Claude in Chrome extension** version 1.0.36 or higher, available in the Chrome Web Store for both browsers
- **Claude Code** version 2.0.73 or higher
- A **direct Anthropic plan** (Pro, Max, Teams, or Enterprise)

### Getting Started (CLI)

Start Claude Code with the `--chrome` flag:

```bash
claude --chrome
```

Or enable Chrome from within an existing session by running `/chrome`.

### Enable Chrome by Default

To avoid passing `--chrome` each session, run `/chrome` and select "Enabled by default".

Note: Enabling Chrome by default in the CLI increases context usage since browser tools are always loaded. If you notice increased context consumption, disable this setting and use `--chrome` only when needed.

### Disable Chrome for a Session

Use the `--no-chrome` flag:

```bash
claude --no-chrome
```

### VS Code

In the VS Code extension, Chrome is available whenever the Chrome extension is installed. No additional flag is needed.

### Managing Site Permissions

Site-level permissions are inherited from the Chrome extension. Manage permissions in the Chrome extension settings to control which sites Claude can browse, click, and type on.

### Checking Connection Status

Run `/chrome` at any time to check the connection status, manage permissions, or reconnect the extension.

### Viewing Available Browser Tools

Run `/mcp` and select `claude-in-chrome` to see the full list of available browser tools.

## Usage Examples

### Test a Local Web Application

```
I just updated the login form validation. Can you open localhost:3000,
try submitting the form with invalid data, and check if the error
messages appear correctly?
```

### Debug with Console Logs

```
Open the dashboard page and check the console for any errors when
the page loads.
```

### Automate Form Filling

```
I have a spreadsheet of customer contacts in contacts.csv. For each row,
go to the CRM at crm.example.com, click "Add Contact", and fill in the
name, email, and phone fields.
```

### Draft Content in Google Docs

```
Draft a project update based on the recent commits and add it to my
Google Doc at docs.google.com/document/d/abc123
```

### Extract Data from Web Pages

```
Go to the product listings page and extract the name, price, and
availability for each item. Save the results as a CSV file.
```

### Multi-site Workflows

```
Check my calendar for meetings tomorrow, then for each meeting with
an external attendee, look up their company website and add a note
about what they do.
```

### Record a Demo GIF

```
Record a GIF showing how to complete the checkout flow, from adding
an item to the cart through to the confirmation page.
```

### Search and Navigate

```
Go to code.claude.com/docs, click on the search box,
type "hooks", and tell me what results appear
```

## Important Details

### Supported Browsers

- Google Chrome
- Microsoft Edge

Not yet supported: Brave, Arc, or other Chromium-based browsers. WSL (Windows Subsystem for Linux) is also not supported.

### Provider Limitations

Chrome integration is not available through third-party providers like Amazon Bedrock, Google Cloud Vertex AI, or Microsoft Foundry. If you access Claude exclusively through a third-party provider, you need a separate claude.ai account to use this feature.

### How Browser Actions Work

- Claude opens new tabs for browser tasks
- Browser actions run in a visible Chrome window in real time
- Claude shares your browser's login state, accessing sites you are already signed into
- When Claude encounters a login page or CAPTCHA, it pauses and asks you to handle it manually

### Native Messaging Host

The first time you enable Chrome integration, Claude Code installs a native messaging host configuration file. Chrome reads this file on startup, so if the extension is not detected on the first attempt, restart Chrome to pick up the new configuration.

Configuration file locations:

**Chrome**:
- macOS: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`
- Linux: `~/.config/google-chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`

**Edge**:
- macOS: `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`
- Linux: `~/.config/microsoft-edge/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`

### Troubleshooting

| Error                                | Cause                                            | Fix                                                             |
|:-------------------------------------|:-------------------------------------------------|:----------------------------------------------------------------|
| "Browser extension is not connected" | Native messaging host cannot reach the extension | Restart Chrome and Claude Code, then run `/chrome` to reconnect |
| "Extension not detected"             | Chrome extension is not installed or is disabled | Install or enable the extension in `chrome://extensions`        |
| "No tab available"                   | Claude tried to act before a tab was ready       | Ask Claude to create a new tab and retry                        |
| "Receiving end does not exist"       | Extension service worker went idle               | Run `/chrome` and select "Reconnect extension"                  |

Other common issues:
- **Connection drops during long sessions**: The Chrome extension's service worker can go idle. Run `/chrome` and select "Reconnect extension".
- **JavaScript dialogs blocking**: Modal dialogs (alert, confirm, prompt) block browser events. Dismiss the dialog manually, then tell Claude to continue.
- **Windows named pipe conflicts (EADDRINUSE)**: Close other Claude Code sessions using Chrome, then restart.

## References

- [Use Claude Code with Chrome (beta) - Claude Code Docs](https://code.claude.com/docs/en/chrome) -- Official documentation covering setup, capabilities, workflows, and troubleshooting
- [Getting Started with Claude in Chrome](https://support.claude.com/en/articles/12012173-getting-started-with-claude-in-chrome) -- Full Chrome extension documentation including shortcuts, scheduling, and permissions
- [CLI Reference - Claude Code Docs](https://code.claude.com/docs/en/cli-reference) -- Documentation on `--chrome` and `--no-chrome` flags
- [Chrome DevTools MCP Server](https://github.com/ChromeDevTools/chrome-devtools-mcp) -- Advanced Chrome DevTools integration for coding agents
