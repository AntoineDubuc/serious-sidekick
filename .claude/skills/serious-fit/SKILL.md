---
name: serious-fit
description: Codebase-grounded review of an implementation plan (or a real diff) — does it DUPLICATE something that already exists, is every new piece minimal, does it FIT the code's conventions, and does it stay self-consistent (fix X without leaving copy/behavior that contradicts X)? Recommends the smallest COMPLETE version, never a blind cut. Use when the user says "serious fit", "does this fit", "am I over-building", "is this too much", "check for duplication", "run fit on this plan", or wants a restraint/reuse pass with the codebase open. Recommend-only; a human verifies every cut. Runs AFTER /serious-review, before /serious-code.
user-invocable: true
---

# serious-fit — the reuse-scan run in reverse

Review a plan **against the real codebase** (not the plan in isolation) and answer, adversarially:
*am I about to duplicate something, is every new piece justified, does it fit the grain, and does it
stay consistent with itself?* Output a short **duplication & bloat & consistency report** and the
**smallest COMPLETE version** — never a blind cut.

> **TRIAL skill.** Its ancestor (`/serious-debloat`) was a blind cutter that removed critical things.
> The fix baked in here is **Check 6 + the cut-safety rule** below. Still: **recommend-only.** Every cut
> must cite the existing code that makes it redundant, and a human verifies before anything is removed.
> Research + validation runs live in `~/Desktop/serious-fit-skill-research/` (run-01 new-endpoint,
> run-02 bug-fix plans).

## Pipeline slot
`plan → review → FIT (this) → code`. Runs AFTER a cold plan review (structure/prose/security) and
BEFORE any code is written, so trims and reconciliations land before implementation. Consumes an
`implementation_plan.md` (or a diff) + the codebase root.

## The six checks (run each against live source; cite `file:line`)

1. **Duplication hunt (the big one).** Does this already exist? Search by **what it does**, not its name —
   grep the nouns/verbs of the capability. Open the **3–5 nearest neighbors** (existing endpoints,
   services, errors, events, helpers). Does any already return >~30% of the planned output? Could we
   **extend/reuse** one instead of adding a new surface? Verdict per overlap: **DUPLICATE / PARTIAL /
   DISTINCT** + `file:line` + rough % coverage.
2. **Minimalism / YAGNI.** For each new file/method/type/field: could it be a small addition to something
   that already exists? Flag speculative surface ("a future X will need it"). **Blast-radius lens:** flag
   edits to a **shared package** or a **new cross-package dependency** that could have stayed local.
3. **Natural fit.** Naming, placement, layer, error handling, test style — match the neighbors? Open
   **2–3 existing instances** of each construct (enum, DTO, error class, event, guard) and match the
   **majority** shape, not just "an" example. Reuse the same plumbing (tenant access, query style, guards)
   rather than a second way to do the same thing.
3. **No hidden migration.** Confirm the plan only reads data that already exists — no new tables/columns/
   events "just in case." If it claims compute-on-read, open the source columns and confirm they're there.
5. **Delete test.** For each nice-to-have: "what breaks if we cut it?" Produce a **cut-list**: item →
   keep / cut / defer + one-line reason + `file:line`. **Delete-first:** the leanest fix sometimes
   *removes* a redundant path rather than adds one — surface those.
6. **Self-consistency (completeness — the anti-cut counterweight).** Does the change fix X but leave copy
   or behavior that now contradicts X? Grep the changed literal/behavior; confirm every **co-located
   surface moves with it** (a button label ⇒ its confirm dialog, toast, twin control; a renamed field ⇒
   every consumer). Flag anything the change makes **FALSE elsewhere** (UI copy, docs, comments).
   Verdict per issue: **INCONSISTENT (must-fix) / COSMETIC / OK** + `file:line`.

### The cut-safety rule (this is what keeps it from over-cutting)
**Before recommending any CUT/TRIM, run Check 6 on it.** If removing it would leave a contradiction or a
half-done fix, **DOWNGRADE the recommendation to KEEP.** A trim that breaks self-consistency is a
regression, not a trim. Every cut must cite the existing thing (`file:line`) that makes it redundant, OR
be labeled speculative — **no evidence, no cut.**

## How to run it (mechanically)
1. Read the plan (and its `source:` research if present, for the "does each field trace to a real need"
   check).
2. Fan out **blind, parallel** reviewers against the codebase: backend duplication · frontend/consumer
   duplication · minimalism/bloat · self-consistency (check 6). (Blind-to-each-other avoids rubber-stamp.)
3. Trace one field/behavior end-to-end to confirm it isn't already exposed; grep the changed literal to
   confirm no co-located surface is left contradicting it.
4. Synthesize: **what exists (reuse) · what's genuinely new · cut-list (each cut passed check 6) · fit
   issues · consistency issues**, each with `file:line`.
5. Verdict: **FITS-CLEAN / TRIM-RECOMMENDED / DUPLICATION-FOUND / INCOMPLETE** + the concrete
   smallest-complete version. Also report **"over-cut avoided"** — any cut you were tempted to make and
   downgraded via check 6 (shows the guardrail firing).

## Output
`fit_verdict.md` next to the plan (or inline): the report above. **Recommend-only** — edits go through the
human. Do not auto-apply.

## Guardrails (anti-rubber-stamp)
- "Nothing obviously duplicated" is **banned** — name the 3–5 neighbors you actually opened and diffed.
- Every duplication claim needs `file:line` + rough % coverage. Every cut needs `file:line` evidence.
- Respect user-approved scope: surface only **NEW** info that would change the decision; don't re-litigate
  settled scope.
- A subagent finding is a hypothesis — the orchestrator re-verifies each cut/keep against source before it
  reaches a human (run-02 showed even *correct* cuts needed this).

## The motivating example (dogfood)
The session that added Check 6 nearly rebuilt this very skill without knowing it existed — exactly the
"does this already exist?" failure Check 1 is built to catch. If in doubt about whether a capability is
new, assume it isn't until you've grepped for it.
