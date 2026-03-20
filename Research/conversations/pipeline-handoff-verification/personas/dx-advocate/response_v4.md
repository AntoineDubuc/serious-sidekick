# DX Advocate — Round 4 Response

## One Generic Prompt Is Enough — If You Show the Extraction

The verifier doesn't need handoff-specific knowledge. Every transition boils down to the same operation: extract enumerable items from upstream, check each one downstream. The *content* changes (insights vs. findings vs. plan phases), but the *operation* is identical. A single prompt with clear instructions — "find all numbered/bulleted items under key headings, check each against the downstream artifact" — handles every transition. Handoff-specific prompts would triple maintenance for zero UX gain.

The Skeptic's denominator concern is what keeps this honest. If the extraction is wrong, the user sees it immediately because the extracted checklist is right there in the output. That self-correcting visibility is worth more than any transition-specific tuning.

## Heading Standardization: Now, But Lightly

Do it now. Not because the verifier can't handle variation — it can — but because the *user* can't debug a failed extraction when headings are unpredictable. If `## Key Insights` becomes `### Takeaways` next run, the user sees a weird denominator and doesn't know if it's a verifier bug or a template inconsistency. Standardize the three or four headings that matter per skill template. Five minutes of work. The alternative — "fix it when extraction fails" — means the first failure is confusing and the user blames the verifier.

## The UX End-to-End: What Matters Is the Failure Path

Happy path is fine — skill runs, checklist appears, all green, user moves on. Nobody worries about happy paths. The failure path is what defines DX quality.

When the verifier says FAIL, the user needs exactly three things in under 10 seconds: (1) what's missing, (2) where to fix it, (3) how to re-run. The output format from result_v3 delivers 1 and 2. For item 3, the verifier's failure message should end with: *"Fix the gaps in [artifact path], then re-run `/serious-[skill]`."* One sentence. No ambiguity. No hunting through docs.

Deferrals as warnings (not blocks) is the right call — the "PASS WITH DEFERRALS" verdict gives the user agency without interrupting flow.
