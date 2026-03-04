# Headless Mode (Non-Interactive / CLI Mode)

## Overview

Headless mode allows you to run Claude Code programmatically from the command line using the `-p` (or `--print`) flag. Instead of launching an interactive session, Claude processes the prompt, prints the response, and exits. This makes Claude Code usable in scripts, CI/CD pipelines, and automation workflows. Anthropic now refers to this capability as part of the "Agent SDK" CLI interface, though the `-p` flag and all CLI options work the same way as the original "headless mode."

## Key Capabilities

- Run Claude Code non-interactively with a single prompt via `-p` / `--print`
- Pipe data into Claude and pipe output out, integrating with Unix-style workflows
- Choose from three output formats: `text`, `json`, and `stream-json`
- Get structured JSON output conforming to a specific schema using `--json-schema`
- Auto-approve specific tools with `--allowedTools` for unattended operation
- Continue or resume previous conversations in headless mode with `--continue` and `--resume`
- Customize or replace the system prompt with `--system-prompt` or `--append-system-prompt`
- Set a maximum budget with `--max-budget-usd` and limit agentic turns with `--max-turns`
- Disable session persistence with `--no-session-persistence` for ephemeral runs
- Use `--permission-mode plan` for read-only analysis in headless mode

## Configuration / Setup

No special configuration is required beyond having Claude Code installed. Simply add the `-p` flag to any `claude` command:

```bash
claude -p "Your prompt here"
```

All standard CLI flags work in combination with `-p`, including:

| Flag | Purpose |
|------|---------|
| `--output-format` | Control output format (`text`, `json`, `stream-json`) |
| `--allowedTools` | Auto-approve specific tools without prompting |
| `--continue` / `-c` | Continue the most recent conversation |
| `--resume` / `-r` | Resume a specific session by ID or name |
| `--append-system-prompt` | Add instructions while keeping default behavior |
| `--system-prompt` | Replace the entire system prompt |
| `--json-schema` | Enforce structured JSON output matching a schema |
| `--max-turns` | Limit the number of agentic turns |
| `--max-budget-usd` | Set a maximum dollar spend for the run |
| `--no-session-persistence` | Do not save the session to disk |
| `--verbose` | Show detailed turn-by-turn output |
| `--fallback-model` | Fall back to a specified model when the default is overloaded |

## Usage Examples

### Basic non-interactive query

```bash
claude -p "What does the auth module do?"
```

### Piping data through Claude

```bash
cat build-error.txt | claude -p 'concisely explain the root cause of this build error' > output.txt
```

### Getting structured JSON output

```bash
claude -p "Summarize this project" --output-format json
```

The JSON output includes the text result in the `result` field, along with session ID and metadata.

### Enforcing a JSON schema

```bash
claude -p "Extract the main function names from auth.py" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"functions":{"type":"array","items":{"type":"string"}}},"required":["functions"]}'
```

The structured result appears in the `structured_output` field of the JSON response.

### Extracting specific fields with jq

```bash
# Extract just the text result
claude -p "Summarize this project" --output-format json | jq -r '.result'

# Extract structured output
claude -p "Extract function names" \
  --output-format json \
  --json-schema '...' \
  | jq '.structured_output'
```

### Streaming output in real time

```bash
claude -p "Explain recursion" --output-format stream-json --verbose --include-partial-messages
```

Each line is a JSON object representing an event. To filter for just the streaming text:

```bash
claude -p "Write a poem" --output-format stream-json --verbose --include-partial-messages | \
  jq -rj 'select(.type == "stream_event" and .event.delta.type? == "text_delta") | .event.delta.text'
```

### Auto-approving tools for unattended operation

```bash
claude -p "Run the test suite and fix any failures" \
  --allowedTools "Bash,Read,Edit"
```

### Creating a commit automatically

```bash
claude -p "Look at my staged changes and create an appropriate commit" \
  --allowedTools "Bash(git diff *),Bash(git log *),Bash(git status *),Bash(git commit *)"
```

The `--allowedTools` flag uses permission rule syntax. The trailing ` *` enables prefix matching (e.g., `Bash(git diff *)` allows any command starting with `git diff`). The space before `*` is important to prevent unintended matches.

### Adding custom instructions to the system prompt

```bash
gh pr diff "$1" | claude -p \
  --append-system-prompt "You are a security engineer. Review for vulnerabilities." \
  --output-format json
```

### Multi-turn headless conversations

```bash
# First request
claude -p "Review this codebase for performance issues"

# Continue the most recent conversation
claude -p "Now focus on the database queries" --continue
claude -p "Generate a summary of all issues found" --continue
```

### Resuming a specific session by ID

```bash
session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')
claude -p "Continue that review" --resume "$session_id"
```

### Read-only analysis in headless mode

```bash
claude --permission-mode plan -p "Analyze the authentication system and suggest improvements"
```

### Using Claude as a linter in a build script

```json
{
  "scripts": {
    "lint:claude": "claude -p 'you are a linter. please look at the changes vs. main and report any issues related to typos. report the filename and line number on one line, and a description of the issue on the second line. do not return any other text.'"
  }
}
```

## Important Details

- **Skills and built-in commands are not available in `-p` mode.** User-invoked skills like `/commit` and built-in commands like `/compact` only work in interactive mode. In `-p` mode, describe the task you want to accomplish instead.
- **Output format `text` is the default.** It returns plain text. Use `json` for structured metadata (session ID, usage, cost) or `stream-json` for real-time streaming.
- **`stream-json` output**: each line is a valid JSON object, but the entire output concatenated together is not valid JSON.
- **`--max-turns`**: limits the number of agentic turns in print mode. Claude exits with an error when the limit is reached. There is no limit by default.
- **`--max-budget-usd`**: sets a maximum dollar amount to spend on API calls before stopping (print mode only).
- **`--no-session-persistence`**: sessions are not saved to disk and cannot be resumed. Useful for ephemeral CI/CD runs.
- **`--fallback-model`**: enables automatic fallback to a specified model when the default model is overloaded (print mode only).
- **Session IDs** are returned in JSON output format, enabling programmatic session management across multiple headless invocations.
- **System prompt flags**: `--system-prompt` replaces the entire default prompt; `--append-system-prompt` adds to it. The append variant is recommended for most use cases as it preserves Claude Code's built-in capabilities.
- **Agent SDK**: For full programmatic control with structured outputs, tool approval callbacks, and native message objects, Anthropic offers Python and TypeScript SDK packages as part of the Agent SDK.

## References

- [Run Claude Code programmatically (Headless)](https://docs.anthropic.com/en/docs/claude-code/headless) -- Official documentation for headless mode / Agent SDK CLI usage
- [CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-reference) -- Complete list of all CLI flags and options
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- Full Agent SDK documentation for Python and TypeScript
- [GitHub Actions](https://docs.anthropic.com/en/docs/claude-code/github-actions) -- Using the Agent SDK in GitHub workflows
- [GitLab CI/CD](https://docs.anthropic.com/en/docs/claude-code/gitlab-ci-cd) -- Using the Agent SDK in GitLab pipelines
