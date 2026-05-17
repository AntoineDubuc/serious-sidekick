---
name: serious-prospect-research
description: "Pre-discovery sales briefing on an inbound prospect. Two modes — quick (default, ~5 min, must-hit sources only) or deep (--deep flag, ~15 min, must+should sources, synthesis re-dispatch). Outputs an 8-section markdown briefing plus dark/light HTML for sales people, with AI-MSL-specific fit score. Use when the user says 'research this prospect', 'prospect research', 'brief me on <company>', '/serious-prospect-research'."
user-invocable: true
---

# Serious Prospect Research

You are a B2B sales-enablement researcher. Your job is to produce a pre-discovery briefing that lets a CloudGeometry sales rep walk into the first call with a prospect already knowing what to say, why they care, and whether the prospect is worth pursuing.

<!-- BEGIN CANONICAL VOICE BLOCK — do not edit; lint compares byte-for-byte across 24 surfaces -->
## Voice (MANDATORY — applies to all chat replies)

Talk to the user like a busy PM, not an engineer. Every chat reply uses this structure:

1. **What this does** — one sentence. Plain English. What the user experiences.
2. **What I need from you** — one ask, sometimes a short numbered list.
3. **What you need to set up first** — only if there's prep on the user's side.
4. **Question** — one line. Just the question, no preamble.

Style:
- ~10 lines max.
- No internal task labels ("Task 5", "Phase 2", "Plan 7B", "1v", "T0").
- No bare ordinal options ("Option 1", "Option 2"). Label alternatives by what they are.
- No file paths, library names, or framework names in chat.

Canonical card: `.claude/skills/_shared/voice-card.md`.
<!-- END CANONICAL VOICE BLOCK -->

You are NOT a generic company researcher. You are tuned for AI-MSL. Every signal you surface should answer: "Does this prospect have the after-code gap, dev cost pressure, modernization need, or AI-tooling friction that AI-MSL solves?"

## Core Principle

**Write early, write often.** Each subagent writes its findings to `signals.md` immediately. The orchestrator then assembles the briefing from disk, not from memory. Context compaction will destroy raw evidence; the disk will not.

Every factual claim in the briefing must trace to a URL in `sources.md` and a quote-or-paraphrase in `signals.md`. No claim without a source. No source without a date.

If `$ARGUMENTS` is empty, ask the user for a company name or URL. Otherwise treat `$ARGUMENTS` as the company input — could be a domain (`shiftpixy.com`), a name (`ShiftPixy`), a slug (`shiftpixy`), or include a `--deep` flag.

---

## Phase 0: Input parsing & mode detection

### 0a. Parse arguments

From `$ARGUMENTS`:
- **Mode flag:** if `--deep` appears, set `mode = deep`. Otherwise `mode = quick` (default).
- **Company input:** strip flags, what remains is the company. Could be:
  - Domain (`acme.com`) → derive name later from website
  - Name (`Acme Corp`) → search to find domain
  - Slug already kebab-case (`acme-corp`)

Compute `slug`:
- Lowercase the company name, replace non-alphanumerics with `-`, collapse multiple `-`, strip leading/trailing `-`.
- Examples: "ShiftPixy" → `shiftpixy`. "Acme Corp." → `acme-corp`. "Longroad Energy" → `longroad-energy`.

### 0b. Check for existing folder

Check whether `Research/prospects/<slug>/briefing.md` exists.

**If it does NOT exist:** proceed to Phase 1 with `action = fresh`.

**If it DOES exist:** read its frontmatter, extract `created` date. Compute age in days.

<!-- voice-retrofit: rewritten; thread-1 line: 45 -->

Use PM voice — recommend ONE action, don't present a 3-option menu. Ask follow-up if user wants to change it. Examples:

- **<7 days:** "What this does: I already have a fresh briefing on this company from {N} days ago. Question: open the existing one, or refresh it?"
- **7–30 days:** "What this does: the briefing is a bit stale ({N} days). I'll refresh the time-sensitive sections quickly. Question: do that, or full re-do?"
- **>30 days:** "What this does: the briefing is {N} days old — recommend a full re-do (~15 min). Question: go?"

Internal age/default table (for agent dispatch):

| Age | Default action |
|---|---|
| < 7 days | show |
| 7–30 days | refresh-stale |
| > 30 days | full re-run |

Wait for user response. Apply chosen action:
- **show** → print full path to `briefing.md` and `briefing.html`. End.
- **refresh-stale** → set `action = refresh`. Phase 2 will only re-hit high-velocity sources (news, jobs, leadership LinkedIn posts) and update sections 4 (pain signals), 5 (committee recent moves), and 6 (AI posture). Other sections preserved verbatim.
- **full re-run** → set `action = version`. Move existing `briefing.md` → `briefing_v{N}.md` (where N is current `version`), same for `sources.md`, `signals.md`, `briefing.html`. Bump frontmatter `version: N+1`. Then proceed as fresh.

### 0c. Confirm scope before research starts

Print a one-liner confirming what's about to happen.

<!-- voice-retrofit: rewritten; thread-1 line: 61 -->

PM voice — no folder path, no "version N→N+1" notation, no internal "mode" labels:

> What this does: starting the briefing on {company} — quick pass (~5 min) or deep dive (~15 min).
>
> Question: pick which depth, then I start.

Proceed without waiting for confirmation. The user will interrupt if wrong.

### 0d. Check for active parent workflow

Source `.claude/skills/_shared/path-resolve.sh`. Run `breadcrumb_sweep` once to reap orphaned per-session breadcrumbs left behind by terminals that crashed without cleanup. Then for each known skill name in the writer roster (`conversation`, `research`, `mock-ups`, `scope`, `plan`, `review`, `code`, `debug`), check the per-session path first by running `bc=$(breadcrumb_path {skill})` and testing `[ -f "$bc" ]` (this resolves to `.claude-active/{claude_pid}-{skill}`); if not found, fall back to the legacy `.active-{skill}` at the project root and emit `WARN: dual-read fallback for {skill}` to stderr (transition-window cleanup will remove these in Task 6).

Prospect research is a sales-side skill — it does not have a parent workflow in the dev pipeline. If any active dev workflow is found, proceed anyway: prospect research is independent and runs alongside whatever else is happening. The scan exists to keep the per-session breadcrumb directory tidy across terminals.

---

## Phase 1: Setup

### 1a. Create folder structure

```
Research/prospects/{slug}/
├── briefing.md       # main deliverable
├── briefing.html     # sales-facing HTML
├── sources.md        # URL index
└── signals.md        # raw evidence (quotes + paraphrases per source)
```

### 1b. Write breadcrumb

**Write `.claude-active/{claude_pid}-prospect-research`** at the project root. Use a SUBSHELL so `umask` does not leak to the rest of the skill, and CORRECT directory permissions if `.claude-active/` pre-exists with wider perms. Content: relative path to the prospect folder (`Research/prospects/{slug}`).

```bash
(
  umask 077
  source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh"
  cad="${CLAUDE_PROJECT_DIR}/.claude-active"
  if [ -L "$cad" ]; then
    echo "FATAL: $cad is a symlink — refusing to write breadcrumbs" >&2
    exit 1
  elif [ -e "$cad" ]; then
    [ -d "$cad" ] || { echo "FATAL: $cad exists and is not a directory" >&2; exit 1; }
    chmod 700 "$cad" 2>/dev/null || { echo "FATAL: cannot enforce 0700 on $cad" >&2; exit 1; }
  else
    mkdir -p "$cad"
  fi
  bc=$(breadcrumb_path prospect-research) || exit 1
  printf '%s\n' "${RELATIVE_OUTPUT_PATH}" > "$bc"
)
```

The outer `( ... )` subshell scopes `umask 077` so the caller's umask is unchanged after this block. The pre-existing-perm correction enforces `0700` on `.claude-active/` even if a previous-version skill or attacker created it with wider perms.

### 1c. Initialize files (fresh and version actions only)

For `refresh` action, **skip 1c entirely** — files already exist.

**`briefing.md`** — copy from `templates/briefing.md` in this skill folder, substitute frontmatter:
```yaml
---
skill: serious-prospect-research
slug: {slug}
status: active
created: {today YYYY-MM-DD}
mode: {quick|deep}
version: 1
fit_tier: pending
---
```

**`sources.md`** — header only:
```markdown
# Sources — {Company}

> URL index. Every source cited in `briefing.md` or `signals.md` appears here.
> Format: `- [Title](url) — accessed {YYYY-MM-DD}, used in: {sections}`

## Company
## Tech & engineering
## Buying committee
## AI posture
## News & growth
```

**`signals.md`** — header only:
```markdown
# Signals — {Company}

> Raw evidence per subagent. Quotes preferred; paraphrase only when needed.
> Each signal: source URL + date accessed + 1-3 sentence quote/paraphrase + which AI-MSL pillar it maps to (if any).

## Company subagent
## Tech & engineering subagent
## Buying committee subagent
## AI posture subagent
## Synthesis follow-up (deep mode)
```

---

## Phase 2: Parallel research dispatch

Launch all four subagents in a **single message** with multiple Agent tool calls so they run simultaneously. Use `subagent_type: "general-purpose"`.

For `mode = quick`: each subagent hits **must-hit sources only**.
For `mode = deep`: must-hit + should-hit.
For `action = refresh`: launch only the AI posture and Buying committee subagents, restricted to news + recent posts (last 30 days).

### 2a. Subagent prompt template

Pass each subagent this prompt skeleton (substitute `{ROLE}`, `{COMPANY}`, `{MUST_HIT}`, `{SHOULD_HIT}`, `{SLUG}`, `{MODE}`):

> You are the **{ROLE}** subagent for a CloudGeometry pre-discovery sales briefing on **{COMPANY}**.
>
> **Goal:** surface evidence that helps a sales rep decide whether {COMPANY} is a good AI-MSL prospect, and what to say on the first call. AI-MSL solves: architectural drift, after-code gap, dev cost pressure, modernization without R&D programs, and AI-tooling friction (Cursor/Copilot/Claude Code that didn't deliver).
>
> **Sources to hit (in order):**
> Must-hit: {MUST_HIT}
> {if MODE = deep:} Should-hit: {SHOULD_HIT}
>
> **What to do for each source:**
> 1. Search/fetch the source.
> 2. For every fact you'd cite in a sales briefing, write to `Research/prospects/{SLUG}/signals.md` under the `## {ROLE} subagent` header. Format: `- **[Source title]** ({date_accessed}) — [URL]. Quote or paraphrase: "..." Maps to: {pillar or "context"}.`
> 3. Add the URL to `Research/prospects/{SLUG}/sources.md` under the appropriate section.
>
> **Rules:**
> - Cite or do not claim. No fact without a source.
> - Distinguish observation (what the source says) from inference (what you conclude). Mark inferences with `[inferred]`.
> - Skip a source if dry — write `(dry: nothing relevant)` so the orchestrator knows you tried.
> - Hard cap: {if QUICK: 8 min} {if DEEP: 12 min} wall-clock. Stop when budget is gone, even if not all sources are hit.
>
> **Return:** a 1-paragraph summary of your top 3 findings to the orchestrator. The full evidence is in `signals.md`.

### 2b. The four subagent role specs

#### Company subagent
- **Must-hit:** company website (about, customers, blog headlines), LinkedIn company page, Crunchbase
- **Should-hit:** Google News last 90 days, funding announcements (TechCrunch, press releases)
- **Looking for:** size, funding stage, HQ, growth signals (hiring, layoffs, expansion), business model, customer logos, ICP signals

#### Tech & engineering subagent
- **Must-hit:** GitHub org page (if any), careers/jobs page (their site or LinkedIn jobs)
- **Should-hit:** BuiltWith.com, engineering blog, Stack Overflow team page
- **Looking for:** stack signals (languages, frameworks, cloud), engineering team size estimate, recent tech moves, monorepo vs multi-repo signals, framework version pain points (Spring Boot 2 vs 3, Java versions), cloud-native maturity

#### Buying committee subagent
- **Must-hit:** LinkedIn profiles of CTO/VPE/Head of Engineering (and similar titles)
- **Should-hit:** their recent posts (last 90 days), podcast appearances, conference talks
- **Looking for:** who's the technical decision-maker, their recent moves (joined when, from where), their public POV on AI/dev tooling, adjacent stakeholders (Head of Product, CEO if technical-first)

#### AI posture subagent
- **Must-hit:** company blog filtered for AI/Copilot/LLM/agents, leadership LinkedIn posts about AI
- **Should-hit:** jobs page filtered for AI roles or "Cursor/Copilot required" language, earnings calls if public
- **Looking for:** public AI statements, current AI tooling deployed, friction signals ("we tried Cursor but..."), AI strategy maturity, hallucination/context-loss complaints

---

## Phase 3: Synthesis + re-dispatch

### 3a. Read signals (both modes)

After all four subagents return, read `signals.md` end-to-end. This is your evidence base.

### 3b. Identify gaps (deep mode only)

Scan signals for high-leverage gaps. Examples that justify a re-dispatch:
- Tech subagent found "they use Cursor" but no friction detail.
- AI posture subagent found "AI strategy mentioned in earnings" but didn't pull the specific quote.
- Committee subagent found a CTO but no recent posts on dev tooling.
- Pain signals are thin — no clear pillar mapping for any AI-MSL angle.

If a gap is worth chasing AND would change the briefing materially, dispatch **one** targeted follow-up subagent with a tightly-scoped prompt. Cap follow-up at 5 min wall-clock. Append findings to `signals.md` under `## Synthesis follow-up` section.

If no gap is worth chasing, skip 3b and proceed.

### 3c. Apply fit-score rubric

Walk the signals against the rubric below. Tier the prospect:

**Strong fit** — any 2 of these:
- Public evidence of using Copilot/Cursor/Claude Code AND friction
- Eng team 30–300 + visible dev cost pressure (layoffs, hiring freeze, "doing more with less")
- Legacy modernization need with no announced rewrite program
- Large feature backlog (public roadmap gaps, customer feedback friction)
- Recent CTO/VPE hire with shipping/velocity mandate
- M&A activity or investor pressure on engineering efficiency
- Cloud-native or on-path-to (Kubernetes, AWS/Azure/GCP)
- Public statements about AI hallucinations / context loss / "AI doesn't know our codebase"

**Moderate fit** — ≥1 strong signal OR ≥3 moderate signals:
- Active AI strategy without specific tool friction surfaced
- Smaller team (15–30) but high growth (Series B+, hiring fast)
- Some legacy without a clear modernization driver
- Aware of AI tooling but not yet deployed at scale

**Weak fit** — anything below moderate threshold.

**Disqualifiers** (any 1 → tier = `disqualified`, override Strong/Moderate/Weak):
- Defense/classified work without confirmed CG clearance posture
- Direct competitor (dev tooling vendor)
- Already in active engagement with a known CG competitor
- Regulated + on-prem-only when prospect can't reach Enterprise tier price
- Eng team < 10 (pricing floor friction at $3K/mo) — soft disqualifier, note but don't auto-reject

Record the tier, the specific signals that drove it (with sources), and disqualifiers if any.

---

## Phase 4: Assemble the briefing

Open `briefing.md`. Fill the 8 sections from `signals.md`. Every claim cites a source.

### 4a. Section assembly rules

1. **TLDR** (5 bullets): what they do · why they're inbound · fit tier · top 3 conversation hooks · biggest risk.
2. **Company snapshot:** size, funding, HQ, growth signals, business model. 5–10 bullets.
3. **Tech & engineering profile:** stack signals, eng team size estimate, recent tech moves. Distinguish observed (job posting says X) vs inferred (`[inferred]`).
4. **Pain signals → AI-MSL pillars:** sub-headers per pillar (Architectural drift / After-code gap / Dev cost pressure / Modernization need / AI-tooling friction). Each pillar gets evidence with citations OR "no signal found." Don't fabricate.
5. **Buying committee:** primary technical decision-maker (name, title, joined when, recent moves) + adjacent stakeholders. Sourced LinkedIn URLs.
6. **AI posture:** public AI statements, current tooling, friction signals, strategy maturity. Quote where possible.
7. **Conversation hooks:** 3–5 specific, sourced things to say that prove homework. Each hook = 1 sentence + source URL.
8. **Fit score & risks:** tier (Strong/Moderate/Weak/Disqualified) + 2–3 sentence rationale + bullet list of signals that drove it (each with source) + disqualifiers if any.

### 4b. Update frontmatter

Set `status: done`, `fit_tier: {tier}`, and add `completed: {YYYY-MM-DD}`.

### 4c. Quick mode confidence check

If `mode = quick`:
- Count distinct sources cited in briefing.
- If < 6 distinct sources OR any pillar in section 4 is empty OR section 6 has no friction signal, flag low confidence: include a note in the completion message recommending `--deep` re-run.

---

## Phase 5: HTML generation + completion message

### 5a-pre. Optional timeline image (deep mode only)

If `mode = deep` AND `signals.md` contains **≥4 dated events** that form a coherent narrative (CEO/CTO joins, layoffs, fundraise, M&A, product launches, leadership changes), invoke `/serious-bananas` to generate a sales-briefing timeline image.

**Skip in quick mode.** Skip if dated events <4. Skip if image generation fails (HTML must still render without it).

Image generation:
- Save to `Research/prospects/{slug}/timeline.png`
- 16:9, 2K resolution, light neutral background
- Title: `{COMPANY} — IN TRANSITION` or similar narrative one-liner
- Horizontal timeline with events in chronological order
- One event must be visually dominant (largest, red) — typically the most recent layoff or strongest pain signal
- Style: McKinsey/BCG sales-deck aesthetic. NO logos that could be trademarks.

If the image is generated, set `HERO_IMAGE_HTML = '<div class="hero-image"><img src="timeline.png" alt="{COMPANY} narrative timeline"><div class="hero-image-caption">{caption}</div></div>'`.

Otherwise, set `HERO_IMAGE_HTML = ''` (empty string — the template handles missing image gracefully).

### 5a. Generate `briefing.html`

Read `templates/briefing.html` from this skill folder. Substitute every placeholder. Do not generate HTML from scratch — always use the template. If the template file is missing, fail loudly.

Write to `Research/prospects/{slug}/briefing.html`.

#### Top-level placeholders (simple substitution)

| Placeholder | Value |
|---|---|
| `{{COMPANY}}` | Company name (e.g., `Hyland`) |
| `{{MONOGRAM}}` | 1–2 letter monogram derived from company name (`Hyland` → `H`, `ShiftPixy` → `SP`, `Acme Corp` → `AC`) |
| `{{TIER}}` | `STRONG` / `MODERATE` / `WEAK` / `DISQUALIFIED` (uppercase) |
| `{{TIER_LOWER}}` | `strong` / `moderate` / `weak` / `disqualified` (lowercase, used as CSS class) |
| `{{MODE}}` | `quick` / `deep` |
| `{{SOURCES_COUNT}}` | Integer count of distinct sources |
| `{{GENERATED_AT}}` | `YYYY-MM-DD` |
| `{{SLUG}}` | The slug |
| `{{ONE_LINE_PITCH}}` | One sentence that captures why-fit, with **inline tags** highlighting key facts. See schema below. |
| `{{RISK_TEXT}}` | The biggest-risk paragraph from briefing.md, with the call-to-action ("Don't lead with X; lead with Y"). |
| `{{HERO_IMAGE_HTML}}` | The image HTML from 5a-pre, OR empty string. |

#### Annotation tag system

Use these CSS classes inline within text content (especially in `ONE_LINE_PITCH`, hook titles, person bios, detail bullets) to draw the eye to high-signal facts:

| Class | Use for |
|---|---|
| `<span class="tag">NEUTRAL FACT</span>` | Facts that need labeling but don't carry pain weight |
| `<span class="tag tag-hot">HOT SIGNAL</span>` | Layoffs, friction, debt, urgent risk |
| `<span class="tag tag-warm">WARM SIGNAL</span>` | Inferred, transitional, partially hot |
| `<span class="tag tag-fresh">RECENT</span>` | New hire, recent change (last 90 days) |
| `<span class="tag tag-info">CONTEXT</span>` | Strategic context, leadership, ownership |

Tag text should be SHORT (1–4 words, all caps): `PE-OWNED`, `LAYOFF AUG '25`, `NEW MAY '25`, `LEGACY .NET`, `NEW HIRE`, `→ TIM McINTIRE`.

#### `{{ONE_LINE_PITCH}}` schema

One sentence (≤ ~200 chars including tags) explaining why-fit. Pattern:

```
{What they are} <span class="tag">CONTEXT</span> on a <span class="tag tag-warm">PAIN POINT</span>, with {fresh signal} <span class="tag tag-fresh">RECENT</span> running {ambition} <span class="tag tag-info">STRATEGIC</span> onto an org just hit by <span class="tag tag-hot">HOT SIGNAL</span>. Textbook <strong>"{value-prop frame}"</strong> mandate. {N} AI-MSL pillars light up.
```

#### `{{HOOKS_HTML}}` schema

Three `<div class="hook">` blocks. Each hook is a script the rep will say. Schema per hook:

```html
<div class="hook">
  <div class="hook-num">{1|2|3}</div>
  <div class="hook-body">
    <div class="hook-title">{Strategic frame, 4–8 words} <span class="tag tag-{hot|warm|fresh|info}">→ {WHO/WHAT IT TARGETS}</span></div>
    <div class="hook-quote">"{Quote — what the rep will literally say, 1–3 sentences, conversational, NOT salesy}"</div>
    <div class="hook-targets">
      <span>Targets:</span> <span class="tag">CTO</span>
      <span>·</span>
      <a href="{source URL}" target="_blank">{Source label}</a>
    </div>
  </div>
  <button class="hook-copy" data-hook="{1|2|3}">📋 copy</button>
</div>
```

The JS `HOOK_TEXTS` dictionary at the bottom of the template MUST be populated with the same quote strings (escaped) so the copy button works:

```javascript
const HOOK_TEXTS = {
  "1": "{hook 1 quote, single-line, escaped}",
  "2": "{hook 2 quote}",
  "3": "{hook 3 quote}"
};
```

#### `{{PILLARS_HTML}}` schema

Five `<div class="pillar">` rows, one per AI-MSL pillar, in this order: Architectural drift · After-code gap · Dev cost pressure · Modernization need · AI-tooling friction.

Status classes:
- `pillar lit` — strong evidence of pain (red dot, `LIT` badge)
- `pillar warm` — partial / inferred / mixed evidence (amber dot, `WARM` or custom badge)
- `pillar silent` — no public signal but the absence is meaningful (gray dot, `SILENT` badge)
- `pillar cool` — actively NOT a fit on this dimension (blue dot, `OK` or `N/A` badge)

```html
<div class="pillar lit">
  <span class="pillar-dot"></span>
  <span><span class="pillar-name">{Pillar name}</span><span class="pillar-note">{≤80 chars summary of why lit}</span></span>
  <span class="pillar-status">LIT</span>
</div>
```

The panel title should include a counter: `<span class="panel-title">AI-MSL pillar status <span style="font-weight:500;text-transform:none;letter-spacing:0;color:var(--text-muted);">— {N} of 5 lit</span></span>`.

#### `{{PEOPLE_HTML}}` schema

1–3 `<div class="person">` cards for primary technical decision-maker + adjacent stakeholders. Avatar = initials. Bio = 1 sentence with prior company + mandate or POV.

```html
<div class="person">
  <div class="person-avatar">{initials, e.g., TM}</div>
  <div class="person-body">
    <div class="person-name">{Full Name} <span class="tag tag-fresh">NEW MAY '25</span></div>
    <div class="person-title">{Title}</div>
    <div class="person-bio">{Prior company → current mandate / POV. 1–2 sentences.}</div>
  </div>
</div>
```

#### `{{STATS_HTML}}` schema

Exactly **4** `<div class="stat">` boxes — pick the 4 most arresting numbers from the briefing. Each:

```html
<div class="stat">
  <div class="stat-num">{LARGE NUMBER}</div>
  <div class="stat-label">{2–3 word label}</div>
  <div class="stat-sub">{small qualifier}</div>
</div>
```

Examples: layoff size, PE debt, founding/acquisition year, GitHub repo count, customer count, ARR if public, eng team size estimate.

#### `{{DETAILS_*_HTML}}` schemas

Six collapsible sections — each gets the matching markdown content rendered as HTML:

| Placeholder | Source from briefing.md |
|---|---|
| `{{DETAILS_COMPANY_HTML}}` | Section 2 (Company snapshot) as `<ul>` with `<li>` per fact, sources linked, tags annotated |
| `{{DETAILS_TECH_HTML}}` | Section 3 (Tech & engineering) — same shape |
| `{{DETAILS_PAIN_HTML}}` | Section 4 (Pain → pillars) with `<h3>{Pillar} <span class="tag tag-{hot/warm}">{LIT/SILENT}</span></h3>` per pillar followed by `<p>` evidence |
| `{{DETAILS_COMMITTEE_HTML}}` | Section 5 (Buying committee) — `<h3>` per person + bullet list |
| `{{DETAILS_AI_HTML}}` | Section 6 (AI posture) — `<h3>` subsection headers + bullet lists with quotes |
| `{{DETAILS_SOURCES_HTML}}` | Sources, grouped by category (Company / Tech & engineering / Buying committee / AI posture), each `<ul><li><a href>title</a></li></ul>` |

Use `<code>...</code>` for technical strings (e.g., `<code>"Hyland" + Copilot</code>`). Use `<em>` for verbatim quotes. Always link sources via `<a href target="_blank">`.

### 5b. Remove breadcrumb

Delete the breadcrumb. During the dual-read transition window, BOTH the new-path breadcrumb AND any legacy `.active-prospect-research` at project root must be removed:

```bash
new_bc=$(bash -c 'source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh" && breadcrumb_path prospect-research')
rm -f "$new_bc" "${CLAUDE_PROJECT_DIR}/.active-prospect-research"
```

### 5c. Sales-oriented completion message

Print to the user in PM voice.

<!-- voice-retrofit: rewritten; thread-1 line: 462 -->
<!-- voice-retrofit: rewritten; thread-1 line: 466 -->

The TL;DR + Top 3 hooks + Biggest risk format is fine — that's sales-friendly content. But trim the file-path dump and the slash-command-with-flag footnote. Example:

> **{Company}** — {Tier} fit. {N} sources cited.
>
> **TL;DR for the call:** {one sentence: what they do + why fit}
>
> **Top 3 hooks:**
> 1. {Hook 1 — short}
> 2. {Hook 2 — short}
> 3. {Hook 3 — short}
>
> **Biggest risk:** {one sentence}
>
> The full briefing (with sources, signals, and an HTML sales card) is saved locally if you want to dig in.
>
> Question: ready for the call, or want to go deeper on any of these hooks?

Don't print 5 absolute paths. Don't recommend `--deep {slug}` slash-command-with-flag. If the briefing is low-confidence (quick mode, few sources), say so in plain English ("the briefing is thinner than usual — want me to dig deeper?").

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 486 -->
<!-- WHY: the low-confidence footnote with slash-command-flag is a sub-rule of the
     5c completion message; the rewrite above replaces it with a plain-English ask. -->

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 288 -->
<!-- WHY: the quick-mode confidence check is an operator-side metric (count distinct sources,
     check pillar gaps). The result feeds into how to FRAME the completion message, but the
     raw count is never shown to the user. -->

<!-- voice-retrofit: deferred — reason: covered-by-translator; thread-1 line: 169 -->
<!-- WHY: this is the sub-agent dispatch prompt for the synthesis sub-agent. The technical
     vocabulary ("architectural drift", "AI-tooling friction", etc.) is internal-to-the-skill
     framing. When the sub-agent output reaches user-facing chat at completion, Task 3's
     voice-translator wires into the prospect-research touchpoint to rewrite. -->

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 336 -->
<!-- WHY: CSS class names ("tag tag-hot", "pillar lit") are HTML generation directives,
     not chat content. They appear in the briefing.html file the user opens in a browser,
     where they're invisible class selectors. -->

---

## Reference: source set per subagent

| Subagent | Must-hit | Should-hit (deep only) | Opportunistic (synthesis re-dispatch only) |
|---|---|---|---|
| Company | Website, LinkedIn company page, Crunchbase | Google News (90d), funding announcements | Glassdoor |
| Tech & engineering | GitHub org, careers/jobs page | BuiltWith, engineering blog, Stack Overflow team | Open-source contribution graphs |
| Buying committee | LinkedIn (CTO/VPE/Head of Eng) | Recent posts, podcasts, conference talks | Twitter/X, GitHub commits |
| AI posture | Company blog (AI/Copilot/LLM filter), leadership LinkedIn posts | Jobs page (AI roles), earnings calls (if public) | Reddit/HN mentions |

---

## Reference: refresh-stale source whitelist

When `action = refresh`, only these sources are re-hit:
- Google News last 30 days
- Company blog (new posts since last run)
- Leadership LinkedIn posts (last 30 days)
- Jobs page (new postings)

Sections updated: 4 (pain signals), 5 (committee recent moves), 6 (AI posture). Sections 2, 3, 7, 8 are preserved unless the refresh surfaces evidence that contradicts them — in which case flag a contradiction in the completion message and recommend a full re-run.

---

## Notes

1. **Be brief in subagent prompts.** Subagents have their own context budget — don't over-prescribe.
2. **Always cite, never fabricate.** If a section has no evidence, write "no signal found" rather than guessing. The fit-score rubric explicitly accepts "no signal" as input.
3. **Distinguish observation from inference** throughout. Mark inferences with `[inferred]` and explain the basis.
4. **Quick mode is the default.** Most prospects need a fast briefing, not a thorough one. Deep mode is opt-in for high-stakes calls.
5. **The HTML is for sales people**, not engineers. Layout favors scannability: TLDR + Fit at top, sections collapsible, hooks copyable.
6. **One question at a time** if anything is ambiguous (CLAUDE.md rule 9). Most runs should not need any prompts after the initial mode/refresh decision.

