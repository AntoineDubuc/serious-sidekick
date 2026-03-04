# Built-in Tools

## Overview

Tools are what make Claude Code agentic. Without tools, Claude can only respond with text. With tools, Claude can act: read your code, edit files, run commands, search the web, and interact with external services. Each tool use returns information that feeds back into the agentic loop, informing Claude's next decision. Claude Code includes a comprehensive set of built-in tools that fall into five main categories: file operations, search, execution, web, and code intelligence.

## Key Capabilities

- **File Operations**: Read files, edit code, create new files, rename and reorganize.
- **Search**: Find files by pattern, search content with regex, explore codebases.
- **Execution**: Run shell commands, start servers, run tests, use git.
- **Web**: Search the web, fetch documentation, look up error messages.
- **Task Management**: Track work progress with structured todo lists.
- **Planning and Control**: Exit plan mode, execute slash commands.
- **Subagent Orchestration**: Launch specialized sub-agents for autonomous work.
- **Notebook Operations**: Modify Jupyter notebook cells.

## Configuration / Setup

Built-in tools are available by default. Their usage is governed by the permissions system:

| Tool type | Example | Approval required | "Yes, don't ask again" behavior |
|-----------|---------|-------------------|-------------------------------|
| Read-only | File reads, Grep | No | N/A |
| Bash commands | Shell execution | Yes | Permanently per project directory and command |
| File modification | Edit/write files | Yes | Until session end |

Configure permissions in `.claude/settings.json`:
```json
{
  "permissions": {
    "allow": ["Bash(npm run *)", "Read(./src/**)"],
    "deny": ["Bash(curl *)", "Read(./.env)"]
  }
}
```

## Usage Examples

### File Operations Tools

#### Read

Retrieves file content with line numbers. Supports text files, images (PNG/JPG), PDFs, and Jupyter notebooks.

**Parameters:**
- `file_path` (required): Absolute path to the file to read.
- `offset` (optional): Line number to start reading from.
- `limit` (optional): Number of lines to read.
- `pages` (optional): Page range for PDF files (e.g., "1-5"). Maximum 20 pages per request.

**Best practices:**
- Use absolute paths, not relative paths.
- By default reads up to 2000 lines from the beginning.
- Lines longer than 2000 characters are truncated.
- Can read images (multimodal support) and PDFs.
- Can read Jupyter notebooks (.ipynb), returning all cells with outputs.
- Always read a file before editing it.

#### Write

Creates new files or completely overwrites existing files.

**Parameters:**
- `file_path` (required): Absolute path to the file to write.
- `content` (required): Content to write to the file.

**Best practices:**
- Requires reading existing files first before overwriting.
- Prefer the Edit tool for modifying existing files (Edit only sends the diff).
- Use for creating new files or complete rewrites only.

#### Edit

Performs exact string replacements in files. More efficient than Write for modifications because it only sends the diff.

**Parameters:**
- `file_path` (required): Absolute path to the file to modify.
- `old_string` (required): The exact text to replace.
- `new_string` (required): The replacement text (must differ from old_string).
- `replace_all` (optional, default false): Replace all occurrences of old_string.

**Best practices:**
- Must read the file first before editing.
- Preserve exact indentation from the file content.
- The edit fails if `old_string` is not unique in the file. Provide more surrounding context or use `replace_all`.
- Use `replace_all` for renaming variables across a file.

#### NotebookEdit

Modifies Jupyter notebook cells.

**Parameters:**
- `notebook_path` (required): Absolute path to the .ipynb file.
- `new_source` (required): New source for the cell.
- `cell_id` (optional): ID of the cell to edit.
- `cell_type` (optional): `"code"` or `"markdown"`.
- `edit_mode` (optional): `"replace"` (default), `"insert"`, or `"delete"`.

### Search Tools

#### Glob

Fast file pattern matching for finding files by name.

**Parameters:**
- `pattern` (required): Glob pattern to match (e.g., `"**/*.js"`, `"src/**/*.ts"`).
- `path` (optional): Directory to search in (defaults to current working directory).

**Best practices:**
- Returns matching file paths sorted by modification time.
- Use instead of bash `find` or `ls` commands.
- Use when you need to find files by name patterns.

#### Grep

Content search powered by ripgrep with full regex support.

**Parameters:**
- `pattern` (required): Regular expression pattern to search for.
- `path` (optional): File or directory to search in.
- `output_mode` (optional): `"files_with_matches"` (default), `"content"`, or `"count"`.
- `glob` (optional): Glob pattern to filter files (e.g., `"*.js"`, `"**/*.tsx"`).
- `type` (optional): File type to search (e.g., `"js"`, `"py"`, `"rust"`).
- `-A` (optional): Lines to show after each match.
- `-B` (optional): Lines to show before each match.
- `-C` / `context` (optional): Lines to show before and after each match.
- `-i` (optional): Case insensitive search.
- `-n` (optional): Show line numbers (defaults to true for content mode).
- `multiline` (optional): Enable multiline matching.
- `head_limit` (optional): Limit output to first N entries.
- `offset` (optional): Skip first N entries.

**Best practices:**
- Always use Grep instead of bash `grep` or `rg`.
- Supports full regex syntax (e.g., `"log.*Error"`, `"function\\s+\\w+"`)
- Literal braces need escaping (use `interface\\{\\}` to find `interface{}` in Go code).

### Execution Tools

#### Bash

Executes shell commands.

**Parameters:**
- `command` (required): The command to execute.
- `description` (optional): Description of what the command does.
- `timeout` (optional): Timeout in milliseconds (max 600000 / 10 minutes).
- `run_in_background` (optional): Run the command in the background.

**Best practices:**
- Working directory persists between commands, but shell state does not.
- Always quote file paths with spaces.
- Use for git, npm, docker, tests, builds, and system utilities.
- Do not use for file operations (reading/writing) -- use dedicated tools instead.
- Use `run_in_background` for long-running commands.

#### BashOutput

Retrieves output from background shell processes.

**Parameters:**
- `bash_id`: ID of the background shell.
- `filter`: Filter for output.

#### KillShell

Terminates background shell processes.

**Parameters:**
- `shell_id`: ID of the shell to terminate.

### Web Tools

#### WebFetch

Retrieves content from a URL and processes it using an AI model.

**Parameters:**
- `url` (required): Fully-formed valid URL to fetch.
- `prompt` (required): What information to extract from the page.

**Best practices:**
- HTTP URLs are upgraded to HTTPS automatically.
- HTML is converted to markdown for processing.
- Includes a 15-minute cache for repeated access to the same URL.
- Will fail for authenticated or private URLs.
- For GitHub URLs, prefer using the `gh` CLI via Bash.

#### WebSearch

Searches the web for current information.

**Parameters:**
- `query` (required): The search query.
- `allowed_domains` (optional): Only include results from these domains.
- `blocked_domains` (optional): Exclude results from these domains.

**Best practices:**
- Provides up-to-date information beyond Claude's knowledge cutoff.
- Only available in the US.
- Always include sources in responses.

### Task Management Tools

#### TodoWrite

Creates and manages structured task lists for tracking progress.

**Parameters:**
- `todos`: Array of todo objects, each with:
  - `content`: Description of the task.
  - `status`: `"pending"`, `"in_progress"`, or `"completed"`.

**Best practices:**
- Maintain exactly one "in_progress" task at a time.
- Mark tasks completed immediately upon finishing.

### Orchestration Tools

#### Task (Agent/Subagent)

Launches specialized sub-agents for autonomous work in separate context windows.

**Parameters:**
- `subagent_type`: Type of subagent (e.g., `"general-purpose"`).
- `prompt`: The task prompt for the subagent.
- `description`: Description of the task.

**Best practices:**
- Use for multi-round research requiring independent exploration.
- Subagents run in their own context, keeping the main conversation clean.
- Results are summarized back to the main conversation.

#### ExitPlanMode

Exits planning mode after presenting an implementation strategy.

**Parameters:**
- `plan`: The implementation plan.

#### SlashCommand

Executes available slash commands within conversations.

**Parameters:**
- `command`: The slash command to execute.

## Important Details

### Tool Categories Summary

| Category | Tools | What Claude Can Do |
|----------|-------|-------------------|
| **File operations** | Read, Write, Edit, NotebookEdit | Read files, edit code, create new files, rename and reorganize |
| **Search** | Glob, Grep | Find files by pattern, search content with regex, explore codebases |
| **Execution** | Bash, BashOutput, KillShell | Run shell commands, start servers, run tests, use git |
| **Web** | WebFetch, WebSearch | Search the web, fetch documentation, look up error messages |
| **Task management** | TodoWrite | Track work progress with structured task checklists |
| **Orchestration** | Task (Agent), ExitPlanMode, SlashCommand | Spawn subagents, exit plan mode, run slash commands |

### Tool Permission Categories

- **Read-only tools** (Glob, Grep, Read): No approval required.
- **Bash commands**: Require approval; "Yes, don't ask again" is permanent per project directory and command.
- **File modification tools** (Edit, Write): Require approval; "Yes, don't ask again" lasts until session end.
- **WebFetch**: Requires approval based on domain permission rules.
- **MCP tools**: Require approval based on server and tool permission rules.

### Extending Built-in Tools

The built-in tools are the foundation. You can extend capabilities with:
- **Skills**: Load domain knowledge and workflows on demand.
- **MCP servers**: Connect to external services (databases, APIs, etc.).
- **Hooks**: Run scripts automatically at specific points in Claude's workflow.
- **Subagents**: Offload tasks to specialized agents with their own context.
- **Plugins**: Bundle skills, hooks, subagents, and MCP servers.
- **Code intelligence plugins**: Add type errors/warnings after edits, go-to-definition, and find-references.

### Key Principles for Tool Usage

1. **Batch independent operations**: Make multiple tool calls in parallel when they are independent.
2. **Prefer specialized tools over bash equivalents**: Use Read instead of `cat`, Grep instead of `grep`, Glob instead of `find`.
3. **Always read files before editing**: The Edit tool requires prior knowledge of exact file content.
4. **Use absolute paths**: Agent threads reset their cwd between bash calls.
5. **Choose the right tool**: Use Glob for finding files by name, Grep for searching content, Read for reading known files, Edit for modifications, Write for new files.

## References

- [How Claude Code Works](https://code.claude.com/docs/en/how-claude-code-works) -- Architecture, agentic loop, and built-in tool categories
- [Configure Permissions](https://code.claude.com/docs/en/permissions) -- Tool permission rules and configuration
- [Best Practices](https://code.claude.com/docs/en/best-practices) -- Tips for effective tool usage
- [Claude Code Built-in Tools Reference](https://www.vtrivedy.com/posts/claudecode-tools-reference) -- Community reference for built-in tools
- [Claude Code System Prompts (GitHub)](https://github.com/Piebald-AI/claude-code-system-prompts) -- System prompt including 18 built-in tool descriptions
- [Extend Claude Code](https://code.claude.com/docs/en/features-overview) -- Skills, MCP, hooks, and subagents
