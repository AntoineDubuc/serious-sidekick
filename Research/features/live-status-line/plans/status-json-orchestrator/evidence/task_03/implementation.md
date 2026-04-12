diff --git a/.claude/skills/serious-code/SKILL.md b/.claude/skills/serious-code/SKILL.md
index 8bf2de0..d344f51 100644
--- a/.claude/skills/serious-code/SKILL.md
+++ b/.claude/skills/serious-code/SKILL.md
@@ -647,3 +647,110 @@ If `/serious-code --resume` is invoked or the orchestrator detects an existing `
 14. **Dead code is not implementation.** A widget/component/handler that exists in its own file but is never imported, instantiated, or mounted by a parent container is dead code. The Completion Gate must verify reachability for all "visible to user" ACs: find the parent container, confirm it imports the new component, confirm it instantiates/renders it, confirm any replaced component is removed. Dead code = FAIL.
 15. **Stub code must be caught before verification.** Step 1.25 scans for `{STUB_PATTERNS}` after implementation. If stubs are found, the implementer must replace them with real code before proceeding. An empty method body or TODO placeholder that reaches verification is a process failure.
 16. **Inter-plan regression is mandatory for multi-plan phases.** After merging a phase's worktrees (Step 1f), re-verify all previous phases' visible-to-user ACs using `{RUNTIME_VERIFY_CMD}`. If any regress, stop and report before starting the next phase. A green phase that silently breaks a previous phase is worse than a red phase.
+
+---
+
+## Outputs
+
+| Output | Location | Description |
+|--------|----------|-------------|
+| `execution_log.md` | `{plan_folder}/` | Phase/plan status, timestamps, failures |
+| `completion_report.md` | `{plan_folder}/` | Final summary with evidence |
+| `progress.md` | `{plan_folder}/plans/` | Per-plan task tracking (multi-plan only) |
+| `evidence/` | `{plan_folder}/` | Per-task evidence artifacts |
+| `status.json` | `$PLAN_DIR/` | Live status for the status line (see below) |
+
+---
+
+## Status JSON Output
+
+Write `$PLAN_DIR/status.json` on every state transition: phase change, task start, task complete, agent start, agent complete. This file is the data contract consumed by the status line (Plan 4b).
+
+**Schema reference:** See `.claude/skills/_shared/status-schema.md` for the full field inventory and type constraints.
+
+This is single-plan status only. Cross-worktree aggregation is future work.
+
+### Write Triggers
+
+Update `status.json` whenever any of these events occur:
+
+- Phase changes (start, complete)
+- Task starts or completes
+- Agent starts, completes, or errors (implementer, reviewer, test_runner, runtime_checker, qa)
+
+### Sanitization Pipeline (4-step, mandatory)
+
+Before writing any string field (`plan_name`, `worktree_name`) to `status.json`, apply this 4-step pipeline in order:
+
+1. **Strip ALL C0 control characters** including TAB, LF, CR:
+   ```bash
+   sanitized=$(printf '%s' "$raw_value" | LC_ALL=C tr -d '\000-\037\177')
+   ```
+2. **Strip UTF-8 bidi codepoints** (U+202A-U+202E, U+2066-U+2069, U+200B-U+200F):
+   ```bash
+   sanitized=$(printf '%s' "$sanitized" | sed 's/[\xe2\x80\x8b-\xe2\x80\x8f]//g; s/[\xe2\x80\xaa-\xe2\x80\xae]//g; s/[\xe2\x81\xa6-\xe2\x81\xa9]//g')
+   ```
+3. **Truncate** to 200 bytes:
+   ```bash
+   sanitized=$(printf '%s' "$sanitized" | head -c 200)
+   ```
+4. **Serialize via JSON library** — use `python3 json.dumps()` or `jq --arg`. NEVER string-interpolate values into a JSON template, because unescaped `"` or `\` in agent strings would break JSON structure:
+   ```bash
+   python3 -c "
+   import json
+   d = {
+       'version': 1,
+       'plan_name': '''$sanitized_plan_name''',
+       ...
+   }
+   print(json.dumps(d))
+   "
+   ```
+   Or equivalently with jq:
+   ```bash
+   jq -n --arg plan_name "$sanitized_plan_name" ... '{version: 1, plan_name: $plan_name, ...}'
+   ```
+
+### File Permissions
+
+Write `status.json.tmp` with mode 0600. The `mv` preserves mode.
+
+```bash
+umask 077
+# ... write to status.json.tmp ...
+```
+
+### Atomic Write Pattern
+
+Write to `$PLAN_DIR/status.json.tmp`, then `mv` to `$PLAN_DIR/status.json`. This ensures the reader never sees partial JSON.
+
+```bash
+# Write to temp file
+python3 -c "import json; ..." > "$PLAN_DIR/status.json.tmp"
+chmod 0600 "$PLAN_DIR/status.json.tmp"
+mv "$PLAN_DIR/status.json.tmp" "$PLAN_DIR/status.json"
+```
+
+### Error Behavior
+
+If the write or `mv` fails (disk full, permissions, missing `$PLAN_DIR`), log a warning to stderr and continue the `/serious-code` session. Do NOT abort the session — status.json is advisory, not load-bearing. The reader (Plan 4b) handles missing files gracefully.
+
+### status.json template
+
+```json
+{
+  "version": 1,
+  "plan_name": "<sanitized plan name>",
+  "phase": {"current": 0, "total": 0},
+  "task": {"current": 0, "total": 0},
+  "agents": {
+    "implementer": "idle",
+    "reviewer": "idle",
+    "test_runner": "idle",
+    "runtime_checker": "idle",
+    "qa": "idle"
+  },
+  "worktree_name": "",
+  "timestamp": "2026-04-12T00:00:00Z"
+}
+```
