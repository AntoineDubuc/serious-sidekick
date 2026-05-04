---
name: serious-debug
description: "Systematic debugging with 3 modes (auto-fix, quick, deep), reproducer-driven feedback, and compounding debug corpus. Use when the user says 'serious debug', 'debug this', 'fix this bug', 'why is this failing', or when /serious-code detects a regression loop."
user-invocable: true
---

# Serious Debug

Systematic debugging skill with reproducer-driven feedback, auto-escalation, and compounding project memory. Three modes — auto-fix (12s, zero interaction), quick (30s overhead, reproducer feedback loop), deep (full investigation with blocking ratchet) — selected automatically by a 3-second triage algorithm.

**Position in the workflow:**
```
/serious-conversation → /serious-research → /serious-scope → /serious-plan → /serious-review → /serious-code ↔ /serious-debug → done
```

**When to use:**
- A test is failing and you need to find and fix the root cause
- `/serious-code` detected a regression loop (2 consecutive red cycles on a previously-green test)
- A production bug needs structured investigation, not trial-and-error
- You want the fix to come with a regression test, blast radius scan, and PR-ready report

**When NOT to use:**
- The "bug" is a missing feature — use `/serious-plan` instead
- You already know the exact fix — just make the edit directly

---

## Phase 0: Intake

### 0-pre. Check for active parent workflow

Before anything else, check for active workflow breadcrumbs in the project root:

1. **Scan for breadcrumbs:** Check for `.active-conversation`, `.active-research`, `.active-mock-ups`, `.active-scope`, `.active-plan`, `.active-code`, `.active-review`, `.active-debug`
2. **Validate each:** For each breadcrumb found, verify the target folder exists and contains a valid output file with parseable YAML frontmatter. If not, delete the stale breadcrumb with a warning: "Removed stale .active-{skill} breadcrumb (target folder missing)."
2b. **Status-based staleness check:** For each validated breadcrumb, read the first 10 lines of the target file and grep for `^status:` to extract the value. If the value is `done` or `abandoned`, the breadcrumb is stale (skill completed but cleanup was interrupted). Remove the `.active-*` file silently — do not prompt the user.
2c. **Age-based staleness check:** If the breadcrumb's target file has `status: active`, check the `.active-*` file's modification time using Bash (`stat -f %m` on macOS or `stat -c %Y` on Linux, or `ls -l` as a portable fallback). If the file is older than 4 hours, warn: "Found .active-{skill} for {slug}, but it hasn't been modified in {N} hours. This may be from an interrupted session. Treat as active? (Y/N)". If the user says No, remove the breadcrumb and proceed. If Yes, treat as a valid active breadcrumb and continue to step 4.
3. **If no valid breadcrumbs exist:** Proceed directly to Phase 0a without any output. Do NOT mention breadcrumbs, scanning, or the absence of active workflows. This is the normal state — the previous skill completed and cleaned up its breadcrumb.
4. **Determine the deepest active workflow:** If multiple valid breadcrumbs exist, follow `parent:` chains in each breadcrumb's target frontmatter. The workflow with the longest parent chain is the deepest. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.
5. **Compare pipeline order:** This skill is `debug` (order 8). The deepest active skill is order {M}.
   - **Pipeline order:** youtube-tldr(0.5) → conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7) → debug(8)
   - If 8 > {M}: this is **advancing**. Proceed directly to the next phase without any output about breadcrumbs or pipeline ordering. Both breadcrumbs coexist. No parent field set, no sub/ folder created.
   - If 8 ≤ {M}: this is **branching**. Continue to step 6.
   - **Special case — invoked from /serious-code (order 7):** This is always advancing. Both `.active-code` and `.active-debug` coexist. Plan state is frozen. Debug output goes to `Research/debug/{slug}/`. On debug completion, `.active-debug` is removed and `/serious-code` resumes.
6. **Branching prompt:**
   - **Cross-skill:** "I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"
   - **Same-skill (debug → debug):** "I see you're already in /serious-debug for {slug}. Start a nested debug within it? (Y/N)" The existing `.active-debug` breadcrumb will be overwritten with the new sub-workflow's path.
7. **If YES (sub-workflow):**
   - Compute proposed depth: follow `parent:` chain, count hops, add 1.
   - **Depth guard:** If proposed depth >= 3, warn: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If No: abort.
   - Set `parent` in this workflow's frontmatter to the parent's output folder path.
   - Create output at `{parent_folder}/sub/debug-{slug}/` instead of the normal location.
8. **If NO:** Create output in normal location, no parent field set.
9. **Same-skill restoration:** On completion, if frontmatter has a `parent:` field and the parent was also debug, restore the breadcrumb by **re-running the writer block** with the parent's folder path as `${RELATIVE_OUTPUT_PATH}` and `${SKILL}=debug`. The writer block writes to `.claude-active/$(claude_pid)-debug`, NOT the legacy `.active-debug` at the project root.

### 0a. Auto-detect bug input

Parse `$ARGUMENTS` and conversation context to identify the bug:

- **Error message or stack trace** — extract from arguments, pasted text, or terminal output
- **Failing test name** — if the user specifies a test, use it as the reproduction signal
- **Natural language description** — "payments fail for amounts over $999"
- **Debug candidate signal from /serious-code** — if `.serious-code-debug-candidate` exists, read it for test name, failure context, and attempt history

If no bug signal is found: "Describe the bug, paste the error, or point me at a failing test."

### 0b. Triage (3 seconds)

Five inputs, one output. No ambiguity.

**Inputs:**
1. **Error familiarity** — regex match against known bug class patterns (null propagation, missing import, type coercion, stale cache, config drift, off-by-one). Source: `templates/bug-classes.json`
2. **File count** — from stack trace + LSP references. Single (1), local (2-4), systemic (5+)
3. **Reproduction signal** — can we reproduce automatically? Exact (test exists), inferred (error + stack trace), none
4. **Corpus recurrence** — query `debug_corpus.jsonl` for symptom similarity. None, low (1-2 prior hits), high (3+)
5. **Bug class fingerprint** — if familiarity matched, the class carries an investigation template

**Classification logic:**
```
if familiarity != unknown AND locality == single AND fix_template.deterministic:
    mode = AUTO_FIX
elif recurrence == high:
    mode = DEEP          # keeps breaking = structural problem
elif familiarity != unknown OR locality != systemic:
    mode = QUICK
else:
    mode = DEEP
```

**Auto-fix gate:** Three conditions AND'd — known pattern + single file + deterministic fix template. If ANY condition fails, drop to QUICK. On verification failure, fall back to QUICK immediately.

**Recurrence override:** `high` forces DEEP regardless of other signals. A file that keeps breaking needs structural investigation, not another quick patch.

**Output:** Write `state.json` to the debug output folder:
```json
{
  "slug": "debug-currency-nan",
  "mode": "QUICK",
  "bug_class": "null_propagation",
  "locality": "single",
  "recurrence": "low",
  "reproducer_cmd": "npm test -- --grep 'formatCurrency'",
  "corpus_hits": [],
  "investigation_template": "null_propagation",
  "phase": "investigate",
  "fix_attempts": 0
}
```

**Triage presentation** (never more than 6 lines):
```
── triage ──────────────────────────────────
mode:       AUTO-FIX | QUICK | DEEP
class:      null propagation | race condition | unknown
scope:      src/payments/formatter.ts (+2 callers)
corpus:     "Similar bug fixed in debug-currency-overflow (Mar 15). Root cause: missing input validation."
confidence: HIGH | MEDIUM | LOW
────────────────────────────────────────────
```
If corpus has no match, omit the corpus line. Never show an empty field.

### 0c. Write breadcrumb and state

1. **Write `.claude-active/{claude_pid}-debug`** at the project root. Use a SUBSHELL so `umask` does not leak to the rest of the skill, and CORRECT directory permissions if `.claude-active/` pre-exists with wider perms. Content: relative path from project root to the debug output folder.

   ```bash
   (
     umask 077
     source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh"
     cad="${CLAUDE_PROJECT_DIR}/.claude-active"
     if [ -L "$cad" ]; then
       echo "FATAL: $cad is a symlink — refusing to write breadcrumbs" >&2
       exit 1
     elif [ -e "$cad" ]; then
       [ -d "$cad" ] || { echo "FATAL: $cad exists and is not a directory" >&2; exit 1; }
       chmod 700 "$cad" 2>/dev/null || { echo "FATAL: cannot enforce 0700 on $cad" >&2; exit 1; }
     else
       mkdir -p "$cad"
     fi
     bc=$(breadcrumb_path debug) || exit 1
     printf '%s\n' "${RELATIVE_OUTPUT_PATH}" > "$bc"
   )
   ```

   The outer `( ... )` subshell scopes `umask 077` so the caller's umask is unchanged after this block. The pre-existing-perm correction enforces `0700` on `.claude-active/` even if a previous-version skill or attacker created it with wider perms.

   On debug completion, remove the breadcrumb — BOTH the new-path and any legacy `.active-debug`:
   ```bash
   new_bc=$(bash -c 'source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh" && breadcrumb_path debug')
   rm -f "$new_bc" "${CLAUDE_PROJECT_DIR}/.active-debug"
   ```
2. **Create output folder:** `Research/debug/{slug}/` (or `{parent_folder}/sub/debug-{slug}/` if sub-workflow).
3. **Initialize `state.json`** with triage output (see 0b).
4. **Initialize `debug_report.md`** from `templates/debug-report.md` with frontmatter:

```yaml
---
skill: serious-debug
slug: {slug}
status: active
parent:        # Set if sub-workflow
source:        # Set if invoked from /serious-code (path to execution_log.md)
created: {date}
---
```

---

<!-- GUARDRAILS -->

## Guardrail Block

These are debugging-specific rationalizations the agent MUST NOT make. Each entry is a self-justification that sounds reasonable but leads to worse outcomes.

| # | Rationalization | Correct action | Why it fails |
|---|----------------|----------------|--------------|
| 1 | "I can see the bug from the code" | Write a reproduction test first. Verify the bug exists before assuming the cause. | Pattern-matching is not verifying. 30% of "obvious" bugs have a different root cause. |
| 2 | "The fix is small, no test needed" | Every fix gets a regression test regardless of size. No exceptions. | Small fixes in shared code cause the largest blast radius regressions. |
| 3 | "Let me just try this quick fix" | Investigate first. The first fix attempt frames the entire debug session. | If the first fix is wrong, you'll debug the debug. The attempt counter increments regardless. |
| 4 | "Tests pass, we're done" | Confirm the ROOT CAUSE is addressed, not just the symptom. | Tests passing proves the symptom is gone. It does not prove the cause is fixed. The same class of bug will recur. |
| 5 | "The error message changed, so progress was made" | Only the reproducer passing counts as progress. A different error is not a fix. | Symptom-chasing. The edit counter still increments. Two different errors is worse than one consistent error. |
| 6 | "This is probably a different bug" | If you found it during this investigation, it is in the blast radius. Log it or fix it. | Scope escape to avoid admitting the current fix is insufficient. |
| 7 | "The guardrail table doesn't apply here" | It applies unconditionally. If you are reasoning about why a row does not apply, that IS the rationalization firing. | Second-order rationalization. The meta-argument is the strongest signal that the guardrail is needed. |

<!-- END GUARDRAILS -->

---

## Phase 1: Investigate

### 1a. Reproduce

Lock the reproduction test or command as `reproducer_cmd` in `state.json`. The reproducer is the architectural spine — every subsequent edit is verified against it.

**Contract:** Non-zero exit = bug present. Zero exit = bug gone.

- If a failing test was provided, use it directly
- If an error message was provided, write a minimal reproduction test that triggers the exact error
- If reproduction fails after 2 attempts: prompt the developer for manual reproduction steps

**Activate the reproducer hook** (PostToolUse on Edit|Write). From this point forward, the reproducer runs after every source file edit automatically.

### 1b. Trace (expanded in deep mode)

Work backward from the symptom:
- Use LSP to trace call graphs from the crash site
- Check `git log` for recent changes to affected files
- In deep mode: run `git bisect` in the background to find the introducing commit

Build a blast radius map (ranked impact list, not a graph):
1. Direct callers (file:line from LSP)
2. Transitive dependencies (hop count)
3. Affected tests (pass/fail status)
4. API endpoints that touch the affected code

### 1c. Diagnose

Formalize the root cause as a **falsifiable hypothesis**: "The bug occurs because X, which means if we change Y, the reproducer will pass."

Write the hypothesis to `debug_report.md` under the Root Cause section.

**Blocking ratchet (deep mode only):** During investigation, the PreToolUse hook blocks Edit|Write on source files. Test files and debug scripts are allowed. The block lifts permanently when you write one sentence naming the root cause in the debug report. Quick mode has no blocking.

---

## Phase 2: Fix

### 2a. Test-first gate

Before any source file edit, a regression test MUST exist that:
- Fails before the fix (confirms the bug)
- Will pass after the fix (confirms the solution)

The PreToolUse hook enforces this in deep mode. In quick mode, the reproducer serves as the gate.

### 2b. Reproducer feedback loop

The agent works freely. After every source file edit, the PostToolUse hook runs the reproducer and reports pass/fail. The agent sees immediate feedback without manual test runs.

**Watch list:** If expressions were pinned (e.g., "watch formatCurrency(1000)"), they are evaluated alongside the reproducer. Value changes are highlighted in the status bar.

### 2c. Auto-escalation (2 failed attempts)

The PostToolUse hook tracks `fix_attempts` in `state.json`. After 2 failed fix attempts in quick mode:

1. Update `state.json`: `mode: "DEEP"`
2. Print escalation message framing what was LEARNED, not what failed:
```
[debug] 2 fix attempts narrowed the problem to state management in useCart().
[debug] Switching to structured investigation — this needs call-graph tracing.
[debug] mode: DEEP | blocking source edits until root cause is written
```
3. Activate the blocking ratchet
4. Re-enter Phase 1 with the information gathered so far

**NEVER say:** "Quick mode failed." "Unable to resolve." "Escalating due to errors." The developer should feel reinforcements arriving, not process punishing them.

---

## Phase 3: Harden (deep mode only)

### 3a. Defense-in-depth

Add guards at the symptom layer, not just the root cause layer. If the root cause was missing input validation, add validation at the entry point AND a defensive check at the crash site.

### 3b. Blast radius scan

Scan for the same pattern in related code:
- Search for the same anti-pattern in files identified during tracing
- Check other callers of the fixed function for the same assumption
- If blast radius > 8 files or 3+ API endpoints: flag for pipeline escalation (see Integration section)

### 3c. Full verification

Run the full affected test suite (not just the reproducer). Run the reproducer 3x to guard against flaky results. Update the debug report with final verification evidence.

---

## Auto-Fix Mode

For deterministic bug classes where the fix is unambiguous.

**Qualifying classes:** missing import (one candidate), typos within edit-distance 1, missing config keys, single-cast type mismatches.

**Flow:**
1. Triage identifies deterministic class + single file + known fix template
2. Apply the fix template
3. Run reproducer to verify
4. If PASS: write minimal report, append to corpus, clean up, done (12 seconds total)
5. If FAIL: **fall back to quick mode immediately** — the fix template was wrong

**Verification circuit breaker:** Auto-fix gets exactly ONE attempt. No retries, no "let me adjust." If the template fix doesn't work, it's not a deterministic bug. Fall back to quick.

---

## Quick Mode Flow

Target: 30 seconds of overhead, then the agent works freely with reproducer feedback.

| Step | Time | Action |
|------|------|--------|
| 1. Parse & triage | 3s | Write `state.json` with mode, class, reproducer |
| 2. Reproduce | 10s | Find or write failing test, lock as `reproducer_cmd` |
| 3. Activate hook | 2s | PostToolUse reproducer runs after every edit |
| 4. Fix | unbounded | Agent works freely, hook gives pass/fail feedback |
| 5. Verify | 10s | Run affected test suite (not just reproducer) |
| 6. Report | 5s | Write minimal debug entry, append to corpus, deactivate hook |

Auto-escalation to deep after 2 failed fix attempts.

---

## Deep Mode Flow

Full investigation with blocking ratchet and expanded substeps.

### Phase 1 — Investigate (blocking ratchet active)
- **1a. Reproduce:** Lock reproduction test/command. Activate reproducer hook.
- **1b. Trace:** Backward from symptom via LSP call graphs. Git bisect in background. Build blast radius map.
- **1c. Diagnose:** Formalize root cause as falsifiable hypothesis. Write to report.
- **1d. Ratchet release:** One sentence naming root cause in the debug report lifts the edit block permanently.

### Phase 2 — Fix
- **2a. Test-first gate:** Regression test must exist before any source edit.
- **2b. Fix with feedback:** Agent fixes, reproducer hook confirms after every edit.
- **2c. Parallel worktrees (3 specific cases only):**
  - Ambiguous root cause with isolated candidates (suspects don't share files)
  - Performance regressions with multiple suspects
  - Fix strategy comparison (tradeoff evaluation)
  - If suspects share files: force sequential. No exceptions.

### Phase 3 — Harden
- **3a. Defense-in-depth:** Guards at symptom layer AND root cause layer.
- **3b. Blast radius scan:** Same pattern in related code. Pipeline escalation if large.
- **3c. Full verification:** Affected test suite + 3x reproducer (flaky guard).

---

## Hook Registration

All 6 hooks are registered in `.claude/settings.json` by `/serious-init`.

| Hook script | Event | Matcher | Purpose |
|-------------|-------|---------|---------|
| `session-start.sh` | SessionStart | — | Triage, corpus query, resume detection, write status bar |
| `block-edit-during-investigate.sh` | PreToolUse | Edit\|Write | Block source file edits during investigation phase (deep mode only). Allow test/script files. |
| `reproducer-gate.sh` | PostToolUse | Edit\|Write | **THE SPINE.** Re-run reproducer + evaluate watch list after every file edit. Track fix attempts. Trigger auto-escalation after 2 failures. |
| `stop-require-report.sh` | Stop | — | Block session exit without verification evidence (all modes) and debug report (deep mode) |
| `stop-plan-escalation.sh` | Stop | — | Offer `/serious-scope` when blast radius > 8 files or 3+ endpoints |
| `stop-corpus-append.sh` | Stop | — | Append resolved session to `debug_corpus.jsonl` at project root |

**Reproducer hook resilience:**

| Failure mode | Mitigation |
|-------------|-----------|
| Flaky reproducer | 3x run on final verification |
| Slow reproducer (>5s) | Downgrade to checkpoint-only (not every edit) |
| Wrong reproducer | Falsification criteria required in diagnosis checkpoint |

---

## Debug Report

Use the template at `templates/debug-report.md`. Six sections, PR-ready:

1. **Bug** — symptom, reproduction steps, affected users/endpoints
2. **Root Cause** — falsifiable hypothesis, one sentence summary
3. **Blast Radius** — ranked impact list (direct callers, transitive, tests, endpoints)
4. **Evidence** — reproducer output, git bisect result, LSP traces
5. **Fix** — what changed, why this approach, alternatives considered
6. **Verification** — reproducer result, test suite result, regression check

**Completion summary** (printed to user):
```
── resolved ────────────────────────────────
root cause: formatCurrency() receives string from API, parses as NaN
fix:        added Number() guard with fallback to 0
hardened:   3 tests added, 2 callers verified
blast:      4 files in impact zone, 0 regressions
report:     Research/debug/debug-currency-nan/debug_report.md
────────────────────────────────────────────
```

For auto-fix, compress to one line:
```
[debug] AUTO-FIX: missing import './utils' → added (1 candidate, verified green) | 12s
```

---

## Debug Corpus

Append-only JSONL file at `debug_corpus.jsonl` in the project root. One entry per resolved debug session.

**Format:**
```jsonl
{"slug":"debug-currency-nan","date":"2026-03-26","symptom":"formatCurrency returns NaN for values over 999","root_cause":"string coercion from API response","bug_class":"type_coercion","files":["src/payments/formatter.ts"],"misleading_hypotheses":["locale formatting issue"],"fix_pattern":"input type guard","reproducer_cmd":"npm test -- --grep formatCurrency","resolution_time_s":45}
```

**Query protocol (SessionStart hook):**
1. Read `debug_corpus.jsonl`
2. Fuzzy-match current symptom against historical `symptom` fields
3. Surface matches with similarity > 0.7
4. Present as: "History suggests: similar bug fixed in {slug} ({date}). Root cause was {root_cause}."

**Policy:** The corpus informs triage. It NEVER overrides it. "History suggests" — never "history decided." A human or the triage algorithm makes the final call.

**Four capabilities that compound over time:**
- **Hotspot detection** — files with high recurrence rates get flagged
- **Reproducer reuse** — prior reproducers for the same file/function cut reproduce time from 10s to 2s
- **Fix pattern detection** — grep your own history for similar root causes
- **Flaky test identification** — tests with intermittent results across sessions get flagged

---

## Watch List

Pin expressions during debugging for evaluation after every edit.

**Invocation:** Natural language — "watch formatCurrency(1000)" or "watch cart.total"

**State file:** `.serious-debug-watches.json` — array of `{ "expr": "...", "last_value": "...", "status": "unchanged|changed" }`

**Evaluation:** The PostToolUse reproducer hook already runs after every file edit. After the reproducer command, it iterates the watch list, evaluates each expression, and updates the state file.

**Display:**
```
[debug] reproducer: FAIL | watches: formatCurrency(1000)=NaN, cart.total=undefined
[debug] reproducer: PASS | watches: formatCurrency(1000)=*$10.00* (was NaN)
```

Value changes are highlighted. Session-scoped — the Stop hook deletes `.serious-debug-watches.json` on exit.

---

## Status Bar

During active debug sessions, maintain a single-line status:

```
[debug] reproducer: FAIL | attempts: 0/2 | phase: investigate | mode: QUICK
```

Fields update in real-time:
- `reproducer:` FAIL (red) or PASS (green)
- `attempts:` current fix attempts / escalation threshold
- `phase:` investigate | fix | harden
- `mode:` AUTO-FIX | QUICK | DEEP
- `bisect:` percentage complete (deep mode only, when bisect is running)

When the reproducer flips to PASS, the entire status line turns green.

---

## Integration

### Auto-invocation from /serious-code

When `/serious-code`'s test-runner agent detects 2 consecutive red cycles on a previously-green test:
1. Write `.serious-code-debug-candidate` with test name, failure context, attempt history
2. Surface recommendation: "Recommend /serious-debug for test X — 2 consecutive regressions detected."
3. User confirms — automatic detection, manual invocation
4. On confirmation: `/serious-debug` launches with full context from the candidate file

### Debug-to-plan pipeline

When blast radius > 8 files or 3+ API endpoints, the `stop-plan-escalation.sh` hook offers:
```
[debug] Blast radius is architecturally significant (12 files, 4 endpoints).
[debug] Recommend /serious-scope → /serious-plan to address the structural issue.
```
If accepted: the debug report becomes the plan's problem statement. Frontmatter `source` links the debug report. Full traceability.

### Branching protocol

`/serious-debug` is pipeline order **8** (lateral to `/serious-code` at order 7).

- **From /serious-code (order 7):** Advancing. Both breadcrumbs coexist. Plan state frozen. Debug output in `Research/debug/{slug}/`. On completion, `.active-debug` removed, code resumes.
- **From /serious-debug (order 8):** Same-skill branching. Prompt for sub-workflow. Output in `{parent}/sub/debug-{slug}/`.
- **From any skill order < 8:** Advancing. Normal behavior, both breadcrumbs coexist.

---

## Arguments

`$ARGUMENTS` can specify:
- A bug description: `/serious-debug "payments fail for amounts over $999"`
- A failing test: `/serious-debug tests/payments/formatter.test.ts`
- A mode override: `/serious-debug --deep "intermittent auth failures"`
- `--auto-fix` — force auto-fix mode (falls back to quick on failure)
- `--resume` — resume an interrupted debug session (reads `state.json`)

---

## What Comes After

- **Bug fixed, small blast radius:** Done. Debug report in `Research/debug/{slug}/`. Corpus updated.
- **Bug fixed, large blast radius:** `/serious-scope` → `/serious-plan` to address the structural issue.
- **Invoked from /serious-code:** Return to `/serious-code` execution. Plan state unfrozen.
- **Pattern detected across multiple files:** Consider `/serious-research` to investigate the systemic issue.
