# DX Advocate — Round 3 Response

## Existing Structure as Contract: Yes, With One Tweak

The synthesis nailed it — upstream artifacts already emit numbered lists, bulleted findings, open questions. That IS the contract. The Skeptic's circularity problem dissolves: we're not asking the skill to produce an extra checklist it might botch. We're asking the verifier to read what's already there.

But here's the DX catch: "already enumerable" isn't the same as "consistently enumerable." If conversation result_v2.md uses `## Key Insights` with numbered items, but next time it uses `### Takeaways` with prose paragraphs, the verifier can't extract a stable checklist. **The tweak: standardize the heading names and require lists (not prose) under them.** That's a formatting guideline, not a contract section. Five minutes of work per skill template, not a restructuring project. The Pragmatist should accept that.

## Deferrals Need Exactly One Thing: A Marker

Don't overthink this. A legitimate deferral is one the user approved. The verifier needs to distinguish "deferred" from "missing." Solution: when a skill defers something, it writes `[DEFERRED: reason]` inline next to the item. The verifier sees the marker, logs it as acknowledged, moves on. No marker = gap = finding. One convention, zero infrastructure.

The error message writes itself: *"Finding F-03: Insight #4 from conversation ('latency budget') not addressed in research and not marked as deferred. Action: address it or add `[DEFERRED: reason]`."*

That's the actionable error I've been asking for since round 1.

## Verifier Output: The User Sees a Checklist

The verifier should output a numbered checklist mapping upstream items to downstream coverage. Each line: upstream item, status (covered / partially covered / deferred / missing), and location in the downstream artifact. Missing items get finding IDs. The user scans it in 15 seconds. That's the Pragmatist's "eyeball the list" idea — but structured enough to be blocking.
