# The Pragmatist — Round 1

## Do we actually need recursive workflows?

Let me push back on the premise before we start designing tree-walking algorithms.

The problem is real: mid-workflow, you discover something that needs an earlier stage. It happens constantly. But the proposed solution — parent-child linking, a work item registry, recursive spawning — that sounds like building a workflow engine. We are not in the workflow engine business. We are in the "help someone ship code" business.

**What actually happens today when a plan task needs research?** You run `/serious-research` manually. It works. The friction is not that you lack a tree structure — it is that there is no breadcrumb trail connecting the sub-research back to the parent plan. That is the actual problem: traceability, not orchestration.

**Here is what I would ship first:**

1. **A `parent` field.** When you invoke any workflow skill, you can optionally pass a reference to the parent work item. That is it. One field. It gets written into the artifact metadata. Now you have your tree — implicitly, through references, not through a recursive engine.

2. **A status convention.** Parent items get a `blocked: waiting on [child-id]` status. Child completes, you manually unblock. No automation. No routing rules. Just a convention humans follow.

3. **Nothing else yet.** No registry. No automatic routing decisions at stage boundaries. No recursive spawning. See if the `parent` field and status convention solve 80% of the pain. They will, because the pain is "I lost track of why I started this sub-research," not "I need the system to automatically spawn sub-workflows."

Build the registry and routing layer only after you have evidence that manual linking is actually the bottleneck. I bet it will not be.
