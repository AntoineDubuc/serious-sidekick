# DX Advocate — Round 1 Response

## The Core DX Problem: Silent Failure Is the Worst Kind of Failure

The current pipeline has one of the worst DX anti-patterns possible: **it fails silently and makes you think it succeeded.** The downstream skill produces output that *looks* complete, reads confidently, and gives no signal that it dropped half the upstream work. You only find out when you manually diff — which means the default experience is "trust the output and get burned later."

That's unacceptable. The fix needs to prioritize one thing above all else: **when something gets dropped, the user must know immediately, without asking.**

## Where Verification Should Live

The verification must be an **independent sub-agent at each handoff**, not instructions embedded in the downstream skill's prompt. We already proved this — self-verification instructions get ignored. The same agent that did the work will rationalize its omissions every time. This isn't a prompting problem you can wordsmith away.

The serious-code completion gate already works because it's a *separate agent* with a *single job*: compare input to output and flag gaps. Copy that pattern.

## What I Care About Most

1. **The error output.** When the verifier catches a gap, what does the user actually see? "Verification failed" is useless. It needs to say: *"Plan omitted research finding R3 (token rotation). Research said 'critical,' plan doesn't mention it. Action needed: add to Phase 2 or explicitly mark as deferred with rationale."* Actionable, specific, no guessing.

2. **Don't add friction to the happy path.** If everything passes, the user should see one line — "Upstream traceability verified: 12/12 findings covered" — and move on. The verification step should be invisible when things work.

3. **Make the gate mandatory, not opt-in.** If it's a flag you have to remember to pass, people won't use it. It should run automatically at every handoff. The user should have to *opt out*, not opt in.

The completion gate pattern from serious-code is the right foundation. Generalize it across all handoffs, invest heavily in the error messages, and keep it out of the way when things are clean.
