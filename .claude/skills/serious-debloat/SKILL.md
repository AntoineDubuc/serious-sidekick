---
name: serious-debloat
description: "Audit a plan OR real code/diff for bloat — reinvented idioms, over-broad fixes, new scaffolding, redundant mechanisms — and recommend (or apply) the smaller version. Use when the user says 'serious debloat', 'debloat this', 'simplify this', 'is this too much', 'am I over-building', 'make it leaner', or wants a restraint/reuse pass on a plan or a change."
user-invocable: true
---

# Serious Debloat

You run a **restraint pass**: given a plan or a real code change, you find where it does MORE than the problem requires and recommend the smallest version that still solves it — reusing what already exists. This is the audit counterpart to `/serious-simple-plan` (which *writes* lean) — `/serious-debloat` *trims* something already written, and it works on **real code**, not just plans.

**Core principle:** the best change is the smallest one that solves the actual problem while reusing existing code. A change can be fully correct and still bloated. Bloat is the target.

**Not a correctness/security/structure review.** Those are `/serious-review`'s job. If the user needs bug-hunting, point them there. This skill only answers "is this bigger than it needs to be, and what's the smaller version?"

---

## Phase 0: Intake — identify the target and the goal

Determine two things (ask only if you genuinely cannot infer them — max 2 questions):

1. **What to audit.** One of:
   - **A plan** — a path to an implementation plan / design doc.
   - **A diff** — uncommitted changes (`git diff`, `git diff --staged`) or a branch delta (`git diff <base>...HEAD`). Default to the current branch's delta vs its base if the user says "this change" / "my PR" without a path.
   - **A file set** — specific files the user names.
   If ambiguous and a git repo is present, default to the branch delta and say so.

2. **The stated problem/goal** — what the change is actually supposed to fix or build. Everything is measured against THIS. If it's not stated and not obvious from the plan/commit messages, ask one line: "In one sentence, what is this change supposed to accomplish?" (Without the goal, you cannot tell necessary from excess.)

Resolve the **codebase root** — the restraint checks need it to detect reinvented idioms.

Announce the target in one line, then proceed. Do not over-negotiate scope.

---

## Phase 1: Dispatch the restraint reviewer

Spawn the **`serious-review-restraint`** agent (Agent tool). Pass it:
- the artifact (plan path, or — for a diff — the diff text plus the list of changed files so it can read them in full context),
- the **codebase root** (it WILL read the codebase to find reusable idioms),
- the **stated problem/goal** from Phase 0.

**Scale to the target:**
- Small target (one plan, a small diff): one restraint agent.
- Large target (a big diff spanning many files/areas): fan out — one restraint agent per coherent area (by package/module/subsystem), each given its slice + the shared goal, then merge. Do not exceed what's useful; 2–4 parallel agents is typical.

For a **diff/code** target, instruct the agent to additionally check:
- **Dead/unreachable additions** — new code with no caller, no route, no consumer.
- **Duplicated logic** — a block that restates something already in the codebase (grep for it).
- **Copy-paste-not-adapted** — pasted code carrying assumptions that don't hold here.
- **Speculative flexibility** — options/params/config nobody currently uses (YAGNI).

Wait for the agent(s). If one fails, retry once, then proceed with a noted gap.

---

## Phase 2: Synthesize

Merge the agent report(s) into a single, ranked verdict:

- **Verdict:** LEAN / TRIMMABLE / BLOATED.
- **Footprint reduction estimate:** concrete (e.g. "~2 tasks, 1 helper, 1 touched package, ~35 lines removable").
- **Cut list**, each item as one of:
  - **CUT** — remove entirely; it's unnecessary. (Name what it is + why it's not needed.)
  - **REUSE** — replace the new thing with an existing idiom at `file:line`.
  - **EXTRACT** — real work, but out of scope for the stated goal → move to a separate change (never silently dropped).
  - **COLLAPSE** — two+ redundant mechanisms → keep the one that actually closes the invariant.
- **Correctness-vs-simplicity tradeoffs** — every cut that removes real coverage, flagged explicitly for the human to accept or reject. Never recommend a coverage-dropping cut silently.
- **Leanest viable version** — the minimum that solves the stated problem.

**Guardrail — do not over-cut:** EXTRACT is not DELETE. If bundled work is real and must happen, recommend a separate PR/plan, not removal. Deferring real work into a vague "later" that never happens is its own failure mode — if the user has said follow-ups don't get done, recommend a concrete separate plan/PR that IS scheduled, not a hand-wave. Never recommend cutting genuine test coverage for real acceptance criteria; target only make-work ceremony.

---

## Phase 3: Report — and optionally apply

Present the verdict in plain language (PM voice if the user is non-technical): lead with the one-line "here's what to cut and how much smaller it gets," then the ranked cut list, then the tradeoffs that need a human decision.

**If the user asked to APPLY** (e.g. `/serious-debloat --apply`, "and make the cuts", "just do it"):
- Apply only the CUT / REUSE / COLLAPSE items that have **no** correctness tradeoff.
- For each tradeoff-flagged item, ask the user (one at a time) before cutting.
- For EXTRACT items, do not delete — record them for a separate change and tell the user.
- After applying, re-state what changed and what was left for the human to decide.

**Otherwise** (default): report only. Offer: "Want me to apply the no-tradeoff cuts, or leave it as recommendations?"

---

## Operating Rules

1. **Premise check FIRST.** Before judging bloat, verify the plan/change's core premise against real source: does the bug/gap it targets actually exist, do its "reuse X at file:line" anchors resolve, is the fix's mechanism consistent with how the code really works? A lean plan for a non-existent problem (bug already fixed, wrong anchor, misunderstood mechanism) is worse than a bloated plan for a real one — flag a false premise as the top finding and stop; bloat assessment is moot until it's corrected.
2. **Measure against the stated goal, always.** Excess is anything the goal doesn't need — no more, no less.
3. **Every recommendation names a concrete smaller alternative** (a cut, a reuse `file:line`, an extraction, a collapse). "Too big" without an alternative is not a finding.
4. **Reuse detection requires reading the codebase — and `grep` alone is not enough.** The sandbox `grep` silently SKIPS files it reads as binary (any source with escape/control bytes, e.g. ANSI-stripping regexes), so a grep miss does NOT prove absence. Confirm existence/absence (and "reuse this" / "this is reinvented / doesn't exist") with the **Read** tool, `rg --text`, `grep -a`, or Python — never a bare grep miss.
4. **Flag correctness tradeoffs; never cut coverage silently.**
5. **Extract, don't drop.** Out-of-scope real work becomes a scheduled separate change.
6. **Bias toward LESS** — when a cut is defensible and tradeoff-free, recommend it.
7. Report-first; apply only on explicit request.

---

## Arguments

`{argument}` may be: a path to a plan/file, `--diff` / `--staged` / `--branch <base>` to target changes, `--apply` to apply no-tradeoff cuts, or nothing (defaults to the current branch delta if in a git repo, else asks). Examples:
- `/serious-debloat Research/bugs/x/plan-A/implementation_plan.md`
- `/serious-debloat --staged` — audit staged changes before committing
- `/serious-debloat --branch main --apply` — trim the branch vs main and apply the safe cuts
- `/serious-debloat` — audit the current change and recommend cuts
