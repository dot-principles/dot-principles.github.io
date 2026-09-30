#!/usr/bin/env bash
# check-stale-docs.sh - Fail when documentation still describes retired or removed behaviour.
# Usage: ./tests/check-stale-docs.sh [repo-root]
#
# Each rule is: <label>|<extended regex>|<files that may legitimately mention it>
# CHANGELOG.md is always allowed (history). Add new rules when something is retired.
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

# User-facing docs and command sources. Generated copies (.agents/) are excluded on purpose.
scan_files() {
    find . -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.ps1' -o -name '*.cmd' \) \
        ! -path './node_modules/*' ! -path './.git/*' ! -path './.vitepress/*' \
        ! -path './.agents/*' ! -path './.idea/*' \
        ! -name 'CHANGELOG.md'
}

RULES=(
    # Old vendored catalog path; legacy uninstall notes may name it.
    'old catalog path|\.principles-catalog|./INSTALL.md ./DESIGN.md ./uninstall.sh'
    # Claude rules files are no longer generated; only legacy cleanup notes may name them.
    'claude rules files|\.claude/rules|./INSTALL.md ./DESIGN.md'
    # Retired command.
    'retired dot-prime|dot-prime|./tests/check-retired-prime.sh'
    # Removed install targets (install.sh only knows <dir>, vendor, --list).
    'removed install targets|install\.(sh|ps1|cmd) (all|claude|copilot|copilot-cli|copilot-ide|codex) |'
    # Catalog counters go stale on the next change; describe what exists, not how many. The scout
    # report example is illustrative output, and a leading ≤ marks a guideline, not a count.
    'catalog counter|(^|[^≤0-9])[0-9]{2,3} (principles|namespaces|shipped groups|groups)\b|./commands/dot/scout.md'
    # Fork is no longer the way to add company principles.
    'fork advice|[Ff]ork this repo(sitory)?(\*\*)? and add|'
)

failures=0
while IFS= read -r file; do
    for rule in "${RULES[@]}"; do
        label="${rule%%|*}"
        rest="${rule#*|}"
        allowed="${rest##*|}"
        regex="${rest%|*}"

        skip=false
        for ok in $allowed; do
            [ "$file" = "$ok" ] && skip=true
        done
        [ "$skip" = true ] && continue

        if matches="$(grep -nE "$regex" "$file" 2>/dev/null)"; then
            while IFS= read -r line; do
                echo "FAIL [$label] $file:$line"
            done <<< "$matches"
            failures=$((failures + 1))
        fi
    done
done < <(scan_files)

if [ "$failures" -gt 0 ]; then
    echo "$failures stale-documentation finding(s). Update the docs, or add the file to the rule's allow-list with a reason."
    exit 1
fi

echo "OK  No stale documentation references found."
