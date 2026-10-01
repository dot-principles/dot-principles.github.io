#!/usr/bin/env bash
# check-resolve.sh - Verify lib/resolve.sh: hierarchy, groups, exclusions, org lock, waivers,
# :max_principles, seeding, and Windows line endings.
# Usage: ./tests/check-resolve.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
RESOLVE="$REPO_ROOT/lib/resolve.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

CAT="$T/project/.agents/principles-catalog"
P="$T/project"
mkdir -p "$CAT/groups" "$CAT/layers/docs" "$P/.git" "$P/sub/deep"

# ── fixture catalog ─────────────────────────────────────────────────────────────────────────
cat > "$CAT/groups/a.yaml" <<'EOF'
name: a
principles:
  - X-ONE
  - X-TWO
EOF
cat > "$CAT/groups/b.yaml" <<'EOF'
name: b
includes:
  - a
principles:
  - X-THREE
EOF
cat > "$CAT/groups/cyc1.yaml" <<'EOF'
name: cyc1
includes:
  - cyc2
principles:
  - C-ONE
EOF
cat > "$CAT/groups/cyc2.yaml" <<'EOF'
name: cyc2
includes:
  - cyc1
principles:
  - C-TWO
EOF
cat > "$CAT/groups/org.yaml" <<'EOF'
name: org
principles:
  - ORG-ONE
  - ORG-TWO
EOF
cat > "$CAT/index.tsv" <<'EOF'
X-ONE|1|one
X-TWO|2|two
X-THREE|3|three
X-FOUR|2|four
X-FIVE|1|five
ORG-ONE|2|org one
ORG-TWO|2|org two
EOF
cat > "$CAT/layers/artifact-types.yaml" <<'EOF'
universal:
  - U-ONE
types:
  docs:
    stack: docs
EOF
cat > "$CAT/layers/docs/layer-1-universal.md" <<'EOF'
| ID | Title | Summary |
|----|-------|---------|
| D-ONE | t | s |
EOF

FAILURES=0
fail() { echo "FAIL [$1] $2"; FAILURES=$((FAILURES + 1)); }

ids()  { bash "$RESOLVE" --catalog "$CAT" --format ids "$@" | tr '\n' ' ' | sed 's/ $//'; }
full() { bash "$RESOLVE" --catalog "$CAT" "$@"; }
expect_ids() { # name expected target [extra resolve args...]
    local name="$1" expected="$2"; shift 2
    local actual; actual="$(ids "$@")"
    [ "$actual" = "$expected" ] || fail "$name" "expected '$expected', got '$actual'"
}
expect_record() { # name pattern target [extra args...]
    local name="$1" pattern="$2"; shift 2
    local out; out="$(full "$@")"
    grep -qE "$pattern" <<< "$out" || fail "$name" "no record matching /$pattern/"
}
expect_no_record() {
    local name="$1" pattern="$2"; shift 2
    local out; out="$(full "$@")"
    if grep -qE "$pattern" <<< "$out"; then fail "$name" "unexpected record matching /$pattern/"; fi
}

# ── 1. hierarchy: root → sub → deep, groups with includes, bare IDs, exclusions ─────────────
printf '%s\n' '# root' '@b' 'x-four' > "$P/.principles"
printf '%s\n' '!X-TWO' > "$P/sub/.principles"
printf '%s\n' 'X-FIVE' > "$P/sub/deep/.principles"
expect_ids "root"          "X-ONE X-TWO X-THREE X-FOUR"         "$P"
expect_ids "sub excludes"  "X-ONE X-THREE X-FOUR"               "$P/sub"
expect_ids "deep extends"  "X-ONE X-THREE X-FOUR X-FIVE"        "$P/sub/deep"
expect_ids "file target"   "X-ONE X-THREE X-FOUR X-FIVE"        "$P/sub/deep/some-file.txt"
expect_record "explain source" '^ACTIVE\|X-FOUR\|\.principles\|$'  "$P"
expect_record "excluded record" '^EXCLUDED\|X-TWO\|sub/\.principles$' "$P/sub"

# ── 2. group exclusion (!@group) ────────────────────────────────────────────────────────────
printf '%s\n' '!@a' > "$P/sub/.principles"
expect_ids "!@group" "X-THREE X-FOUR" "$P/sub"
printf '%s\n' '!X-TWO' > "$P/sub/.principles"

# ── 3. include cycle terminates; unknown group warns ────────────────────────────────────────
printf '%s\n' '@cyc1' '@nope' > "$P/sub/deep/.principles"
expect_record "cycle warn"   '^WARN\|include cycle' "$P/sub/deep"
expect_record "unknown warn" "^WARN\\|unknown group 'nope'" "$P/sub/deep"
expect_record "cycle still expands" '^ACTIVE\|C-TWO\|' "$P/sub/deep"
printf '%s\n' 'X-FIVE' > "$P/sub/deep/.principles"

# ── 4. Windows line endings ─────────────────────────────────────────────────────────────────
printf '@a\r\n!X-TWO\r\n' > "$P/sub/deep/.principles"
expect_ids "CRLF" "X-ONE X-THREE X-FOUR" "$P/sub/deep"
printf '%s\n' 'X-FIVE' > "$P/sub/deep/.principles"

# ── 5. seeding ──────────────────────────────────────────────────────────────────────────────
expect_ids "seed" "U-ONE D-ONE X-ONE X-TWO X-THREE X-FOUR" "$P" --seed docs
printf '%s\n' '!D-ONE' >> "$P/.principles"
expect_ids "exclusion beats seed" "U-ONE X-ONE X-TWO X-THREE X-FOUR" "$P" --seed docs
printf '%s\n' '@b' 'x-four' > "$P/.principles"

# ── 6. org baseline: lock wins over !ID, project :lock is ignored ───────────────────────────
printf '%s\n' '# org baseline' ':lock ORG-ONE' 'ORG-TWO' > "$CAT/org.principles"
printf '%s\n' '@b' 'x-four' '!ORG-ONE' '!ORG-TWO' ':lock X-ONE' '!X-ONE' > "$P/.principles"
expect_ids "org lock" "ORG-ONE X-TWO X-THREE X-FOUR" "$P"
expect_record "lock override"  '^LOCK-OVERRIDE\|ORG-ONE\|\.principles$' "$P"
expect_record "locked flag"    '^ACTIVE\|ORG-ONE\|org baseline\|locked$' "$P"
expect_record "org first"      '^FILE\|org baseline$' "$P"
expect_record "project lock ignored" '^WARN\|\.principles: :lock is only honoured' "$P"
printf '%s\n' ':lock @org' > "$CAT/org.principles"
printf '%s\n' '@b' '!ORG-TWO' > "$P/.principles"
expect_ids "lock a group" "ORG-ONE ORG-TWO X-ONE X-TWO X-THREE" "$P"

# ── 7. waivers ──────────────────────────────────────────────────────────────────────────────
export PRINCIPLES_TODAY="2026-09-30"
printf '%s\n' '@b' ':waive X-TWO until 2026-12-31 "legacy API, see ADR-12"' > "$P/.principles"
printf '%s\n' '# none' > "$CAT/org.principles"
expect_ids "waiver active" "X-ONE X-THREE" "$P"
expect_record "waived record" '^WAIVED\|X-TWO\|2026-12-31\|legacy API, see ADR-12\|\.principles$' "$P"
printf '%s\n' '@b' ':waive X-TWO until 2026-09-30 "last day counts"' > "$P/.principles"
expect_ids "waiver on its last day" "X-ONE X-THREE" "$P"
printf '%s\n' '@b' ':waive X-TWO until 2026-01-01 "old"' > "$P/.principles"
expect_ids "waiver expired" "X-ONE X-TWO X-THREE" "$P"
expect_record "expired record" '^EXPIRED\|X-TWO\|2026-01-01\|old\|\.principles$' "$P"
printf '%s\n' '@b' ':waive X-TWO until 2026-12-31' > "$P/.principles"
expect_ids "waiver without reason is ignored" "X-ONE X-TWO X-THREE" "$P"
expect_record "no reason warn" '^WARN\|\.principles: :waive X-TWO needs a reason' "$P"
printf '%s\n' '@b' ':waive X-TWO until soon "x"' > "$P/.principles"
expect_ids "bad date is ignored" "X-ONE X-TWO X-THREE" "$P"
expect_record "bad date warn" '^WARN\|\.principles: bad :waive line' "$P"
printf '%s\n' ':lock ORG-ONE' 'ORG-TWO' > "$CAT/org.principles"
printf '%s\n' '@b' ':waive ORG-ONE until 2026-12-31 "sunset in Q4"' > "$P/.principles"
expect_ids "waiver beats lock" "ORG-TWO X-ONE X-TWO X-THREE" "$P"
expect_record "waived locked" '^WAIVED\|ORG-ONE\|2026-12-31\|sunset in Q4\|' "$P"
printf '%s\n' '# none' > "$CAT/org.principles"
unset PRINCIPLES_TODAY

# ── 8. :max_principles drops Layer 2, then Layer 3; never Layer 1 or locked ─────────────────
printf '%s\n' '@b' 'x-four' 'x-five' ':max_principles 4' > "$P/.principles"
# layers: X-ONE 1, X-TWO 2, X-THREE 3, X-FOUR 2, X-FIVE 1. Five over a cap of 4: drop one L2, last first.
expect_ids "cap drops layer 2 first" "X-ONE X-TWO X-THREE X-FIVE" "$P"
expect_record "trimmed record" '^TRIMMED\|X-FOUR\|2$' "$P"
printf '%s\n' '@b' 'x-four' 'x-five' ':max_principles 2' > "$P/.principles"
expect_ids "cap then drops layer 3" "X-ONE X-FIVE" "$P"
printf '%s\n' '@b' 'x-four' 'x-five' ':max_principles 1' > "$P/.principles"
expect_ids "cap never drops layer 1" "X-ONE X-FIVE" "$P"
printf '%s\n' ':lock ORG-ONE' > "$CAT/org.principles"
printf '%s\n' '@b' ':max_principles 1' > "$P/.principles"
expect_ids "cap never drops locked" "ORG-ONE X-ONE" "$P"
printf '%s\n' '# none' > "$CAT/org.principles"

# ── 8b. explicit mode (--spec): groups and IDs replace the hierarchy ────────────────────────
printf '%s\n' '@b' '!X-TWO' > "$P/.principles"
printf '%s\n' ':lock ORG-ONE' > "$CAT/org.principles"
expect_ids "spec: group and id" "X-ONE X-TWO X-FIVE" "$P" --spec "a, @x-five"
expect_ids "spec ignores .principles and org" "X-ONE X-TWO" "$P" --spec "a"
expect_record "spec group record" '^GROUP\|a\|explicit$' "$P" --spec "a"
printf '%s\n' '# none' > "$CAT/org.principles"
if out="$(bash "$RESOLVE" --catalog "$CAT" --spec "a nope" "$P" 2>&1)"; then
    fail "spec unknown" "expected a non-zero exit for an unknown item"
else
    [ $? -eq 3 ] || true
    grep -q 'Unknown principle or group: nope' <<< "$out" || fail "spec unknown message" "got: $out"
fi

# ── 8c. the deepest file wins: a deeper @group or ID adds back what an outer file excluded ───
P2="$T/deepest"
mkdir -p "$P2/.git" "$P2/n1/n2" "$P2/m1"
printf '# none\n' > "$CAT/org.principles"

# A. outer !@b removes everything of b (which includes a); a deeper @a adds only a's principles back
printf '@b\n' > "$P2/.principles"
printf '!@b\n' > "$P2/n1/.principles"
printf '@a\n' > "$P2/n1/n2/.principles"
expect_ids "deepest: root"                "X-ONE X-TWO X-THREE" "$P2"
expect_ids "deepest: outer exclusion"     ""                    "$P2/n1"
expect_ids "deepest: deeper add wins"     "X-ONE X-TWO"         "$P2/n1/n2"
expect_record "deepest: reinstated"       '^REINSTATED\|X-ONE\|n1/\.principles\|n1/n2/\.principles$' "$P2/n1/n2"
expect_record "deepest: added-by is the deeper file" '^ACTIVE\|X-ONE\|n1/n2/\.principles\|$' "$P2/n1/n2"
expect_record "deepest: still excluded"   '^EXCLUDED\|X-THREE\|n1/\.principles$' "$P2/n1/n2"
out="$(bash "$RESOLVE" --catalog "$CAT" --format explain "$P2/n1/n2")"
grep -q 'Reinstated:    X-ONE was excluded in n1/.principles and added back by n1/n2/.principles' <<< "$out" \
    || fail "deepest: explain" "explain output lacks the Reinstated line: $out"

# B. within one file an exclusion wins, in either line order
printf 'X-FIVE\n!X-FIVE\n' > "$P2/m1/.principles"
expect_ids "same file: exclusion after add"  "X-ONE X-TWO X-THREE" "$P2/m1"
printf '!X-FIVE\nX-FIVE\n' > "$P2/m1/.principles"
expect_ids "same file: exclusion before add" "X-ONE X-TWO X-THREE" "$P2/m1"

# C. an exclusion of a principle that is not active yet does not bind a later addition
printf '!X-FOUR\n' > "$P2/n1/.principles"
printf 'X-FOUR\n' > "$P2/n1/n2/.principles"
expect_ids "exclusion of nothing"            "X-ONE X-TWO X-THREE X-FOUR" "$P2/n1/n2"

# D. a deeper !ID still removes what an outer file added
printf '@b\nX-FOUR\n' > "$P2/.principles"
printf '!X-FOUR\n' > "$P2/n1/.principles"
rm -f "$P2/n1/n2/.principles"
expect_ids "deeper exclusion"                "X-ONE X-TWO X-THREE"        "$P2/n1"
expect_ids "outer file unaffected"           "X-ONE X-TWO X-THREE X-FOUR" "$P2"

# E. a locked principle cannot be removed by any file, deep or not
printf ':lock ORG-ONE\n' > "$CAT/org.principles"
printf '!ORG-ONE\n' > "$P2/n1/.principles"
expect_ids "lock survives a deeper exclusion" "ORG-ONE X-ONE X-TWO X-THREE X-FOUR" "$P2/n1"
expect_record "lock override still reported"  '^LOCK-OVERRIDE\|ORG-ONE\|n1/\.principles$' "$P2/n1"
printf '# none\n' > "$CAT/org.principles"

# F. seeds can be excluded by an outer file and added back by a deeper one
printf '@a\n' > "$P2/.principles"
printf '!D-ONE\n' > "$P2/n1/.principles"
printf 'D-ONE\n' > "$P2/n1/n2/.principles"
expect_ids "seed excluded"                   "U-ONE X-ONE X-TWO" "$P2/n1" --seed docs
expect_ids "seed added back deeper"          "U-ONE D-ONE X-ONE X-TWO" "$P2/n1/n2" --seed docs

# ── 9. errors ───────────────────────────────────────────────────────────────────────────────
if bash "$RESOLVE" --catalog "$T/missing" "$P" >/dev/null 2>&1; then
    fail "missing catalog" "expected a non-zero exit"
fi
if bash "$RESOLVE" --catalog "$CAT" >/dev/null 2>&1; then
    fail "missing target" "expected a non-zero exit"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES resolve check(s) failed."
    exit 1
fi
echo "OK  resolve.sh: hierarchy, groups, lock, waivers, cap and seed behave as documented."
