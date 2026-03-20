# The Pragmatist — Round 1

## Position: Steal the pattern that already works

You already solved this problem. The serious-code completion gate uses an independent sub-agent to verify acceptance criteria, and it works. Stop designing — copy that pattern and apply it to every handoff.

## What I'd actually build

One verification step that fires automatically between skills. Not a framework. Not a registry. One prompt template that says: "Here is the upstream artifact. Here is what the downstream skill produced. List what was omitted, contradicted, or deferred." Run it as a sub-agent so the skill that did the work isn't grading its own homework.

That's it. That solves the three failure modes you named. Ship it, see if it catches the problems, iterate.

## Where it should live

In the skill files themselves. Each downstream skill already has a section describing what it reads from upstream. Add a completion gate at the end — same as serious-code does — that spawns a verifier agent before the skill marks itself done. No new infrastructure. No hooks. No middleware layer. Just a prompt block in each SKILL.md.

## What I'd push back on

- **A centralized verification service** — you have 6 skills, not 60. Central coordination is overhead you don't need.
- **Schema validation or structured contracts** — the artifacts are natural language. The verification is natural language. Don't force structure onto something that works fine as prose comparison.
- **Making this blocking/gating before you prove it catches real problems** — start with it as a warning. Make it blocking after you trust it.

## The fastest path

Copy serious-code's gate pattern. Paste it into serious-research and serious-plan (the two worst offenders). Test with your next real workflow. Took you an afternoon to build the first gate — this should take less since you're repeating yourself.
