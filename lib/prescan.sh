#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# prescan.sh — Run every inspection pattern of the active principles against a target in one
# call. Replaces one bash tool call per pattern.
#
# Usage: prescan.sh [--catalog DIR] [--ids ID,ID,...] [--timeout SECONDS] <target>
#
#   <target>     File or directory; substituted for $TARGET in the patterns
#   --ids        Principles to scan for (default: every ID in <catalog>/active.md)
#   --timeout    Per-command limit in seconds (default 30; ignored if `timeout` is missing)
#
# Patterns come from the catalog's .context-inspect.md files (one `command` | SEVERITY |
# description line per pattern) and run from the git root. They are read-only greps, but they
# are shell commands taken from the catalog: only vendor catalogs you trust.
#
# Output (pipe-delimited; the raw match is last because it may contain `|`):
#   HIT|<ID>|<SEVERITY>|<description>|<raw output line of the command>
#   INSPECTED|<ID>|<number of hits>      the principle has patterns (hits may be 0)
#   SEMANTIC|<ID>                        no patterns: needs reading, not grepping
set -euo pipefail
# shellcheck source=principles-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/principles-common.sh"

CATALOG=""; IDS_ARG=""; TIMEOUT_S=30; TARGET=""
while [ $# -gt 0 ]; do
    case "$1" in
        --catalog) CATALOG="$2"; shift 2 ;;
        --ids)     IDS_ARG="$2"; shift 2 ;;
        --timeout) TIMEOUT_S="$2"; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)        echo "prescan.sh: unknown option $1" >&2; exit 2 ;;
        *)         TARGET="$1"; shift ;;
    esac
done
[ -n "$TARGET" ] || { echo "prescan.sh: a target path is required" >&2; exit 2; }
[ -e "$TARGET" ] || { echo "prescan.sh: no such path: $TARGET" >&2; exit 2; }
TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
ROOT="$(pc_git_root "$(pc_abs_dir "$TARGET")")"
[ -n "$CATALOG" ] || CATALOG="$(pc_default_catalog "$ROOT")"
[ -d "$CATALOG/principles" ] || { echo "prescan.sh: no catalog at $CATALOG (run install.sh vendor)" >&2; exit 2; }

declare -a IDS=()
if [ -n "$IDS_ARG" ]; then
    IFS=',' read -ra IDS <<< "${IDS_ARG^^}"
else
    [ -f "$CATALOG/active.md" ] || { echo "prescan.sh: $CATALOG/active.md not found (run /dot-scout)" >&2; exit 2; }
    while IFS= read -r id; do IDS+=("$id"); done < <(sed -nE 's/^- ([A-Z0-9]+(-[A-Z0-9]+)*):.*/\1/p' "$CATALOG/active.md")
fi
declare -A WANT=()
for id in "${IDS[@]}"; do WANT["$id"]=1; done

RUN=(); command -v timeout >/dev/null 2>&1 && RUN=(timeout "$TIMEOUT_S")
declare -A HITS=() HAS_PATTERN=()

# Hits in build output and other ignored files are noise: they duplicate the source. A hit whose
# path is in a build or dependency directory, or is ignored by git, is dropped.
HAVE_GIT=0
[ -e "$ROOT/.git" ] && command -v git >/dev/null 2>&1 && HAVE_GIT=1
declare -A IGNORED=()
is_ignored() { # path -> 0 if the file is build output or git-ignored
    local path="$1" r=1
    if [ -n "${IGNORED[$path]+_}" ]; then return "${IGNORED[$path]}"; fi
    case "$path" in
        */node_modules/*|*/build/*|*/dist/*|*/.gradle/*|*/target/*|*/__pycache__/*|*/.git/*) r=0 ;;
        *) if [ "$HAVE_GIT" = 1 ] && git -C "$ROOT" check-ignore -q -- "$path" 2>/dev/null; then r=0; fi ;;
    esac
    IGNORED["$path"]=$r
    return "$r"
}

while IFS= read -r f; do
    cur=""
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [[ "$line" == '### '* ]]; then
            cur="${line#\#\#\# }"; cur="${cur%% *}"
            continue
        fi
        [ -n "$cur" ] && [ -n "${WANT[$cur]+_}" ] || continue
        if [[ "$line" =~ ^-\ \`(.*)\`\ \|\ ([A-Z]+)\ \|\ (.*)$ ]]; then
            cmd="${BASH_REMATCH[1]}"; sev="${BASH_REMATCH[2]}"; desc="${BASH_REMATCH[3]}"
            HAS_PATTERN["$cur"]=1
            out="$(cd "$ROOT" && TARGET="$TARGET" "${RUN[@]+"${RUN[@]}"}" bash -c "$cmd" 2>/dev/null || true)"
            n=0
            while IFS= read -r hit; do
                [ -n "$hit" ] || continue
                hit_path="${hit%%:*}"
                if [ -e "$hit_path" ] && is_ignored "$hit_path"; then continue; fi
                printf 'HIT|%s|%s|%s|%s\n' "$cur" "$sev" "$desc" "$hit"
                n=$((n + 1))
            done <<< "$out"
            HITS["$cur"]=$(( ${HITS[$cur]:-0} + n ))
        fi
    done < "$f"
done < <(find "$CATALOG/principles" -name '.context-inspect.md' | sort)

for id in "${IDS[@]}"; do
    if [ -n "${HAS_PATTERN[$id]+_}" ]; then
        echo "INSPECTED|$id|${HITS[$id]:-0}"
    else
        echo "SEMANTIC|$id"
    fi
done
