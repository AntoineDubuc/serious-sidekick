---
name: serious-mock-ups
description: "Generate UI mock-ups from research output before implementation planning. Three fidelity levels (wireframe, visual, interactive flow), iterative feedback, component inventory, and design decision log. Use when the user says 'serious mock-ups', 'mock up', 'show me the UI', 'wireframe this', or wants to visualize before planning."
user-invocable: true
---

# Serious Mock-Ups

Generate UI mock-ups from `/serious-research` output (or any input) before moving to `/serious-plan`. Provides a visual checkpoint so you validate layout, flow, and interaction before committing to an implementation plan.

**Position in the workflow:**
```
/serious-conversation → /serious-research → /serious-mock-ups → /serious-plan → /serious-code → /serious-review → done
```

---

## Phase 0: Intake

### 0a. Auto-detect research

Before asking anything, scan the project:

- Check `Research/features/*/research.md` for files with `Status: Complete`
- Check `Research/bugs/*/research.md` and `Research/exploratory/*/research.md`
- Check for `synthesis.md` files (from deep-mode `/serious-research`)
- If `$ARGUMENTS` specifies a path, use that directly

### 0b. Present what you found

**If exactly one completed research found:**
> "I found completed research at `Research/features/auth/research.md`. Use this as the basis for mock-ups?"

**If multiple found:**
> List them and ask which one to use.

**If nothing found:**
> "No research found. You can: point me to a research file, describe what you want to mock up, or run `/serious-research` first."

### 0c. Identify UI surfaces

Read the research (or user description) and extract every user-facing component, screen, view, or interaction mentioned. Present them as a numbered checklist:

> "I found these UI surfaces in your research:"
> 1. Dashboard overview — main landing screen with metrics
> 2. Settings panel — user preferences and configuration
> 3. Notification center — alert list with filtering
> 4. Onboarding flow — 3-step wizard for new users
>
> "Which ones do you want to mock up? (all, or list numbers)"

If the research doesn't mention specific UI surfaces, ask the user to describe what screens/views they're envisioning.

### 0d. Choose fidelity level

Ask which fidelity level to start with:

- **Wireframe (Recommended)** — ASCII/text-based layouts rendered right in the conversation. Fast, no dependencies, great for structure decisions. Start here to nail down layout before going visual.
- **Visual mock-up** — Generated via Gemini image API. Proper styling, colors, realistic component rendering. Requires `GEMINI_API_KEY` in `.env`.
- **Both** — Wireframe first for structure approval, then visual mock-up for the approved layout.

Default to **Both** — wireframes are fast and establish structure; visuals bring it to life after.

### 0e. Set up the mock-ups folder

Create the output structure:

```
{research_folder}/
└── mock-ups/
    ├── mock-up-summary.md        # Component inventory + design decisions (generated at end)
    ├── 01_{surface_slug}/
    │   ├── wireframe_v1.md       # ASCII wireframe
    │   ├── visual_v1.png         # Gemini-generated (if requested)
    │   └── feedback.md           # Iteration log — what changed and why
    ├── 02_{surface_slug}/
    │   └── ...
    └── flow.md                   # Screen-to-screen navigation map
```

If the input wasn't from `/serious-research`, create the folder under `Research/features/{slug}/mock-ups/`.

---

## Phase 1: Wireframes

For each selected UI surface, generate an ASCII wireframe.

### 1a. Generate the wireframe

Use box-drawing characters to create a clear, readable layout:

```
┌─────────────────────────────────────────────────────────────────┐
│  HEADER                                          [User ▾] [⚙]  │
├──────────────┬──────────────────────────────────────────────────┤
│              │                                                  │
│  SIDEBAR     │  MAIN CONTENT                                    │
│              │                                                  │
│  [Dashboard] │  ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  [Settings]  │  │  Metric A   │ │  Metric B   │ │  Metric C  │ │
│  [Reports]   │  │  1,234      │ │  567        │ │  89%       │ │
│  [Users]     │  └─────────────┘ └─────────────┘ └────────────┘ │
│              │                                                  │
│              │  ┌──────────────────────────────────────────────┐ │
│              │  │  TABLE                                      │ │
│              │  │  Name    | Status  | Date      | Actions    │ │
│              │  │  --------|---------|-----------|--------    │ │
│              │  │  Item 1  | Active  | 2026-03-07| [Edit]     │ │
│              │  │  Item 2  | Pending | 2026-03-06| [Edit]     │ │
│              │  └──────────────────────────────────────────────┘ │
│              │                                                  │
├──────────────┴──────────────────────────────────────────────────┤
│  FOOTER                                          v1.0 | Help   │
└─────────────────────────────────────────────────────────────────┘
```

**Wireframe rules:**
- Use `┌ ┐ └ ┘ ─ │ ├ ┤ ┬ ┴ ┼` for borders
- Label every section clearly (HEADER, SIDEBAR, MAIN CONTENT, etc.)
- Show interactive elements in `[brackets]`
- Show placeholder data that's realistic, not lorem ipsum
- Include relative sizing cues (a wider box = more screen real estate)
- Annotate below the wireframe: key layout decisions, component types, interaction notes

### 1b. Present and iterate

Show the wireframe to the user and ask for feedback. Common feedback patterns:

- Layout changes: "Move the sidebar to the right", "Make the header sticky"
- Content changes: "Add a search bar", "Remove the footer"
- Structure changes: "Use tabs instead of a sidebar", "Split this into two columns"

For each round of feedback:
1. Regenerate the wireframe as a new version (`wireframe_v2.md`, `wireframe_v3.md`)
2. Log the feedback and what changed in `feedback.md`

### 1c. Write wireframe files

Save each version to the mock-ups folder:

**wireframe_v1.md:**
```markdown
# Wireframe: {Surface Name} — v1

## Layout

{ASCII wireframe here}

## Annotations

- **Header:** Fixed top bar with logo, nav, user menu
- **Sidebar:** Collapsible, 240px default width
- **Main content:** Responsive grid, 3 metric cards + data table
- **Table:** Sortable columns, pagination at bottom

## Interactive Elements

| Element | Type | Action |
|---------|------|--------|
| [User ▾] | Dropdown | Opens profile/logout menu |
| [⚙] | Icon button | Opens settings |
| [Edit] | Text button | Opens edit modal |

## Open Questions

- Should the sidebar collapse on mobile or become a hamburger menu?
- Does the table need bulk actions (select all, delete selected)?
```

**feedback.md:**
```markdown
# Feedback Log: {Surface Name}

## v1 → v2
**Feedback:** "Add a search bar in the header and make the metric cards clickable"
**Changes:**
- Added search input to header between logo and user menu
- Metric cards now show hover state indicator [→] and link to detail views

## v2 → v3
**Feedback:** "The sidebar is too wide, and I want filters above the table"
**Changes:**
- Reduced sidebar from 240px to 200px
- Added filter bar (status dropdown, date range picker) between metrics and table
```

Continue iterating until the user approves the wireframe. Approval can be explicit ("looks good", "approved") or implicit (moving to the next surface).

---

## Phase 2: Visual Mock-Ups

After wireframe approval (or directly if the user chose visual-only fidelity), generate visual mock-ups using the Gemini image API.

### 2a. Craft the prompt

Build a Gemini prompt from the approved wireframe:

```
UI mock-up for a web application. {surface description from research}.

Layout: {describe the wireframe layout in prose — sections, positioning, hierarchy}

Components: {list from wireframe annotations — buttons, tables, cards, forms, etc.}

Style: {pick based on context or ask the user}
- Modern SaaS style (clean, lots of whitespace, subtle shadows)
- Dashboard style (data-dense, dark or light theme, charts)
- Consumer app style (friendly, rounded corners, vibrant colors)
- Admin panel style (functional, compact, form-heavy)

Requirements:
- Show realistic placeholder data, not lorem ipsum
- Label all interactive elements clearly
- Use a consistent color palette
- High resolution, crisp rendering
- No watermarks. No extra text outside the UI.
```

### 2b. Generate with Gemini

Use the same Gemini API approach as `/serious-bananas`:

- Model: `gemini-3-pro-image-preview` (default) or `gemini-3.1-flash-image-preview` (faster)
- Aspect ratio: `16:9` for desktop, `9:16` for mobile, `3:2` for tablet
- Save to: `{mock-ups_folder}/{surface_slug}/visual_v1.png`
- Requires `GEMINI_API_KEY` in `.env` and `pip install google-genai pillow`

### 2c. Show and iterate

Display the generated image to the user using the Read tool. Ask for feedback.

For each round:
1. Adjust the prompt based on feedback
2. Generate a new version (`visual_v2.png`, `visual_v3.png`)
3. Log changes in `feedback.md`

Continue until the user approves.

### 2d. Responsive variants (optional)

If the user wants, generate variants for different screen sizes:
- `visual_v{N}_desktop.png` — 16:9
- `visual_v{N}_tablet.png` — 3:2
- `visual_v{N}_mobile.png` — 9:16

Flag where the layout will need breakpoint logic and note it in annotations.

---

## Phase 3: Interactive Flows

After individual screens are approved, map how they connect.

### 3a. Generate flow.md

```markdown
# Screen Flow: {Feature Name}

## Navigation Map

```
[Landing Page]
    │
    ├── Click "Sign Up" ──→ [Onboarding Step 1]
    │                            │
    │                            ├── Next ──→ [Onboarding Step 2]
    │                            │                │
    │                            │                └── Next ──→ [Onboarding Step 3]
    │                            │                                 │
    │                            │                                 └── Done ──→ [Dashboard]
    │                            │
    │                            └── Back ──→ [Landing Page]
    │
    ├── Click "Log In" ──→ [Login Form]
    │                          │
    │                          ├── Success ──→ [Dashboard]
    │                          └── Failure ──→ [Login Form] (error state)
    │
    └── Click "Learn More" ──→ [Features Page]
```

## Screen Inventory

| # | Screen | Entry Points | Exit Points | States |
|---|--------|-------------|-------------|--------|
| 1 | Landing Page | Direct URL | Sign Up, Log In, Learn More | default |
| 2 | Login Form | Landing → Log In | Dashboard (success), self (error) | default, error, loading |
| 3 | Dashboard | Login success, Onboarding done | Settings, Profile, Logout | default, empty state, loaded |

## State Variations

Screens that have multiple states worth mocking up:
- **Dashboard — empty state:** New user, no data yet. Show onboarding prompt.
- **Dashboard — loaded:** Returning user with data.
- **Login — error:** Invalid credentials message.
```

### 3b. Identify state variations worth mocking

For each screen, ask whether alternate states need their own wireframe/visual:
- Empty states (no data yet)
- Error states (failed load, validation errors)
- Loading states (skeleton screens, spinners)
- Permission variants (admin vs regular user)

Only mock up states the user considers important. Don't over-produce.

---

## Phase 4: Completion

After all screens are approved, generate the summary deliverable.

### 4a. Generate mock-up-summary.md

```markdown
# Mock-Up Summary: {Feature Name}

**Source:** {research file path}
**Surfaces mocked:** {count}
**Iterations:** {total feedback rounds across all surfaces}
**Fidelity:** {wireframe / visual / both}

## Component Inventory

Components identified across all mock-ups, ready for implementation planning:

| Component | Type | Surfaces Used In | Notes |
|-----------|------|-------------------|-------|
| TopNav | Navigation bar | All screens | Fixed position, logo + search + user menu |
| Sidebar | Navigation panel | Dashboard, Settings | Collapsible, 200px width |
| MetricCard | Data display | Dashboard | Clickable, links to detail view |
| DataTable | Table | Dashboard, Reports | Sortable, paginated, bulk actions |
| FilterBar | Form controls | Dashboard | Status dropdown + date range picker |
| Modal | Dialog | Dashboard (edit) | Standard confirm/cancel pattern |
| OnboardingWizard | Multi-step form | Onboarding flow | 3 steps, progress indicator |

## Design Decisions

| # | Decision | Alternatives Considered | Rationale |
|---|----------|------------------------|-----------|
| 1 | Tabs over accordion for settings | Accordion, single scrolling page | User has 4 setting categories — tabs keep them visible without scrolling |
| 2 | Sidebar navigation over top nav | Top horizontal nav, hamburger menu | 8+ nav items — sidebar scales better than horizontal |
| 3 | Inline editing over modal editing | Full-page edit, modal form | Items have few fields — inline is faster for the user |

## Screen Flow Summary

{Copy or summarize flow.md navigation map}

## Responsive Notes

| Breakpoint | Layout Change |
|-----------|---------------|
| < 768px | Sidebar collapses to hamburger menu |
| < 1024px | Metric cards stack vertically (1 column) |
| < 480px | Table switches to card view |

## Files Produced

| Surface | Wireframes | Visuals | Feedback Rounds |
|---------|-----------|---------|-----------------|
| Dashboard | v1, v2, v3 (approved) | v1, v2 (approved) | 3 |
| Settings | v1 (approved) | v1 (approved) | 1 |
| Onboarding | v1, v2 (approved) | — | 2 |

## Input for /serious-plan

This summary is auto-detected by `/serious-plan`. The following feed directly into the implementation plan:
- **Component inventory** → task breakdown (one task per component cluster)
- **Design decisions** → acceptance criteria ("must use tabs, not accordion")
- **Screen flow** → integration tasks and navigation implementation
- **Responsive notes** → responsive/breakpoint tasks
- **State variations** → edge case acceptance criteria
```

### 4b. Report to user

Present:
- The mock-ups folder path
- How many surfaces were mocked up, at what fidelity
- The component inventory (quick summary)
- Key design decisions captured
- Reminder: "Run `/serious-plan` next — it will auto-detect these mock-ups and use the component inventory and design decisions."

---

## Arguments

`$ARGUMENTS` can specify:
- A path to research: `/serious-mock-ups Research/features/auth/research.md`
- `--wireframe` — wireframe only, skip visuals
- `--visual` — visual only, skip wireframes
- `--flow-only` — only generate the screen flow, skip individual mock-ups (useful when screens are already designed externally)

---

## Operating Rules

1. **Wireframe before visual.** Always offer wireframes first — they're fast and catch layout problems before you burn Gemini API calls.
2. **Iterate until approved.** Never move past a surface until the user says it's good. No assumed approvals.
3. **Realistic data only.** No "Lorem ipsum", no "John Doe". Use plausible placeholder data that helps the user evaluate the layout with real-world content.
4. **Log every decision.** Every piece of feedback and every layout change goes in `feedback.md`. The implementation plan needs to know *why* the design looks the way it does.
5. **Component inventory is mandatory.** The summary must list every component. This is what `/serious-plan` uses to create implementation tasks.
6. **Don't over-produce.** Mock up what matters. Not every screen needs a mobile variant. Not every state needs a visual. Ask the user what's worth their time.
7. **State variations are first-class.** Empty states, error states, and loading states are not afterthoughts — they're often where UX breaks. Surface them early.
8. **The summary is not optional.** Generate `mock-up-summary.md` with the full component inventory and design decision log. If the session is interrupted, resume must generate it.
