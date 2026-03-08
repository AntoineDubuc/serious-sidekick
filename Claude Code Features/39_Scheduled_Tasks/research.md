# Scheduled Tasks

## Overview

Scheduled tasks let Claude re-run a prompt automatically on an interval. Use them to poll a deployment, babysit a PR, check back on a long-running build, or remind yourself to do something later in the session. Tasks are session-scoped — they live in the current Claude Code process and are gone when you exit.

## Key Capabilities

- **`/loop` command** — quickest way to schedule a recurring prompt with an optional interval
- **One-time reminders** — natural language scheduling for single-fire tasks
- **Cron-based scheduling** — standard 5-field cron expressions under the hood
- **Session-scoped** — no persistence across restarts, no background daemon
- **Local timezone** — all times interpreted in your local timezone, not UTC
- **Up to 50 concurrent tasks** — per session limit
- **Low-priority execution** — fires between your turns, never interrupts mid-response
- **3-day auto-expiry** — recurring tasks automatically expire after 3 days

## The /loop Command

### Basic Usage

```
/loop 5m check if the deployment finished and tell me what happened
```

Claude parses the interval, converts it to a cron expression, schedules the job, and confirms the cadence and job ID.

### Interval Syntax

Intervals are optional. You can lead with them, trail with them, or leave them out entirely.

| Form | Example | Parsed interval |
|------|---------|----------------|
| Leading token | `/loop 30m check the build` | every 30 minutes |
| Trailing `every` clause | `/loop check the build every 2 hours` | every 2 hours |
| No interval | `/loop check the build` | defaults to every 10 minutes |

Supported units: `s` (seconds), `m` (minutes), `h` (hours), `d` (days). Seconds are rounded up to the nearest minute (cron has one-minute granularity). Non-clean intervals like `7m` or `90m` are rounded to the nearest clean interval.

### Loop Over Another Command

The scheduled prompt can itself be a command or skill invocation:

```
/loop 20m /review-pr 1234
```

Each time the job fires, Claude runs `/review-pr 1234` as if you had typed it.

## One-Time Reminders

For one-shot reminders, describe what you want in natural language:

```
remind me at 3pm to push the release branch
```

```
in 45 minutes, check whether the integration tests passed
```

Claude pins the fire time to a specific minute and hour using a cron expression, confirms when it will fire, and the task deletes itself after running.

## Managing Scheduled Tasks

Ask Claude in natural language:

```
what scheduled tasks do I have?
```

```
cancel the deploy check job
```

### Underlying Tools

| Tool | Purpose |
|------|---------|
| `CronCreate` | Schedule a new task. Accepts a 5-field cron expression, the prompt to run, and whether it recurs or fires once. |
| `CronList` | List all scheduled tasks with their IDs, schedules, and prompts. |
| `CronDelete` | Cancel a task by ID. |

Each task gets an 8-character ID for reference and cancellation.

## How Scheduled Tasks Run

- The scheduler checks every second for due tasks and enqueues them at low priority
- A scheduled prompt fires between your turns, not while Claude is mid-response
- If Claude is busy when a task comes due, the prompt waits until the current turn ends
- All times are in your local timezone

### Jitter

To avoid every session hitting the API at the same moment:

- **Recurring tasks:** fire up to 10% of their period late, capped at 15 minutes. An hourly job might fire anywhere from `:00` to `:06`.
- **One-shot tasks:** scheduled for the top or bottom of the hour fire up to 90 seconds early.

The offset is derived from the task ID (deterministic — same task always gets the same offset). To avoid jitter, pick a minute that is not `:00` or `:30`.

### Three-Day Expiry

Recurring tasks automatically expire 3 days after creation. The task fires one final time, then deletes itself. To extend, cancel and recreate before expiry. For durable scheduling, use Desktop scheduled tasks or GitHub Actions.

## Cron Expression Reference

Standard 5-field format: `minute hour day-of-month month day-of-week`

All fields support: wildcards (`*`), single values (`5`), steps (`*/15`), ranges (`1-5`), and comma-separated lists (`1,15,30`).

| Expression | Meaning |
|-----------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Every hour on the hour |
| `7 * * * *` | Every hour at 7 minutes past |
| `0 9 * * *` | Every day at 9am local |
| `0 9 * * 1-5` | Weekdays at 9am local |
| `30 14 15 3 *` | March 15 at 2:30pm local |

Day-of-week: `0` or `7` for Sunday through `6` for Saturday. Extended syntax (`L`, `W`, `?`, name aliases like `MON` or `JAN`) is NOT supported.

When both day-of-month and day-of-week are constrained, a date matches if either field matches (standard vixie-cron semantics).

## Disabling Scheduled Tasks

Set `CLAUDE_CODE_DISABLE_CRON=1` in your environment to disable the scheduler entirely. The cron tools and `/loop` become unavailable, and any already-scheduled tasks stop firing.

## Important Details

### Limitations

- Tasks only fire while Claude Code is running and idle. Closing the terminal cancels everything.
- No catch-up for missed fires. If a task's time passes while Claude is busy, it fires once when Claude becomes idle.
- No persistence across restarts. Restarting Claude Code clears all tasks.
- Session limit of 50 concurrent tasks.
- Minimum granularity is 1 minute (seconds rounded up).

### For Durable Scheduling

- **Desktop scheduled tasks** — graphical setup, survives restarts
- **GitHub Actions** — `schedule` trigger for unattended automation

## Common Patterns

### Monitor a Deployment

```
/loop 5m check the deployment status at https://api.example.com/health and let me know when it's healthy
```

### Watch PR Checks

```
/loop 10m check if PR #42 CI checks have passed yet
```

### Build Babysitting

```
in 30 minutes, check whether the integration tests passed
```

### Periodic Code Review

```
/loop 20m /review-pr 1234
```

### End-of-Day Reminder

```
remind me at 5pm to commit and push my changes
```

## References

- [Run prompts on a schedule — Claude Code Docs](https://code.claude.com/docs/en/scheduled-tasks) — Official documentation with full cron reference and examples
- [Desktop scheduled tasks](https://code.claude.com/docs/en/desktop#schedule-recurring-tasks) — Durable scheduling via Desktop app
- [GitHub Actions](https://code.claude.com/docs/en/github-actions) — Unattended cron-driven automation
