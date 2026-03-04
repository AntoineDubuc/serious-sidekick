---
name: headless-mode
description: "Auto-load when user asks about headless mode, scripting, CI/CD pipelines, the -p flag, automation, or running Claude Code non-interactively"
---

# Headless Mode (Non-Interactive / CLI Mode)

## Quick Reference
- **`-p` / `--print` flag**: runs Claude Code non-interactively -- processes prompt, prints response, exits.
- **Three output formats**: `text` (default), `json` (structured metadata + session ID), `stream-json` (real-time streaming, one JSON object per line).
- **`--allowedTools`**: auto-approve specific tools for unattended operation, using permission rule syntax (e.g., `"Bash(git diff *),Read,Edit"`).
- **`--json-schema`**: enforce structured JSON output matching a schema (result in `structured_output` field).
- **`--continue` / `-c`**: continue the most recent conversation; `--resume` / `-r`: resume a specific session by ID.
- **`--append-system-prompt`**: add instructions while keeping defaults (recommended); `--system-prompt`: replace entire system prompt.
- **`--max-turns`**: limit agentic turns; `--max-budget-usd`: set dollar spend cap.
- **`--no-session-persistence`**: ephemeral runs that are not saved to disk.
- **`--permission-mode plan`**: read-only analysis in headless mode.
- **Skills and `/` commands are NOT available in `-p` mode** -- describe the task instead.

## Configuration

**Key CLI flags for headless mode:**

| Flag | Purpose |
|------|---------|
| `--output-format` | `text`, `json`, or `stream-json` |
| `--allowedTools` | Auto-approve specific tools |
| `--continue` / `-c` | Continue most recent conversation |
| `--resume` / `-r` | Resume specific session by ID |
| `--append-system-prompt` | Add to default system prompt |
| `--system-prompt` | Replace entire system prompt |
| `--json-schema` | Enforce structured JSON output |
| `--max-turns` | Limit agentic turns |
| `--max-budget-usd` | Set dollar spend cap |
| `--no-session-persistence` | Ephemeral, non-resumable run |
| `--verbose` | Detailed turn-by-turn output |
| `--fallback-model` | Auto-fallback when default model is overloaded |

## Common Patterns

1. **Pipe data through Claude for analysis:**
   ```bash
   cat build-error.txt | claude -p 'explain the root cause' > output.txt
   ```

2. **Automated commit with scoped tool permissions:**
   ```bash
   claude -p "Look at staged changes and create a commit" \
     --allowedTools "Bash(git diff *),Bash(git log *),Bash(git status *),Bash(git commit *)"
   ```
   The trailing ` *` enables prefix matching. The space before `*` is important.

3. **PR review with custom role:**
   ```bash
   gh pr diff "$1" | claude -p \
     --append-system-prompt "You are a security engineer. Review for vulnerabilities." \
     --output-format json
   ```

4. **Multi-turn headless conversation:**
   ```bash
   claude -p "Review this codebase for performance issues"
   claude -p "Now focus on the database queries" --continue
   claude -p "Generate a summary of all issues found" --continue
   ```

5. **Structured output with jq extraction:**
   ```bash
   claude -p "Extract function names from auth.py" \
     --output-format json \
     --json-schema '{"type":"object","properties":{"functions":{"type":"array","items":{"type":"string"}}},"required":["functions"]}' \
     | jq '.structured_output'
   ```

6. **Stream text in real time:**
   ```bash
   claude -p "Explain recursion" --output-format stream-json --verbose --include-partial-messages | \
     jq -rj 'select(.type == "stream_event" and .event.delta.type? == "text_delta") | .event.delta.text'
   ```

## Gotchas
- **`stream-json`**: each line is valid JSON, but the entire output concatenated is NOT valid JSON.
- **`--max-turns`**: Claude exits with an error when the limit is reached; there is no default limit.
- **`--system-prompt` replaces everything** -- you lose built-in Claude Code capabilities. Prefer `--append-system-prompt`.
- **Session IDs** are only returned in `json` output format, not `text`.
- **`--fallback-model`** only works in print mode.
- **Switching mid-conversation to fast mode** in headless charges full uncached input price for entire context.
- For full programmatic control with callbacks and native messages, use the **Agent SDK** (Python/TypeScript packages) instead of CLI headless mode.

@./Claude Code Features/11_Headless_Mode/research.md
