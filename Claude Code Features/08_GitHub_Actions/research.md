# GitHub Actions

## Overview

Claude Code GitHub Actions brings AI-powered automation to GitHub workflows. With a simple `@claude` mention in any PR or issue, Claude can analyze code, create pull requests, implement features, and fix bugs while following your project's standards. The action is built on top of the Claude Agent SDK and is available as `anthropics/claude-code-action@v1`.

## Key Capabilities

- **Instant PR creation**: describe what you need and Claude creates a complete PR with all necessary changes
- **Automated code implementation**: turn issues into working code with a single `@claude` command
- **Code review**: automated PR reviews for security, quality, and best practices
- **Standards compliance**: Claude respects `CLAUDE.md` guidelines and existing code patterns
- **Flexible triggers**: responds to `@claude` mentions in issue comments, PR comments, and PR review comments
- **Custom automation**: schedule workflows, respond to events, and run custom prompts
- **Skills support**: prebuilt prompts like `/review` or `/fix` for common tasks
- **Multi-provider support**: works with direct Anthropic API, AWS Bedrock, and Google Vertex AI
- **Secure by default**: code stays on GitHub's runners; API keys stored as GitHub Secrets

## Configuration / Setup

### Quick Setup

The easiest method is through Claude Code in the terminal:
```bash
claude
> /install-github-app
```
This guides you through setting up the GitHub app and required secrets.

**Requirements:**
- Repository admin access
- The GitHub app requests read & write permissions for Contents, Issues, and Pull requests
- Only available for direct Claude API users (Bedrock/Vertex users need manual setup)

### Manual Setup

1. **Install the Claude GitHub app**: [https://github.com/apps/claude](https://github.com/apps/claude)
2. **Add `ANTHROPIC_API_KEY`** to repository secrets
3. **Copy the workflow file** from [examples/claude.yml](https://github.com/anthropics/claude-code-action/blob/main/examples/claude.yml) into `.github/workflows/`

### Action Parameters (v1)

| Parameter | Description | Required |
|-----------|-------------|----------|
| `prompt` | Instructions for Claude (text or skill like `/review`) | No |
| `claude_args` | CLI arguments passed to Claude Code | No |
| `anthropic_api_key` | Claude API key | Yes (for direct API) |
| `github_token` | GitHub token for API access | No |
| `trigger_phrase` | Custom trigger phrase (default: `@claude`) | No |
| `use_bedrock` | Use AWS Bedrock instead of Claude API | No |
| `use_vertex` | Use Google Vertex AI instead of Claude API | No |

### Common CLI Arguments via `claude_args`

```yaml
claude_args: "--max-turns 5 --model claude-sonnet-4-6 --mcp-config /path/to/config.json"
```

- `--max-turns`: maximum conversation turns (default: 10)
- `--model`: model to use (e.g., `claude-sonnet-4-6`, `claude-opus-4-6`)
- `--mcp-config`: path to MCP configuration
- `--allowed-tools`: comma-separated list of allowed tools
- `--append-system-prompt`: add custom instructions

## Usage Examples

### Basic Workflow (Respond to @claude Mentions)

```yaml
name: Claude Code
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
jobs:
  claude:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Automated Code Review on PR Open

```yaml
name: Code Review
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "/review"
          claude_args: "--max-turns 5"
```

### Scheduled Daily Report

```yaml
name: Daily Report
on:
  schedule:
    - cron: "0 9 * * *"
jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "Generate a summary of yesterday's commits and open issues"
          claude_args: "--model opus"
```

### Using @claude in Issues and PRs

```text
@claude implement this feature based on the issue description
@claude how should I implement user authentication for this endpoint?
@claude fix the TypeError in the user dashboard component
```

### AWS Bedrock Configuration

```yaml
name: Claude PR Action
permissions:
  contents: write
  pull-requests: write
  issues: write
  id-token: write
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
jobs:
  claude-pr:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'issues' && contains(github.event.issue.body, '@claude'))
    runs-on: ubuntu-latest
    env:
      AWS_REGION: us-west-2
    steps:
      - uses: actions/checkout@v4
      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}
      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-west-2
      - uses: anthropics/claude-code-action@v1
        with:
          github_token: ${{ steps.app-token.outputs.token }}
          use_bedrock: "true"
          claude_args: '--model us.anthropic.claude-sonnet-4-6 --max-turns 10'
```

### Google Vertex AI Configuration

```yaml
steps:
  - uses: actions/checkout@v4
  - name: Generate GitHub App token
    id: app-token
    uses: actions/create-github-app-token@v2
    with:
      app-id: ${{ secrets.APP_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}
  - name: Authenticate to Google Cloud
    id: auth
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
  - uses: anthropics/claude-code-action@v1
    with:
      github_token: ${{ steps.app-token.outputs.token }}
      use_vertex: "true"
      claude_args: '--model claude-sonnet-4@20250514 --max-turns 10'
    env:
      ANTHROPIC_VERTEX_PROJECT_ID: ${{ steps.auth.outputs.project_id }}
      CLOUD_ML_REGION: us-east5
```

## Important Details

### Migration from Beta to v1

The GA version (v1) introduces breaking changes from the beta:
- **Update action version**: change `@beta` to `@v1`
- **Remove mode configuration**: `mode: "tag"` / `mode: "agent"` is now auto-detected
- **Update prompt inputs**: replace `direct_prompt` with `prompt`
- **Move CLI options**: convert `max_turns`, `model`, `custom_instructions` to `claude_args`
- **Settings format change**: `claude_env` replaced with `settings` JSON format

### Authentication Methods

1. **Direct Anthropic API**: use `ANTHROPIC_API_KEY` secret
2. **AWS Bedrock**: configure OIDC with GitHub, set `use_bedrock: "true"`, use `AWS_ROLE_TO_ASSUME` secret
3. **Google Vertex AI**: configure Workload Identity Federation, set `use_vertex: "true"`, use `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT` secrets
4. **Custom GitHub App**: for branded usernames or custom auth flows, create your own GitHub App with Contents, Issues, and Pull requests permissions

### CLAUDE.md Configuration

Create a `CLAUDE.md` file at the repository root to define:
- Code style guidelines
- Review criteria
- Project-specific rules
- Preferred patterns

Claude follows these guidelines when creating PRs and responding to requests.

### Cost Considerations

- **GitHub Actions costs**: runs on GitHub-hosted runners, consuming Actions minutes
- **API costs**: each interaction consumes API tokens based on prompt and response length
- **Optimization tips**: use specific `@claude` commands, configure `--max-turns`, set workflow timeouts, use GitHub concurrency controls

### Security

- Never commit API keys directly to the repository
- Always use GitHub Secrets for API keys
- Limit action permissions to only what's necessary
- Review Claude's suggestions before merging

### Auto-Detection

The v1 action automatically detects whether to run in interactive mode (responds to `@claude` mentions) or automation mode (runs immediately with a prompt) based on the configuration.

## References

- [Claude Code GitHub Actions](https://code.claude.com/docs/en/github-actions) -- Official documentation for setting up and configuring Claude Code GitHub Actions
- [claude-code-action Repository](https://github.com/anthropics/claude-code-action) -- Source code, examples, and issue tracker for the GitHub Action
- [Example Workflows](https://github.com/anthropics/claude-code-action/tree/main/examples) -- Ready-to-use workflow files for different scenarios
- [Security Documentation](https://github.com/anthropics/claude-code-action/blob/main/docs/security.md) -- Detailed security guidance for permissions, authentication, and best practices
