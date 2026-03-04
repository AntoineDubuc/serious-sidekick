---
name: remote-control
description: "Assist with remote control, mobile access, teleport, working from phone, or continuing sessions from another device"
---

# Remote Control

## Quick Reference
- Remote Control lets you continue a local Claude Code session from your phone, tablet, or any browser
- Claude keeps running locally -- filesystem, MCP servers, tools, and project config stay on your machine
- Only messages and tool results travel through Anthropic's servers
- Requires a **Max plan** (Pro plan support coming soon; API keys not supported)
- Must be logged in via `/login` and have accepted workspace trust at least once
- Start from CLI: `claude remote-control` or from an existing session: `/remote-control` (shorthand: `/rc`)
- Connect via session URL, QR code (press spacebar), or find it in claude.ai/code session list
- One remote session per Claude Code instance at a time
- Terminal must stay open -- closing it ends the remote session
- Auto-reconnects if laptop sleeps; times out after ~10 minutes of network outage

## Configuration

```bash
# Start a new remote control session
cd ~/projects/my-app
claude remote-control

# Flags for CLI start
claude remote-control --verbose        # Detailed logs
claude remote-control --sandbox        # Enable sandboxing
claude remote-control --no-sandbox     # Disable sandboxing

# From inside an existing session
/rename "Auth refactor session"   # Name it first for easy finding
/remote-control                    # Or /rc

# Enable for all sessions automatically
/config  # Set "Enable Remote Control for all sessions" to true

# Install mobile app
/mobile   # Shows download QR code for iOS/Android
```

## Common Patterns

### Start at desk, continue on phone
1. `claude remote-control` in your project directory
2. Press spacebar for QR code, scan with phone
3. Continue the conversation from the Claude mobile app

### Pull a web session to local (Teleport)
Use `/teleport` or `claude --teleport <session-id>` to pull a cloud-based Claude Code session down to your local terminal. Requires a clean working directory (stash or commit first). One-way: web to local only.

### Remote Control vs. Claude Code on the Web
| Aspect | Remote Control | Claude Code on the Web |
|:-------|:---------------|:----------------------|
| Execution | Runs on your machine | Runs on Anthropic cloud |
| Local tools | Full access to MCP servers, tools | No local access |
| Best for | Continuing local work remotely | Starting fresh without local setup |

## Security
- **Outbound only**: No inbound ports opened on your machine
- **TLS transport**: Same security as any Claude Code session
- **Short-lived credentials**: Multiple credentials, each scoped to a single purpose, expiring independently
- **Local execution**: Nothing moves to the cloud except messages and tool results

## Gotchas
- **Max plan required**: Not available on Pro, Team, or Enterprise plans currently
- **One session limit**: Each Claude Code instance supports only one remote connection at a time
- **Terminal must stay open**: Remote Control runs as a local process; closing the terminal ends it
- **Network timeout**: ~10 minutes of network outage causes the session to exit; run `claude remote-control` again
- **Teleport needs clean workdir**: Stash or commit changes before pulling web sessions locally

@../../Claude Code Features/31_Remote_Control/research.md
