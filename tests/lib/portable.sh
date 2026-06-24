#!/bin/bash
# portable.sh — cross-platform path helpers for the test suite (macOS + Windows/Git-Bash).
#
# WHY THIS EXISTS
# On Windows under Git Bash (MSYS), the shell speaks POSIX paths (/tmp/x, /c/Users/x) but
# native executables — notably the Windows python.org interpreter the tests shell out to —
# do NOT understand them: `/tmp/...` is read as `C:\tmp\...` and `/c/...` as a missing path,
# producing FileNotFoundError. `cygpath -m` converts a POSIX path to MIXED form
# (`C:/Users/...`) that BOTH MSYS shell tools AND native Windows executables accept.
#
# On macOS / Linux, `cygpath` does not exist, so every helper is a pass-through: paths stay
# POSIX and the native python reads them directly. This file therefore changes nothing on
# macOS/Linux and only translates on Windows — never swap a Mac assumption for a Windows one.
#
# Usage:
#   source "<repo>/tests/lib/portable.sh"
#   REPO_ROOT="$(winpath "$REPO_ROOT")"   # normalize any path handed to native exes
#   TMP_DIR="$(mktemp -d)"                # already mixed-form because TMPDIR is exported below

# winpath <path> — echo <path> in a form native executables (python) can open.
# No-op on macOS/Linux (no cygpath); mixed-form conversion on Windows/MSYS.
winpath() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

# Make `mktemp -d` return a path native executables can read, by pointing TMPDIR at a
# mixed-form temp root on Windows. On macOS/Linux TMPDIR is left untouched.
if command -v cygpath >/dev/null 2>&1; then
  export TMPDIR="$(cygpath -m "${TMPDIR:-/tmp}")"
fi
