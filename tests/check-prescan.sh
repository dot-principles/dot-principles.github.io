#!/usr/bin/env bash
# check-prescan.sh - Verify lib/prescan.sh: hits, INSPECTED/SEMANTIC records, and that hits in build
# output and git-ignored files (which duplicate the source) are dropped.
# Usage: ./tests/check-prescan.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PRESCAN="$REPO_ROOT/lib/prescan.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

FAILURES=0
fail() { echo "FAIL [$1] $2"; FAILURES=$((FAILURES + 1)); }

CAT="$T/catalog"
mkdir -p "$CAT/principles/t"
cat > "$CAT/principles/t/.context-inspect.md" <<'EOF'
# test patterns
### T-ONE

- `grep -rn "TODO" $TARGET` | LOW | todo marker

### T-TWO

- `grep -rn "nothing-matches-this" $TARGET` | MEDIUM | never matches
EOF

scan() { bash "$PRESCAN" --catalog "$CAT" --ids T-ONE,T-TWO,T-THREE "$@" 2>&1; }

populate() { # dir
    mkdir -p "$1/src" "$1/bin" "$1/node_modules/dep" "$1/build"
    printf 'TODO fix this\n' > "$1/src/a.txt"
    printf 'TODO fix this\n' > "$1/bin/a.txt"
    printf 'TODO in a dependency\n' > "$1/node_modules/dep/x.txt"
    printf 'TODO in build output\n' > "$1/build/y.txt"
    printf 'a|b TODO with a pipe\n' > "$1/src/pipe.txt"
}

# ── 1. in a git repository: build dirs and git-ignored files are dropped ────────────────────
G="$T/gitproj"; mkdir -p "$G"
git -C "$G" init -q
printf 'bin/\n' > "$G/.gitignore"
populate "$G"
out="$(scan "$G")"

grep -q '^HIT|T-ONE|LOW|todo marker|.*src/a.txt:1:TODO fix this$' <<< "$out" || fail "src hit" "hit in src/a.txt missing: $out"
grep -q 'src/pipe.txt:1:a|b TODO with a pipe$' <<< "$out" || fail "pipe in raw match" "raw match containing | not preserved: $out"
grep -q '/bin/a.txt' <<< "$out" && fail "git-ignored file" "hit from a git-ignored bin/ directory was reported"
grep -q '/node_modules/' <<< "$out" && fail "node_modules" "hit from node_modules was reported"
grep -q '/build/' <<< "$out" && fail "build dir" "hit from build/ was reported"
grep -qx 'INSPECTED|T-ONE|2' <<< "$out" || fail "hit count" "expected 2 hits for T-ONE (src/a.txt, src/pipe.txt): $out"
grep -qx 'INSPECTED|T-TWO|0' <<< "$out" || fail "inspected without hits" "T-TWO should be INSPECTED with 0 hits: $out"
grep -qx 'SEMANTIC|T-THREE' <<< "$out" || fail "semantic" "T-THREE has no patterns and should be SEMANTIC: $out"

# ── 2. without git: the build and dependency directories are still dropped ──────────────────
N="$T/nogit"; mkdir -p "$N"
populate "$N"
out="$(scan "$N")"
grep -q '/node_modules/' <<< "$out" && fail "no git: node_modules" "hit from node_modules was reported"
grep -q '/build/' <<< "$out" && fail "no git: build dir" "hit from build/ was reported"
grep -q 'src/a.txt:1' <<< "$out" || fail "no git: src hit" "hit in src/a.txt missing: $out"
grep -q '/bin/a.txt' <<< "$out" || fail "no git: bin kept" "without git there is no ignore file, so bin/ is scanned: $out"

# ── 3. errors ───────────────────────────────────────────────────────────────────────────────
if bash "$PRESCAN" --catalog "$CAT" --ids T-ONE "$T/missing" >/dev/null 2>&1; then
    fail "missing target" "expected a non-zero exit"
fi
if bash "$PRESCAN" --catalog "$T/no-catalog" --ids T-ONE "$G" >/dev/null 2>&1; then
    fail "missing catalog" "expected a non-zero exit"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES prescan check(s) failed."
    exit 1
fi
echo "OK  prescan.sh reports hits once, from source files only, and keeps INSPECTED/SEMANTIC records."
