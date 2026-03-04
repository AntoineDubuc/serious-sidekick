# Agent SDK

## Overview

The Claude Agent SDK (formerly Claude Code SDK) provides programmatic access to Claude Code's capabilities through Python and TypeScript libraries. It gives developers the same tools, agent loop, and context management that power Claude Code, enabling them to build production AI agents that can read files, run commands, search the web, edit code, and more. The SDK is also available via the CLI using the `-p` flag for non-interactive (headless) usage in scripts and CI/CD pipelines.

## Key Capabilities

- **Built-in tool execution**: agents can read files, run commands, edit code, search codebases, fetch web content, and more out of the box -- no tool implementation required
- **Two API styles in Python**: `query()` for one-off tasks (new session each time) and `ClaudeSDKClient` for continuous multi-turn conversations
- **Async streaming**: messages are streamed as they arrive via async iterators/generators
- **Session management**: capture session IDs and resume conversations with full context, or fork sessions to explore different approaches
- **Subagent orchestration**: spawn specialized sub-agents with custom prompts, tool restrictions, and models
- **Hook system**: run custom code at key lifecycle points (PreToolUse, PostToolUse, Stop, SessionStart, SessionEnd, etc.)
- **MCP integration**: connect to external tools, databases, and APIs via Model Context Protocol servers (including in-process SDK MCP servers)
- **Permission control**: fine-grained tool access with allowedTools, disallowedTools, and permission modes
- **Structured output**: define JSON schemas for structured agent responses
- **Custom system prompts**: fully replace or append to the default Claude Code system prompt
- **Third-party provider support**: works with Amazon Bedrock, Google Vertex AI, and Microsoft Azure AI Foundry

## Configuration / Setup

### Installation

**Python:**
```bash
pip install claude-agent-sdk
```

**TypeScript:**
```bash
npm install @anthropic-ai/claude-agent-sdk
```

### Authentication

Set your API key as an environment variable:
```bash
export ANTHROPIC_API_KEY=your-api-key
```

For third-party providers:
- **Amazon Bedrock**: set `CLAUDE_CODE_USE_BEDROCK=1` and configure AWS credentials
- **Google Vertex AI**: set `CLAUDE_CODE_USE_VERTEX=1` and configure Google Cloud credentials
- **Microsoft Azure**: set `CLAUDE_CODE_USE_FOUNDRY=1` and configure Azure credentials

### CLI Headless Mode

Use the `-p` (or `--print`) flag for non-interactive usage:
```bash
claude -p "Find and fix the bug in auth.py" --allowedTools "Read,Edit,Bash"
```

## Usage Examples

### Basic Python Usage with query()

```python
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions

async def main():
    async for message in query(
        prompt="Find and fix the bug in auth.py",
        options=ClaudeAgentOptions(allowed_tools=["Read", "Edit", "Bash"]),
    ):
        print(message)

asyncio.run(main())
```

### Basic TypeScript Usage with query()

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "Find and fix the bug in auth.py",
  options: { allowedTools: ["Read", "Edit", "Bash"] }
})) {
  console.log(message);
}
```

### Python ClaudeSDKClient for Multi-Turn Conversations

```python
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions

async def main():
    options = ClaudeAgentOptions(
        system_prompt="You are an expert Python developer",
        permission_mode="acceptEdits",
        cwd="/home/user/project",
    )

    async for message in query(prompt="Create a Python web server", options=options):
        print(message)

asyncio.run(main())
```

### Session Resumption (TypeScript)

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

let sessionId: string | undefined;

// First query: capture the session ID
for await (const message of query({
  prompt: "Read the authentication module",
  options: { allowedTools: ["Read", "Glob"] }
})) {
  if (message.type === "system" && message.subtype === "init") {
    sessionId = message.session_id;
  }
}

// Resume with full context from the first query
for await (const message of query({
  prompt: "Now find all places that call it",
  options: { resume: sessionId }
})) {
  if ("result" in message) console.log(message.result);
}
```

### Subagents via SDK (Python)

```python
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

async def main():
    async for message in query(
        prompt="Use the code-reviewer agent to review this codebase",
        options=ClaudeAgentOptions(
            allowed_tools=["Read", "Glob", "Grep", "Task"],
            agents={
                "code-reviewer": AgentDefinition(
                    description="Expert code reviewer for quality and security reviews.",
                    prompt="Analyze code quality and suggest improvements.",
                    tools=["Read", "Glob", "Grep"],
                )
            },
        ),
    ):
        if hasattr(message, "result"):
            print(message.result)

asyncio.run(main())
```

### Hooks via SDK (Python)

```python
import asyncio
from datetime import datetime
from claude_agent_sdk import query, ClaudeAgentOptions, HookMatcher

async def log_file_change(input_data, tool_use_id, context):
    file_path = input_data.get("tool_input", {}).get("file_path", "unknown")
    with open("./audit.log", "a") as f:
        f.write(f"{datetime.now()}: modified {file_path}\n")
    return {}

async def main():
    async for message in query(
        prompt="Refactor utils.py to improve readability",
        options=ClaudeAgentOptions(
            permission_mode="acceptEdits",
            hooks={
                "PostToolUse": [
                    HookMatcher(matcher="Edit|Write", hooks=[log_file_change])
                ]
            },
        ),
    ):
        if hasattr(message, "result"):
            print(message.result)

asyncio.run(main())
```

### CLI Structured Output with JSON Schema

```bash
claude -p "Extract the main function names from auth.py" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"functions":{"type":"array","items":{"type":"string"}}},"required":["functions"]}'
```

### CLI Session Continuation

```bash
# First request
claude -p "Review this codebase for performance issues"

# Continue the most recent conversation
claude -p "Now focus on the database queries" --continue

# Resume a specific session by ID
session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')
claude -p "Continue that review" --resume "$session_id"
```

### Custom MCP Server (Python)

```python
from claude_agent_sdk import tool, create_sdk_mcp_server

@tool("add", "Add two numbers", {"a": float, "b": float})
async def add(args):
    return {"content": [{"type": "text", "text": f"Sum: {args['a'] + args['b']}"}]}

calculator = create_sdk_mcp_server(
    name="calculator",
    version="2.0.0",
    tools=[add],
)
```

## Important Details

### query() vs ClaudeSDKClient (Python)

| Feature | `query()` | `ClaudeSDKClient` |
|---------|-----------|-------------------|
| Session | Creates new session each time | Reuses same session |
| Conversation | Single exchange | Multiple exchanges in same context |
| Connection | Managed automatically | Manual control |
| Interrupts | Not supported | Supported |
| Continue Chat | New session each time | Maintains conversation |
| Use Case | One-off tasks | Continuous conversations |

### Built-in Tools Available

| Tool | Description |
|------|-------------|
| **Read** | Read any file in the working directory |
| **Write** | Create new files |
| **Edit** | Make precise edits to existing files |
| **Bash** | Run terminal commands, scripts, git operations |
| **Glob** | Find files by pattern |
| **Grep** | Search file contents with regex |
| **WebSearch** | Search the web for current information |
| **WebFetch** | Fetch and parse web page content |
| **AskUserQuestion** | Ask the user clarifying questions |

### Key Options (TypeScript)

Notable options for `query()` include: `allowedTools`, `disallowedTools`, `permissionMode` (default, acceptEdits, plan, dontAsk, bypassPermissions), `model`, `maxTurns`, `maxBudgetUsd`, `systemPrompt`, `mcpServers`, `agents`, `hooks`, `resume`, `continue`, `cwd`, `outputFormat`, `settingSources`, `thinking`, and `effort`.

### Output Formats (CLI)

- `text` (default): plain text output
- `json`: structured JSON with result, session ID, and metadata
- `stream-json`: newline-delimited JSON for real-time streaming

### Branding Guidelines

- Partners may optionally reference Claude branding
- Allowed: "Claude Agent", "Claude", "{YourAgentName} Powered by Claude"
- Not permitted: "Claude Code" or "Claude Code Agent"

### SDK vs Client SDK

The Agent SDK handles the tool loop automatically (Claude reads files, runs commands, edits code autonomously). The Anthropic Client SDK gives direct API access where you implement tool execution yourself.

## References

- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- Main SDK documentation with capabilities, installation, and examples
- [Python SDK Reference](https://platform.claude.com/docs/en/agent-sdk/python) -- Complete Python API reference including query(), ClaudeSDKClient, and types
- [TypeScript SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) -- Complete TypeScript API reference including query(), Options, and types
- [Run Claude Code Programmatically](https://code.claude.com/docs/en/headless) -- CLI headless mode documentation for scripts and CI/CD
- [Python SDK GitHub](https://github.com/anthropics/claude-agent-sdk-python) -- Source code and issue tracker for the Python SDK
- [TypeScript SDK GitHub](https://github.com/anthropics/claude-agent-sdk-typescript) -- Source code and issue tracker for the TypeScript SDK
- [Example Agents](https://github.com/anthropics/claude-agent-sdk-demos) -- Demo agents including email assistant, research agent, and more
