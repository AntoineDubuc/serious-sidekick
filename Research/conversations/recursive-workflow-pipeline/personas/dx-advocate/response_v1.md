# DX Advocate — Round 1 Response

The flat pipeline already has a developer experience problem: it's five skills with five different mental models, five different folder structures, and five different sets of arguments. Adding recursive spawning makes this exponentially worse unless the *interface* is dead simple.

**My core concern: will future-you understand what happened?**

Right now, if I run `/serious-research` and it internally spawns a sub-conversation and a sub-research, I come back to... what? A tree of folders I didn't ask for? Artifacts I can't trace? The moment recursion is invisible, the system becomes hostile to its own user.

**What I want to see:**

1. **One command, one obvious result.** If `/serious-research` decides it needs a sub-conversation, that's fine -- but it must tell me *before* spawning it, and I must be able to say no. Silent recursion is a sharp edge. The user should always be the one deciding "yes, this sub-problem deserves its own workflow."

2. **A single status view.** If we build a work item registry, it needs a `/status` command that shows me the full tree: what's running, what's waiting, what finished, what spawned what. Think `docker ps` -- flat, scannable, shows hierarchy without forcing you to navigate it. Without this, recursive workflows are a black box.

3. **Predictable folder layout.** Sub-workflows should nest *inside* their parent's folder, not scatter across `Research/`. If my research on auth spawns a sub-conversation about token formats, that conversation lives at `Research/features/auth/sub/token-formats/`, not at some sibling path I have to hunt for.

4. **Error messages that explain the tree.** When a sub-workflow fails, the error must say: "Task X in sub-research Y (spawned by research Z, task 3) failed because..." -- not just "research failed." Recursive systems produce recursive errors, and developers will curse us if we don't flatten those into readable messages.

**What I push against:** any design where the user has to read source code to understand what the system did while they were away. If recursion happens, it must be *legible* recursion.
