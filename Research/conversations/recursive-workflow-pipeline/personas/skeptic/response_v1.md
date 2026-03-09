# The Skeptic — Round 1

## Are we solving a real problem or building a cathedral for a niche annoyance?

Before we architect anything, I need to challenge the premise. The claim is: "the pipeline is actually a tree, not a line." Is it? How often does this actually happen today? Has anyone counted the number of times a stage genuinely needed to recurse back versus the number of times a user just... handled it manually and moved on? Because there's a massive difference between "this happens and is mildly inconvenient" and "this is a structural flaw blocking real work."

**What specifically worries me:**

- **Infinite recursion.** A conversation spawns a sub-conversation that spawns a sub-conversation. Where does it stop? Every recursive system needs a base case. What's ours? Depth limits feel arbitrary. "User judgment" isn't a mechanism, it's a prayer.

- **Complexity explosion.** The current flat pipeline is simple enough that someone can hold it in their head. A work item registry, parent-child linking, routing decisions at every boundary — that's a workflow engine. Are we sure we want to build a workflow engine? Because workflow engines are where projects go to die.

- **The 80/20 trap.** The recursive case probably covers 20% of real usage but will consume 80% of development effort. What if we just made it easy to manually kick off a sub-workflow and link back to the parent with a reference? No registry, no routing, no tree — just a convention.

- **Who debugs this?** When a recursive workflow tree gets three levels deep and something fails at level 2, what does the user see? What do they do?

I'm not saying recursion is wrong. I'm saying: show me the evidence that this is a frequent, painful problem before we commit to an architecture that triples the system's complexity.
