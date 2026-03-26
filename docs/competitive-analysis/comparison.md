# Competitive Analysis — Consolidated Comparison

**Date:** 2026-03-26
**Scope:** BMAD-AT-CLAUDE, Claude Code Superpowers, + 30 projects in the broader landscape
**Purpose:** Identify what competitors have that we should adopt, and what advantages to protect

---

## Executive Summary

The Claude Code framework market is mature and crowded (30+ projects). Three tiers matter:

| Tier | Project | Stars | Core Strength |
|------|---------|-------|---------------|
| **Giant** | Superpowers (obra) | 115K | Multi-platform + persuasion-based skills |
| **Standard** | BMAD Method | 42.4K | Full Agile lifecycle + context-engineered stories |
| **Rising** | Everything-Claude-Code | 78.6K | Breadth (28 agents, 116 skills, marketplace) |
| **Us** | Serious Sidekick | — | Deepest pipeline orchestration + artifact lifecycle |

**Our position:** We have the most rigorous workflow pipeline in the ecosystem (7 stages, frontmatter tracking, hash-verified handoffs). Nobody else has mock-up stages, scoping manifests, or plan-before-code quality gates at our depth. But we have **zero visibility** — not on any marketplace, not in any awesome list, not distributed as a plugin.

**The gap that matters most:** Distribution, not features.

---

## Competitive Positioning

### What Only We Have (Defend These)

| Feature | Why It's Unique |
|---------|----------------|
| **7-stage enforced pipeline** (conversation → research → mockups → scope → plan → review → code) | Most granular pipeline in the ecosystem. BMAD has ~5 stages, Superpowers ~7 but loosely coupled |
| **Mock-up stage** integrated into pipeline | No competitor has a dedicated mockup workflow feeding into scoping. Superpowers has a visual brainstorm companion but it's not a pipeline stage |
| **Scope manifests** with split boundaries and shared contracts | Nobody else has a dedicated scoping stage. Others jump from spec/PRD directly to tasks |
| **Plan quality gate** with adversarial multi-agent review | Most frameworks review code, not plans. Our anti-slop auditor is unique |
| **Frontmatter-based workflow tracking** with hash-verified staleness | BMAD has YAML state files (less formal). Nobody else does cross-artifact hash verification |
| **Breadcrumb files** (.active-{skill}) for real-time status | No equivalent anywhere |
| **39-feature Claude Code documentation** library | No competitor bundles platform feature docs |
| **Persona panel discussions** (hub-and-spoke with synthesis) | BMAD has "Party Mode" (less structured). Superpowers has nothing equivalent |

### What They Have That We Should Steal

Prioritized by impact × ease of adoption:

#### Tier 1: High Impact, Low Effort (Do First)

| # | Feature | Source | What To Do | Why |
|---|---------|--------|-----------|-----|
| 1 | **Anti-rationalization tables** | Superpowers | Add explicit "rationalization → rebuttal" tables to every skill | Proven to prevent agents from cutting corners. Every Superpowers skill has these. |
| 2 | **1% invocation rule** | Superpowers | Add to our meta-skill guidance: "If 1% chance a skill applies, MUST invoke it" | Ensures skills are actually used, not forgotten |
| 3 | **Persuasion principles** in skill writing | Superpowers | Apply Authority, Commitment, Social Proof patterns to all skills | Research-backed: doubled agent compliance (33% → 72%) |
| 4 | **Source citation requirements** | BMAD | Require `[Source: path#section]` in plans and code artifacts | Forces traceability. BMAD does this in stories; we should do it in plans |
| 5 | **Subagent status protocol** | Superpowers | Formalize DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED in `/serious-code` | Clear orchestration signals. Easy to adopt |
| 6 | **Anti-performative code review** | Superpowers | Ban "Great point!" / "You're right!" in review. Push back when reviewer is wrong | Improves review quality. Their `receiving-code-review` skill is excellent |
| 7 | **Verification-before-completion** | Superpowers | Add explicit: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" | Prevents premature "done" claims. Low effort, high impact |

#### Tier 2: High Impact, Medium Effort

| # | Feature | Source | What To Do | Why |
|---|---------|--------|-----------|-----|
| 8 | **Systematic debugging skill** | Superpowers | Create `/serious-debug` with 4-phase methodology: Root Cause → Pattern Analysis → Hypothesis → Implementation | Their debugging skill is exceptional (8 supporting files). We have no equivalent. |
| 9 | **Brownfield workflow** | BMAD | Add brownfield templates to `/serious-scope` and `/serious-plan`. Include enhancement classification (single story / feature / major) | Significant gap. BMAD has 3 brownfield workflows. We assume greenfield. |
| 10 | **Cross-artifact validation checklist** | BMAD | Expand `/serious-review` beyond single-plan review. Add PO-style validation across research → scope → plan consistency | BMAD's 80-item PO Master Checklist catches cross-artifact inconsistencies we'd miss |
| 11 | **Document sharding** | BMAD | Implement auto-splitting of large research/plan files by H2 sections | Practical context window management. BMAD uses `md-tree` CLI. Simple and effective |
| 12 | **Context embedding in implementation** | BMAD | When `/serious-code` dispatches tasks, embed ALL relevant context so the agent doesn't re-read upstream | BMAD's biggest innovation: stories are self-contained. Our agents still need to read plans + research |
| 13 | **TDD for skill creation** | Superpowers | Write pressure scenarios, test without skill, document failures, write skill addressing them | Skills tested against real failure modes, not just designed from first principles |
| 14 | **Plugin marketplace distribution** | Landscape | Package as an Anthropic marketplace plugin | The #1 distribution gap. Everything-Claude-Code and Superpowers both use marketplace. One-click install vs. clone-and-configure |

#### Tier 3: Strategic / High Effort

| # | Feature | Source | What To Do | Why |
|---|---------|--------|-----------|-----|
| 15 | **Multi-platform support** | Superpowers, BMAD | At minimum, document what would need to change. At max, add Cursor/Codex/Gemini support | Market is moving agent-agnostic. Superpowers' 115K stars come largely from this |
| 16 | **Interactive installer** | BMAD | `npx serious-sidekick install` with modular skill selection | BMAD's installer is proven. Reduces friction |
| 17 | **Cross-session persistent memory** | Pilot Shell, Landscape | Add searchable, confidence-scored observations that persist across sessions | Pilot Shell's "observations" pattern is the best implementation. We have CLAUDE.md but not structured memory |
| 18 | **Integration test suite** | Superpowers | Build headless Claude Code tests that verify skill behaviors via transcript parsing | Superpowers tests skills with real headless sessions. High effort but ensures quality |
| 19 | **Visual brainstorming companion** | Superpowers | Enhance `/serious-mock-ups` with browser-based WebSocket preview | Zero-dependency Node.js server. Bridges text/visual gap |
| 20 | **GitHub Issues integration** | CCPM | Use Issues as source of truth for `/serious-scope` | Enables team collaboration (agents + humans on same board) |

---

## Feature Matrix — Head-to-Head

### Workflow & Pipeline

| Capability | Serious Sidekick | Superpowers | BMAD |
|------------|-----------------|-------------|------|
| Pipeline stages | **7** (most in ecosystem) | 7 (loosely coupled) | ~5 (Agile phases) |
| Pipeline enforcement | **Frontmatter + breadcrumbs** | 1% rule (soft) | Workflow YAML (manual) |
| Handoff verification | **Hash-checked staleness** | None | Manual PO checklist |
| Brainstorming/Design | **Persona panel** (10+ personas) | 9-step dialogue + visual companion | Analyst + brainstorming task |
| Research | **Automated** (quick/deep modes) | None | Generates prompts only |
| Mock-ups | **3 fidelity levels** in pipeline | Visual companion (brainstorm only) | Outsources to v0/Lovable |
| Scoping | **Manifests with split boundaries** | None | PRD with epics (static) |
| Plan writing | **v6 template** with TDD protocol | 2-5 min atomic tasks | SM creates stories |
| Plan review | **Multi-agent adversarial** | Plan document reviewer | PO Master Checklist |
| Execution | **5-agent TDD in parallel worktrees** | Subagent-per-task + 2-stage review | Single Dev agent, sequential |
| Debugging | None | **4-phase systematic** (8 files) | None |
| Brownfield | None | None | **3 dedicated workflows** |
| Change management | None | None | **Sprint Change Proposals** |

### Agent Orchestration

| Capability | Serious Sidekick | Superpowers | BMAD |
|------------|-----------------|-------------|------|
| Agent count | 5 (in /serious-code) + skill-specific | 14 skills (loosely coupled) | 10 named personas |
| Parallel execution | **Worktree-based** | Parallel dispatch skill | Sequential only |
| Subagent protocol | Informal | **DONE/BLOCKED/NEEDS_CONTEXT** | None |
| Code review | Anti-slop auditor + structural | **2-stage** (spec then quality) | Single QA agent |
| Agent personas | Functional roles | Functional roles | **Named characters** (Winston, James, etc.) |
| Agent permissions | None | None | **Strict section ownership** |

### Skill Quality & Enforcement

| Capability | Serious Sidekick | Superpowers | BMAD |
|------------|-----------------|-------------|------|
| Anti-rationalization | None | **Tables in every skill** | None |
| Persuasion psychology | None | **Research-backed** (2x compliance) | None |
| Skill testing | None | **TDD for skills** (pressure scenarios) | None |
| Invocation enforcement | Breadcrumbs + hooks | **1% rule** | `*` prefix commands |
| Verification enforcement | Frontmatter hashes | **"No claims without evidence"** | Story DoD checklist |

### Platform & Distribution

| Capability | Serious Sidekick | Superpowers | BMAD |
|------------|-----------------|-------------|------|
| Platforms | Claude Code only | **5** (Claude, Cursor, Codex, OpenCode, Gemini) | **7+** (all major IDEs + web UIs) |
| Distribution | Template repo (clone) | **Marketplace plugin** | **npx installer** |
| Ecosystem visibility | None | Listed everywhere | Listed everywhere |
| Installation | Manual | One-click marketplace | `npx bmad-method install` |

### Documentation & Templates

| Capability | Serious Sidekick | Superpowers | BMAD |
|------------|-----------------|-------------|------|
| Platform feature docs | **39 features** documented | Anthropic best practices ref | None |
| Document templates | 1 (plan v6) | Inline in skills | **12 templates** (YAML) |
| Quality checklists | Built into /serious-review | Anti-patterns refs | **6 checklists** (80+ items) |
| Document sharding | None | None | **Auto-split by H2** |

---

## Landscape Threats

### Projects to Watch

| Project | Stars | Why It Matters |
|---------|-------|---------------|
| **GitHub Spec Kit** | 82.6K | Agent-agnostic spec-driven dev. GitHub official. Could become the standard. |
| **Ruflo** | Significant | WASM/Rust performance layer + 75% cost savings via model routing. Infrastructure play. |
| **Pilot Shell** | 1.6K | Most opinionated about quality. Cross-session memory with searchable observations. |
| **CCPM** | 7.6K | GitHub Issues as PM layer. Enables real human+AI team collaboration. |

### Emerging Patterns We Should Track

1. **Plugin marketplace is where adoption happens now** — 9,000+ plugins. `/plugin install` is the new standard.
2. **Cross-agent compatibility is becoming expected** — Leading projects support 5+ platforms.
3. **Spec-driven development** is becoming the dominant paradigm (GitHub's backing).
4. **Native Agent Teams** (Claude Code v2.1.32+) reduces need for external orchestration.
5. **MCP server bundling** extends agent capabilities beyond text (code knowledge graphs, hash-verified editing).

---

## Strategic Recommendations

### Phase 1: Quick Wins (1-2 weeks)

Adopt proven techniques that require only editing existing skill files:

- [ ] Add anti-rationalization tables to all 7 skills
- [ ] Add persuasion patterns (Authority, Commitment, Social Proof) to skill writing
- [ ] Adopt 1% invocation rule in meta-skill guidance
- [ ] Formalize subagent status protocol (DONE/BLOCKED/NEEDS_CONTEXT/DONE_WITH_CONCERNS)
- [ ] Add source citation requirements (`[Source: path#section]`) to plans
- [ ] Add verification-before-completion enforcement to `/serious-code`
- [ ] Adopt anti-performative review principles in `/serious-review`

### Phase 2: New Capabilities (2-4 weeks)

Build missing features identified across competitors:

- [ ] Create `/serious-debug` skill (4-phase systematic debugging, adapted from Superpowers)
- [ ] Add brownfield workflow support to `/serious-scope` and `/serious-plan`
- [ ] Expand `/serious-review` to cross-artifact validation (PO-style)
- [ ] Implement document sharding for large research/plan files
- [ ] Add context embedding to `/serious-code` (BMAD's self-contained story pattern)
- [ ] Build TDD methodology for our own skill creation

### Phase 3: Distribution & Visibility (4-6 weeks)

Get on the map:

- [ ] Package as Anthropic marketplace plugin (`.claude-plugin/plugin.json` + `marketplace.json`)
- [ ] Submit to awesome-claude-code (32.7K stars), awesome-claude-skills, awesome-claude-code-toolkit
- [ ] Create `npx serious-sidekick install` interactive installer
- [ ] Add GitHub topic tags for discoverability
- [ ] Write a launch blog post / announcement

### Phase 4: Strategic Decisions (evaluate)

Big moves that need deliberate choice:

- [ ] **Multi-platform support** — Cursor, Codex, Gemini CLI? Superpowers proves this drives adoption (115K stars) but requires maintaining 5 plugin formats
- [ ] **Cross-session persistent memory** — Pilot Shell pattern? Searchable observations with confidence scores?
- [ ] **Integration test suite** — Headless Claude Code tests verifying skill behaviors?
- [ ] **MCP server bundling** — Code knowledge graph? Hash-verified editing?
- [ ] **GitHub Issues integration** — CCPM's team collaboration model?

---

## Sources

- [BMAD-AT-CLAUDE Research](./BMAD/research.md) — 217 stars, 10 agents, 12 templates, 6 workflows
- [Superpowers Research](./claude-code-superpowers/research.md) — 115K stars, 14 skills, persuasion-based design
- [Landscape Research](./landscape/research.md) — 30+ projects across 6 tiers
