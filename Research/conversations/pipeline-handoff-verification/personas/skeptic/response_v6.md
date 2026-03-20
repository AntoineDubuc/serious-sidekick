# The Skeptic — Round 6

## Scope shirking detection: the strongest proposal, with one gap

Pattern matching on placement is the right approach — it sidesteps semantic reasoning entirely. "Does this item have its own section or acceptance criteria?" is a structural question an LLM can answer reliably. My concern: what about items that get a dedicated section but the section is empty or trivial? "Section 4.2: Rate Limiting — We will address rate limiting." That's not future-work placement, it's not a parenthetical aside, but it's also not substantive. The check needs a minimum-substance threshold — at least one action item, task, or design decision within the section. Without that, the system rewards creating headings instead of doing work.

## Per-item manual override: fine, but what prevents abuse?

One `[VERIFIED: override]` marker and you bypass verification for that item forever. Across all future downstream skills. What stops someone from slapping overrides on everything when the verifier is annoying? There's no friction, no audit trail, no "why." At minimum, the convention should be `[VERIFIED: override — reason]` where the reason is required for the marker to be recognized. A reason creates social accountability even if nothing enforces it programmatically.

## Startup extractability check: genuinely good

No complaints. Failing fast before burning 20 minutes is obviously correct. Dual-mode in the shared file (extract vs. verify) is clean. The only question: what's the threshold for "can't find structured lists"? If the upstream artifact has prose paragraphs instead of numbered items, does it warn or block? I'd say warn — blocking on format would be too aggressive for v1.

## Retroactive verification: solves my gap, creates a new one

This directly addresses the legacy-plan problem I raised in round 5 — good. But the `verified` frontmatter field is a point-in-time stamp. If someone edits the upstream artifact *after* verification, the downstream plan's `verified: 2026-03-15` is now stale. The field says "verified" but the inputs changed. The fix: hash the upstream artifact at verification time. `verified: 2026-03-15 | sha:a3b2c1`. Next skill checks the hash against the current file. Different hash = re-verify. Without this, retroactive verification gives false confidence on modified artifacts.
