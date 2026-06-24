# Testing `/serious-simple-plan` on macOS + updating the skillset

**For: Claude Code running on the Mac.** This branch (`feat/serious-simple-plan`) was built and
verified on **Windows (Git Bash / MINGW64)**. It adds three things:
1. `/serious-simple-plan` — a restraint-focused alternative to `/serious-plan` (thin overlay; the
   existing planner is untouched).
2. A code-time fence guard (`.claude/skills/serious-code/hooks/protected-path-guard.sh`, wired as a
   `PreToolUse(Edit|Write)` hook) that enforces an `--avoid` list.
3. Cross-platform fixes: a test path-portability shim (`tests/lib/portable.sh`) and a
   manifest-generator fix (forward-slash keys on every OS).

Your job on the Mac: **confirm it's green on macOS** (the real cross-platform proof) and know how
to **distribute the new command**.

---

## A. Test on macOS

From the cloned canonical repo on the Mac:

```bash
git fetch origin
git checkout feat/serious-simple-plan
```

### 1. The new command's own tests (these must pass)
```bash
bash tests/test_simple_plan_skill.sh
#   → expect: 38 passed, 0 failed

bash tests/run_tests.sh tests/hooks/test_protected_path_guard.sh
#   → expect: 17 passed (on macOS the 2 cases skipped on Windows — symlink + unreadable-file —
#     now RUN, so you should see 17/17 here vs 15 passed + 2 skipped on Windows)
```

### 2. Guard safety (must be a no-op when no fence is set)
```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$PWD"'/README.md"}}' \
  | bash .claude/skills/serious-code/hooks/protected-path-guard.sh; echo "exit=$?"
#   → expect: exit=0, no output. The guard only acts when the active /serious-code plan has a
#     protected-paths.txt sidecar; otherwise it does nothing.
```

### 3. Full suite — the cross-platform parity check
```bash
bash tests/run_tests.sh
```
What to expect / how to read it:
- `tests/lib/portable.sh` is a **no-op on macOS** (it only translates paths when `cygpath` exists,
  i.e. on Windows). So it cannot have changed macOS behavior — any macOS pass/fail is the test's
  own, not the shim's.
- The **manifest tests should be GREEN**: `test_generate_manifest`, `test_integration`,
  `test_parse_manifest` (the generator now emits forward-slash keys on every OS).
- Some Windows-only failures simply **won't occur** on macOS (the `python3` Store-stub issue, the
  `detect_os` MINGW case, the symlink restriction).
- Some failures are part of a **separately-scoped cross-platform project** and may still fail on
  macOS too — compare against the documented baseline in
  `Research/debug/test-suite-green/debug_report.md` (section 7 lists every remaining item).
  Known still-pending: `is_serious()` edge, `test_status_line` (expects `~/.claude/statusline-command.sh`),
  `test_dispatch_audit` symlink fake-bin, slow-git timeouts, and wiring `tests/hooks/` into the
  default runner. **The manifest-generator item on that list is already DONE (closed on this branch).**

### 4. Try the command live (optional but ideal)
In Claude Code on the Mac:
```
/serious-simple-plan <path-to-research-or-manifest> --avoid "src/payments/**"
```
Confirm the produced `implementation_plan.md` has the avoid globs under **Appendix → Out of Scope**,
plus a `protected-paths.txt` + `protected-paths.sha256` sidecar in the plan folder. Running it
**without** `--avoid` should produce a plan and **no** sidecar.

---

## B. Update the skillset (distribute the new command)

- **Inside this repo:** Claude Code auto-discovers skills from `.claude/skills/`, so once the branch
  is checked out the `/serious-simple-plan` command is already usable here — no extra step.
- **To a global Claude Code install (normal flow):** after this branch is **merged to `main`**, run:
  ```bash
  serious-update          # pulls main, syncs skills/agents/hooks per manifest.json, merges settings
  ```
  `serious-update` reads `manifest.json` (now portable forward-slash keys) and SHA-256-verifies every
  file, so the new `SKILL.md` and `protected-path-guard.sh` distribute correctly on macOS.
  Useful variants: `serious-update --diff` (preview), `serious-update --check` (no apply),
  `serious-update --rollback` (revert).
- **Pre-merge (testing only):** do NOT run `serious-update` (it pulls `main`, which doesn't have the
  branch yet). Just work inside the checked-out branch repo.
- **Settings note:** Task 2 added one `PreToolUse(Edit|Write)` entry to `.claude/settings.json` (the
  guard). `serious-update`'s settings merge is additive and preserves user hooks.

---

## C. After macOS confirms green
Merge `feat/serious-simple-plan` → `main`, then `serious-update` on any install picks it up. If
macOS surfaces a NEW failure (not in the baseline above), capture it and add it to the
`Research/debug/test-suite-green/` project rather than patching ad-hoc.
