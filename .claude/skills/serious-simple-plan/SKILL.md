---
name: serious-simple-plan
description: "Restraint-focused alternative to /serious-plan: generates a lean implementation plan biased toward reusing existing code, inventing nothing new without justification, and keeping the change footprint small. Accepts a --avoid list of files/areas to route around. Use when the user says 'serious simple plan', 'simple plan', 'lean plan', 'restraint plan', or wants a deliberately minimal plan instead of the full /serious-plan."
user-invocable: true
---

# Serious Simple Plan

A thin **restraint overlay** on top of `/serious-plan`. It produces a standard
`implementation_plan.md` — so `/serious-review` and `/serious-code` consume it unchanged — but
biases every decision toward doing *less*: reuse what already exists, invent nothing new unless
there is genuinely no other way, keep the change footprint small, and route around a
user-supplied "do not touch" list.

This overlay **references** the working planner in place. It does **not** copy or restate the
planner's phases, and it never edits the working planner.

## How this relates to `/serious-plan`

**Run the existing planner's flow, then layer restraint on top.** Follow `/serious-plan`
Phases 0-3 exactly as written in:

```
.claude/skills/serious-plan/SKILL.md
```

Read that file and execute its Phase 0 (Intake), Phase 1 (Plan Generation), Phase 2
(Self-Review), and Phase 3 (Present — Verification Gate) by reference. This overlay adds the
restraint rules below at the points indicated; everything not overridden here behaves exactly as
`/serious-plan` specifies.

**The working `/serious-plan/SKILL.md` is never modified by this overlay.** It is read and
followed, not edited.

---

## Restraint Overlay — applied on top of `/serious-plan` Phases 0-3

### R0. Arguments (extends `/serious-plan` Arguments)

In addition to everything `/serious-plan` accepts, `$ARGUMENTS` may include:

- `--avoid "<glob,glob>"` — a comma-separated list of repo-root-relative globs the plan must
  route around (the "do not touch" boundary). Each glob uses forward-slash separators and is
  relative to the repository root (e.g. `--avoid "src/payments/**,src/util/secrets.js"`).

If `--avoid` is absent, this overlay still applies the restraint behavior (reuse-first yardstick,
restraint intent statement); it simply writes no boundary sidecar and runs no Conflict Gate.

### R1. `--avoid` parsing and sanitization — run during Phase 0 intake

When `--avoid` is provided, resolve it into a clean list **before** drafting any tasks:

1. Split the value on commas into individual glob entries; trim surrounding whitespace from each.
2. **Sanitize each entry before it is written anywhere:**
   - Strip CR/LF and all control characters from the entry.
   - Reject the entry if it contains a `..` path segment, or if it has a leading `/` (globs must
     be repo-root-relative, not absolute and not traversing upward).
   - Normalize backslashes to forward slashes.
3. A rejected entry **stops generation immediately with a clear error** naming the offending
   value and the rule it broke. Never silently drop a rejected entry — a silent drop would leave
   the user believing an area is fenced when it is not.
4. The resolved list is the set of surviving sanitized globs, in input order, de-duplicated.

This sanitization is the writer side of the contract consumed by the code-time guard: a single
`--avoid` value must never be able to inject an extra line or a neutralizing `#` into the sidecar.

### R2. Boundary sidecar — write during Phase 0f (plan location), only when `--avoid` is given

Whenever `--avoid` resolved to one or more globs, write a `protected-paths.txt` sidecar into the
plan's output folder (the same folder that holds `implementation_plan.md`):

- **Format:** one repo-root-relative forward-slash glob per line, blank and `#` lines ignored by
  the reader.
- **Write each glob with `printf '%s\n'`** — exactly one sanitized glob per line — so no value
  can inject extra lines or a `#`.

Then write a `protected-paths.sha256` companion alongside it: the SHA-256 of `protected-paths.txt`
(via `sha256sum` or `shasum -a 256`). The code-time guard verifies this digest before trusting
the list, so the companion is written every time the sidecar is written.

```bash
# inside the plan output folder, with the sanitized globs in the array `globs`
: > protected-paths.txt
for g in "${globs[@]}"; do printf '%s\n' "$g" >> protected-paths.txt; done
{ sha256sum protected-paths.txt 2>/dev/null || shasum -a 256 protected-paths.txt; } \
  | awk '{print $1}' > protected-paths.sha256
```

When `--avoid` is absent, write neither file — an empty boundary is a no-op.

### R3. Reuse scan — run BEFORE drafting tasks, during Phase 1

Before drafting any task, perform a **reuse-scan** so the plan extends what exists instead of
adding new surface:

1. Grep the codebase for existing functions, types, helpers, and utilities that already cover the
   intended behavior (search by the nouns/verbs in the research findings and the feature intent).
2. For broad or unfamiliar areas, dispatch an Explore sub-agent (the `Explore` agent type) to map
   existing modules and naming conventions; this Explore step is optional and used when a plain
   Grep sweep is not enough.
3. Feed the scan results into each task's **Key components**: name the existing file/function the
   task reuses, so the plan prefers extending it over introducing a new dependency or module.

The reuse scan precedes task drafting; a task that adds new code must first show the reuse scan
found no existing thing to extend.

### R4. Restraint yardstick — apply during Phase 1 task drafting

New complexity (a new file, dependency, abstraction, config surface, or option) is allowed
**only if** a one-line justification holds on **at least one** of these three tests:

- **breaks-today** — without it, something the user needs today is broken.
- **named-and-dated-future-need** — a specific, named, and dated near-term need requires it now.
- **named-user-or-business-outcome** — it delivers a named user-facing or business outcome.

If none of the three holds, reuse the existing thing or pick the simplest in-place change. Write
the one-line justification next to the new complexity in the plan so a reviewer sees why it
earned its place. This yardstick is the default decision rule for every "should I add this?"
moment during drafting.

### R5. Restraint intent statement — write into the generated plan during Phase 1

State the restraint intent explicitly in the generated plan (in the Executive Summary and the
Appendix → Technical Decisions). Name that the plan is deliberately lean: it reuses existing
code, omits speculative surface, and routes around the avoid-list. This exists so that
`/serious-review` reads the deliberate omissions as intentional restraint, not as gaps — an
unstated omission is read as a gap by review.

### R6. No-source annotation — apply during Phase 1

`/serious-plan` already requires every acceptance criterion to cite an upstream source. This
overlay adds restraint-specific criteria (reuse-first, boundary routing). Any restraint criterion
this overlay invents that does not trace to an upstream finding must be annotated with
`[NO SOURCE: reason]` so the reviewer sees it as a deliberate restraint addition, not drift.

### R7. Conflict Gate — run before writing the plan (after task drafting, within Phase 2)

After tasks are drafted and before the `implementation_plan.md` is written, run the **Conflict
Gate** when an avoid-list is present:

1. For each task, list its foreseeable files (from Key components and impact analysis) and test
   whether any **intersect** the avoid-list globs.
2. For every task that intersects the boundary, surface it to the user — **one conflict per message** — presenting exactly three things:
   - **what it must touch** — the protected file(s) the task would otherwise write.
   - **why no clean alternative** — why the work cannot stay inside the boundary cleanly.
   - **the dumber in-boundary option** — the simplest change that stays inside the boundary, even
     if cruder.
3. Ask the user to choose one:
   - **approve-cross** — allow this task to cross into the protected area.
   - **force-in-boundary-workaround** — take the dumber in-boundary option instead.
   - **cancel** — stop and do not write the plan.

Present conflicts strictly one per message; wait for the user's choice before surfacing the next.

The Conflict Gate is **best-effort and non-exhaustive**: it reasons over *foreseeable* files at
plan time, which cannot see every file an implementer will actually touch. The **binding enforcement is at code time** — the `/serious-code` guard that matches real write targets against
`protected-paths.txt`. The Conflict Gate is the early-warning pass, not the boundary itself.

### R8. Breadcrumb and output filename — during Phase 0f and Phase 3

This overlay reuses the existing **`plan` breadcrumb slot** — it is **not a new** `simple-plan`
breadcrumb name. Follow `/serious-plan` Phase 0f's writer block exactly, writing the slot via:

```
breadcrumb_path plan
```

and emit the output file named exactly `implementation_plan.md`. A consequence of reusing the
`plan` slot is that `/serious-status` and `/serious-abandon` display and abandon this workflow as
"plan"; that is the accepted behavior. Removal of the breadcrumb at Phase 3 follows
`/serious-plan` unchanged.

---

## Self-Review additions (extends `/serious-plan` Phase 2)

In addition to the `/serious-plan` Phase 2 checklist, confirm:

- [ ] Every new complexity has a one-line restraint-yardstick justification (R4).
- [ ] The reuse scan ran before task drafting and its findings appear in Key components (R3).
- [ ] The restraint intent is stated in the plan so omissions are not read as gaps (R5).
- [ ] If `--avoid` was given, `protected-paths.txt` and `protected-paths.sha256` exist in the plan
      folder and the Appendix → Out of Scope lists the resolved globs verbatim (R2, below).
- [ ] If `--avoid` was given, the Conflict Gate ran and any intersecting task was resolved (R7).
- [ ] Any invented restraint criterion carries `[NO SOURCE: reason]` (R6).

## Recording the avoid-list in the plan (extends `/serious-plan` Appendix)

Record the resolved `--avoid` list **verbatim** in the generated plan's **Appendix → Out of
Scope** — the exact sanitized globs, one per line — so the boundary is human-readable in the plan
itself, independent of the sidecar.

---

## What this overlay does NOT change

- It does not duplicate or restate `/serious-plan` Phases 0-3 — it references them in place.
- It does not edit `.claude/skills/serious-plan/SKILL.md`.
- It does not introduce a new breadcrumb identity — it writes the existing `plan` slot.
- It does not change the output filename — the result is `implementation_plan.md`.

## What Comes After

Once the user approves the plan:

1. Run `/serious-review` to review the plan before `/serious-code`.
2. Run `/serious-code` to begin implementation. When the plan folder carries a
   `protected-paths.txt`, the code-time guard enforces the avoid-list for real.
