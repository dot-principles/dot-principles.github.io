#!/usr/bin/env bash
# check-audit-gates.sh — Verify that the Phase 8–10 gate language is intact, and that the audit
# core still hands over to it. The gates live in the fix-flow reference file, which dot-audit
# reads only after it has findings; the core must point at it and keep the approval rule.
# Run locally before pushing, or via CI on PRs that touch audit/skill files.
# Usage: ./tests/check-audit-gates.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

# Gate files: the source, and the installed copy (run `./install.sh vendor .` first).
GATE_FILES=(
  "$REPO_ROOT/commands/dot/.audit-fix-flow.md"
  "$REPO_ROOT/.agents/skills/dot-audit/fix-flow.md"
)

# Core files: the command source and the installed skill. They must not lose the handover.
CORE_FILES=(
  "$REPO_ROOT/commands/dot/audit.md"
  "$REPO_ROOT/.agents/skills/dot-audit/SKILL.md"
)

ERRORS=0

check() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -qF -- "$pattern" "$file"; then
    echo "FAIL [$label]"
    echo "     File   : $file"
    echo "     Missing: $pattern"
    ERRORS=$((ERRORS + 1))
  fi
}

for file in "${GATE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL [file-exists] Missing file: $file"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  name="$(basename "$file")"

  check "$file" "## Phase 8"                                    "$name: Phase 8 heading"
  check "$file" "GATE — Requires explicit user approval"        "$name: Phase 8 GATE marker"
  check "$file" "Would you like me to fix these findings"       "$name: Phase 8 fix question"
  check "$file" "Yes, fix them"                                 "$name: Phase 8 Yes choice"
  check "$file" "No, just the report"                          "$name: Phase 8 No choice"
  check "$file" "## Phase 9"                                    "$name: Phase 9 heading"
  check "$file" "How would you like to proceed"                 "$name: Phase 9 commit question"
  check "$file" "Commit only"                                   "$name: Phase 9 Commit-only choice"
  check "$file" "Commit and push"                               "$name: Phase 9 Commit-and-push choice"
  check "$file" "Exit"                                          "$name: Phase 9 Exit choice"
  check "$file" "## Phase 10"                                   "$name: Phase 10 heading"
  check "$file" "Shall I open a pull request"                   "$name: Phase 10 PR question"
  check "$file" "Yes, open PR"                                  "$name: Phase 10 Yes choice"
  check "$file" "No, keep the branch"                           "$name: Phase 10 No choice"

  # Gates use plain-text output (not an ask_user tool), so each must end with the hard-stop phrase
  # (Phases 8, 9 and 10 each end with this instruction).
  count=$(grep -cF "End your response here. Do not call any tools" "$file" || true)
  if [[ "$count" -lt 3 ]]; then
    echo "FAIL [$name: hard-stop count]"
    echo "     File   : $file"
    echo "     Expected: at least 3 occurrences of hard-stop (Phases 8, 9, 10); found: $count"
    ERRORS=$((ERRORS + 1))
  fi
done

for file in "${CORE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL [file-exists] Missing file: $file"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  name="$(basename "$file")"

  check "$file" "fix-flow.md"                                   "$name: hands over to fix-flow.md"
  check "$file" "explicit user approval"                        "$name: approval rule stated in the core"
  check "$file" "does **not** grant permission to fix"          "$name: no implied permission to fix"
done

if [[ $ERRORS -eq 0 ]]; then
  echo "OK  All Phase 8–10 gate markers verified in ${#GATE_FILES[@]} files; ${#CORE_FILES[@]} core files hand over to them."
  exit 0
else
  echo ""
  echo "FAIL $ERRORS check(s) failed. The audit gate workflow is incomplete."
  exit 1
fi
