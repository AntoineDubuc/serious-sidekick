# Remote Control

## Overview

Remote Control allows you to continue a local Claude Code session from your phone, tablet, or any browser. It connects claude.ai/code or the Claude mobile app (iOS/Android) to a Claude Code session running on your local machine. Claude keeps running locally the entire time -- your filesystem, MCP servers, tools, and project configuration all stay on your machine. Only the messages you type and tool results Claude generates travel through Anthropic's servers.

Unlike Claude Code on the web (which runs on cloud infrastructure), Remote Control sessions run directly on your machine. The web and mobile interfaces are just a window into that local session.

## Key Capabilities

- **Continue local sessions remotely**: Start a task at your desk, pick it up from your phone or another browser.
- **Full local environment access**: Filesystem, MCP servers, tools, and project configuration remain available remotely.
- **Multi-device sync**: Conversation stays in sync across all connected devices. Send messages from terminal, browser, and phone interchangeably.
- **Automatic reconnection**: If your laptop sleeps or network drops, the session reconnects automatically when the machine comes back online.
- **QR code for quick mobile access**: Press spacebar to display a QR code for scanning with your phone.
- **Session naming**: Use `/rename` before `/remote-control` to give sessions descriptive names for easy identification.
- **No inbound ports**: Your machine only makes outbound HTTPS requests. No ports are opened on your machine.

## Configuration / Setup

### Requirements

- **Subscription**: Requires a Max plan. Pro plan support is coming soon. API keys are not supported.
- **Authentication**: Run `claude` and use `/login` to sign in through claude.ai.
- **Workspace trust**: Run `claude` in your project directory at least once to accept the workspace trust dialog.

### Starting a New Remote Control Session

Navigate to your project directory and run:

```bash
claude remote-control
```

The process stays running in the terminal, waiting for remote connections. It displays a session URL and you can press spacebar to show a QR code.

Supported flags:
- `--verbose`: Show detailed connection and session logs.
- `--sandbox` / `--no-sandbox`: Enable or disable sandboxing for filesystem and network isolation.

### From an Existing Session

If already in a Claude Code session:

```
/remote-control
```

Or the shorthand:

```
/rc
```

This starts Remote Control carrying over your current conversation history and displays a session URL and QR code. The `--verbose`, `--sandbox`, and `--no-sandbox` flags are not available with this command.

### Connecting from Another Device

Once active, connect via:
- **Session URL**: Open the URL displayed in the terminal in any browser (goes to claude.ai/code).
- **QR code**: Scan with your phone to open in the Claude app.
- **Session list**: Open claude.ai/code or the Claude app and find the session by name. Remote Control sessions show a computer icon with a green status dot when online.

### Enabling for All Sessions

Run `/config` inside Claude Code and set **Enable Remote Control for all sessions** to `true`. Each Claude Code instance supports one remote session at a time.

### Installing the Mobile App

Use the `/mobile` command inside Claude Code to display a download QR code for iOS or Android.

## Related Commands

### /teleport

The `/teleport` command (or `claude --teleport <session-id>`) allows pulling a web-based Claude Code session down to your local terminal. This is useful for continuing cloud sessions locally where you have access to your full development environment.

Note: Teleportation requires a clean working directory. Use Git stashes or commit changes before pulling sessions. The process is one-way: you can pull web sessions to local, but cannot push local sessions to the web directly.

### /desktop

The `/desktop` command relates to the Claude Code Desktop integration, allowing you to move or manage sessions across different surfaces (CLI, VS Code, Desktop app, Web).

## Security

- **Outbound only**: Remote Control makes outbound HTTPS requests only and never opens inbound ports on your machine.
- **TLS transport**: All traffic travels through the Anthropic API over TLS, the same transport security as any Claude Code session.
- **Short-lived credentials**: The connection uses multiple short-lived credentials, each scoped to a single purpose and expiring independently.
- **Local execution**: Claude Code keeps running locally. Nothing moves to the cloud except messages and tool results.

## Usage Examples

**Start a remote session and pick it up on your phone:**
```bash
# At your desk
cd ~/projects/my-app
claude remote-control
# Displays: Session URL: https://claude.ai/code/session/abc123
# Press spacebar for QR code, scan with phone
```

**Continue an existing session remotely:**
```
/rename "Auth refactor session"
/remote-control
# Share the URL or scan QR code from another device
```

**Enable Remote Control for every session automatically:**
```
/config
# Set "Enable Remote Control for all sessions" to true
```

## Important Details

### Remote Control vs. Claude Code on the Web

| Aspect              | Remote Control                              | Claude Code on the Web                    |
|:--------------------|:--------------------------------------------|:------------------------------------------|
| **Execution**       | Runs on your machine                        | Runs on Anthropic cloud infrastructure    |
| **Local tools**     | Full access to local MCP servers, tools     | No local access                           |
| **Best for**        | Continuing local work from another device   | Starting fresh without local setup        |

### Limitations

- **One remote session at a time**: Each Claude Code session supports one remote connection.
- **Terminal must stay open**: Remote Control runs as a local process. If you close the terminal or stop Claude, the session ends.
- **Extended network outage**: If your machine is awake but unable to reach the network for more than roughly 10 minutes, the session times out and exits. Run `claude remote-control` again to start a new session.
- **Plan requirements**: Currently available on Max plans only. Pro plan support is coming soon. Not available on Team or Enterprise plans.

## References

- [Continue local sessions from any device with Remote Control - Claude Code Docs](https://code.claude.com/docs/en/remote-control) -- Official documentation covering setup, connection, security, and limitations
- [Anthropic reveals Remote Control - TechRadar](https://www.techradar.com/pro/anthropic-reveals-remote-control-a-mobile-version-of-claude-code-to-keep-you-productive-on-the-move) -- Launch coverage with feature details
- [Claude Code Remote Control - Simon Willison](https://simonwillison.net/2026/Feb/25/claude-code-remote-control/) -- Technical analysis of the Remote Control feature
- [Session Teleportation in Claude Code - Habr](https://habr.com/en/articles/986590/) -- Guide on teleporting sessions between environments
