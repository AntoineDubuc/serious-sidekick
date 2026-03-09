# The Architect — Round 1

## The Pipeline Is a Graph. Treat It Like One.

The flat pipeline is a lie we told ourselves for simplicity. The actual structure is a directed acyclic graph (DAG) where any stage can spawn children that re-enter the pipeline at any earlier stage. The architecture needs three layers, cleanly separated:

### Layer 1: Work Item Registry

A single registry that tracks every work item — top-level or spawned. Each item carries: a unique ID, a parent ID (nullable), a current stage, a status, and a type hint for routing. This is the spine. Everything else hangs off it. Think of it like a process table in an OS — it doesn't do work, it tracks what exists and where it is.

### Layer 2: Stage Boundary Router

At every stage boundary, a routing decision occurs: does this item proceed forward, spawn children, or loop back? This is an explicit decision point, not an implicit side effect. The router examines the stage output, applies routing rules, and either advances the item or creates child work items in the registry. The key constraint: **a parent cannot advance past a stage until all children spawned at that boundary are resolved.**

### Layer 3: Stage Executors

The actual skills (`/serious-conversation`, `/serious-research`, etc.) remain unchanged. They take a work item, produce output, and return control to the router. They should not know about recursion. They should not know about parents or children. They process one item and hand back results.

### The Critical Interface

The router is where all the complexity lives, and it should be the *only* place that knows about the tree structure. Keep the stages dumb and the registry flat. The tree is an emergent property of parent-child links, not a data structure you build explicitly.

This gives us recursion without coupling. A stage never calls another stage — the router does that through the registry.
