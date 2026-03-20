# The Skeptic — Round 4

## Generic prompt vs. handoff-specific: are we sure one size fits?

Everyone's treating "extract numbered items from upstream, check them downstream" as uniform. It's not. Conversation-to-research is a *semantic* mapping — an insight like "users distrust silent token rotation" could be addressed by a finding titled something completely different. Research-to-plan is *structural* — a finding either has a corresponding plan section or it doesn't. A generic prompt will handle the structural case fine and hallucinate matches on the semantic case. One prompt, yes, but it needs transition-specific extraction hints — even if that's just a single line like "match by meaning, not by title" for earlier handoffs vs. "match by explicit reference" for later ones.

## Heading standardization: do it now

The DX Advocate is right and the Pragmatist is wrong on timing. "Only standardize when extraction breaks" means the first user to hit an unstructured artifact gets a failed verification with no obvious fix. That's the worst possible first experience. Standardize the three or four heading names now. It's five minutes of work and it removes an entire class of extraction failure.

## The failure mode nobody's discussing: verifier confidence

The verifier is an LLM doing semantic matching. It will sometimes be wrong — calling something "covered" when the downstream artifact only vaguely gestures at it, or flagging "missing" when it's addressed under different terminology. What's the recourse? If the user overrides a false positive, is that logged? If a false negative slips through, the system gave false assurance. We need to be honest that the verifier's accuracy is itself uncertain, and the "show the denominator" design only partially mitigates this. Consider a `[VERIFIED: manual override]` marker for when the user disagrees with the verifier's judgment.
