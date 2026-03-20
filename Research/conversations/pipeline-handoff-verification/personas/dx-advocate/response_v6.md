# DX Advocate — Round 6 Response

## The End-to-End User Experience

Fair call. We said "wait" on things that belong in v1. Let me walk through what a user actually experiences with all four features working together.

**The happy path feels invisible — and that's correct.** User runs `/serious-plan`. Phase 0 fires the startup extractability check: "Found 8 items in research.md. Proceeding." One line of output. Plan gets written. Verifier fires automatically, produces the traceability checklist, stamps `verified: 2026-03-19` into the frontmatter. User sees a green checklist and moves on. Three automated steps, zero user actions. That's the bar.

**The failure path is where UX actually matters, and it's solid.** Scope shirking detection catches the sneaky case — the item that technically appears in the plan but got dumped into a "future considerations" paragraph. The checklist shows SHIRKED instead of MISSING. That distinction matters because it tells the user *the system caught a dodge, not a gap*. The user knows the downstream skill saw the item and dismissed it, which is a different remediation than "it was never mentioned." Clear signal, clear action.

**The per-item override is elegant precisely because it's a convention.** User adds `[VERIFIED: override]` next to the shirked item, re-runs. No flags, no config, no commands to learn. The marker lives in the artifact itself, so it's visible during review and greppable later. One concern: document a single canonical example in the verifier output's failure message. "To override, add `[VERIFIED: override]` next to item 4 in plan.md." Don't make the user go hunting for syntax.

**Retroactive verification is the quiet safety net.** User pulls up a pre-verifier plan and runs `/serious-code`. The frontmatter has no `verified` field. Verification fires before work begins. This is the right moment — it catches the gap *before* burning time, not after. The startup extractability check and the retroactive trigger are complementary: one validates structure, the other validates history.

**One UX risk across all four:** the startup phase now does two checks (extractability + retroactive verification) before any real work. If both warn, that's two messages before the user sees progress. Keep them terse. One line each, max.
