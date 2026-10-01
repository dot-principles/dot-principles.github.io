#!/usr/bin/env bash
# check-extends.sh - Verify `:extends` (org baseline) in install.sh vendor: local and git sources,
# pinning, principles.lock, org.principles, precedence over other extras, errors, cleanup.
# Usage: ./tests/check-extends.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"

FAILURES=0
fail() { echo "FAIL [$1] $2"; FAILURES=$((FAILURES + 1)); }
has()  { grep -qF -- "$2" "$1" 2>/dev/null || fail "$3" "$1 lacks: $2"; }
lacks(){ if grep -qF -- "$2" "$1" 2>/dev/null; then fail "$3" "$1 unexpectedly has: $2"; fi; return 0; }

make_org() { # dir namespace principle-id
    local dir="$1" ns="$2" id="$3"
    mkdir -p "$dir/principles/$ns" "$dir/groups"
    printf 'description: "%s test namespace"\n' "$ns" > "$dir/principles/$ns/catalog.yaml"
    printf '# %s - Test principle\n\n**Layer:** 1\n**Categories:** test\n**Applies-to:** all\n**Summary:** Summary for %s.\n' "$id" "$id" \
        > "$dir/principles/$ns/${id,,}.md"
    printf 'name: %s\nprinciples:\n  - %s\n' "$ns" "$id" > "$dir/groups/$ns.yaml"
    printf '# org baseline\n:lock %s\n' "$id" > "$dir/org.principles"
}
vendor() { bash "$REPO_ROOT/install.sh" vendor "$1" 2>&1; }
new_project() { P="$T/$1"; mkdir -p "$P/.git"; }

# ── 1. local source: merged, locked, recorded ───────────────────────────────────────────────
make_org "$T/org-src" acme ACME-ONE
new_project local
CAT="$P/.agents/principles-catalog"
printf ':extends ../org-src\n@acme\n!ACME-ONE\n' > "$P/.principles"
# a user-level extra with the same namespace must lose to the org baseline (registered first)
make_org "$T/other" acme OTHER-ONE
printf '%s\n' "$T/other" > "$P/.principles-extra"
out="$(vendor "$P")" || fail "vendor local" "$out"

has "$CAT/index.tsv" "ACME-ONE|1|Summary for ACME-ONE." "extends: principle indexed"
lacks "$CAT/index.tsv" "OTHER-ONE" "extends wins the namespace collision"
has "$CAT/groups/acme.yaml" "ACME-ONE" "extends: group vendored"
has "$CAT/org.principles" ":lock ACME-ONE" "org.principles copied"
has "$CAT/org.principles" "# from ../org-src local" "org.principles provenance"
has "$CAT/principles.lock" "extends ../org-src local org-principles=" "lock records the local source"
[ -d "$CAT/bin" ] && [ -f "$CAT/bin/resolve.sh" ] || fail "bin" "scripts were not vendored"

resolved="$(bash "$CAT/bin/resolve.sh" --format full "$P")"
grep -q '^ACTIVE|ACME-ONE|org baseline|locked$' <<< "$resolved" || fail "lock through vendor" "ACME-ONE should stay active and locked: $resolved"
grep -q '^LOCK-OVERRIDE|ACME-ONE|' <<< "$resolved" || fail "lock override" "project !ACME-ONE should be reported"

# vendoring again gives the same lock (nothing drifts by itself)
cksum < "$CAT/principles.lock" > "$T/lock1"
vendor "$P" >/dev/null
cksum < "$CAT/principles.lock" > "$T/lock2"
cmp -s "$T/lock1" "$T/lock2" || fail "lock stable" "principles.lock changed without any input change"

# ── 2. removing :extends removes the baseline ───────────────────────────────────────────────
printf '@acme\n' > "$P/.principles"
rm -f "$P/.principles-extra"
vendor "$P" >/dev/null
[ ! -e "$CAT/org.principles" ] || fail "cleanup org.principles" "still present after :extends was removed"
[ ! -e "$CAT/principles.lock" ] || fail "cleanup lock" "still present after :extends was removed"

# ── 3. git source: pinned to a tag, commit recorded ─────────────────────────────────────────
make_org "$T/org-remote.git" corp CORP-ONE
git -C "$T/org-remote.git" init -q
git -C "$T/org-remote.git" -c user.name=t -c user.email=t@example.com add -A
git -C "$T/org-remote.git" -c user.name=t -c user.email=t@example.com commit -q -m "baseline"
git -C "$T/org-remote.git" tag v1.0.0
SHA="$(git -C "$T/org-remote.git" rev-parse v1.0.0)"
# move the default branch on, so the pin must pick the tag and not HEAD
printf '# changed\n:lock CORP-CHANGED\n' > "$T/org-remote.git/org.principles"
git -C "$T/org-remote.git" -c user.name=t -c user.email=t@example.com commit -q -am "later change"

new_project git
CAT="$P/.agents/principles-catalog"
printf ':extends %s@v1.0.0\n@corp\n' "$T/org-remote.git" > "$P/.principles"
out="$(vendor "$P")" || fail "vendor git" "$out"
has "$CAT/principles.lock" "ref=v1.0.0 commit=$SHA" "lock records the tag's commit"
has "$CAT/org.principles" ":lock CORP-ONE" "baseline taken from the pinned tag"
lacks "$CAT/org.principles" "CORP-CHANGED" "later commits are not picked up"
has "$CAT/index.tsv" "CORP-ONE|1|" "git source: principle indexed"

# a commit id works as a pin too
printf ':extends %s@%s\n@corp\n' "$T/org-remote.git" "$SHA" > "$P/.principles"
out="$(vendor "$P")" || fail "vendor git commit pin" "$out"
has "$CAT/principles.lock" "commit=$SHA" "commit pin resolved"

# ── 4. errors are loud, never silent ────────────────────────────────────────────────────────
printf ':extends %s\n@corp\n' "$T/org-remote.git" > "$P/.principles"
if out="$(vendor "$P")"; then fail "unpinned git" "vendor should fail for an unpinned git source"; else
    grep -q "must be pinned" <<< "$out" || fail "unpinned message" "expected a 'must be pinned' message, got: $out"
fi
printf ':extends ../does-not-exist\n' > "$P/.principles"
if out="$(vendor "$P")"; then fail "missing dir" "vendor should fail for a missing :extends directory"; else
    grep -q "directory not found" <<< "$out" || fail "missing dir message" "expected 'directory not found', got: $out"
fi
printf ':extends %s@v9.9.9\n' "$T/org-remote.git" > "$P/.principles"
if vendor "$P" >/dev/null; then fail "bad ref" "vendor should fail for an unknown ref"; fi

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES extends check(s) failed."
    exit 1
fi
echo "OK  :extends vendors the org baseline, pins git sources, writes principles.lock and fails loudly."
