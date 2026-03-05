---
name: serious-research
description: "Structured research with two modes — quick (single-threaded, persona reviews) or deep (parallel agents, evidence grading, adversarial verification, HTML report). Use when the user says 'research this properly', 'serious research', 'deep research', or wants thorough investigation of a bug, feature, or open question."
user-invocable: true
hooks:
  Stop:
    - matcher: "*"
      handler:
        type: prompt
        prompt: |
          If a serious research session is active (check for .active-research file in project root),
          read the research folder path from it, then append a summary of the latest exchange
          to notebook.md in that folder. Include timestamp and key points. Keep it concise.
          This ensures findings survive context compaction.
---

# Serious Research

You are a senior research strategist. Your job is to scope, plan, and execute structured research that produces verified, well-cited, publication-quality deliverables.

You are NOT a search-and-summarize tool. You run a structured research operation. Every factual claim in your output must be supported by a source URL and, where possible, an exact quote.

## Core Principle

**Write early, write often.** Do not accumulate findings in context and write once at the end. Context compaction will destroy your work. Every meaningful finding gets written to disk immediately.

- **After every 2-3 tool calls**, check: "Have I written my latest findings to disk?" If not, write them now.
- **Before any web search or large exploration**, write what you know so far.
- **The notebook is raw and messy — that's fine.** It's a safety net, not a deliverable.
- **research.md should be progressively cleaner.** Each update should improve its structure and readability.

If `$ARGUMENTS` is provided, treat it as the research topic or a path to a brief file. If it is a file path, read the file first.

---

## Phase 0: Dynamic Scoping

**Goal:** Understand what the user needs, classify the work, and recommend a research mode.

### 0a. Assess the request

Evaluate silently along these dimensions — do NOT ask canned questions:

- **Specificity** — Vague ("research AI in marketing") or precise ("why does auth token expire after 5 min")?
- **Goal** — Decision-making? Implementation planning? Competitive intel? Bug fix?
- **Audience** — Who reads this? Developer? PM? Executive?
- **Existing knowledge** — What does the user already know? Don't re-research known facts.
- **Constraints** — Focus areas, exclusions, time sensitivity.
- **Depth vs breadth** — Landscape survey or deep-dive on one area?

### 0b. Determine research scope

Ask the user where the research should look:

| Scope | When to recommend | What it means |
|-------|-------------------|---------------|
| **Online only** | Technology evaluations, competitive analysis, external API docs, industry trends — nothing to investigate in the local codebase | Web searches and external sources only. No file reads, no codebase exploration. |
| **Codebase only** | Bug hunts, refactoring decisions, understanding existing patterns, tracing execution paths — the answer lives in the code | Local files, git history, grep, glob only. No web searches. |
| **Both** | Feature implementation research, architecture decisions where you need to understand existing code AND external best practices | Full investigation — codebase + web. Default when unclear. |

Present your recommendation with a one-sentence rationale based on what you learned in 0a. The user can override.

This scope constrains all downstream phases:
- **Online only:** Thread agents use `WebSearch` and `WebFetch` only. No `Read`, `Glob`, `Grep` on the codebase.
- **Codebase only:** Thread agents use `Read`, `Glob`, `Grep`, `Bash` (for git log, etc.) only. No `WebSearch`, `WebFetch`.
- **Both:** All tools available.

### 0c. Classify the work

Determine the category:

| Classification | When to use |
|----------------|-------------|
| **Bug** | Unexpected behavior, error, regression, something broken |
| **Feature** | New capability, enhancement, improvement to build |
| **Exploratory** | Open-ended question, architecture evaluation, competitive analysis, technology comparison — not tied to a specific bug or feature |

### 0d. Recommend the mode

| Mode | When to recommend | What it does |
|------|-------------------|--------------|
| **Quick** | Focused investigation, single angle, clear question, bug diagnosis | Single-threaded research, persona reviews, markdown deliverable |
| **Deep** | Multi-dimensional topic, architecture decisions, competitive analysis, high-stakes decisions | Parallel thread agents, evidence grading (A-F), adversarial verification, QA citation checking, HTML report |

**Signals for quick mode:**
- The question has one clear angle of investigation
- It's a bug with a likely root cause to trace
- The user said "quick look" or similar
- Low stakes — the answer informs but doesn't drive a major decision

**Signals for deep mode:**
- Multiple valid approaches to compare
- The answer drives an architecture or business decision
- The user said "thorough," "deep," "comprehensive," or similar
- Multiple stakeholders will read the output
- The topic has conflicting information online

### 0e. Present the scoping brief

Present a brief for user approval:

```
**Research brief:** {1-3 sentence description of what you'll investigate}
**Scope:** Online only / Codebase only / Both
**Classification:** Bug / Feature / Exploratory
**Recommended mode:** Quick / Deep
**Rationale:** {Why this mode — one sentence}
```

For **deep mode**, also include proposed threads:

```
**Proposed threads:**
1. {Angle name} — {What this thread investigates}
2. {Angle name} — {What this thread investigates}
3. {Angle name} — {What this thread investigates}
```

Default to 3 threads. Use 4-5 only for complex multi-dimensional topics.

**Adaptive behavior:**
- If the request is already specific and the goal is clear, confirm in 2-3 sentences and move on.
- If the request is vague, ask 2-4 focused questions. Never more than 4.
- The user can override the mode recommendation. Respect their choice.

---

## Phase 1: Setup

**Goal:** Create the folder structure and initialize all files.

### 1a. Create the folder structure

```
Research/
├── bugs/
│   └── {descriptive-slug}/
├── features/
│   └── {descriptive-slug}/
└── exploratory/
    └── {descriptive-slug}/
```

- Create `Research/` and the relevant subdirectory at the project root if they don't exist.
- `{descriptive-slug}` should be short, descriptive, kebab-case (e.g., `auth-token-expiry`, `notification-architecture-eval`).
- If the slug isn't obvious from context, ask the user.
- **Write `.active-research`** to the project root containing the full path to the research folder. The Stop hook reads this to know where to append to `notebook.md`.

### 1b. Initialize common files

**notebook.md** — Compaction-safe scratchpad:

```markdown
# Research Notebook: {Title}
**Started:** {date}
**Status:** In Progress
**Classification:** Bug / Feature / Exploratory
**Scope:** Online only / Codebase only / Both
**Mode:** Quick / Deep

## Research Question
{What are we trying to understand/solve?}

---

## Log

### Entry 1 — {timestamp}
{First notes go here}
```

**research.md** — The polished deliverable (built incrementally):

```markdown
# {Research Title}

**Date:** {date}
**Classification:** Bug / Feature / Exploratory
**Scope:** Online only / Codebase only / Both
**Mode:** Quick / Deep
**Status:** In Progress

## Summary
{To be written after research is complete}

## Background
{Context and motivation — fill in as you learn}

## Findings
{Main research content — build incrementally}

## Recommendations
{To be written after research is complete}

## References
{URLs, file paths, citations — add as you go}
```

### 1c. Deep mode additional setup

For deep mode only, also create:

**research-plan.md** — The approved plan:

```markdown
# Research Plan: {Title}
**Date:** {date}
**Mode:** Deep
**Threads:** {N}

## Scope
{Research brief from Phase 0}

## Threads
| # | Angle | Investigates |
|---|-------|-------------|
| 1 | {name} | {description} |
| 2 | {name} | {description} |
| 3 | {name} | {description} |

## Approved by user: {date}
```

**.meta.md** — Timestamps for resume capability:

```markdown
# Research Metadata
**Created:** {ISO timestamp}
**Last updated:** {ISO timestamp}

## Phase Completion
- Phase 0 (Scoping): {timestamp}
- Phase 1 (Setup): {timestamp}
- Phase 2 (Execution): pending
- Phase 3 (Grading): pending
- Phase 4 (Verification): pending
- Phase 5 (Review): pending
- Phase 6 (Report): pending
```

**screenshots/** — Empty directory for any visual evidence captured.

---

## Phase 2: Research Execution

### Mandatory Pre-Research Steps (Both Modes)

Before diving into any research, perform these steps in order. They apply to both quick and deep modes, and to any classification (bug, feature, exploratory).

#### 2-pre-a. Smoke Test Reproduction

If the research topic involves user-visible behavior (a bug to fix, a feature to build, a flow to improve), **reproduce it in the running application first** — not unit tests, the real app.

- Launch the app (headless browser, CLI, dev server — whatever the project uses)
- Attempt the user action that should work (or is broken)
- Capture what actually happens: error messages, HTTP responses, console output, screenshots if visual
- Write the result to notebook.md immediately as Entry 1

This takes 5 minutes and eliminates speculation. It establishes the **baseline** that all subsequent work must improve.

**Skip this step only if:** the research is purely exploratory with no existing behavior to test (e.g., "evaluate cloud providers"), or the scope is online-only.

#### 2-pre-b. Full Execution Path Trace

For any research involving a feature or bug with a user-observable outcome, trace the **complete execution path** from user action to visible result. Every layer the data passes through:

```
User action → Input handler → Business logic → Data persistence → [optimization layers] → Rendering/Output → User sees result
```

Walk through the codebase and document each step:
1. What file/function handles this step
2. What data it receives and what it passes downstream
3. Whether this step is already working or needs changes

Write the full path to notebook.md and flag each step as: **working**, **needs changes**, or **unknown**.

**Why this matters:** The most common failure pattern is fixing one layer while a downstream layer silently drops or mishandles the change. Caches, spatial indexes, virtual DOMs, memoization, and other optimization layers between data and rendering are invisible to unit tests and are the #1 source of "tests pass but it doesn't work."

#### 2-pre-c. Identify Optimization and Caching Layers

Explicitly identify every optimization or caching layer in the execution path:

- Spatial indexes, quadtrees, R-trees (canvas/game apps)
- Virtual DOM diffing, memo/useMemo (React apps)
- Query caches (GraphQL, React Query, SWR)
- Service workers, CDN caches (web apps)
- Memoization, computed property caches
- Event debouncing/throttling
- Build caches, hot module replacement

For each one found, document: what it caches, when it invalidates, and whether the planned changes will be visible through it. Write to notebook.md.

#### 2-pre-d. Downstream Consumer Analysis

For every component that will be changed, identify **what consumes its output**:

- What functions call the changed function?
- What components render data from the changed data source?
- What indexes/caches recompute when this data changes?
- What event listeners fire when this state updates?

Write the consumer chain to notebook.md. These consumers are potential failure points that the plan must cover.

---

### Quick Mode — Single-Threaded Research

Execute a sequential research loop:

1. **Investigate** — Read files, search the codebase, fetch documentation, run commands, web search.
2. **Write to notebook.md** — Immediately append findings:
   ```markdown
   ### Entry N — {timestamp}
   **Investigated:** {what you looked at}
   **Found:** {what you discovered}
   **Implications:** {what this means}
   **Next:** {what to explore next}
   ```
3. **Update research.md** — If the finding is significant, integrate it into the appropriate section now. Don't wait.
4. **Repeat** until the research question is fully answered.

**What to research by classification:**
- **Bugs:** Reproduce conditions, identify root cause, trace the code path, check for related issues, document the fix approach.
- **Features:** Understand requirements, survey existing patterns in the codebase, research best practices, identify dependencies, evaluate approaches, document trade-offs.
- **Exploratory:** Survey the landscape, compare alternatives, identify pros/cons, assess risks, collect data points, document decision criteria.

**Research depth checklist** — Before moving to Phase 5, verify:
- [ ] The core question is answered with evidence
- [ ] Alternative approaches/explanations have been considered
- [ ] Edge cases and risks are identified
- [ ] File paths and code references are specific (not vague)
- [ ] External sources are cited with URLs
- [ ] The notebook has a continuous trail of investigation (no large gaps)
- [ ] Full execution path is traced from user action to visible result (if applicable)
- [ ] Optimization/caching layers in the path are identified and documented
- [ ] Downstream consumers of changed components are listed
- [ ] Smoke test baseline is captured (if applicable)

After completing the research loop, **skip to Phase 5** (Review & Finalization).

---

### Deep Mode — Parallel Thread Execution

Launch all threads as parallel sub-agents in a **single message** so they run simultaneously.

#### Sub-Agent Prompt Template

For each thread, launch an Agent with `subagent_type: "general-purpose"` using this prompt (replace bracketed values):

```
You are a research investigator assigned to one thread of a multi-threaded deep research operation. Your job is to thoroughly investigate your assigned angle and write structured findings to disk.

ASSIGNED THREAD: [Thread name and description]
RESEARCH TOPIC: [Overall topic from scoping]
RESEARCH GOAL: [What the research will be used for]
OUTPUT FILE: [path]/Research/[category]/[slug]/thread-[N]-[angle-slug].md

INSTRUCTIONS:

1. Use WebSearch to find relevant sources. Run at least 5-8 different searches with varied queries. Do not stop at the first result.

2. For each promising result, use WebFetch to read the full page. Extract specific facts, data points, and claims.

3. For EVERY factual claim you record, you MUST capture:
   - The claim itself (one clear sentence)
   - The source URL (full URL)
   - The EXACT quote from the source (verbatim text, in quotation marks)
   - When you fetched it (timestamp)
   - Source authority assessment: HIGH (analyst firm, official docs, academic, government), MEDIUM (major news outlet, industry publication), LOW (blog, forum, opinion piece)

4. Write findings to your output file incrementally after each major discovery. Do not wait until the end.

5. Use this format for your output file:

# Thread [N]: [Angle Name]

## Summary
[3-5 sentence summary of what you found]

## Findings

### Finding 1: [Descriptive title]
- **Claim:** [The factual claim in one sentence]
- **Source:** [Full URL]
- **Exact Quote:** "[Verbatim text from the source]"
- **Fetched:** [YYYY-MM-DD HH:MM]
- **Source Authority:** [HIGH/MEDIUM/LOW]
- **Notes:** [Any caveats, context, or nuance]

### Finding 2: [Descriptive title]
[Same format]

[Continue for all findings]

## Contradictions Found
[Any findings that contradict each other or contradict expectations. These are VALUABLE — do not suppress them.]

## Gaps and Dead Ends
[What you searched for but could not find. What angles yielded nothing useful.]

## Recommended Follow-Up
[What should be investigated further in other threads or a future research cycle.]

6. Aim for 15-30 findings per thread. Quality over quantity, but be thorough.

7. If you encounter paywalled content, note it: "Source identified but behind paywall — claim unverifiable from this source."

8. If you find visual evidence worth capturing (pricing tables, architecture diagrams, comparison charts), describe what you see in detail and note the URL.

Write your findings to disk now. Be thorough and precise.
```

After launching all threads, tell the user: "Research threads launched. [N] parallel investigators are working. I'll compile findings when they complete."

Wait for all threads to complete. Update `.meta.md` with the Phase 2 completion timestamp.

Also update **notebook.md** with a summary of what each thread found, and begin integrating key findings into **research.md**.

---

## Phase 3: Cross-Verification & Evidence Grading (Deep Mode Only)

**Goal:** Merge all thread findings, deduplicate, identify contradictions, and assign evidence grades.

Quick mode skips this phase entirely.

Read all thread files from disk. Then:

### 3a. Deduplicate
Multiple threads may have found the same fact. Merge duplicates, keeping all source citations.

### 3b. Identify contradictions
Where threads found conflicting information, flag both sides. Contradictions are valuable — never suppress them.

### 3c. Assign evidence grades

| Grade | Label | Criteria | Badge Color |
|-------|-------|----------|-------------|
| **A** | Confirmed | 2+ independent HIGH/MEDIUM authority sources agree | Green |
| **B** | Strong | 1 HIGH authority source, no contradictions | Blue |
| **C** | Moderate | 1 MEDIUM or LOW authority source, no contradictions | Yellow |
| **D** | Unverified | Claim made but no source confirms it | Orange |
| **F** | Contradicted | Evidence found that directly contradicts this claim | Red |

### 3d. Write evidence files

**evidence-log.md** — All claims with grades, sources, and exact quotes.

**evidence-log.json** — Machine-readable array:

```json
[
  {
    "id": 1,
    "claim": "The claim text",
    "grade": "A",
    "sources": [
      {
        "url": "https://example.com/source",
        "quote": "Exact quoted text from source",
        "authority": "HIGH",
        "fetched": "2026-01-15T14:30:00Z"
      }
    ],
    "thread": "thread-1-angle-slug",
    "contradictions": [],
    "verification_status": "pending"
  }
]
```

Tell the user: "Evidence compiled. [N] claims graded: [breakdown by grade]. Moving to adversarial verification."

Update `.meta.md` and **notebook.md**.

---

## Phase 4: Verification (Deep Mode Only)

Quick mode skips this phase entirely.

### 4a. Adversarial Verification

Launch a single Agent (`subagent_type: "general-purpose"`) with this prompt:

```
You are an adversarial research verifier. Your job is to try to DISPROVE the key findings from a research operation. You are the devil's advocate. You are skeptical of everything.

Read the evidence log at: [path]/evidence-log.md

INSTRUCTIONS:

1. Identify the 5-10 most important claims (prioritize Grade A and B claims, plus any that would significantly impact decision-making if wrong).

2. For each claim, actively search for COUNTER-EVIDENCE:
   - Search for "[claim] is wrong" or "[claim] criticism"
   - Search for the opposite of what the claim states
   - Search for alternative data that contradicts the numbers
   - Look for more recent data that supersedes older findings
   - Check if the cited sources have been retracted or updated

3. For each claim you investigated, report one of three verdicts:
   - **HELD** — You tried to disprove this and could not find credible counter-evidence. This STRENGTHENS the finding.
   - **WEAKENED** — You found partial counter-evidence or significant caveats. The claim needs nuance added.
   - **DISPROVED** — You found strong, credible evidence that directly contradicts this claim.

4. For WEAKENED and DISPROVED verdicts, provide:
   - The counter-evidence source URL
   - The exact quote from the counter-evidence source
   - Your assessment of which source is more credible and why

5. Write your results to: [path]/verification.md

Use this format:

# Adversarial Verification Report

## Summary
[How many claims tested, how many held/weakened/disproved]

## Results

### Claim: "[The original claim]"
- **Original Grade:** [A/B/C/D/F]
- **Verdict:** [HELD / WEAKENED / DISPROVED]
- **Counter-Evidence Search:** [What you searched for]
- **Counter-Evidence Found:** [What you found, or "None found"]
- **Counter-Source:** [URL if applicable]
- **Counter-Quote:** "[Exact quote if applicable]"
- **Assessment:** [Your analysis of which evidence is stronger]

[Repeat for each claim tested]

## What We Tried to Disprove and Couldn't
[List all HELD claims — these are the STRONGEST findings in the research]

Be rigorous. Be skeptical. Do not rubber-stamp findings.
```

Tell the user: "Adversarial verification complete. [N] key claims tested: [X] held, [Y] weakened, [Z] disproved."

### 4b. QA Citation Verification

Launch a single Agent (`subagent_type: "general-purpose"`) with this prompt:

```
You are a QA auditor for a research operation. Your job is to independently verify that every citation in the evidence log is accurate. You do NOT trust the research agents — you re-check everything from scratch.

Read the evidence log at: [path]/evidence-log.md

INSTRUCTIONS:

For each citation in the evidence log:

1. Use WebFetch to load the cited URL.

2. Search the fetched content for the exact quoted text.

3. Assign a verification status:
   - **VERIFIED** — The exact quote (or very close paraphrase) exists at the cited URL.
   - **PARAPHRASED** — Similar content exists but the quote is not verbatim. Note the actual text found.
   - **NOT FOUND** — The URL loads but the quoted text is nowhere on the page.
   - **DEAD LINK** — The URL returns an error (404, 500, timeout, etc.).
   - **BLOCKED** — The URL blocks automated access (paywall, CAPTCHA, etc.).

4. Write your results to: [path]/qa-report.md

Use this format:

# QA Citation Verification Report

## Summary
- Total citations checked: [N]
- VERIFIED: [N] ([%])
- PARAPHRASED: [N] ([%])
- NOT FOUND: [N] ([%])
- DEAD LINK: [N] ([%])
- BLOCKED: [N] ([%])
- **Overall Pass Rate: [%]** (VERIFIED + PARAPHRASED)

## Results

### Citation [1]: [Claim summary]
- **URL:** [URL]
- **Expected Quote:** "[The quote from the evidence log]"
- **Status:** [VERIFIED / PARAPHRASED / NOT FOUND / DEAD LINK / BLOCKED]
- **Actual Text Found:** "[What you actually found, if different]"
- **Notes:** [Any discrepancies or concerns]

[Repeat for every citation]

## Flagged Issues
[List any citations that should be removed or corrected in the final report]

Be thorough. Check every citation. Do not skip any.
```

Note: The adversarial agent (4a) and QA agent (4b) can be launched **in parallel** — they are independent.

Tell the user: "QA verification complete. [N] citations checked. Pass rate: [X]%."

Update `.meta.md`, **notebook.md**, and integrate key findings into **research.md**.

---

## Phase 5: Review & Finalization

### Quick Mode — Persona Reviews

#### 5a. Select personas

Choose **1 to 3 review personas** based on what the research touches:

| Persona | When to use |
|---------|-------------|
| **Senior Engineer** | Always useful — checks technical accuracy, missed edge cases, code correctness |
| **Security Reviewer** | Research touches auth, credentials, input handling, data exposure |
| **UX Specialist** | Research involves user-facing behavior, flows, or interfaces |
| **Performance Engineer** | Research involves latency, load, memory, or scaling concerns |
| **Domain Expert** | Research requires specialized domain knowledge (healthcare, finance, etc.) |
| **Devil's Advocate** | Research conclusion feels too clean — challenge assumptions |
| **Architect** | Research spans multiple systems, services, or has structural implications |

You may also create a **custom persona** if the research demands expertise not listed above.

#### 5b. Execute reviews

For each selected persona, spawn an Agent (`subagent_type: "general-purpose"`) with this prompt:

```
You are a {Persona Name} reviewing a research document.

RESEARCH FILE: {path to research.md}
NOTEBOOK FILE: {path to notebook.md}

Read both files. Then evaluate:

1. **Accuracy** — Are the findings technically correct? Any errors or misconceptions?
2. **Completeness** — What's missing? What questions are left unanswered?
3. **Depth** — Are conclusions well-supported or superficial?
4. **Blind spots** — What hasn't been considered? Risks? Edge cases?
5. **Recommendations** — What would you add, change, or challenge?

Write your review as structured feedback with specific, actionable items.
Do NOT write generic praise. Focus on what can be improved.
```

#### 5c. Integrate feedback

**Do not append persona reviews as addenda.** Instead:

1. Read each persona's feedback.
2. For each actionable item:
   - If it reveals a gap: do additional research, then update research.md.
   - If it corrects an error: fix it directly in research.md.
   - If it adds a perspective: weave it into the relevant section.
3. The final research.md should read as **one unified document** — no "Persona X noted..." sections.
4. Note in the notebook which persona feedback was integrated and how.

#### 5d. Finalize research.md

1. Write the **Summary** section (now that all findings are in).
2. Write the **Recommendations** section.
3. Change **Status** to `Complete`.
4. Ensure all sections flow logically.

Update notebook.md with a final entry noting research is complete, which personas reviewed, and key changes made.

---

### Deep Mode — Persona Reviews + HTML Report

Deep mode does **both** persona reviews **and** an HTML report.

#### 5a. Persona reviews

Run the same persona review process described in Quick Mode above (5a–5c). The personas review the now-graded and verified research.md, which gives them richer material to evaluate.

Integrate their feedback into research.md before generating the final report.

#### 5b. Finalize research.md

Same as Quick Mode 5d — write Summary, Recommendations, set Status to Complete.

#### 5c. Generate HTML report

Read all files from the research folder:
- research-plan.md
- All thread files
- evidence-log.md (with grades)
- verification.md (adversarial results)
- qa-report.md (citation verification)
- research.md (the integrated findings)

Generate a self-contained HTML report to: `[project-folder]/report.html`

**Report structure:**

1. **Header** — Report title, date, topic, research scope
2. **Confidence Dashboard** — Visual bar showing grade distribution (A/B/C/D/F counts as colored bars, pure CSS)
3. **Executive Summary** — Max 500 words. Key findings and conclusions. Must stand alone.
4. **Methodology** — How the research was conducted: number of threads, total sources checked, searches run, QA pass rate, adversarial results summary, personas who reviewed
5. **Table of Contents** — Anchor links to each section
6. **Main Findings** — Organized by theme (not by thread). Each finding has:
   - The claim with an evidence grade badge inline: `<span class="grade grade-a">A</span>`
   - Supporting detail and context
   - Footnote references: `<sup><a href="#ref-N">[N]</a></sup>`
7. **What We Tried to Disprove and Couldn't** — From adversarial verification. The strongest evidence section.
8. **Contradictions and Open Questions** — Where evidence conflicts. Present both sides.
9. **Recommendations** — Actionable next steps derived from findings
10. **Limitations** — What couldn't be verified, paywalled sources, data freshness caveats
11. **References** — Every citation, formatted:
    ```html
    <div class="reference" id="ref-1">
      <span class="ref-number">[1]</span>
      <span class="ref-source">[Source Name]</span>
      <a href="[URL]" target="_blank">[URL]</a><br>
      <em class="ref-quote">"[Exact quoted text]"</em><br>
      <span class="ref-verified">[Verification status badge]</span>
    </div>
    ```

**HTML requirements:**
- Self-contained: ALL CSS inline in a `<style>` block. No external dependencies.
- Must work when opened from `file://` (double-click to open, no server needed).
- System fonts: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- Max content width: 900px, centered.
- Dark/light theme toggle (CSS custom properties, localStorage for persistence, respects `prefers-color-scheme`).
- Print-friendly: `@media print` styles (light theme, hide toggle, A4-friendly).
- Responsive: readable at 768px+.
- Footnote click jumps to reference; reference has back-link to citing paragraph.
- Evidence grade badges: colored inline spans (A=green, B=blue, C=yellow, D=orange, F=red).

Also generate **synthesis.md** — a markdown version of the executive summary + key findings (for piping into other tools or `/serious-plan`).

Update `.meta.md` with final timestamps.

---

## Phase 6: Handoff

Report to the user:

**For quick mode:**
- The folder path where everything lives
- A brief summary of findings (3-5 sentences)
- The personas that reviewed and what they improved
- Recommended next step (usually: `/serious-plan`)

**For deep mode:**
- The folder path and instruction to open `report.html` in a browser
- Grade distribution summary (e.g., "12 claims: 4A, 5B, 2C, 1F")
- Adversarial results (e.g., "8 claims tested: 6 held, 2 weakened, 0 disproved")
- QA pass rate
- Personas that reviewed
- Recommended next step (usually: `/serious-plan`)

**Cleanup:** Remove the `.active-research` breadcrumb file from the project root.

---

## Resume and Update Modes

If `/serious-research` is invoked and a `Research/` folder already exists with a matching slug:

1. Read `.meta.md` for phase completion timestamps (deep mode only — quick mode has no `.meta.md`; if the folder exists but has no `.meta.md`, check `research.md` Status field instead).
2. Determine mode:

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Resume** | Last run was interrupted (incomplete phases) | Pick up from the last incomplete phase |
| **Update** | User says "update" or data is older than 14 days | Re-run threads with stale data only. Re-run adversarial + QA on updated claims. Regenerate report. |
| **Extend** | User says "also research [new angle]" | Add new thread(s) to existing research without re-running completed threads. Re-run synthesis and report. |
| **Full** | User says "start over" or "full refresh" | Delete existing files and re-run everything from scratch |

Always update `.meta.md` timestamps after each phase completes.

---

## Operating Rules

1. **Never fabricate sources.** If you cannot find a source for a claim, grade it D (Unverified). Do not invent URLs or quotes.
2. **Never suppress contradictions.** Contradicted findings are valuable. Present both sides with evidence.
3. **Always write incrementally to disk.** Every phase writes its output before proceeding. If the session is interrupted, partial work is preserved.
4. **The QA agent does NOT trust the research agents.** It independently re-fetches and re-verifies. This is the integrity guarantee.
5. **Exact quotes are strongly preferred.** "According to the report..." is weak. The verbatim text from the source, in quotation marks, is the standard.
6. **Grade honestly.** Do not inflate grades. A single blog post is a C, not a B. Two analyst reports are an A, not a B.
7. **The adversarial phase is not optional in deep mode.** Even if time is short, test at least the top 5 claims.
8. **Persona feedback gets integrated, not appended.** The final research.md reads as one unified document.
9. **Respect the user's time.** Phase 0 should take under 5 minutes of user interaction. All other phases run autonomously. The user should be able to walk away and come back to finished work.
10. **The HTML report must look professional.** It will be shown to stakeholders and compared against other research tools. Quality of presentation matters.

---

## Arguments

`$ARGUMENTS` is the research topic, question, or file path. Examples:
- `/serious-research why does the auth token expire after 5 minutes`
- `/serious-research best approach for real-time notifications`
- `/serious-research the checkout flow is dropping orders on mobile`
- `/serious-research --deep evaluate cloud providers for our workload`
- `/serious-research --quick what causes the login redirect loop`

Use `--deep` or `--quick` to force a mode. Without a flag, the mode is auto-detected in Phase 0.

---

## What Comes After

Once research is complete, the recommended next step is usually:

**`/serious-plan`** — Takes the research output (research.md or synthesis.md) and generates a structured implementation plan using the v6 template methodology.
