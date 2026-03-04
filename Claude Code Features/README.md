# Claude Code Features

Comprehensive documentation of all Claude Code features, sourced from Anthropic's official documentation and community resources. Each subfolder contains a `research.md` with detailed information, configuration examples, and source references.

**Last Updated:** March 2, 2026

---

## Foundation

| # | Feature | Description |
|---|---------|-------------|
| [01](./01_Core_CLI/) | **Core CLI** | Terminal-native agentic coding tool — installation, CLI flags, basic commands |
| [02](./02_CLAUDE_md/) | **CLAUDE.md** | Project memory and instructions — user/project/folder-level configuration files |
| [16](./16_Memory_System/) | **Memory System** | Auto-memory, persistent memory directory, MEMORY.md across sessions |
| [15](./15_Session_Management/) | **Session Management** | Continue/resume sessions, session IDs, forking, naming |

## Configuration & Customization

| # | Feature | Description |
|---|---------|-------------|
| [18](./18_Settings_and_Configuration/) | **Settings & Configuration** | settings.json, keybindings.json, environment variables, config hierarchy |
| [23](./23_Keybindings/) | **Keybindings** | Customizable keyboard shortcuts across 17+ contexts with chord support |
| [24](./24_Status_Line/) | **Status Line** | Shell-script-driven status bar with model, context, cost, git info |
| [27](./27_Output_Styles/) | **Output Styles** | Default/Explanatory/Learning styles + custom Markdown style files |
| [36](./36_Themes/) | **Themes** | Color themes — dark/light, colorblind-accessible, ANSI terminal themes |

## Extensibility

| # | Feature | Description |
|---|---------|-------------|
| [03](./03_Hooks/) | **Hooks** | Lifecycle hooks (PreToolUse, PostToolUse, etc.) — shell, HTTP, and LLM handlers |
| [04](./04_Skills_and_Slash_Commands/) | **Skills & Slash Commands** | Custom commands, skills system, built-in commands, auto-invocation |
| [05](./05_MCP_Integration/) | **MCP Integration** | Model Context Protocol servers for external tool connections |
| [26](./26_Plugins/) | **Plugins** | Distributable packages of skills, agents, hooks, MCP/LSP servers |

## Multi-Agent & Orchestration

| # | Feature | Description |
|---|---------|-------------|
| [09](./09_Subagents/) | **Subagents** | Specialized agents with custom prompts, tools, and parallel execution |
| [28](./28_Agent_Teams/) | **Agent Teams** | Experimental multi-agent swarms with peer-to-peer messaging |
| [07](./07_Agent_SDK/) | **Agent SDK** | Python & TypeScript SDKs for programmatic Claude Code usage |

## Modes & Interaction

| # | Feature | Description |
|---|---------|-------------|
| [21](./21_Plan_Mode/) | **Plan Mode** | Read-only exploration mode — Shift+Tab to cycle, /plan to activate |
| [22](./22_Vim_Mode/) | **Vim Mode** | Vim-style editing — NORMAL/INSERT/VISUAL modes, motions, text objects |
| [29](./29_Fast_Mode/) | **Fast Mode** | Same Opus 4.6 model at 2.5x speed — /fast toggle |
| [37](./37_Interactive_Features/) | **Interactive Features** | Prompt suggestions, bash mode (!), /diff, /stats, @references, and more |

## Security & Permissions

| # | Feature | Description |
|---|---------|-------------|
| [10](./10_Permissions_and_Security/) | **Permissions & Security** | Allow/Ask/Deny tiers, permission modes, security best practices |
| [35](./35_Sandboxing/) | **Sandboxing** | OS-level isolation (macOS Seatbelt, Linux bubblewrap) for filesystem & network |
| [38](./38_Enterprise_and_Managed_Settings/) | **Enterprise & Managed Settings** | Organization-wide policies, managed settings, MDM, forced login |

## Platforms & Integrations

| # | Feature | Description |
|---|---------|-------------|
| [06](./06_IDE_Extensions/) | **IDE Extensions** | VS Code extension and JetBrains plugin — inline diffs, diagnostics |
| [25](./25_Chrome_Integration/) | **Chrome Integration** | Browser automation, live debugging, authenticated web app testing |
| [33](./33_Desktop_App/) | **Desktop App** | Standalone app with visual diffs, parallel sessions, connectors |
| [34](./34_Claude_Code_Web/) | **Claude Code Web** | Browser-based at claude.ai/code — no local setup required |
| [08](./08_GitHub_Actions/) | **GitHub Actions** | CI/CD with claude-code-action — PR automation, @claude mentions |
| [32](./32_Slack_Integration/) | **Slack Integration** | @Claude in Slack channels — auto-detects coding tasks |
| [31](./31_Remote_Control/) | **Remote Control** | Continue sessions from phone/tablet/browser, teleport between environments |

## Tools & Development

| # | Feature | Description |
|---|---------|-------------|
| [19](./19_Built_in_Tools/) | **Built-in Tools** | Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch, and more |
| [13](./13_Git_Worktrees/) | **Git Worktrees** | Parallel development with isolated worktrees per agent |
| [30](./30_Checkpointing_and_Rewind/) | **Checkpointing & Rewind** | Automatic code snapshots — Esc+Esc to rewind |
| [12](./12_Context_Management/) | **Context Management** | Auto-compaction, extended thinking, context window optimization |
| [11](./11_Headless_Mode/) | **Headless Mode** | Non-interactive -p flag for scripting, CI/CD, and automation |

## Infrastructure

| # | Feature | Description |
|---|---------|-------------|
| [14](./14_Cloud_Providers/) | **Cloud Providers** | AWS Bedrock, Google Vertex AI configuration and authentication |
| [20](./20_Multi_Model_Support/) | **Multi-Model Support** | Opus/Sonnet/Haiku selection, model aliases, adaptive reasoning |
| [17](./17_Cost_Management/) | **Cost Management** | Token tracking, spend limits, optimization strategies |

---

## Chronological Timeline (by Release Date)

| Date | # | Feature | Category |
|------|---|---------|----------|
| Feb 2025 | [01](./01_Core_CLI/) | **Core CLI** | Foundation |
| Feb 2025 | [02](./02_CLAUDE_md/) | **CLAUDE.md** | Foundation |
| Feb 2025 | [10](./10_Permissions_and_Security/) | **Permissions & Security** | Security |
| Feb 2025 | [19](./19_Built_in_Tools/) | **Built-in Tools** | Tools |
| Mar 2025 | [22](./22_Vim_Mode/) | **Vim Mode** | Interaction |
| Mar 2025 | [04](./04_Skills_and_Slash_Commands/) | **Custom Slash Commands** (skills added Oct 2025) | Extensibility |
| Mar 2025 | [05](./05_MCP_Integration/) | **MCP Integration** | Extensibility |
| Mar 2025 | [14](./14_Cloud_Providers/) | **Cloud Providers** (Bedrock, Vertex) | Infrastructure |
| Mar 2025 | [12](./12_Context_Management/) | **Context Management / Compaction** | Tools |
| Mar 2025 | [16](./16_Memory_System/) | **Memory System** (auto-memory added Feb 2026) | Foundation |
| Mar 2025 | [18](./18_Settings_and_Configuration/) | **Settings & Configuration** | Configuration |
| May 2025 | [11](./11_Headless_Mode/) | **Headless Mode** (GA) | Automation |
| Jun 2025 | [21](./21_Plan_Mode/) | **Plan Mode** | Interaction |
| Jun 2025 | [03](./03_Hooks/) | **Hooks** | Extensibility |
| Jun 2025 | [15](./15_Session_Management/) | **Session Management** | Foundation |
| Jul 2025 | [09](./09_Subagents/) | **Subagents** | Orchestration |
| Aug 2025 | [27](./27_Output_Styles/) | **Output Styles** | Configuration |
| Aug-Sep 2025 | [24](./24_Status_Line/) | **Status Line** | Configuration |
| Sep 2025 | [06](./06_IDE_Extensions/) | **IDE Extensions** (VS Code + JetBrains) | Platforms |
| Sep 2025 | [07](./07_Agent_SDK/) | **Agent SDK** | Orchestration |
| Sep 2025 | [08](./08_GitHub_Actions/) | **GitHub Actions** | Platforms |
| Sep 2025 | [30](./30_Checkpointing_and_Rewind/) | **Checkpointing & Rewind** | Tools |
| Sep 2025 | [17](./17_Cost_Management/) | **Cost Management** | Infrastructure |
| Oct 2025 | [34](./34_Claude_Code_Web/) | **Claude Code on the Web** | Platforms |
| Oct 2025 | [35](./35_Sandboxing/) | **Sandboxing** | Security |
| Oct 2025 | [26](./26_Plugins/) | **Plugins** | Extensibility |
| Nov 2025 | [33](./33_Desktop_App/) | **Desktop App** | Platforms |
| Nov 2025 | [25](./25_Chrome_Integration/) | **Chrome Integration** (all paid Dec 2025) | Platforms |
| Nov 2025 | [38](./38_Enterprise_and_Managed_Settings/) | **Enterprise & Managed Settings** (plist/registry Feb 2026) | Security |
| Dec 2025 | [32](./32_Slack_Integration/) | **Slack Integration** | Platforms |
| Dec 2025 | [20](./20_Multi_Model_Support/) | **Multi-Model Support** (model picker) | Infrastructure |
| Dec 2025 | [37](./37_Interactive_Features/) | **Interactive Features** (prompt suggestions, etc.) | Interaction |
| Jan 2026 | [23](./23_Keybindings/) | **Keybindings** (customizable) | Configuration |
| Jan 2026 | [31](./31_Remote_Control/) | **Remote Control** (teleport Jan; mobile Feb 2026) | Platforms |
| Jan 2026 | [36](./36_Themes/) | **Themes** | Configuration |
| Feb 2026 | [28](./28_Agent_Teams/) | **Agent Teams / Swarms** (experimental) | Orchestration |
| Feb 2026 | [29](./29_Fast_Mode/) | **Fast Mode** (research preview) | Interaction |
| Feb 2026 | [13](./13_Git_Worktrees/) | **Git Worktrees** | Tools |

### Key Milestones

| Date | Milestone |
|------|-----------|
| **Feb 24, 2025** | Claude Code v0.2.0 research preview launched with Claude 3.7 Sonnet |
| **May 22, 2025** | v1.0.0 — General Availability |
| **Sep 29, 2025** | v2.0.0 — IDE extensions, Agent SDK, GitHub Actions, Checkpointing |
| **Oct 20, 2025** | Claude Code on the Web launched |
| **Nov 24, 2025** | Desktop App Code tab with Opus 4.5 |
| **Jan 7, 2026** | v2.1.0 — Teleport, keybindings, skill hot-reload |
| **Feb 5, 2026** | Opus 4.6 + Agent Teams, auto-memory |
| **Feb 25, 2026** | Remote Control for mobile |

### Timeline Sources
- [Claude Code CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- [Claudefast Complete Changelog](https://claudefa.st/blog/guide/changelog)
- [Anthropic Blog: Claude 3.7 Sonnet and Claude Code (Feb 2025)](https://www.anthropic.com/news/claude-3-7-sonnet)
- [Anthropic Blog: Enabling Claude Code to work more autonomously (Sep 2025)](https://www.anthropic.com/news/enabling-claude-code-to-work-more-autonomously)
- [Anthropic Blog: Claude Code on the Web (Oct 2025)](https://claude.com/blog/claude-code-on-the-web)
- [TechCrunch: Anthropic releases Opus 4.6 (Feb 2026)](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)
- [Dev.to: Reflections of Claude Code from CHANGELOG](https://dev.to/oikon/reflections-of-claude-code-from-changelog-833)

---

## Primary Sources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code/overview) — Official Anthropic docs
- [Claude Code CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-reference)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/claude-code/sdk)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
