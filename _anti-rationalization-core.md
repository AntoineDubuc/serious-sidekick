# Anti-Rationalization Core — Universal Entries

> This is the **authoring source-of-truth** for universal anti-rationalization entries.
> It is never loaded at runtime by the agent. Its entries are materialized (copy-pasted)
> into each SKILL.md's Guardrail Block. Update entries here, then propagate to all skills.

<!-- GUARDRAILS — UNIVERSAL ENTRIES (source-of-truth) -->

> **Before acting on any step in this skill, check this table.**
> If your planned action matches a Rationalization entry, STOP and follow the Correct Action instead.

| # | Rationalization | Correct action | Why it fails |
|---|----------------|----------------|--------------|
| U1 | "A general description captures the intent — the implementer will know what to do" | Name the file, the function, the type, the line range. No hedge words. | Every downstream failure in the evidence log traces to vague language ("consider", "as needed") in upstream artifacts. Vague inputs produce vague outputs. |
| U2 | "This component is too simple for the full process" | The process applies regardless of perceived simplicity. Follow every phase. | The 4 documented /serious-plan failures ALL occurred in "simple" features where shortcuts seemed safe. Complexity is not the threshold. |
| U3 | "The guardrail table doesn't apply to this situation" | It applies unconditionally. If you're reasoning about why a row doesn't apply, that IS the rationalization the row describes. | This is second-order rationalization. The table exists because of situations that "seemed different." |

<!-- END GUARDRAILS -->
