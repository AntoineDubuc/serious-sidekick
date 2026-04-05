---
name: serious-conversation
description: "Structured conversation with a panel of personas for ideation, understanding, and exploration. Use when the user says 'serious conversation', 'let's think about this', 'brainstorm', 'I want to talk through something', or wants to explore an idea before researching or planning."
user-invocable: true
hooks:
  Stop:
    - matcher: "*"
      handler:
        type: prompt
        prompt: |
          If a serious conversation is active (check for .active-conversation file in project root),
          read the conversation folder path from it, then append a summary of the latest exchange
          to conversation.md in that folder. Include timestamp, who spoke (user or orchestrator),
          and the key points. Keep it concise.
---

# Serious Conversation

A structured conversational skill where you think out loud with a panel of personas. Each persona is a sub-agent with a distinct perspective. The Orchestrator (Claude Code) moderates, synthesizes, and helps you converge on insights.

**Position in the workflow:**
```
/serious-conversation  →  /serious-research  →  /serious-plan  →  implement
```

Use this BEFORE research — for ideation, understanding, brainstorming, or exploring a question.

---

## Phase 0: Discovery

### 0-pre. Check for active parent workflow

Before anything else, check for active workflow breadcrumbs in the project root:

1. **Scan for breadcrumbs:** Check for `.active-conversation`, `.active-research`, `.active-mock-ups`, `.active-scope`, `.active-plan`, `.active-code`, `.active-review`
2. **Validate each:** For each breadcrumb found, verify the target folder exists and contains a valid output file with parseable YAML frontmatter. If not, delete the stale breadcrumb with a warning: "Removed stale .active-{skill} breadcrumb (target folder missing)."
3. **If no valid breadcrumbs exist:** Proceed directly to Phase 0a without any output. Do NOT mention breadcrumbs, scanning, or the absence of active workflows. This is the normal state — the previous skill completed and cleaned up its breadcrumb.
4. **Determine the deepest active workflow:** If multiple valid breadcrumbs exist, follow `parent:` chains in each breadcrumb's target frontmatter. The workflow with the longest parent chain is the deepest. If multiple independent top-level breadcrumbs exist (none with parent fields), use the most recently modified breadcrumb as the comparison target.
5. **Compare pipeline order:** This skill is `conversation` (order 1). The deepest active skill is order {M}.
   - **Pipeline order:** conversation(1) → research(2) → mock-ups(3) → scope(4) → plan(5) → review(6) → code(7)
   - If 1 > {M}: this is **advancing**. Proceed directly to the next phase without any output about breadcrumbs or pipeline ordering. Both breadcrumbs coexist.
   - If 1 ≤ {M}: this is **branching**. Continue to step 6.
   - **Note:** Since conversation is order 1 (the lowest), it can never be greater than any active skill's order. Advancing never applies to conversation — it will always branch when another workflow is active. The only branching case is same-skill (conversation → conversation).
6. **Branching prompt:**
   - **Cross-skill:** "I see you're in /serious-{active_skill} for {slug}. This looks like it needs its own workflow. Link as a sub-workflow? (Y/N)"
   - **Same-skill (conversation → conversation):** "I see you're already in /serious-conversation for {slug}. Start a nested /serious-conversation within it? (Y/N)" Note: the existing `.active-conversation` breadcrumb will be overwritten with the new sub-workflow's path.
7. **If YES (sub-workflow):**
   - Compute proposed depth: follow `parent:` chain from the proposed parent's frontmatter, count hops until no `parent:` field, add 1.
   - **Depth guard:** If proposed depth ≥ 3, warn: "This would be depth {N} (3+ levels deep). Are you sure? (Y/N)". If No: do not create the sub-workflow, return without starting the new skill.
   - Set `parent` in this workflow's frontmatter to the parent's output folder path
   - Create output at `{parent_folder}/sub/{slug}/` instead of the normal location
8. **If NO:** Create output in normal location, no parent field set.
9. **Same-skill restoration:** On wrap-up/completion of this skill, if frontmatter has a `parent:` field and the parent was the same skill type (conversation), restore the breadcrumb: write `.active-conversation` with the parent's folder path as content. This works even if the parent was itself a sub-workflow (depth 2), because the parent's frontmatter has its own parent reference, and the breadcrumb just needs to point to the immediate parent.

### 0a. Ask two questions

**Question 1:** "What do you want to talk about?"

Let the user describe the topic freely. This becomes the seed input for the personas.

**Question 2:** "What are you hoping to get out of this?"

Present options:
1. **Understanding** — "I want to understand something better"
2. **Decision** — "I need to make a choice between approaches"
3. **Ideas** — "I want creative/divergent thinking"
4. **Exploration** — "I'm not sure what I'm looking for yet"

The desired outcome shapes how the Orchestrator frames its synthesis:
- Understanding → synthesis explains trade-offs and clarifies concepts
- Decision → synthesis presents sharp trade-off analysis with a recommendation
- Ideas → synthesis encourages divergence, captures all ideas without narrowing
- Exploration → synthesis identifies threads worth pulling on

### 0b. Generate a slug

Create a URL-safe slug from the topic. Example: "auth systems for our API" → `auth-systems-for-our-api`

### 0c. Propose personas

Based on the topic, propose 3-5 personas from the roster (see Persona Roster below). Explain briefly why each was chosen.

Then show the **full roster** (built-ins + any saved customs from `Research/conversations/_personas/`) and let the user:
- Remove any proposed persona
- Add others from the roster
- Create a custom persona (see Custom Personas below)

### 0d. Create the conversation folder

```
Research/conversations/{slug}/
├── conversation.md                    # User-Orchestrator discussion log
├── personas/
│   ├── {persona-1}/
│   │   └── prompt.md                 # Persona system prompt (editable)
│   ├── {persona-2}/
│   │   └── prompt.md
│   └── {persona-3}/
│       └── prompt.md
```

Copy each selected persona's `prompt.md` from the built-in templates (or from the library for saved customs). For new custom personas, generate using the template (see Custom Personas below).

Initialize `conversation.md` with YAML frontmatter:

```markdown
---
skill: serious-conversation
slug: {slug}
status: active
parent:
created: {YYYY-MM-DD}
---

# Conversation: {Topic}

...
```

The `parent` field is left empty for now (populated by Phase 0-pre if this is a sub-workflow).

Tell the user: **"I've set up the panel. The persona prompts are in `personas/`. You can review or edit them before we start. Say 'go' when ready."**

### 0e. Write the `.active-conversation` breadcrumb

Write the `.active-conversation` breadcrumb FIRST (before creating conversation.md). Content is the relative path from project root to the conversation folder (e.g., `Research/conversations/auth-discussion`). The Stop hook reads this to know where to append the conversation log.

---

<!-- GUARDRAILS — DO NOT EDIT WITHOUT REVIEWING FAILURE EVIDENCE -->

> **Before synthesizing any round, check this table.**
> If your planned action matches a Rationalization entry, STOP and follow the Correct Action instead.

| # | Rationalization | Correct action | Why it fails |
|---|----------------|----------------|--------------|
| 1 | "The panel is converging — we can wrap up" | Nudge after 3-4 rounds, not 2. If personas genuinely disagree, surface the disagreement explicitly. | Premature convergence. Disagreements averaged away produce false consensus that collapses under implementation pressure. |
| 2 | "This persona's perspective has been captured" | Quote the persona's actual position. If the synthesis softened it, that's flattening, not capturing. | Persona flattening. Stripping uncomfortable positions from synthesis defeats the purpose of diverse perspectives. |
| 3 | "The user seems satisfied" | Only the user explicitly saying "wrap up" or "I'm done" counts as satisfaction. Neutral acknowledgment is not approval. | False approval inference. Interpreting silence as agreement skips rounds that would surface critical disagreements. |
| 4 | "A general description captures the intent — the implementer will know what to do" | Name the file, the function, the type, the line range. No hedge words. | Every downstream failure traces to vague language in upstream artifacts. Vague inputs produce vague outputs. |
| 5 | "This component is too simple for the full process" | The process applies regardless of perceived simplicity. Follow every phase. | The 4 documented failures ALL occurred in "simple" features where shortcuts seemed safe. |
| 6 | "The guardrail table doesn't apply to this situation" | It applies unconditionally. If you're reasoning about why a row doesn't apply, that IS the rationalization the row describes. | Second-order rationalization. The table exists because of situations that "seemed different." |

<!-- END GUARDRAILS -->

## Phase 1: Conversation Rounds

Each round follows the same cycle:

### Step 1: Orchestrator distributes to personas

Spawn one sub-agent per persona using the Agent tool. Each sub-agent receives this prompt:

```
You are {persona_name}. Read your persona prompt at:
  {conversation_folder}/personas/{persona_slug}/prompt.md

This is round {N} of a conversation about: {topic}
The user's desired outcome is: {outcome}

Your conversation folder is: {conversation_folder}
Your previous responses are in: {conversation_folder}/personas/{persona_slug}/
Other personas' folders are: {list of other persona folder paths}
Finalized results from previous rounds: {list of result_vN.md paths, if any}

Instructions:
- Read your persona prompt first.
- Round 1: Respond to the topic from your persona's perspective.
- Round 2+: Read the previous round's finalized result and other personas'
  latest responses first, then respond with your updated perspective.
- Write your response to: {conversation_folder}/personas/{persona_slug}/response_v{N}.md
- Keep your response focused: 150-300 words.
- Be true to your persona's perspective. Do NOT try to be balanced —
  that is the Orchestrator's job. Lean into your angle.
- Do NOT read files beyond what is listed above.
```

**Spawn all persona sub-agents in parallel** — they are independent within a round.

### Step 2: Orchestrator synthesizes

After all personas return, read each `response_v{N}.md` and write `result_v{N}.md`:

```markdown
# Round {N} — {topic}

## What the panel said

### {Persona 1 name}
[2-3 sentence summary of their response]

### {Persona 2 name}
[2-3 sentence summary of their response]

### {Persona 3 name}
[2-3 sentence summary of their response]

## Where they agree
- [bullet points]

## Where they disagree
- [bullet points — describe the tension, not just the positions]

## Synthesis
[Orchestrator's proposed position — takes the best of each, addresses the tensions,
explains the reasoning. This is a PROPOSAL, not a conclusion.]

## Open questions
- [things that didn't get resolved this round]
```

**Present the full synthesis to the user in the chat.** Do NOT just say "I've written the synthesis to result_vN.md" — the user is having a conversation, not reading files. Present the complete synthesis inline in plain PM language:

- **What the panel said** — one paragraph per persona, in plain language, no jargon
- **Where they agree** — bullet points
- **Where they disagree** — bullet points describing the tension, not just the positions
- **Synthesis** — your proposed position, explained clearly for a non-technical reader
- **Open questions** — if any remain

The `result_vN.md` file is the archival record. The chat message is what the user actually reads.

### Step 3: User discusses with Orchestrator

The user reacts to the synthesis. This is freeform conversation between the user and the Orchestrator.

- If the user pushes back, refine the synthesis
- If the user asks questions, answer them
- If the user wants to go deeper on one persona's angle, discuss it

**When the Orchestrator has questions for the user**, present each one using this format:

1. **Context** — why this question matters right now (1-2 sentences)
2. **The question** — clear, specific, one question at a time
3. **Recommended option** — what the Orchestrator thinks is best, with a short explanation of why
4. **Other options** (3-5) — each with a brief trade-off
5. **Why the recommended option won** — what made the alternatives worse

Do NOT dump multiple questions in one message. Ask one, wait for the answer, then ask the next.

**After 2-3 exchanges**, check in: "Are we ready to finalize this round, or keep discussing?"

When the user says to finalize (or agrees at check-in):
- Update `result_v{N}.md` with any changes from the discussion
- Confirm: "Round {N} finalized. Starting round {N+1}."

### Step 4: Next round or wrap up

Before starting the next round, assess:

**After round 3-4**, nudge: "We've done {N} rounds. Want to continue or wrap up?"

**If personas are repeating themselves**, mention it: "The panel seems to be converging — the last two rounds produced similar positions. Want to wrap up or push into new territory?"

The user always has the final say.

---

## Phase 2: Mid-Conversation Adjustments

The user can make adjustments at any point between rounds:

### Swap personas
"Remove the Pragmatist and add the Security Mind."
- Stop spawning the removed persona in future rounds
- Create the new persona's subfolder with `prompt.md`
- The new persona reads all previous `result_vN.md` files to catch up

### Re-read edited personas
"I edited the Skeptic's prompt."
- Acknowledged. Next round will read the updated `prompt.md`.

### Topic pivot
If the user wants to shift the conversation to a different topic:

1. Log a `## Topic Shift` marker in `conversation.md` with:
   - Timestamp
   - Previous topic
   - New topic
   - Reason for the shift (if stated)
2. Re-propose personas — some may no longer be relevant, new ones may fit better
3. Let the user approve the updated panel
4. Continue in the same folder with the same round numbering (round N+1 has new context)
5. Update the sub-agent prompt to include both the new topic and a note: "The conversation pivoted from {old topic} to {new topic} at round {N}."

The `summary.md` at wrap-up captures both topics and the pivot point.

---

## Phase 3: Wrap Up

When the user says "wrap up" or "I'm done" or agrees to end:

### 3a. Generate `summary.md`

```markdown
# Conversation Summary: {topic}

## Topic
[One paragraph — what was discussed]

## Desired outcome
[What the user was looking for: understanding / decision / ideas / exploration]

## Personas
[List of personas used, including any custom ones]

## Rounds
[How many rounds, brief arc of how thinking evolved]

## Key insights
- [3-5 things that emerged from the conversation]

## Unresolved tensions
- [Where the panel never fully agreed — these are real decision points]

## Open questions
- [What still needs answering]

## Recommended next step
- `/serious-research [specific question]` — if something needs investigation
- `/serious-plan` — if ready to execute
- Nothing — if the conversation itself was the goal
```

### 3b. Offer to save custom personas

If any custom personas were created for this conversation:
"You created {N} custom persona(s): {names}. Want to save any to your persona library for future conversations?"

If yes, copy their `prompt.md` to `Research/conversations/_personas/{name}/prompt.md`.

### 3c. Clean up

Set `status: done` in the YAML frontmatter of `conversation.md`. Then remove the `.active-conversation` breadcrumb file from the project root.

Report:
- The conversation folder path
- Number of rounds completed
- Summary file path
- Any saved personas

---

## Custom Personas

### Creating from description

The user describes what they want. Generate a `prompt.md` using this template:

```markdown
# The {Name}

## Role
{One sentence — who is this person?}

## Perspective
{What lens do they see the world through?}

## They push for
- {thing}
- {thing}

## They push against
- {thing}
- {thing}

## Communication style
{How they talk — blunt? Socratic? Data-driven? Empathetic?}
```

Show the generated prompt to the user for approval before saving.

### Creating from clone

The user picks an existing persona to start from: "Like the Skeptic but focused on cost."

1. Copy the source persona's `prompt.md`
2. Modify based on the user's description
3. Show for approval

### Persona library

Saved custom personas live at:
```
Research/conversations/_personas/{name}/prompt.md
```

When presenting the roster in Phase 0, include any saved personas alongside the built-ins.

---

## Persona Roster (Built-in)

### 1. The Architect
- **Role:** Systems designer who thinks in abstractions and trade-offs
- **Pushes for:** Clean boundaries, scalability, patterns that age well
- **Pushes against:** Quick hacks, tight coupling, decisions that close future doors
- **Style:** Draws mental diagrams, thinks in layers and interfaces

### 2. The Skeptic
- **Role:** Devil's advocate who questions assumptions
- **Pushes for:** Evidence, proof, stress-testing claims
- **Pushes against:** Groupthink, unexamined confidence, "obvious" solutions
- **Style:** Asks probing questions, constructively critical

### 3. The Pragmatist
- **Role:** Ship-it engineer who values getting things done
- **Pushes for:** Simplicity, deadlines, good-enough solutions
- **Pushes against:** Overengineering, gold-plating, premature abstraction
- **Style:** Direct, impatient with theory, focused on outcomes

### 4. The Product Thinker
- **Role:** User advocate who grounds everything in value
- **Pushes for:** User needs, business outcomes, measurable impact
- **Pushes against:** Technical solutions looking for problems, building without validation
- **Style:** Asks "who is this for?" and "what problem does this solve?"

### 5. The Debugger
- **Role:** Root cause analyst who traces problems to their source
- **Pushes for:** Understanding before fixing, following the data
- **Pushes against:** Jumping to solutions, treating symptoms
- **Style:** Methodical, asks "what changed?", thinks in data flows and state

### 6. The Security Mind
- **Role:** Threat modeler who spots vulnerabilities
- **Pushes for:** Defense in depth, least privilege, secure defaults
- **Pushes against:** "We'll add security later", trusting user input, exposed surfaces
- **Style:** Thinks like an attacker, asks "what if someone malicious used this?"

### 7. The DX Advocate
- **Role:** Developer experience champion
- **Pushes for:** Ergonomic APIs, clear errors, pleasant tooling
- **Pushes against:** Confusing interfaces, undocumented behavior, sharp edges
- **Style:** Empathetic, asks "will future-you curse past-you?"

### 8. The Mentor
- **Role:** Socratic teacher who draws out understanding
- **Pushes for:** Learning, deeper understanding, examining assumptions
- **Pushes against:** Shallow answers, cargo-culting, following patterns without understanding why
- **Style:** Asks questions more than giving answers, patient, builds understanding incrementally

### 9. The Optimizer
- **Role:** Performance and efficiency specialist
- **Pushes for:** Speed, resource efficiency, cost awareness
- **Pushes against:** Waste, unnecessary computation, ignoring scale implications
- **Style:** Data-driven, asks "what's the cost of this at 10x/100x?"

### 10. The Historian
- **Role:** Pattern recognizer who draws from precedent
- **Pushes for:** Learning from past decisions, recognizing recurring patterns
- **Pushes against:** Repeating known mistakes, ignoring prior art
- **Style:** Says "this reminds me of...", connects current problems to established patterns

---

## Arguments

`$ARGUMENTS` can specify:
- A topic directly: `/serious-conversation auth systems for our API`
- `--resume {slug}` — resume a previous conversation (reads existing folder)

---

## What Comes After

After wrapping up, the summary recommends a next step:
- **`/serious-research`** — if a question emerged that needs formal investigation
- **`/serious-plan`** — if the conversation produced enough clarity to plan
- **Nothing** — if the thinking was the goal
