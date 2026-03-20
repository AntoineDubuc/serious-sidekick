# The Architect — Round 6

Fair call. We declared victory and punted the structural gaps. Here's my stress-test of each proposed fix.

## 1. Scope Shirking Detection

**Verdict: Sound.** Pattern-matching on placement is the right abstraction — it sidesteps semantic reasoning entirely. The verifier already extracts items and locates them; this just changes what counts as "covered" from "mentioned anywhere" to "mentioned in a substantive position." Three placement buckets (own section/task/AC, dismissive placement, absent) are exhaustive and unambiguous.

**One real problem:** "Future work" sections aren't always shirking. A research finding might say "consider WebSocket support" — deferring that in the plan is legitimate. The `[DEFERRED: reason]` marker already handles this, but the verifier prompt needs to be explicit: items in dismissive placements WITHOUT a `[DEFERRED]` marker are shirked. Items WITH the marker are deferred. This is the boundary condition where the two mechanisms interact.

## 2. Per-Item Manual Override

**Verdict: Sound, trivially.** One line in the verifier prompt, one convention for users. No new machinery. The `[VERIFIED: override]` marker lives in the downstream artifact where it belongs — the user is asserting "I handled this, the verifier can't see it." Clean separation: the system flags, the user overrides, the override is visible in the artifact for future readers.

**No new problems.** This is a convention, not a feature.

## 3. Startup Extractability Check

**Verdict: Sound, but scope the two modes carefully.** Extract-mode and verify-mode in the same file is fine — they share the item extraction logic. But they have different failure semantics: extract-mode failing means "stop before wasting time," verify-mode failing means "your output is incomplete." The prompt needs to make this modal behavior explicit or you'll get verify-mode behavior at startup (blocking on coverage gaps that don't exist yet).

**Implementation note:** Extract-mode should output the item list to a scratch location that verify-mode reads later. This avoids re-extraction and ensures both modes agree on what was found.

## 4. Retroactive Verification

**Verdict: Sound with one structural concern.** The `verified: YYYY-MM-DD` frontmatter field is clean — it's the same pattern as `status: active`. Downstream skills already read frontmatter, so checking for one more field is trivial.

**The concern:** What triggers verification on an old plan? The proposal says the next skill checks for the field. But the next skill is `/serious-code`, which reads the plan, not the research. The verifier checks research-to-plan coverage. So `/serious-code` needs to know: does this plan have a `verified` field? If not, invoke the verifier against the plan's upstream source. This means the plan's frontmatter must include a `source` field pointing to the research artifact. Without that backlink, retroactive verification can't find what to verify against. Add `source: Research/features/auth/research.md` to the plan frontmatter spec.

## Summary

All four solutions are architecturally sound. Two need refinement:
- **Shirking detection** needs explicit interaction rules with `[DEFERRED]` markers
- **Retroactive verification** needs a `source` field in plan frontmatter to enable backlink resolution

Neither refinement changes the design — they're specification gaps, not structural flaws.
