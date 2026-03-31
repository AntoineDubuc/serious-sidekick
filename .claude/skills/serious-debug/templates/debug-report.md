## Bug: {{BUG_SUMMARY}}

**Reported:** {{DATE}}
**Mode:** {{MODE}} (auto-fix / quick / deep)
**Session:** {{SLUG}}

---

**Root Cause:** {{ROOT_CAUSE_STATEMENT}}

---

**Blast Radius:** {{FILE_COUNT}} files affected, {{TEST_COUNT}} tests touched, {{ENDPOINT_COUNT}} API endpoints impacted

### Direct Callers
{{DIRECT_CALLERS_LIST}}

### Transitive Dependencies
{{TRANSITIVE_LIST}}

### Affected Tests
{{AFFECTED_TESTS_WITH_STATUS}}

### API Endpoints
{{ENDPOINTS_LIST}}

---

**Evidence:**
- **Reproducer:** `{{REPRODUCER_CMD}}` — {{REPRODUCER_BEFORE}} before fix, {{REPRODUCER_AFTER}} after
- **Git bisect:** {{BISECT_RESULT}}
- **Hypotheses tested:**
{{HYPOTHESES_LOG}}

---

**Fix:** {{FIX_SUMMARY}}

### Changes
{{CHANGES_LIST_WITH_FILE_LINE}}

### Regression Test
- File: `{{REGRESSION_TEST_PATH}}`
- Assertion: {{REGRESSION_TEST_DESCRIPTION}}

---

**Verification:**
- Reproducer: {{FINAL_REPRODUCER_STATUS}}
- Affected tests: {{AFFECTED_TESTS_FINAL_STATUS}}
- Full suite: {{FULL_SUITE_STATUS}}
- Runtime check: {{RUNTIME_STATUS}}
