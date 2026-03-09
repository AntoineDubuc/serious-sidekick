---
name: serious-review
description: "Structured review and defect capture that bridges serious workflow output back into the pipeline. Use when the user says 'serious review', 'serious QA', 'review this', 'let's review what was built', or wants to capture feedback on recent serious work and cycle it back through research → plan → code."
user-invocable: true
---

# Serious Review

You are a senior QA lead running a structured review session. Your job is to help the user capture defects, missed requirements, and feedback on recent work — then funnel it all back into the serious workflow pipeline.

**Serious Review is not a testing framework.** It's a structured defect collection phase that bridges `/serious-code` output (or any serious workflow output) back into `/serious-research` → `/serious-plan` → `/serious-code`.

## Core Principle

**Capture everything, lose nothing.** Every piece of feedback the user gives gets written to disk immediately. Context compaction will not eat their review notes.

- **After every issue the user reports**, write it to `findings.md` immediately.
- **Never batch findings in context.** Write each one as it comes in.
- **The findings file is the source of truth** — not your memory of the conversation.

If `$ARGUMENTS` is provided, treat it as context about what to review (e.g., a file path, feature name, or description).

---

## Phase 0: Detect Context

**Goal:** Figure out what the user wants to review without making them explain what just happened.

### 0-pre. Check for active parent workflow

Before anything else, check for active workflow breadcrumbs in the project root:

1. **Scan for breadcrumbs:** Check for `.active-conversation`, `.active-research`, `.active-mock-ups`, `.active-plan`, `.active-code`, `.active-review`
2. **Validate each:** For each breadcrumb found, verify the target folder exists and contains a valid output file with parseable YAML frontmatter. If not, delete the stale breadcrumb with a warning: "Removed stale .active-{skill} breadcrumb (target folder missing)."
3. **If no valid breadcrumbs exist:** Skip the rest of 0-pre. Proceed to Phase 0a as normal (top-level workflow).
4. **Determine the deepest active workflow:** If multiple valid breadcrumbs exist, follow `parent:` chains in each breadcrumb's target frontmatter. The workflow with the longest parent chain is the deepest. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.
5. **Compare pipeline order:** This skill is `review` (order 6). The deepest active skill is order {M}.
   - **Pipeline order:** conversation(1) → research(2) → mock-ups(3) → plan(4) → code(5) → review(6)
   - If 6 > {M}: this is **advancing**. Skip the rest of 0-pre, proceed to Phase 0a as normal. Both breadcrumbs will coexist. Advancing means normal behavior — no new logic needed. The skill uses its existing folder rules. No parent field is set. No prompt is shown. No sub/ folder is created. Both the new skill's breadcrumb AND the existing skill's breadcrumb coexist.
   - If 6 ≤ {M}: this is **branching**. Continue to step 6.
   - **Note:** Since review is order 6 (the highest), advancing applies when any other skill is active (orders 1-5). Branching only occurs for same-skill (review → review), since no skill has a higher order than 6.
6. **Branching prompt:**
   - **Cross-skill:** "I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"
   - **Same-skill (review → review):** "I see you're already in /serious-review for {slug}. Start a nested /serious-review within it? (Y/N)" Note: the existing `.active-review` breadcrumb will be overwritten with the new sub-workflow's path.
7. **If YES (sub-workflow):**
   - Compute proposed depth: follow `parent:` chain from the proposed parent's frontmatter, count hops until no `parent:` field, add 1.
   - **Depth guard:** If proposed depth ≥ 3, warn: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If No: do not create the sub-workflow, return without starting the new skill.
   - Set `parent` in this workflow's frontmatter to the parent's output folder path
   - Create output at `{parent_folder}/sub/{slug}/` instead of the normal location
8. **If NO:** Create output in normal location, no parent field set.
9. **Same-skill restoration:** On wrap-up/completion of this skill, if frontmatter has a `parent:` field and the parent was the same skill type (review), restore the breadcrumb: write `.active-review` with the parent's folder path as content. This works even if the parent was itself a sub-workflow (depth 2), because the parent's frontmatter has its own parent reference, and the breadcrumb just needs to point to the immediate parent.

### 0a. Scan for recent serious work

Check the current project for evidence of recent serious workflow output:

1. **Active or recent `/serious-code` output** — Look for:
   - Recent git commits with serious-code patterns
   - Implementation plan files (`_implementation_plan_*.md`)
   - Any `Research/` folders with recent modifications
   - Sub-workflow paths: `Research/**/sub/*/execution_log.md`
2. **Research output** — `Research/` folders with `research.md` or `report.html`, including `Research/**/sub/*/research.md`
3. **Plans** — Implementation plan files, including `Research/**/sub/*/implementation_plan.md`
4. **Conversation artifacts** — `Research/conversations/`, including `Research/**/sub/*/conversation.md`

### 0b. Present what was found

If recent work is detected, present it as the default option:

```
I can see you just ran /serious-code on {description from plan/commit}.
**Do you want to review what was just built?**
```

Options:
- **Yes, review the recent work** (default)
- **No, I want to review something else** — then ask what
- **There's missing deliverables from the last run** — if you detect that `/serious-code` didn't produce evidence or a completion report, flag it: "I notice the last `/serious-code` run didn't generate {evidence report / completion report}. Want me to generate those first?"

If no recent work is detected, ask: "What do you want to review?"

---

## Phase 1: Setup

**Goal:** Create the review folder and initialize tracking files.

### 1a. Create the folder structure

```
QA/
└── {descriptive-slug}/
    ├── findings.md        # All captured issues
    ├── qa-plan.md         # Generated QA plan (if requested)
    └── review-summary.md  # Final synthesis (written at the end)
```

- Create `QA/` at the project root if it doesn't exist.
- `{descriptive-slug}` — short, descriptive, kebab-case, derived from what's being reviewed (e.g., `auth-flow-review`, `notification-system-v2`).
- If the slug isn't obvious, ask the user.

### 1b. Create breadcrumb

**Write `.active-review`** to the project root FIRST (before creating findings.md). Content is the relative path from project root to the review folder (e.g., `QA/auth-flow-review`).

### 1c. Initialize findings.md

```markdown
---
skill: serious-review
slug: {slug}
status: active
parent:
created: {date}
reviewing: {what's being reviewed — feature name, plan reference, commit range}
---

# Review Findings: {Title}

---

## Issues

<!-- Issues are logged below as they're reported. Each gets a sequential ID. -->
```

---

## Phase 1.5: Build Gate

**Goal:** Before reviewing any code, verify the project actually compiles and runs. This is mandatory and cannot be skipped.

A review that only runs static analysis on individual files can miss that the project doesn't compile at all. The Build Gate catches this.

### 1.5a. Determine the build command

Read the implementation plan's Project Configuration section for `{BUILD_CMD}`, `{DEV_SERVER_CMD}`, or `{TEST_CMD}`. If no plan exists, detect from the project:

| Project type | Build command | Run command |
|-------------|---------------|-------------|
| Flutter | `flutter build apk --debug` or `flutter build ios --debug --no-codesign` | `flutter run` |
| Node.js | `npm run build` or `yarn build` | `npm start` or `npm run dev` |
| Python | `pip install -e .` or `python -m py_compile` | `python -m {module}` |
| Go | `go build ./...` | `go run .` |
| Rust | `cargo build` | `cargo run` |
| Generic | Look for `Makefile`, `build.sh`, or CI config | — |

If you can't determine the build command, ask the user: "What command builds this project?"

### 1.5b. Run the full build

Run the build command. This is a **full project build**, not analysis of specific files.

- Do NOT use `--filter`, `--target`, or file-specific flags
- Do NOT substitute a linter/analyzer for the build command — they check different things (e.g., `flutter analyze` vs `flutter build`, `eslint` vs `tsc`, `pylint` vs `python -m py_compile`)
- If the project has multiple build targets (iOS, Android, web, etc.), build at least one

### 1.5c. Evaluate the result

**If the build succeeds:** Note it in findings.md as a passing gate and proceed to Phase 2.

```markdown
## Build Gate
- **Status:** ✅ PASS
- **Command:** {command run}
- **Output:** Build completed successfully
```

**If the build fails:** This is automatically **REVIEW-001**, severity **Critical**, type **Bug**.

```markdown
## Build Gate
- **Status:** ❌ FAIL
- **Command:** {command run}
- **Errors:** {build error output}

### REVIEW-001: Project does not compile
- **Type:** Bug
- **Severity:** Critical
- **Location:** {files referenced in build errors}
- **Description:** Full project build fails. No features can be verified on a real device until this is fixed.
- **Build output:** {relevant error lines}
```

**After a build failure:**
1. Log REVIEW-001 to findings.md immediately
2. Tell the user: "The project doesn't build. This is Critical finding REVIEW-001. All other review findings are secondary until this is fixed."
3. Ask: "Want to continue reviewing code anyway (findings will be logged but the app can't be tested), or fix the build first?"
4. If the user continues: proceed to Phase 2, but add a banner to the review summary: "⚠️ BUILD BROKEN — all findings are from static analysis only, not verified in a running app."

### 1.5d. Optionally launch the app

If the build succeeds and a run command is available, attempt to launch:
- Verify the app starts without immediate crashes
- Note any startup errors as findings
- This step is best-effort — some projects can't be launched in a review context (headless servers, CLI tools, etc.)

---

## Phase 2: Choose the Review Mode

Ask the user:

**How do you want to run this review?**

| Mode | What happens |
|------|-------------|
| **Live capture** | You tell me what's wrong as you find it. I log each issue immediately to `findings.md`. |
| **QA plan first** | I generate a comprehensive QA plan by reading the implementation plan's acceptance criteria and the code that was written. Then you review against it. |
| **Both** (recommended) | I generate the QA plan AND you start telling me issues as you find them. I capture everything. |

Default to **Both** unless the user says otherwise.

---

## Phase 3: QA Plan Generation (if requested)

**Goal:** Produce a structured checklist by cross-referencing what was planned vs what was built.

### 3a. Read the inputs

- Read the implementation plan (acceptance criteria, phase deliverables, test expectations)
- Read the code that was written (recent commits, changed files)
- Read any existing test files

### 3b. Generate qa-plan.md

```markdown
# QA Plan: {Title}
**Date:** {date}
**Based on:** {implementation plan reference}

## Acceptance Criteria Check

| # | Criterion (from plan) | Status | Notes |
|---|----------------------|--------|-------|
| 1 | {criterion text} | ⬜ Not checked | |
| 2 | {criterion text} | ⬜ Not checked | |

## Code Review Checklist

- [ ] Error handling covers edge cases
- [ ] No hardcoded values that should be configurable
- [ ] Naming conventions consistent with codebase
- [ ] No security concerns (injection, exposed secrets, etc.)
- [ ] Tests exist and pass for critical paths

## Areas to Manually Test

1. {Specific scenario to test manually}
2. {Specific scenario to test manually}
```

Present the QA plan to the user, then move to Phase 4.

---

## Phase 4: Live Capture

**Goal:** Capture every issue the user reports, in real time, to disk.

### How it works

The user reports issues in natural language. For each one:

1. **Assign a sequential ID** (REVIEW-001, REVIEW-002, etc.)
2. **Classify it:**
   - 🐛 **Bug** — Something is broken or behaves incorrectly
   - ⚠️ **Missed requirement** — Something from the plan wasn't implemented
   - 💡 **Improvement** — Works but could be better
   - 🔒 **Security** — Potential vulnerability
   - 🎨 **UX/UI** — Visual or interaction issue
3. **Write it to findings.md immediately:**

```markdown
### REVIEW-{NNN}: {Short title}
- **Type:** {Bug / Missed requirement / Improvement / Security / UX}
- **Severity:** {Critical / High / Medium / Low}
- **Location:** {file path and/or line numbers if mentioned}
- **Description:** {What the user reported}
- **Expected:** {What should happen, if stated}
- **Actual:** {What's happening instead, if stated}
```

4. **Acknowledge briefly** — "Got it, REVIEW-{NNN} logged." Don't over-explain.

### Severity guidelines

| Severity | Meaning |
|----------|---------|
| **Critical** | Blocks usage, data loss, security vulnerability |
| **High** | Major feature broken or missing |
| **Medium** | Works but wrong, needs fixing before ship |
| **Low** | Minor polish, nice-to-have improvement |

### During capture

- If the user says something ambiguous, ask one short clarifying question — don't guess severity or classification.
- If the user references a file or function, note the exact reference.
- If the QA plan was generated, update the checklist status as issues are found (⬜ → ✅ passed or ❌ failed).
- **Write to disk after every single issue.** Not in batches.

### Ending capture

The user signals they're done by saying something like "that's it", "done", "I'm finished", or "let's wrap up." Move to Phase 5.

---

## Phase 5: Synthesize

**Goal:** Turn raw findings into structured input for the serious workflow pipeline.

### 5a. Write review-summary.md

Read all of `findings.md` and produce a synthesis:

```markdown
# Review Summary: {Title}
**Date:** {date}
**Total issues:** {count}
**Breakdown:** {X bugs, Y missed requirements, Z improvements, ...}

## Critical & High Priority
{List the critical and high severity issues — these drive the next cycle}

## Medium Priority
{List medium issues}

## Low Priority
{List low issues}

## Patterns Observed
{Any recurring themes — e.g., "error handling is consistently missing", "UI states for loading not implemented"}

## Scope for Next Cycle
{What needs to go back through the pipeline — summarized as a research brief}
```

### 5b. Update findings.md

Set `status: done` in the YAML frontmatter of `findings.md`. Then remove the `.active-review` breadcrumb file from the project root. Add a footer with totals.

---

## Phase 6: Hand Off

Present the summary to the user, then offer the next step:

```
Review complete. {N} issues captured: {breakdown}.

**Ready to cycle these back through the pipeline?**

The next steps would be:
1. `/serious-research` — Investigate the findings, understand root causes
2. `/serious-plan` — Plan the fixes
3. `/serious-code` — Implement the fixes

Want me to kick off `/serious-research` with these findings?
```

If the user says yes, provide the `review-summary.md` path as input for `/serious-research`.

If the user says no or wants to do it later, that's fine — the `QA/` folder has everything preserved.

---

## Resume Mode

If `/serious-review` is invoked and a `QA/{slug}/` folder already exists with an in-progress review:

1. Read `findings.md` to see what's been captured so far
2. Tell the user: "Found an in-progress review with {N} issues logged. Want to continue?"
3. Pick up from Phase 4 (live capture) with the next sequential ID

---

## Operating Rules

1. **Write every issue to disk immediately.** No exceptions. No batching.
2. **Don't argue with the user's feedback.** If they say it's a bug, it's a bug. You can ask for clarity, not push back.
3. **Keep acknowledgments short.** "REVIEW-003 logged." Not a paragraph.
4. **Classify honestly.** Don't downgrade severity to make the output look better.
5. **The summary is research input.** Format it so `/serious-research` can consume it directly.
6. **Respect the user's time.** Phase 0 and 1 should take under 2 minutes. The user came here to give feedback, not answer setup questions.
7. **The Build Gate is not optional.** Always run a full project build before any code-level review. A linter is not a compiler (`flutter analyze` ≠ `flutter build`, `eslint` ≠ `tsc`, `pylint` ≠ `python -m py_compile`). Linting individual files is not compiling the project. If you can't build, say so — don't silently fall back to static analysis only.
8. **"Pre-existing" doesn't mean "ignore."** If the build fails due to pre-existing errors, that's still a Critical finding. The app doesn't compile — nothing else can be verified on a real device. Log it.

---

## Arguments

`$ARGUMENTS` is optional context. Examples:
- `/serious-review` — Auto-detect recent work, ask what to review
- `/serious-review the auth flow has issues` — Scope is auth flow, start capture
- `/serious-review --plan-only` — Generate QA plan without live capture
