# The Skeptic — Round 5

## [VERIFIED: manual override] — wait, but document the intent now

Don't build it. But write one sentence in the known limitations section: "When the verifier is wrong, the user's only recourse is `--skip-verify`. A structured override mechanism is deferred until false positive frequency is measured." That sentence costs nothing and prevents future-us from reinventing the rationale. The risk of building it now isn't wasted effort — it's that we design the override format before we know what false positives actually look like. Are they wrong extractions? Wrong matches? Both? The override mechanism should fit the actual failure shape, not our guess.

## Contradictions vs. omissions: omissions only for v1

Contradiction detection sounds valuable in theory. In practice, what does "the downstream says the opposite" even mean for most pipeline items? A research finding says "use short-lived tokens" and the plan says "use long-lived tokens" — is that a contradiction or a deliberate design decision the user made between skills? The verifier can't distinguish intentional revision from accidental drift without understanding user intent. That's a much harder problem than "is this item present or absent." Ship omission detection. If users report that contradictions are slipping through and causing real damage, revisit.

## Completion gate overlap: I'm not convinced they're cleanly separate

The synthesis says the handoff verifier and serious-code's completion gate serve "different lifecycle moments." Are we sure? Serious-code's gate checks whether plan items were implemented. The handoff verifier checks whether upstream items appear in the plan. If a research finding was missed by the plan, and then serious-code faithfully implements the (incomplete) plan and passes its gate — the system gave a green light to incomplete work. That's not complementary, that's a gap. The handoff verifier only helps if it actually ran and blocked. What if the user ran `/serious-plan` before the verifier existed, then later runs `/serious-code` on that old plan? The completion gate passes. Nobody catches the original omission. We should at minimum document that the handoff verifier is the *only* defense against upstream drift, and serious-code's gate explicitly does not cover it.
