---
name: scheduled-tasks
description: "Auto-load when user asks about scheduled tasks, /loop command, cron scheduling, recurring prompts, reminders, polling, or timed automation in Claude Code"
---

# Scheduled Tasks — Quick Reference

## /loop Command

```
/loop 5m check if the deployment finished
/loop check the build every 2 hours
/loop 20m /review-pr 1234
```

- Default interval: 10 minutes (if omitted)
- Units: `s` (seconds, rounded to minutes), `m` (minutes), `h` (hours), `d` (days)
- Can loop over other commands/skills

## One-Time Reminders

```
remind me at 3pm to push the release branch
in 45 minutes, check whether the integration tests passed
```

Single-fire task, deletes itself after running.

## Managing Tasks

```
what scheduled tasks do I have?
cancel the deploy check job
```

### Tools

| Tool | Purpose |
|------|---------|
| `CronCreate` | Schedule task (cron expression + prompt + recur flag) |
| `CronList` | List all tasks with IDs, schedules, prompts |
| `CronDelete` | Cancel task by 8-char ID |

## Key Rules

- **Session-scoped** — gone when you exit Claude Code
- **Local timezone** — not UTC
- **Max 50 tasks** per session
- **3-day auto-expiry** on recurring tasks
- **Low priority** — fires between turns, never interrupts mid-response
- **No catch-up** — missed fires don't accumulate
- **1-minute granularity** — seconds rounded up

## Cron Syntax

5-field: `minute hour day-of-month month day-of-week`

| Expression | Meaning |
|-----------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Hourly on the hour |
| `0 9 * * *` | Daily at 9am |
| `0 9 * * 1-5` | Weekdays at 9am |

Supports: `*`, single values, `*/N` steps, ranges (`1-5`), lists (`1,15,30`).
Does NOT support: `L`, `W`, `?`, name aliases (`MON`, `JAN`).

## Jitter

- Recurring: up to 10% of period late (max 15 min)
- One-shot at `:00`/`:30`: up to 90 seconds early
- Deterministic per task ID

## Disable

`CLAUDE_CODE_DISABLE_CRON=1` in environment.

## For Durable Scheduling

Session tasks don't survive restarts. Use instead:
- **Desktop app** — scheduled tasks UI, survives restarts
- **GitHub Actions** — `schedule` trigger for unattended automation
