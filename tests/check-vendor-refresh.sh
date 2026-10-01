#!/usr/bin/env bash
# check-vendor-refresh.sh - Verify that `install.sh vendor` on an already scouted project keeps the
# generated review files (vendor wipes the catalog, including active.md), remembers the detected
# stacks, and leaves an unscouted project alone.
# Usage: ./tests/check-vendor-refresh.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"

FAILURES=0
fail() { echo "FAIL [$1] $2"; FAILURES=$((FAILURES + 1)); }
vendor() { bash "$REPO_ROOT/install.sh" vendor "$1" 2>&1; }

P="$T/project"; mkdir -p "$P/.git"
CAT="$P/.agents/principles-catalog"
printf '@docs\n' > "$P/.principles"

# ── 1. never scouted: vendor installs the catalog and scripts, and writes no review files ────
vendor "$P" >/dev/null
[ -x "$CAT/bin/emit.sh" ] || [ -f "$CAT/bin/emit.sh" ] || fail "scripts vendored" "bin/emit.sh missing"
[ -f "$CAT/VERSION" ] || fail "version vendored" "VERSION missing"
[ ! -e "$P/.agents/instructions/review.md" ] || fail "unscouted" "vendor must not generate review files for a project that was never scouted"
[ ! -e "$CAT/active.md" ] || fail "unscouted active.md" "active.md written for an unscouted project"

# ── 2. scout (what dot-scout's last phase runs), then vendor again ──────────────────────────
printf 'copilot-review\nvendor\n' > "$CAT/install.cfg"
bash "$CAT/bin/emit.sh" --root "$P" --stacks docs >/dev/null
[ -f "$CAT/active.md" ] && [ -f "$P/.agents/instructions/review.md" ] || fail "emit" "emit.sh wrote no files"
[ -f "$P/.github/instructions/docs.instructions.md" ] || fail "copilot file" "docs.instructions.md missing"
grep -qx 'stack-docs' "$CAT/install.cfg" || fail "stacks remembered" "stack-docs not in install.cfg"
grep -qx 'scout' "$CAT/install.cfg" || fail "scout marker" "emit.sh did not record the scout marker"
cksum < "$P/.agents/instructions/review.md" > "$T/before"

out="$(vendor "$P")"
[ -f "$CAT/active.md" ] || fail "active.md kept" "vendor removed active.md and did not regenerate it"
grep -q 'refreshed generated review files' <<< "$out" || fail "refresh message" "vendor did not report the refresh"
grep -qx 'stack-docs' "$CAT/install.cfg" || fail "stacks survive vendor" "stack-docs lost in install.cfg"
grep -qx 'copilot-review' "$CAT/install.cfg" || fail "targets survive vendor" "copilot-review lost in install.cfg"
cksum < "$P/.agents/instructions/review.md" > "$T/after"
cmp -s "$T/before" "$T/after" || fail "stable refresh" "review.md changed although nothing changed"
bash "$CAT/bin/emit.sh" --root "$P" --check >/dev/null || fail "fresh after vendor" "--check reports stale right after vendor"
grep -q 'DOC-PURPOSE' "$P/.github/instructions/docs.instructions.md" || fail "docs principles" "docs.instructions.md lacks DOC-PURPOSE"

# ── 3. a changed .principles is noticed by --check and healed by the next vendor ────────────
printf '@docs\n!DOC-PURPOSE\n' > "$P/.principles"
if bash "$CAT/bin/emit.sh" --root "$P" --check >/dev/null; then fail "stale detected" "--check missed a changed .principles"; fi
vendor "$P" >/dev/null
bash "$CAT/bin/emit.sh" --root "$P" --check >/dev/null || fail "healed" "vendor did not refresh after .principles changed"
! grep -q 'DOC-PURPOSE' "$P/.github/instructions/docs.instructions.md" || fail "exclusion applied" "DOC-PURPOSE still in docs.instructions.md"

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES vendor-refresh check(s) failed."
    exit 1
fi
echo "OK  vendor keeps scouted projects' generated files current, remembers stacks, leaves unscouted projects alone."
