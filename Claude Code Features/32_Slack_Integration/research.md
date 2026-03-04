# Slack Integration

## Overview

Claude Code in Slack brings Claude Code directly into your Slack workspace. When you mention `@Claude` with a coding task in a Slack channel, Claude automatically detects the coding intent and creates a Claude Code session on the web (claude.ai/code), allowing you to delegate development work without leaving your team conversations. The integration is built on the existing Claude for Slack app and adds intelligent routing to Claude Code on the web for coding-related requests.

## Key Capabilities

- **Automatic coding intent detection**: Claude analyzes `@Claude` mentions and determines whether the request is a coding task, routing it to Claude Code on the web automatically.
- **Two routing modes**: "Code only" (all mentions go to Claude Code) or "Code + Chat" (intelligent routing between Claude Code and Claude Chat).
- **Context gathering from Slack**: Claude gathers context from thread messages and recent channel messages to understand the problem, select the repository, and inform its approach.
- **Progress updates in threads**: As the Claude Code session progresses, status updates are posted back to the Slack thread.
- **Completion summaries**: When finished, Claude @mentions you with a summary and action buttons.
- **Direct PR creation**: Create a pull request directly from the session's changes via a "Create PR" button.
- **Repository auto-selection**: Claude automatically selects the appropriate repository based on conversation context.
- **Retry routing**: If Claude routes to Chat when you wanted Code (or vice versa), you can click "Retry as Code" or switch modes.

## Configuration / Setup

### Prerequisites

| Requirement            | Details                                                                        |
|:-----------------------|:-------------------------------------------------------------------------------|
| Claude Plan            | Pro, Max, Teams, or Enterprise with Claude Code access (premium seats)         |
| Claude Code on the Web | Access to Claude Code on the web must be enabled                               |
| GitHub Account         | Connected to Claude Code on the web with at least one repository authenticated |
| Slack Authentication   | Your Slack account linked to your Claude account via the Claude app            |

### Step-by-Step Setup

1. **Install the Claude App in Slack**: A workspace administrator installs the Claude app from the [Slack App Marketplace](https://slack.com/marketplace/A08SF47R6P4).

2. **Connect your Claude account**:
   - Open the Claude app in Slack (click "Claude" in your Apps section).
   - Navigate to the App Home tab.
   - Click "Connect" to link your Slack and Claude accounts.
   - Complete the authentication flow in your browser.

3. **Configure Claude Code on the web**:
   - Visit claude.ai/code and sign in with the same account connected to Slack.
   - Connect your GitHub account.
   - Authenticate at least one repository.

4. **Choose your routing mode** in the Claude App Home in Slack:

   | Mode            | Behavior                                                                                |
   |:----------------|:----------------------------------------------------------------------------------------|
   | **Code only**   | All @mentions route to Claude Code sessions. Best for teams using Slack exclusively for dev tasks. |
   | **Code + Chat** | Intelligent routing between Claude Code (coding) and Claude Chat (writing, analysis, general questions). Best for a single @Claude entry point for all work. |

5. **Add Claude to channels**: Claude is NOT automatically added to any channels. Invite it by typing `/invite @Claude` in desired channels.

## Usage Examples

### Bug Investigation

In a Slack channel where a bug is reported:
```
@Claude Can you investigate the null pointer exception in the auth module
and propose a fix? The error trace is in the thread above.
```

Claude gathers context from the thread, creates a Claude Code session, posts progress updates, and delivers a summary with a link to the session and a "Create PR" button.

### Quick Feature Implementation

```
@Claude Add input validation to the user registration endpoint in the
backend API. Email should be validated and passwords must be at least 8 chars.
```

### Collaborative Debugging

In a thread where teammates are discussing an issue:
```
@Claude Based on this discussion, can you look into the connection pooling
issue and suggest a fix?
```

Claude reads the full thread context to understand the problem.

## Session Flow

1. **Initiation**: You @mention Claude with a coding request in a channel.
2. **Detection**: Claude analyzes the message and detects coding intent.
3. **Session creation**: A new Claude Code session is created on claude.ai/code.
4. **Progress updates**: Claude posts status updates to your Slack thread as work progresses.
5. **Completion**: Claude @mentions you with a summary and action buttons.
6. **Review**: Click "View Session" to see the full transcript, or "Create PR" to open a pull request.

## Important Details

### Message Actions

- **View Session**: Opens the full Claude Code session in your browser.
- **Create PR**: Creates a pull request directly from the session's changes.
- **Retry as Code**: Re-routes a Chat response to a Claude Code session.
- **Change Repo**: Select a different repository if Claude chose incorrectly.

### Access and Permissions

- Each user runs sessions under their own Claude account.
- Sessions count against the individual user's plan limits.
- Users can only access repositories they have personally connected.
- Sessions appear in your Claude Code history on claude.ai/code.
- For Enterprise and Teams accounts, sessions created from Slack are automatically visible to the organization.

### Channel-Based Access Control

- Claude only responds in channels where it has been invited.
- Admins can control usage by managing which channels Claude is invited to.
- Works in both public and private channels.
- Does NOT work in direct messages (DMs).

### Security Consideration

When @Claude is invoked in Slack, Claude is given access to the conversation context. Claude may follow directions from other messages in the context, so users should only use Claude in trusted Slack conversations.

### Current Limitations

- **GitHub only**: Currently supports repositories on GitHub only.
- **One PR at a time**: Each session can create one pull request.
- **Rate limits apply**: Sessions use your individual Claude plan's rate limits.
- **Web access required**: Users must have Claude Code on the web access; those without it will only get standard Claude chat responses.
- **Channels only**: Does not work in DMs, only in Slack channels (public or private).

### Troubleshooting

- **Sessions not starting**: Verify Claude account is connected in App Home, Claude Code on the web access is enabled, and at least one GitHub repository is connected.
- **Wrong repository**: Click "Change Repo" or include the repository name in your request.
- **Authentication errors**: Disconnect and reconnect your Claude account in the App Home.

## References

- [Claude Code in Slack - Claude Code Docs](https://code.claude.com/docs/en/slack) -- Official documentation covering setup, routing modes, session flow, and troubleshooting
- [Claude Code and Slack - Claude Blog](https://claude.com/blog/claude-code-and-slack) -- Anthropic's announcement blog post
- [Claude Code is coming to Slack - TechCrunch](https://techcrunch.com/2025/12/08/claude-code-is-coming-to-slack-and-thats-a-bigger-deal-than-it-sounds/) -- Launch coverage and analysis
- [Slack App Marketplace - Claude](https://slack.com/marketplace/A08SF47R6P4) -- Install the Claude app for your workspace
