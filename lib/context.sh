#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# context.sh — Print the audit context (principle statement and violations to detect) for the
# requested principle IDs, and nothing else. Replaces reading whole per-namespace
# .context-audit.md files when only a few entries are needed.
#
# Usage: context.sh [--catalog DIR] <ID>...
#        context.sh [--catalog DIR] --active        (every ID in <catalog>/active.md)
#
# Output is the entries verbatim, each starting with "### ID - Title". An ID with no entry in
# this catalog is reported as "### ID - (no audit context in this catalog)" and the script
# still exits 0, so one missing entry never stops a review.
set -euo pipefail
# shellcheck source=principles-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/principles-common.sh"

CATALOG=""; ACTIVE=0; declare -a IDS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --catalog) CATALOG="$2"; shift 2 ;;
        --active)  ACTIVE=1; shift ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)        echo "context.sh: unknown option $1" >&2; exit 2 ;;
        *)         IDS+=("${1^^}"); shift ;;
    esac
done
[ -n "$CATALOG" ] || CATALOG="$(pc_default_catalog "$(pc_git_root "$(pwd)")")"
[ -d "$CATALOG/principles" ] || { echo "context.sh: no catalog at $CATALOG (run install.sh vendor)" >&2; exit 2; }

if [ "$ACTIVE" = 1 ]; then
    [ -f "$CATALOG/active.md" ] || { echo "context.sh: $CATALOG/active.md not found (run /dot-scout)" >&2; exit 2; }
    while IFS= read -r id; do IDS+=("$id"); done < <(sed -nE 's/^- ([A-Z0-9]+(-[A-Z0-9]+)*):.*/\1/p' "$CATALOG/active.md")
fi
[ "${#IDS[@]}" -gt 0 ] || { echo "context.sh: give at least one principle ID (or --active)" >&2; exit 2; }

# One pass over the context files: which file holds each ID.
declare -A FILE_OF=()
while IFS= read -r f; do
    while IFS= read -r id; do
        [ -n "${FILE_OF[$id]+_}" ] || FILE_OF["$id"]="$f"
    done < <(awk '/^### /{ print $2 }' "$f" | tr -d '\r')
done < <(find "$CATALOG/principles" -name '.context-audit.md' | sort)

first=1
for id in "${IDS[@]}"; do
    [ "$first" = 1 ] || echo
    first=0
    if [ -z "${FILE_OF[$id]+_}" ]; then
        echo "### $id - (no audit context in this catalog)"
        continue
    fi
    awk -v id="$id" '
        { sub(/\r$/, "") }
        /^### / { p = ($2 == id) }
        p { print }' "${FILE_OF[$id]}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
done
