---
skill: serious-research
slug: readme-diagram-accuracy
status: done
parent:
created: 2026-03-20
classification: Bug
scope: Codebase only
mode: Quick
---

# README Diagram Accuracy Audit

## Summary

4 of 6 diagrams have issues. Diagram 4 (Code Execution) and Diagram 3 (Plan Review) are the worst — missing 40% of the actual execution cycle and oversimplifying convergence rules respectively. Diagram 1 (Pipeline) is missing Review verification and loop-back. Diagram 5 (Verification) conflates extract and verify modes. Diagram 6 (Pie Chart) is accurate.

## Findings

### Finding 1: Pipeline Flow — Missing Review verification and loop-back
The diagram shows Code → Review with no verify label, contradicting "verification at every handoff." Also missing Review → Research/Plan loop-back arrows for defect cycling.

### Finding 2: Conversation — Shows 4 fixed personas instead of "3-5 selected from 10"
Diagram implies these 4 are always used. Should indicate selection from a pool and show the convergence/wrap-up decision.

### Finding 3: Plan Review — Oversimplified to uselessness
"File paths wrong?" is not in the SKILL.md at all. Missing: severity classification (Critical/Major/Minor), convergence rules (3+ Majors → re-review, max 3 rounds), Integration Review for multi-plan, and escalation to user on max rounds.

### Finding 4: Code Execution — Missing 3 critical steps
Shows Implementer → 4 agents → Gate, but actual cycle has 6 steps: Smoke Test (Step 0) → Implement → Stub Detection (Step 1.25) → Post-Impl Smoke (Step 1.5) → 4 Verification Agents → Completion Gate. Also missing retry limits (max 2) and escalation.

### Finding 5: Verification Flow — Conflates two modes
Doesn't distinguish Phase 0 extract-mode (startup) from completion verify-mode. Missing the 6 disposition types and the sub-agent requirement. "User fixes gaps" loop target is wrong — should loop to re-verify, not re-do work.

### Finding 6: Feature Pie Chart — Accurate
All counts verified against CLAUDE.md and file system. 39 features, 9 categories, all correct.

## Recommendations

Fix diagrams 1, 3, 4, and 5 — they're the ones that will mislead someone trying to understand or use the system. Diagram 2 needs a minor tweak. Diagram 6 is fine. However, there's a tension: more accurate diagrams are more complex and harder to scan. The fix should balance accuracy with readability — show the important steps, not every edge case.
