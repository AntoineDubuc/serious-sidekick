#!/usr/bin/env python3
"""
plan-lint — deterministic pre-gate for /serious-plan and /serious-review.

Catches the defect classes that survive human and agent review rounds because
they are mechanical, not judgemental:

  P*  placeholders    — undefined {VAR}; {VAR} pasted into a runnable line
  C*  citations       — file paths and file:line / file#anchor references that
                        do not resolve against the real tree
  T*  task structure  — Master Checklist / task sections / test-file map must
                        describe the SAME set of tasks; every task needs
                        components, criteria, a gate and a rollback
  D*  propagation     — every row of "Decisions of record" must show up in a
                        task's Key components AND in an acceptance criterion.
                        (THE failure: "a fix landed in the section that argues
                        for it and not in the task that builds it.")
  S*  superseded      — terms the plan itself declares dead must not survive
                        anywhere else in the document
  G*  gates           — gate commands that cannot fail (or cannot pass), and
                        gates with no pasted evidence of ever being executed
  F*  facts           — numeric claims about env-var sets checked against the
                        real .env by NAME ONLY (values are never read or shown)
  M*  metadata        — required workflow frontmatter

Exit codes: 0 = no errors, 1 = at least one ERROR, 2 = bad invocation.
Stdlib only. Read-only: this script never writes to anything it inspects.

Usage:
    plan-lint.py <plan.md | plan-dir> [more...] [--json] [--strict] [--quiet]

    --strict   treat WARN as failure too
    --json     machine-readable findings on stdout
    --quiet    only print the summary line per plan
"""

from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

SOURCE_EXT = {
    "ts", "tsx", "js", "jsx", "mjs", "cjs", "json", "yml", "yaml",
    "sql", "sh", "md", "html", "css", "env",
}

NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
}

# A path token is allowed to be missing from disk if its line marks it as new.
NEW_MARKERS = re.compile(
    r"\b(NEW|CREATE|CREATES|ADD|ADDS|to be created|does not exist( today|yet)?|"
    r"neither exists|captur\w*|fixtures?|evidence|generated|produced|writes)\b", re.I)
MODIFY_MARKERS = re.compile(r"\b(MODIFY|MODIFIES|EDIT|EXTEND|EXTENDS|existing|already exists)\b")

# The plan is saying this file should NOT exist — absence is the point.
ELIMINATED = re.compile(
    r"\b(removes?|removed|deletes?|deleted|no longer|not needed|drops?|dropped|"
    r"eliminat\w+|no reference implementation|avoids?|instead of)\b", re.I)

# Evidence that a command was actually run, not composed.
EVIDENCE_MARKERS = re.compile(
    r"\b(executed|Executed|verified|Verified|real output|actual output|exit\s+\d|"
    r"Test Suites:|Tests:|ESLint found|prints|returned|→\s*\d{3}\b)"
)


@dataclass
class Finding:
    check: str
    severity: str  # ERROR | WARN
    line: int
    message: str
    detail: str = ""

    def anchor(self, path: Path) -> str:
        return f"{path}:{self.line}"


@dataclass
class Doc:
    path: Path
    lines: list[str]
    project_root: Path
    repo_root: Path | None = None
    config: dict[str, str] = field(default_factory=dict)
    fenced: dict[int, str] = field(default_factory=dict)  # 1-based line -> fence lang
    findings: list[Finding] = field(default_factory=list)

    def add(self, check: str, severity: str, line: int, message: str, detail: str = "") -> None:
        self.findings.append(Finding(check, severity, line, message, detail))

    def text(self) -> str:
        return "".join(self.lines)

    def in_fence(self, lineno: int) -> str | None:
        return self.fenced.get(lineno)


# --------------------------------------------------------------------------
# parsing helpers
# --------------------------------------------------------------------------

def load_doc(path: Path) -> Doc:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    project_root = find_project_root(path)
    doc = Doc(path=path, lines=lines, project_root=project_root)
    mark_fences(doc)
    parse_config(doc)
    return doc


def find_project_root(path: Path) -> Path:
    for parent in [path.resolve()] + list(path.resolve().parents):
        if (parent / ".claude").is_dir() and (parent / "CLAUDE.md").exists():
            return parent
    return path.resolve().parent


def mark_fences(doc: Doc) -> None:
    lang: str | None = None
    for i, raw in enumerate(doc.lines, start=1):
        stripped = raw.lstrip()
        if stripped.startswith("```"):
            if lang is None:
                lang = stripped[3:].strip() or "plain"
                doc.fenced[i] = "__open__"
            else:
                doc.fenced[i] = "__close__"
                lang = None
            continue
        if lang is not None:
            doc.fenced[i] = lang


def section_bounds(doc: Doc, heading_re: str, level: int = 2) -> tuple[int, int] | None:
    """1-based [start, end) of a heading's body, ignoring fenced content."""
    pat = re.compile(rf"^#{{{level}}} \s*{heading_re}", re.IGNORECASE)
    start = None
    for i, raw in enumerate(doc.lines, start=1):
        if doc.in_fence(i):
            continue
        if start is None and pat.match(raw):
            start = i
            continue
        if start is not None and re.match(rf"^#{{1,{level}}} ", raw):
            return (start, i)
    if start is not None:
        return (start, len(doc.lines) + 1)
    return None


def table_rows(doc: Doc, start: int, end: int) -> list[tuple[int, list[str]]]:
    """Markdown table rows in [start, end), as (lineno, cells)."""
    out = []
    for i in range(start, min(end, len(doc.lines) + 1)):
        raw = doc.lines[i - 1]
        if doc.in_fence(i):
            continue
        s = raw.strip()
        if not s.startswith("|") or not s.endswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue  # separator
        out.append((i, cells))
    return out


def parse_config(doc: Doc) -> None:
    bounds = section_bounds(doc, r"Project Configuration")
    if not bounds:
        return
    rows = table_rows(doc, *bounds)
    for _, cells in rows:
        if len(cells) < 2:
            continue
        m = re.search(r"\{([A-Z][A-Z0-9_]*)\}", cells[0])
        if m:
            doc.config[m.group(1)] = cells[1]
    repo = doc.config.get("REPO_ROOT", "")
    m = re.search(r"`([^`]+)`", repo) or re.search(r"(/[\w./-]+)", repo)
    if m:
        p = Path(m.group(1))
        if p.is_dir():
            doc.repo_root = p


def code_spans(line: str) -> list[str]:
    return re.findall(r"`([^`\n]+)`", line)


def slugify(heading: str) -> str:
    h = heading.strip().lower()
    h = re.sub(r"[`*_]", "", h)
    h = re.sub(r"[^\w\s-]", "", h)
    return re.sub(r"\s+", "-", h).strip("-")


# --------------------------------------------------------------------------
# path resolution
# --------------------------------------------------------------------------

_INDEX_CACHE: dict[str, dict[str, list[str]]] = {}


def file_index(root: Path) -> dict[str, list[str]]:
    """basename -> [posix paths relative to root]. Cached per root.

    node_modules IS indexed: plans legitimately cite library internals
    (MikroORM's QueryBuilder.js, for example) as evidence for a decision.
    """
    key = str(root)
    if key in _INDEX_CACHE:
        return _INDEX_CACHE[key]
    idx: dict[str, list[str]] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {".git", ".next", "dist-cache"}]
        rel = os.path.relpath(dirpath, root)
        for fn in filenames:
            p = fn if rel == "." else f"{rel}/{fn}"
            idx.setdefault(fn, []).append(p)
    _INDEX_CACHE[key] = idx
    return idx


def index_lookup(doc: Doc, token: str) -> Path | None:
    """Resolve a token by basename, then by path-suffix, across known roots."""
    base = token.rsplit("/", 1)[-1]
    for root in filter(None, [doc.repo_root, doc.project_root]):
        idx = file_index(root)
        hits = idx.get(base)
        if not hits:
            continue
        if "/" not in token:
            return root / hits[0]
        needle = token.lstrip("./")
        for h in hits:
            if h == needle or h.endswith("/" + needle):
                return root / h
    return None


def candidate_bases(doc: Doc) -> list[Path]:
    bases: list[Path] = []
    if doc.repo_root:
        bases.append(doc.repo_root)
        pkgs = doc.repo_root / "packages"
        if pkgs.is_dir():
            for pkg in sorted(p for p in pkgs.iterdir() if p.is_dir()):
                bases.append(pkg / "src")
                bases.append(pkg)
        bases.append(doc.repo_root.parent)
    bases.append(doc.project_root)
    bases.append(doc.path.parent)
    bases.append(doc.path.parent.parent)
    seen, out = set(), []
    for b in bases:
        r = str(b)
        if r not in seen:
            seen.add(r)
            out.append(b)
    return out


def resolve_path(doc: Doc, token: str, bases: list[Path]) -> Path | None:
    t = token.lstrip("./")
    if token.startswith("/"):
        p = Path(token)
        return p if p.exists() else None
    for base in bases:
        p = base / t
        if p.exists():
            return p
    return None


PATH_RE = re.compile(
    r"^(?P<path>[\w][\w./@~-]*\.(?P<ext>[a-z]{2,5}))"
    r"(?::(?P<l1>\d+)(?:-(?P<l2>\d+))?)?"
    r"(?:#(?P<anchor>[\w-]+))?$"
)


def declared_new_paths(doc: Doc) -> set[str]:
    """Files this plan says it creates: NEW-marked lines and every Test-file map row.

    A path the plan creates cannot be expected on disk before the plan is built.
    """
    declared: set[str] = set()

    def harvest(line: str) -> None:
        for span in code_spans(line):
            for tok in re.split(r"\s+|·", span.strip()):
                m = PATH_RE.match(tok.strip().rstrip(".,;:)"))
                if m and m.group("ext") in SOURCE_EXT:
                    declared.add(m.group("path"))

    # A NEW bullet owns its indented continuation lines: the marker is on the
    # first line, the path it creates is often on the second.
    in_new_bullet = False
    for i, raw in enumerate(doc.lines, start=1):
        if doc.in_fence(i):
            continue
        is_bullet = bool(re.match(r"^\s*[-*]\s", raw))
        if is_bullet:
            in_new_bullet = bool(NEW_MARKERS.search(raw))
        elif not raw.strip() or not raw.startswith((" ", "\t")):
            in_new_bullet = False
        if in_new_bullet or NEW_MARKERS.search(raw):
            harvest(raw)

    tm = section_bounds(doc, r"Test-file map", level=3)
    if tm:
        for lineno, cells in table_rows(doc, *tm):
            for cell in cells[1:]:
                harvest(cell)

    # Sibling plans in the same manifest create files this plan legitimately
    # names before they exist. Plan 2 citing a module Plan 1 creates is correct.
    for sibling in sorted(doc.path.parent.parent.glob("*/implementation_plan.md")):
        if sibling.resolve() == doc.path.resolve():
            continue
        try:
            for line in sibling.read_text(encoding="utf-8", errors="replace").splitlines():
                if NEW_MARKERS.search(line):
                    harvest(line)
        except OSError:
            continue

    # A file declared NEW by full path is the same file when named bare later.
    return declared | {p.rsplit("/", 1)[-1] for p in declared}


def templated_outputs(doc: Doc) -> list[re.Pattern]:
    """Filenames a fenced command builds from a template.

    `(out / f'issue-{key}.v2.json')` really does produce `issue-ABC-123.v2.json`;
    without this the plan looks like it references those files from nowhere.
    """
    pats: list[re.Pattern] = []
    for i, raw in enumerate(doc.lines, start=1):
        if not doc.in_fence(i):
            continue
        for lit in re.findall(r"""['"]([^'"\n]*\{[^'"\n}]*\}[^'"\n]*\.[a-z]{2,5})['"]""", raw):
            rx = "".join(".*" if part.startswith("{") else re.escape(part)
                         for part in re.split(r"(\{[^}]*\})", lit) if part)
            pats.append(re.compile(rx.replace(".*.*", ".*") + "$"))
    return pats


def dirs_written_in_fences(doc: Doc) -> set[str]:
    """Directories a fenced command writes into — their contents are produced, not missing."""
    out: set[str] = set()
    for i, raw in enumerate(doc.lines, start=1):
        if not doc.in_fence(i):
            continue
        for m in re.finditer(r"[\w./-]*/(?:__tests__|fixtures|evidence|tmp)[\w./-]*", raw):
            out.add(m.group(0).rstrip("'\").,"))
    return out


def check_paths_and_citations(doc: Doc) -> None:
    bases = candidate_bases(doc)
    declared = declared_new_paths(doc)
    written_dirs = dirs_written_in_fences(doc)
    templates = templated_outputs(doc)
    last_path_on_line: dict[int, Path] = {}

    for i, raw in enumerate(doc.lines, start=1):
        fence = doc.in_fence(i)
        # Inside fences we only look at explicit path-like arguments, not prose.
        spans = code_spans(raw) if not fence else []
        line_is_new = bool(NEW_MARKERS.search(raw))

        for span in spans:
            tok = span.strip().rstrip(".,;:)")
            m = PATH_RE.match(tok)
            if not m:
                # bare `:55` — bind to the most recent resolved path
                bare = re.fullmatch(r":(\d+)(?:-(\d+))?", tok)
                if bare:
                    target = None
                    for back in range(i, max(0, i - 4), -1):
                        if back in last_path_on_line:
                            target = last_path_on_line[back]
                            break
                    if target:
                        check_line_number(doc, i, target, bare.group(1), bare.group(2), tok)
                continue

            ext = m.group("ext")
            if ext not in SOURCE_EXT:
                continue
            path_tok = m.group("path")
            if "/" not in path_tok and ext in {"md", "env"} and not path_tok.startswith("."):
                # bare filenames like `research.md` — resolvable, keep going
                pass

            resolved = resolve_path(doc, path_tok, bases) or index_lookup(doc, path_tok)

            if resolved is None:
                if line_is_new or path_tok in declared or path_tok.rsplit("/", 1)[-1] in declared:
                    continue  # a file this plan (or a sibling plan) creates
                if any(t.match(path_tok.rsplit('/', 1)[-1]) for t in templates):
                    continue  # produced by a templated filename in a fenced command
                if ELIMINATED.search(raw):
                    continue  # the plan is arguing this file should not exist
                if MODIFY_MARKERS.search(raw):
                    doc.add("C1", "ERROR", i,
                            f"path marked as existing does not resolve: {path_tok}",
                            "MODIFY/EXTEND implies the file is already on disk")
                elif any(path_tok.startswith(d.lstrip("./")) or d.endswith(
                        path_tok.rsplit("/", 1)[0]) for d in written_dirs):
                    doc.add("C1", "WARN", i,
                            f"path is never named as an output: {path_tok}",
                            "a fenced command writes into its directory, but the file is not declared")
                else:
                    doc.add("C1", "ERROR", i,
                            f"path does not resolve and is not declared NEW: {path_tok}",
                            "not on disk, not on a NEW line, not in the Test-file map")
                continue

            last_path_on_line[i] = resolved

            if m.group("l1"):
                check_line_number(doc, i, resolved, m.group("l1"), m.group("l2"), tok)

            if m.group("anchor"):
                check_anchor(doc, i, resolved, m.group("anchor"), tok)


def check_line_number(doc: Doc, lineno: int, target: Path, l1: str, l2: str | None, tok: str) -> None:
    try:
        total = sum(1 for _ in target.open("r", encoding="utf-8", errors="replace"))
    except OSError as exc:
        doc.add("C2", "WARN", lineno, f"cannot read cited file {target}", str(exc))
        return
    hi = int(l2 or l1)
    lo = int(l1)
    if lo < 1 or hi > total:
        doc.add("C2", "ERROR", lineno,
                f"citation out of range: {tok}",
                f"{target} has {total} lines, citation reaches {hi}")
    elif l2 and int(l2) < lo:
        doc.add("C2", "ERROR", lineno, f"inverted line range: {tok}")


def check_anchor(doc: Doc, lineno: int, target: Path, anchor: str, tok: str) -> None:
    if target.suffix != ".md":
        return
    try:
        body = target.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return
    slugs = {slugify(h) for h in re.findall(r"^#{1,6}\s+(.*)$", body, re.M)}
    want = slugify(anchor)
    # A shortened anchor (`#Plan-1` for "Plan 1: `some-slug`") is accepted;
    # an anchor matching no heading at all is not.
    if not any(s == want or s.startswith(want + "-") for s in slugs):
        doc.add("C3", "ERROR", lineno,
                f"anchor does not resolve to a heading: {tok}",
                f"{target.name} has no heading slugging to '{want}'")


# --------------------------------------------------------------------------
# placeholders
# --------------------------------------------------------------------------

# `{VAR}` is a plan placeholder. `${VAR}` is shell interpolation — not ours.
PLACEHOLDER_RE = re.compile(r"(?<!\$)\{([A-Z][A-Z0-9_]{2,})\}")


def check_placeholders(doc: Doc) -> None:
    if not doc.config:
        doc.add("P0", "ERROR", 1, "no '## Project Configuration' table found",
                "every {VAR} used in the plan must be defined there")
        return

    config_bounds = section_bounds(doc, r"Project Configuration")

    for i, raw in enumerate(doc.lines, start=1):
        names = set(PLACEHOLDER_RE.findall(raw))
        if not names:
            continue

        for name in sorted(names):
            if name not in doc.config:
                doc.add("P1", "ERROR", i, f"undefined placeholder {{{name}}}",
                        "not a row of the Project Configuration table")

        fence = doc.in_fence(i)
        if not fence or fence in {"__open__", "__close__"}:
            continue
        if fence not in {"bash", "sh", "shell", "zsh", "console"}:
            continue
        # Comment lines are how the plans *declare* a command for a placeholder.
        code = raw.split("#", 1)[0]
        if not code.strip():
            continue
        leaked = PLACEHOLDER_RE.findall(code)
        if leaked:
            doc.add("P2", "ERROR", i,
                    f"placeholder in a runnable line: {', '.join('{%s}' % n for n in sorted(set(leaked)))}",
                    "a pasted {VAR} is a literal shell token — the command cannot run as written")

    # Placeholders defined but referenced nowhere at all (including by other rows).
    if config_bounds:
        lo, hi = config_bounds
        rows = "".join(doc.lines[lo - 1:hi - 1])
        body = "".join(doc.lines[:lo - 1] + doc.lines[hi - 1:])
        for name in sorted(doc.config):
            token = f"{{{name}}}"
            uses_elsewhere = token in body
            # Its own defining cell does not count as a use; other rows do.
            uses_in_table = rows.count(token) > 1
            if not uses_elsewhere and not uses_in_table:
                doc.add("P3", "WARN", lo,
                        f"placeholder {{{name}}} is defined but never used")


# --------------------------------------------------------------------------
# task structure
# --------------------------------------------------------------------------

TASK_HEADING_RE = re.compile(r"^###\s+Task\s+([^\s—–:]+)")


def task_sections(doc: Doc) -> dict[str, tuple[int, int]]:
    starts: list[tuple[str, int]] = []
    for i, raw in enumerate(doc.lines, start=1):
        if doc.in_fence(i):
            continue
        m = TASK_HEADING_RE.match(raw)
        if m:
            starts.append((m.group(1), i))
    out: dict[str, tuple[int, int]] = {}
    for idx, (tid, line) in enumerate(starts):
        end = len(doc.lines) + 1
        for j in range(line + 1, len(doc.lines) + 1):
            if doc.in_fence(j):
                continue
            if re.match(r"^#{1,3} ", doc.lines[j - 1]):
                end = j
                break
        out[tid] = (line, end)
    return out


def checklist_tasks(doc: Doc) -> tuple[dict[str, int], int]:
    bounds = section_bounds(doc, r"Master Checklist")
    if not bounds:
        return {}, 0
    ids: dict[str, int] = {}
    for lineno, cells in table_rows(doc, *bounds):
        if not cells or not cells[0]:
            continue
        head = re.sub(r"[`*]", "", cells[0]).strip()
        if head.lower() in {"#", "task", "id"}:
            continue
        if re.fullmatch(r"[\w.-]+", head):
            ids[head] = lineno
    return ids, bounds[0]


def testmap_tasks(doc: Doc) -> tuple[dict[str, int], int]:
    bounds = section_bounds(doc, r"Test-file map", level=3)
    if not bounds:
        return {}, 0
    ids: dict[str, int] = {}
    for lineno, cells in table_rows(doc, *bounds):
        if not cells or not cells[0]:
            continue
        head = re.sub(r"[`*]", "", cells[0]).strip()
        if head.lower() in {"task", "#"}:
            continue
        if re.fullmatch(r"[\w.-]+", head):
            ids[head] = lineno
    return ids, bounds[0]


def check_task_consistency(doc: Doc) -> dict[str, tuple[int, int]]:
    sections = task_sections(doc)
    checklist, cl_line = checklist_tasks(doc)
    testmap, tm_line = testmap_tasks(doc)

    if not checklist:
        doc.add("T0", "ERROR", 1, "no '## Master Checklist' table with task ids found")
    if not sections:
        doc.add("T0", "ERROR", 1, "no '### Task <id>' sections found")
    if not testmap:
        doc.add("T0", "ERROR", 1, "no '### Test-file map' table found")

    sec_ids = set(sections)
    cl_ids = set(checklist)
    tm_ids = set(testmap)

    for missing in sorted(cl_ids - sec_ids):
        doc.add("T1", "ERROR", checklist[missing],
                f"Task {missing} is in the Master Checklist but has no task section")
    for missing in sorted(sec_ids - cl_ids):
        doc.add("T1", "ERROR", sections[missing][0],
                f"Task {missing} has a section but is not in the Master Checklist")
    if testmap:
        for missing in sorted(cl_ids - tm_ids):
            doc.add("T1", "ERROR", cl_line,
                    f"Task {missing} is in the Master Checklist but not in the Test-file map")
        for missing in sorted(tm_ids - cl_ids):
            doc.add("T1", "ERROR", testmap[missing],
                    f"Task {missing} is in the Test-file map but not in the Master Checklist")

    if cl_ids and sec_ids and tm_ids and cl_ids == sec_ids == tm_ids:
        pass

    return sections


def block_lines(doc: Doc, start: int, end: int, label_re: str) -> list[tuple[int, str]]:
    """Lines belonging to a **Label** block inside [start, end)."""
    pat = re.compile(rf"^\*\*{label_re}\.?\*\*", re.IGNORECASE)
    out: list[tuple[int, str]] = []
    active = False
    for i in range(start, min(end, len(doc.lines) + 1)):
        raw = doc.lines[i - 1]
        if doc.in_fence(i):
            if active:
                out.append((i, raw))
            continue
        m = pat.match(raw.strip())
        if m:
            active = True
            rest = raw.strip()[m.end():].lstrip(" —-–:")
            if rest:  # `**Key components** — MODIFY x; MODIFY y` on one line
                out.append((i, rest))
            continue
        if active and re.match(r"^\*\*[A-Z]", raw.strip()) and not pat.match(raw.strip()):
            break
        if active:
            out.append((i, raw))
    return out


def all_criteria(doc: Doc, start: int, end: int) -> list[tuple[int, str]]:
    """Every checkbox line in a task, labelled block or not."""
    return [(i, doc.lines[i - 1]) for i in range(start, min(end, len(doc.lines) + 1))
            if not doc.in_fence(i) and re.match(r"^\s*-\s*\[[ xX]\]", doc.lines[i - 1])]


def check_task_completeness(doc: Doc, sections: dict[str, tuple[int, int]]) -> None:
    for tid, (start, end) in sorted(sections.items()):
        body = "".join(doc.lines[start - 1:end - 1])

        # A manual/verification task states **Steps** instead of components.
        comps = (block_lines(doc, start, end, r"Key components?")
                 or block_lines(doc, start, end, r"Steps"))
        if not any(l.strip() for _, l in comps):
            doc.add("T2", "ERROR", start,
                    f"Task {tid}: no '**Key components**' (or '**Steps**') block")

        labelled = [(i, l) for i, l in block_lines(doc, start, end, r"Acceptance criteria")
                    if re.match(r"^\s*-\s*\[[ xX]\]", l)]
        crits = labelled or all_criteria(doc, start, end)
        if not crits:
            doc.add("T2", "ERROR", start, f"Task {tid}: no acceptance criteria")
        elif not labelled:
            doc.add("T6", "WARN", start,
                    f"Task {tid}: criteria are not under an '**Acceptance criteria**' heading",
                    "every other task uses the heading; reviewers scan for it")

        if not re.search(r"\*\*Rollback\.?\*\*", body):
            doc.add("T3", "WARN", start, f"Task {tid}: no rollback stated")

        if not re.search(r"\bGate\b", body) and not re.search(r"\{[A-Z_]*TEST_CMD\}", body):
            doc.add("T4", "WARN", start, f"Task {tid}: no gate command named")

        # A criterion that names no checkable object is unverifiable.
        for i, line in crits:
            txt = re.sub(r"^\s*-\s*\[[ xX]\]\s*", "", line).strip()
            if len(txt) < 25 and "`" not in txt:
                doc.add("T5", "WARN", i,
                        f"Task {tid}: criterion is too thin to verify",
                        txt[:70])


# --------------------------------------------------------------------------
# decision propagation — the check that matters most
# --------------------------------------------------------------------------

STOPWORDS = {"true", "false", "null", "npm", "test", "bash", "ts", "js"}


def anchor_terms(cell: str) -> list[str]:
    """Code identifiers naming the SUBJECT of a decision.

    Citations (`manifest.md#Plan-1`) are evidence for the decision, not the thing
    it decides — including them made every cited decision look untraceable.
    """
    terms = []
    for span in re.findall(r"`([^`]+)`", cell):
        s = span.strip()
        if len(s) < 4 or s.lower() in STOPWORDS:
            continue
        if " " in s and not re.search(r"[.(]", s):
            continue
        m = PATH_RE.match(s)
        if m and m.group("ext") in SOURCE_EXT:
            continue  # a citation, not the subject
        terms.append(s)
    return terms


def norm(s: str) -> str:
    """Collapse a term so `OauthStateService` matches `oauth-state.service.ts`."""
    return re.sub(r"[^a-z0-9]", "", s.lower())


def check_decision_propagation(doc: Doc, sections: dict[str, tuple[int, int]]) -> None:
    bounds = section_bounds(doc, r"Decisions of record", level=3)
    if not bounds:
        doc.add("D0", "ERROR", 1, "no '### Decisions of record' table found")
        return

    dec_lo, dec_hi = bounds

    comp_blob_parts: list[str] = []
    crit_blob_parts: list[str] = []
    task_blob_parts: list[str] = []
    for tid, (start, end) in sections.items():
        task_blob_parts.append("".join(doc.lines[start - 1:end - 1]))
        comp_blob_parts.append(doc.lines[start - 1])  # the task heading names what it builds
        comp_blob_parts += [l for _, l in (block_lines(doc, start, end, r"Key components?")
                                           or block_lines(doc, start, end, r"Steps"))]
        labelled = [l for i, l in block_lines(doc, start, end, r"Acceptance criteria")
                    if re.match(r"^\s*-\s*\[[ xX]\]", l)]
        crit_blob_parts += labelled or [l for _, l in all_criteria(doc, start, end)]

    comp_blob = norm("\n".join(comp_blob_parts))
    crit_blob = norm("\n".join(crit_blob_parts))
    task_blob = norm("\n".join(task_blob_parts))

    for lineno, cells in table_rows(doc, dec_lo, dec_hi):
        if len(cells) < 2:
            continue
        decision = cells[0]
        if decision.lower().strip() in {"decision", ""}:
            continue

        terms = anchor_terms(decision)
        if not terms:
            doc.add("D2", "WARN", lineno,
                    "decision carries no `code term` — cannot be traced mechanically",
                    re.sub(r"\*", "", decision)[:80])
            continue

        label = re.sub(r"[*`]", "", decision)[:70]
        hint = f"{label} · terms: {', '.join(terms[:3])}"

        in_task = any(norm(t) in task_blob for t in terms)
        in_comp = any(norm(t) in comp_blob for t in terms)
        in_crit = any(norm(t) in crit_blob for t in terms)

        # A prohibition ("No base HTTP client", "Do not extend KNOWN_CODES")
        # has nothing to build — only something to check.
        negative = bool(re.match(r"^\s*\**\s*(no|not|do not|don'?t|never)\b",
                                 re.sub(r"[*`]", "", decision), re.I))

        if not in_task:
            doc.add("D1", "ERROR", lineno,
                    "decision appears in NO task — argued for, never built", hint)
        elif not in_comp and not in_crit:
            doc.add("D1", "ERROR", lineno,
                    "decision is mentioned in a task but neither built nor checked",
                    hint + " — not in any Key components block, not in any criterion")
        elif not in_comp and not negative:
            doc.add("D3", "WARN", lineno,
                    "decision is checked by a criterion but names no Key component", hint)
        elif not in_crit:
            doc.add("D3", "WARN", lineno,
                    "decision is built but no acceptance criterion names it", hint)


# --------------------------------------------------------------------------
# superseded terms — opt-in, declared by the plan itself
# --------------------------------------------------------------------------

SUPERSEDED_BLOCK = re.compile(
    r"<!--\s*lint:superseded\s*(?P<body>.*?)-->", re.S | re.I)

EXPLANATORY = re.compile(
    r"\b(superseded|earlier version|no longer|instead of|rather than|NOT\b|never|"
    r"replaced|was\b|previously|do not|don't|deleted|removed)\b", re.I)


def check_superseded(doc: Doc) -> None:
    blob = doc.text()
    m = SUPERSEDED_BLOCK.search(blob)
    if not m:
        doc.add("S0", "WARN", 1,
                "no <!-- lint:superseded --> block",
                "declare replaced designs so the linter can prove the old wording is gone")
        return

    decl_lines = set()
    offset = blob[:m.start()].count("\n") + 1
    for k in range(offset, offset + m.group(0).count("\n") + 1):
        decl_lines.add(k)

    terms: list[tuple[str, str]] = []
    for line in m.group("body").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = re.split(r"\s*->\s*", line, maxsplit=1)
        terms.append((parts[0].strip().strip("`"), parts[1].strip() if len(parts) > 1 else ""))

    for term, repl in terms:
        if not term:
            continue
        for i, raw in enumerate(doc.lines, start=1):
            if i in decl_lines or term not in raw:
                continue
            if EXPLANATORY.search(raw):
                continue  # the line is explaining that it is dead
            doc.add("S1", "ERROR", i,
                    f"superseded term still specified: {term}",
                    f"replaced by: {repl}" if repl else "declared dead by this plan")


# --------------------------------------------------------------------------
# gate satisfiability
# --------------------------------------------------------------------------

ALWAYS_TRUE = [
    (re.compile(r"\|\|\s*(true|:)\s*$"), "`|| true` makes the command incapable of failing"),
    (re.compile(r"\bcurl\b(?=[^|\n]*\s-[a-zA-Z]*f)[^|\n]*\|"),
     "`curl -f` piped: on 404 curl prints nothing and the pipeline still reports success"),
    (re.compile(r"\bgrep\b[^|\n]*\|\s*(wc|head|tail|cat)\b"),
     "grep piped into a counter: exit status comes from the counter, which always succeeds"),
    (re.compile(r"^\s*(?!.*\b(if|\|\||&&|exit|test)\b).*\bgrep\b(?!.*\s-q).*$"),
     "grep result is neither tested nor used — the gate cannot fail on a match"),
]

SWALLOW = re.compile(r"2>\s*/dev/null")


def bash_blocks(doc: Doc) -> list[tuple[int, int]]:
    out, open_at, lang = [], None, None
    for i, raw in enumerate(doc.lines, start=1):
        marker = doc.fenced.get(i)
        if marker == "__open__":
            lang = raw.lstrip()[3:].strip().lower()
            open_at = i
        elif marker == "__close__":
            if open_at is not None and lang in {"bash", "sh", "shell", "zsh", "console"}:
                out.append((open_at, i))
            open_at, lang = None, None
    return out


def guarded_assignments(code: list[tuple[int, str]]) -> set[str]:
    """Vars captured with `x=$(… || true)` AND later asserted on.

    `n=$(grep -c … || true)` followed by `[ "$n" -eq 0 ] || exit 1` is the
    CORRECT idiom for grep's count-zero exit — not a defanged gate.
    """
    assigned = {}
    for i, raw in code:
        m = re.match(r"^\s*(\w+)=\$\(", raw)
        if m:
            assigned[m.group(1)] = i
    blob = "".join(l for _, l in code)
    return {v for v in assigned
            if re.search(rf"(\[\[?[^\]]*\$\{{?{v}\b|\btest\b[^\n]*\$\{{?{v}\b)", blob)}


def check_gates(doc: Doc) -> None:
    task_ranges = list(task_sections(doc).values())

    for start, end in bash_blocks(doc):
        body_lines = [(i, doc.lines[i - 1]) for i in range(start + 1, end)]
        code = [(i, l) for i, l in body_lines if l.split("#", 1)[0].strip()]
        if not code:
            continue

        safe_vars = guarded_assignments(code)
        in_task = any(lo <= start < hi for lo, hi in task_ranges)

        for i, raw in code:
            line = raw.split("#", 1)[0].rstrip()
            m = re.match(r"^\s*(\w+)=\$\(", line)
            if m and m.group(1) in safe_vars:
                continue  # captured, then asserted on below
            for pat, why in ALWAYS_TRUE:
                if pat.search(line):
                    doc.add("G1", "ERROR", i, "gate cannot fail", why)
                    break
            if SWALLOW.search(line) and re.search(r"\b(test|\[|grep|curl|npm|npx)\b", line):
                doc.add("G2", "WARN", i,
                        "stderr discarded on an assertion line",
                        "a real failure becomes indistinguishable from a pass")

        # Multi-command gate blocks need `set -e` or explicit exit handling.
        if len(code) > 2:
            blob = "".join(l for _, l in code)
            if "set -e" not in blob and not re.search(r"\|\||&&|\bexit\b|\bif\b", blob):
                doc.add("G3", "WARN", start,
                        "multi-command block with no `set -e` and no exit handling",
                        "an early command can fail while the block still reports success")

        # Provenance: was this ever run? Only gates are held to this — setup
        # and pre-flight scripts are instructions, not assertions.
        if in_task:
            window = "".join(doc.lines[max(0, start - 8):min(len(doc.lines), end + 6)])
            if not EVIDENCE_MARKERS.search(window):
                doc.add("G4", "WARN", start,
                        "gate block with no pasted evidence of ever being executed",
                        "'a gate that has not been run is not a gate'")


# --------------------------------------------------------------------------
# env-var count claims (names only — values are never read)
# --------------------------------------------------------------------------

COUNT_CLAIM = re.compile(
    r"\b(?:all\s+)?(?P<num>\d+|" + "|".join(NUMBER_WORDS) + r")\s+"
    r"(?:`)?(?P<prefix>[A-Z][A-Z0-9_]*)_\*?(?:`)?\s+"
    r"(?:env(?:ironment)?\s+)?(?:vars?|variables?|keys?|entries)",
    re.IGNORECASE)


def env_var_names(env_path: Path) -> set[str]:
    """Variable NAMES only. Values are never read into memory or reported."""
    names = set()
    try:
        with env_path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                key = s.split("=", 1)[0].strip()
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                    names.add(key)
    except OSError:
        return set()
    return names


def check_env_claims(doc: Doc) -> None:
    if not doc.repo_root:
        return
    env_path = doc.repo_root / ".env"
    if not env_path.exists():
        return
    names = env_var_names(env_path)
    if not names:
        return

    for i, raw in enumerate(doc.lines, start=1):
        for m in COUNT_CLAIM.finditer(raw):
            word = m.group("num").lower()
            claimed = NUMBER_WORDS.get(word)
            if claimed is None:
                try:
                    claimed = int(word)
                except ValueError:
                    continue
            prefix = m.group("prefix").upper()
            actual = sum(1 for n in names if n.startswith(prefix + "_"))
            if actual == 0:
                continue
            if actual != claimed:
                doc.add("F1", "ERROR", i,
                        f"claims {claimed} {prefix}_* vars; .env defines {actual}",
                        f"counted by name in {env_path} — values not read")


# --------------------------------------------------------------------------
# frontmatter
# --------------------------------------------------------------------------

REQUIRED_FM = ["skill", "slug", "status", "created"]


def check_frontmatter(doc: Doc) -> None:
    if not doc.lines or doc.lines[0].strip() != "---":
        doc.add("M1", "ERROR", 1, "no YAML frontmatter")
        return
    end = None
    for i in range(2, len(doc.lines) + 1):
        if doc.lines[i - 1].strip() == "---":
            end = i
            break
    if end is None:
        doc.add("M1", "ERROR", 1, "unterminated frontmatter")
        return
    keys = {}
    for i in range(2, end):
        m = re.match(r"^([a-z_]+):\s*(.*)$", doc.lines[i - 1].strip())
        if m:
            keys[m.group(1)] = m.group(2).strip()
    for req in REQUIRED_FM:
        if req not in keys:
            doc.add("M1", "ERROR", 1, f"frontmatter missing required field '{req}'")

    src = keys.get("source") or keys.get("verified_source")
    if src:
        p = doc.project_root / src
        if not p.exists():
            doc.add("M2", "ERROR", 1, f"frontmatter source does not exist: {src}")


# --------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------

CHECKS = [
    ("frontmatter", check_frontmatter),
    ("placeholders", check_placeholders),
    ("paths", check_paths_and_citations),
    ("gates", check_gates),
    ("env-claims", check_env_claims),
    ("superseded", check_superseded),
]


def lint(path: Path) -> Doc:
    doc = load_doc(path)
    for _, fn in CHECKS:
        fn(doc)
    sections = check_task_consistency(doc)
    check_task_completeness(doc, sections)
    check_decision_propagation(doc, sections)
    doc.findings.sort(key=lambda f: (f.severity != "ERROR", f.line, f.check))
    return doc


def report(doc: Doc, quiet: bool) -> tuple[int, int]:
    errors = [f for f in doc.findings if f.severity == "ERROR"]
    warns = [f for f in doc.findings if f.severity == "WARN"]

    if not quiet:
        print(f"\n\033[1m{doc.path}\033[0m")
        if doc.repo_root:
            print(f"  repo root: {doc.repo_root}")
        if not doc.findings:
            print("  clean")
        for f in doc.findings:
            colour = "\033[31m" if f.severity == "ERROR" else "\033[33m"
            print(f"  {colour}{f.severity:<5}\033[0m {f.check:<3} "
                  f"{doc.path.name}:{f.line}  {f.message}")
            if f.detail:
                print(f"        └─ {f.detail}")

    verdict = "FAIL" if errors else ("WARN" if warns else "PASS")
    print(f"\n  {verdict}: {len(errors)} error(s), {len(warns)} warning(s) — {doc.path.name}")
    return len(errors), len(warns)


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a for a in argv[1:] if a.startswith("--")}
    if not args:
        print(__doc__)
        return 2

    targets: list[Path] = []
    for a in args:
        p = Path(a).expanduser()
        if p.is_dir():
            found = sorted(p.rglob("implementation_plan.md"))
            if not found:
                print(f"no implementation_plan.md under {p}", file=sys.stderr)
                return 2
            targets += found
        elif p.exists():
            targets.append(p)
        else:
            print(f"not found: {p}", file=sys.stderr)
            return 2

    docs = [lint(t) for t in targets]

    if "--json" in flags:
        print(json.dumps([
            {
                "plan": str(d.path),
                "errors": sum(1 for f in d.findings if f.severity == "ERROR"),
                "warnings": sum(1 for f in d.findings if f.severity == "WARN"),
                "findings": [asdict(f) for f in d.findings],
            } for d in docs
        ], indent=2))
    else:
        total_e = total_w = 0
        for d in docs:
            e, w = report(d, "--quiet" in flags)
            total_e += e
            total_w += w
        if len(docs) > 1:
            print(f"\n\033[1mTOTAL: {total_e} error(s), {total_w} warning(s) "
                  f"across {len(docs)} plan(s)\033[0m")

    failed = any(f.severity == "ERROR" for d in docs for f in d.findings)
    if "--strict" in flags:
        failed = failed or any(d.findings for d in docs)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
