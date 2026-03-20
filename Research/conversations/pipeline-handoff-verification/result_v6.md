# Round 6 — Pipeline Handoff Verification (Final)

## What the panel said

All four solutions passed the panel. Each persona validated the core approach and surfaced refinements:

### The Architect
All four architecturally sound. Two refinements needed: (1) shirking detection needs explicit interaction rules with `[DEFERRED]` markers — items in dismissive placements WITHOUT a marker are shirked, WITH a marker are legitimately deferred. (2) Retroactive verification needs a `source` field in plan frontmatter pointing to the upstream artifact, so the verifier knows what to verify against.

### The Skeptic
Three refinements: (1) Shirking detection needs a minimum-substance threshold — a heading with no real content ("Section 4.2: Rate Limiting — We will address rate limiting.") games the placement check. Require at least one action item or design decision per section. (2) Manual override should require a reason: `[VERIFIED: override — reason]` for accountability. (3) Retroactive verification should hash the upstream artifact at verification time (`verified: 2026-03-15 | sha:a3b2c1`) — if someone edits upstream after verification, the hash catches it.

### The Pragmatist
Concrete build order with estimates:
1. Manual override — 30 min (one sentence in prompt)
2. Scope shirking detection — 2-3 hrs (IS the verifier's core logic, not an add-on)
3. Startup extractability check — 1-2 hrs (warn, don't block)
4. Retroactive verification — 1 hr (frontmatter stamp)
Total: 5-7 hrs prompt work + 3-4 hrs real-artifact testing. No new files or commands.

### The DX Advocate
End-to-end UX is solid. Happy path: three automated steps, zero user actions, one line of output at startup. Failure path: SHIRKED vs MISSING distinction gives clear signal for different remediations. Override syntax must appear in the failure message itself — don't make users hunt for it. One risk: startup phase now has two checks; keep them to one line each.

## Refinements Accepted Into Design

| Refinement | Source | Impact |
|---|---|---|
| `[DEFERRED]` + dismissive placement = legitimate; no marker = SHIRKED | Architect | Clarifies interaction between two mechanisms |
| Minimum-substance threshold (heading needs action items, not just a title) | Skeptic | Catches "hollow section" gaming |
| Override requires reason: `[VERIFIED: override — reason]` | Skeptic | Accountability without friction |
| `source` field in downstream frontmatter pointing to upstream artifact | Architect | Enables retroactive verification backlinks |
| Upstream content hash at verification time | Skeptic | Catches post-verification upstream edits |
| Warn on unstructured upstream, don't block | Pragmatist + Skeptic | Avoids false blocking on prose-heavy artifacts |
| Include override syntax in failure message | DX Advocate | Zero-hunting UX |
| Keep startup checks to one line each | DX Advocate | Don't stall the user's sense of progress |

## Final Complete Design

### Architecture
- One shared file: `.claude/skills/_shared/handoff-verifier.md`
- Referenced via markdown link by each downstream skill
- Two modes: **extract** (startup) and **verify** (completion)
- Independent sub-agent execution

### Startup Phase (Extract Mode)
Runs during Phase 0, before the skill does any work:
1. Read upstream artifact
2. Extract enumerable items from numbered lists / bulleted sections
3. Output: "Found N items in [path]. Proceeding."
4. If no structured lists found: warn (don't block)
5. If downstream frontmatter lacks `verified` field and upstream exists: run retroactive verification immediately
6. Save extracted items for verify-mode to reuse

### Completion Phase (Verify Mode)
Runs after the skill writes its primary output:

**For each upstream item, check disposition:**

| Disposition | Rule |
|---|---|
| ✅ **COVERED** | Item has its own section, task, or acceptance criteria with at least one action item or design decision |
| ⚠️ **DEFERRED** | Item has `[DEFERRED: reason]` marker — passes with warning |
| 🚫 **SHIRKED** | Item appears only in future work / out of scope / nice to have / parenthetical WITHOUT a `[DEFERRED]` marker, OR has a dedicated heading but no substantive content |
| ❌ **MISSING** | Item not mentioned at all |
| ✅ **OVERRIDE** | Item has `[VERIFIED: override — reason]` marker — treated as covered |

**Output format:**
```
## Upstream Traceability Check
Source: Research/features/auth/research.md
Extracted items: 8

1. Token rotation policy     → ✅ Covered (plan §2.3)
2. Session invalidation      → ✅ Covered (plan §1.1)
3. Refresh token scope       → ⚠️ DEFERRED: "out of scope per user" (plan §4)
4. Rate limiting             → 🚫 SHIRKED — mentioned in "Future Considerations" without [DEFERRED] marker
5. Key storage               → ✅ Covered (plan §3.2)
6. Audit logging             → ❌ MISSING — not addressed, not deferred
7. Token lifetime policy     → ✅ Covered (plan §2.1)
8. Revocation endpoint       → ✅ Override (plan §3.4) [VERIFIED: override — handled via existing middleware]

Verdict: FAIL — 1 shirked, 1 missing, 1 deferred (review recommended)
Fix gaps in Research/features/auth/implementation_plan.md, then re-run /serious-plan.
To override a finding, add [VERIFIED: override — reason] next to the item.
```

**Verdict rules:**
- All COVERED/OVERRIDE → **PASS**
- Any DEFERRED, no SHIRKED/MISSING → **PASS WITH DEFERRALS**
- Any SHIRKED or MISSING → **FAIL**

### Frontmatter Updates
On successful verification, stamp the downstream artifact:
```yaml
verified: 2026-03-19
verified_source: Research/features/auth/research.md
verified_hash: a3b2c1d4
```

### Retroactive Verification
When the next downstream skill starts and reads the artifact:
- No `verified` field → run verification before proceeding
- `verified_hash` doesn't match current upstream file → re-verify
- Both present and matching → skip, already verified

### Deferral Convention
```
[DEFERRED: reason] — legitimate, user-approved deferral
```
- Passes the gate as a warning
- Appears in output as ⚠️

### Override Convention
```
[VERIFIED: override — reason]
```
- Treated as covered
- Reason required for marker to be recognized
- Syntax included in every failure message

### Known Limitations
- Catches downstream drift, not upstream incompleteness
- Verifier is an LLM doing semantic matching — occasional errors expected
- Extracted checklist shown in output so user can catch bad extractions
- Upstream hash comparison is content-based, not semantic — reformatting triggers re-verification

### Implementation Sequence
1. Standardize key headings in skill output templates (~5 min per skill)
2. Write `.claude/skills/_shared/handoff-verifier.md` with both modes, shirking detection, override support (~3-4 hrs)
3. Add `source` field to downstream skill frontmatter specs (~30 min)
4. Wire extract-mode into Phase 0 for serious-plan (~1 hr)
5. Wire verify-mode into serious-plan completion (~1 hr)
6. Test on 3 real artifacts, tune shirking patterns (~3-4 hrs)
7. Roll to remaining transitions (~2 hrs)

Total: ~12-15 hours of work. No new commands, no new skills, no new files beyond the one shared verifier prompt.
