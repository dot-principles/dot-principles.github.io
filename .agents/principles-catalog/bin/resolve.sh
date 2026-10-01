#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# resolve.sh — Resolve the active principle set for a path from its .principles hierarchy.
#
# Usage: resolve.sh [--catalog DIR] [--seed TYPE] [--spec GROUPS-OR-IDS] [--format full|ids|explain] <target>
#
#   <target>      File or directory to resolve for (the hierarchy walk starts at its directory)
#   --catalog     Vendored catalog (default: <git-root>/.agents/principles-catalog)
#   --seed TYPE   Also seed the universal principles and the Layer 1 principles of artifact
#                 type TYPE (code, docs, config, infra, schema, pipeline)
#   --spec LIST   Explicit mode: use these groups and IDs (comma or space separated, optional @)
#                 instead of the .principles hierarchy; unknown items exit with status 3
#   --format      full (default): one record per line, see below
#                 ids:     active IDs only, one per line
#                 explain: human-readable, shows which file added or removed each ID
#
# Hierarchy, outermost first: the org baseline (<catalog>/org.principles, if present), then every
# .principles file from the git root down to the target's directory. The deepest file that
# mentions a principle decides: `!ID` / `!@group` in an outer file removes it, and an `@group` or
# ID in a deeper file adds it back (REINSTATED). Within one file, exclusions win over additions,
# whatever the line order. Seeds come first, so any file can exclude them. Governance:
#   :lock ID|@group        (org baseline only) the ID is always active; `!ID` from any file is
#                          ignored and reported as LOCK-OVERRIDE
#   :waive ID until YYYY-MM-DD "reason"
#                          a dated, reasoned exception; honoured even for locked IDs, reported
#                          as WAIVED, and ignored (EXPIRED) after the date
#   :max_principles N      cap the set; Layer 2, then Layer 3, are dropped first
#   :extends ...           handled when the catalog is vendored; ignored here
#
# Records (full format, pipe-delimited; `|` inside free text is replaced by `/`):
#   FILE|<label>                          hierarchy file that was read, outermost first
#   GROUP|<name>|<file>                   an @group that was activated, in order
#   ACTIVE|<ID>|<added-by>|<flags>        added-by: the file that made it active (the deeper one
#                                         after a REINSTATED); flags: locked
#   EXCLUDED|<ID>|<excluded-by>           removed and not added back
#   REINSTATED|<ID>|<excluded-by>|<added-back-by>
#   LOCK-OVERRIDE|<ID>|<file>
#   WAIVED|<ID>|<until>|<reason>|<file>
#   EXPIRED|<ID>|<until>|<reason>|<file>
#   TRIMMED|<ID>|<layer>                  dropped by :max_principles
#   WARN|<message>
#
# Environment: PRINCIPLES_TODAY=YYYY-MM-DD overrides today's date (for tests).
set -euo pipefail
# shellcheck source=principles-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/principles-common.sh"

CATALOG=""
SEED_TYPE=""
SPEC=""
FORMAT="full"
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --catalog) CATALOG="$2"; shift 2 ;;
        --seed)    SEED_TYPE="$2"; shift 2 ;;
        --spec)    SPEC="$2"; shift 2 ;;
        --format)  FORMAT="$2"; shift 2 ;;
        -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        -*)        echo "resolve.sh: unknown option $1" >&2; exit 2 ;;
        *)         TARGET="$1"; shift ;;
    esac
done
[ -n "$TARGET" ] || { echo "resolve.sh: a target path is required" >&2; exit 2; }
case "$FORMAT" in full|ids|explain) ;; *) echo "resolve.sh: bad --format $FORMAT" >&2; exit 2 ;; esac

TODAY="$(pc_today)"
START_DIR="$(pc_abs_dir "$TARGET")" || exit 2
ROOT="$(pc_git_root "$START_DIR")"

[ -n "$CATALOG" ] || CATALOG="$(pc_default_catalog "$ROOT")"
[ -d "$CATALOG/groups" ] || { echo "resolve.sh: no catalog at $CATALOG (run install.sh vendor)" >&2; exit 2; }

# ── state ────────────────────────────────────────────────────────────────────────────────────
declare -a ORDER=()          # every ID that was ever active, in order of first appearance
declare -A SEEN=()           # ID -> 1 once it is in ORDER
declare -A ACTIVE=()         # ID -> 1 while it is currently active
declare -A ADDED_BY=()       # ID -> label of the file that made it (most recently) active
declare -A EXCL_BY=()        # ID -> label of the file that removed it; cleared when it is added back
declare -A LOCKED=()         # ID -> 1
declare -A WAIVE=()          # ID -> "until|reason|label"
declare -a NOTES=()          # output records other than ACTIVE
declare -a GROUP_RESULT=()   # filled by expand_group
declare -a FILE_ADDS=()      # additions and exclusions of the file being read; applied at its end
declare -a FILE_EXCLS=()
CURRENT_LABEL=""
MAX_PRINCIPLES=""

note() { NOTES+=("$1"); }
clean() { printf '%s' "$1" | tr -d '\r' | sed 's/|/\//g'; }

# Make a principle active. If an outer file removed it, this is a REINSTATED.
activate() {
    local id="${1^^}" label="$2"
    if [ -z "${SEEN[$id]+_}" ]; then
        SEEN["$id"]=1
        ORDER+=("$id")
    fi
    if [ -z "${ACTIVE[$id]+_}" ]; then
        ACTIVE["$id"]=1
        ADDED_BY["$id"]="$label"
        if [ -n "${EXCL_BY[$id]+_}" ]; then
            note "REINSTATED|$id|${EXCL_BY[$id]}|$label"
            unset 'EXCL_BY[$id]'
        fi
    fi
}

# Remove an active principle. A locked principle cannot be removed; a principle that is not active
# stays as it is (an exclusion does not bind later additions).
deactivate() {
    local id="${1^^}" label="$2"
    if [ -n "${LOCKED[$id]+_}" ]; then
        note "LOCK-OVERRIDE|$id|$label"
        return 0
    fi
    if [ -n "${ACTIVE[$id]+_}" ]; then
        unset 'ACTIVE[$id]'
        EXCL_BY["$id"]="$label"
    fi
    return 0
}

# Expand a group into GROUP_RESULT (IDs only) and record any warnings.
expand_group() {
    GROUP_RESULT=()
    local line
    while IFS= read -r line; do
        case "$line" in
            '#WARN|'*) note "WARN|${line#\#WARN|} (in $CURRENT_LABEL)" ;;
            '')        ;;
            *)         GROUP_RESULT+=("$line") ;;
        esac
    done < <(pc_group_ids "$CATALOG" "$1")
}

pc_load_index "$CATALOG"
yaml_list() { pc_yaml_list "$@"; }

# ── seeding (universal + stack Layer 1) ──────────────────────────────────────────────────────
seed() {
    local type="$1" id
    local at="$CATALOG/layers/artifact-types.yaml"
    if [ -f "$at" ]; then
        while IFS= read -r id; do activate "$id" "seed:universal"; done < <(yaml_list "$at" universal)
    else
        note "WARN|no layers/artifact-types.yaml in the catalog; universal seed skipped"
    fi
    local l1="$CATALOG/layers/$type/layer-1-universal.md"
    if [ -f "$l1" ]; then
        while IFS= read -r id; do activate "$id" "seed:$type"; done \
            < <(sed -nE 's/^\| ([A-Z0-9]+(-[A-Z0-9]+)+) \|.*/\1/p' "$l1" | tr -d '\r')
    else
        note "WARN|no Layer 1 file for artifact type '$type'"
    fi
}

# ── one .principles file ─────────────────────────────────────────────────────────────────────
is_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }

process_file() {
    local file="$1" label="$2" is_org="$3"
    CURRENT_LABEL="$label"
    FILE_ADDS=()
    FILE_EXCLS=()
    note "FILE|$label"
    local raw line id
    while IFS= read -r raw || [ -n "$raw" ]; do
        line="${raw//$'\r'/}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        case "$line" in
            '#'*) continue ;;
            ':max_principles'*)
                local n="${line#:max_principles}"; n="${n//[[:space:]]/}"
                if [[ "$n" =~ ^[0-9]+$ ]]; then MAX_PRINCIPLES="$n"
                else note "WARN|$label: bad :max_principles value '$n'"; fi ;;
            ':lock'*)
                if [ "$is_org" != 1 ]; then
                    note "WARN|$label: :lock is only honoured in the org baseline (ignored)"; continue
                fi
                local arg="${line#:lock}"; arg="${arg//[[:space:]]/}"
                if [[ "$arg" == @* ]]; then
                    note "GROUP|${arg#@}|$label"
                    expand_group "${arg#@}"
                    for id in ${GROUP_RESULT[@]+"${GROUP_RESULT[@]}"}; do
                        activate "$id" "$label"; LOCKED["${id^^}"]=1
                    done
                elif [ -n "$arg" ]; then
                    activate "$arg" "$label"; LOCKED["${arg^^}"]=1
                fi ;;
            ':waive'*)
                local rest="${line#:waive}" wid until reason
                rest="$(printf '%s' "$rest" | sed 's/^[[:space:]]*//')"
                wid="${rest%%[[:space:]]*}"
                rest="${rest#"$wid"}"; rest="$(printf '%s' "$rest" | sed 's/^[[:space:]]*//')"
                local w_date="" w_text=""
                if [[ "$rest" =~ ^until[[:space:]]+([0-9-]+)[[:space:]]*(.*)$ ]]; then
                    w_date="${BASH_REMATCH[1]}"; w_text="${BASH_REMATCH[2]}"
                fi
                if is_date "$w_date"; then
                    until="$w_date"; reason="$(clean "$w_text" | sed 's/^"//; s/"$//')"
                    if [ -z "$reason" ]; then
                        note "WARN|$label: :waive ${wid^^} needs a reason in quotes (ignored)"
                    else
                        WAIVE["${wid^^}"]="$until|$reason|$label"
                    fi
                else
                    note "WARN|$label: bad :waive line, expected ':waive ID until YYYY-MM-DD \"reason\"' (ignored)"
                fi ;;
            ':extends'*) continue ;;
            :*) note "WARN|$label: unknown directive '${line%% *}'" ;;
            '!@'*)
                expand_group "${line#!@}"
                for id in ${GROUP_RESULT[@]+"${GROUP_RESULT[@]}"}; do
                    FILE_EXCLS+=("$id")
                done ;;
            '!'*) FILE_EXCLS+=("${line#!}") ;;
            '@'*)
                note "GROUP|${line#@}|$label"
                expand_group "${line#@}"
                for id in ${GROUP_RESULT[@]+"${GROUP_RESULT[@]}"}; do
                    FILE_ADDS+=("$id")
                done ;;
            *) FILE_ADDS+=("${line%%[[:space:]]*}") ;;
        esac
    done < "$file"

    # Apply the file: additions first, then exclusions, so an exclusion wins within its own file
    # whatever the line order. A deeper file's additions then override an outer file's exclusions.
    for id in ${FILE_ADDS[@]+"${FILE_ADDS[@]}"}; do activate "$id" "$label"; done
    for id in ${FILE_EXCLS[@]+"${FILE_EXCLS[@]}"}; do deactivate "$id" "$label"; done
}

# ── run ──────────────────────────────────────────────────────────────────────────────────────
if [ -n "$SPEC" ]; then
    # Explicit mode: the given groups and IDs replace the .principles hierarchy (no org baseline).
    CURRENT_LABEL="explicit"
    note "FILE|explicit: $SPEC"
    for item in ${SPEC//,/ }; do
        item="${item#@}"
        [ -n "$item" ] || continue
        if [ -f "$CATALOG/groups/${item,,}.yaml" ]; then
            note "GROUP|${item,,}|explicit"
            expand_group "$item"
            for id in ${GROUP_RESULT[@]+"${GROUP_RESULT[@]}"}; do activate "$id" "explicit"; done
        elif [ -n "${PC_LAYER[${item^^}]+_}" ]; then
            activate "$item" "explicit"
        else
            echo "resolve.sh: Unknown principle or group: $item. Check available groups in $CATALOG/groups/." >&2
            exit 3
        fi
    done
else
    [ -n "$SEED_TYPE" ] && seed "$SEED_TYPE"

    if [ -f "$CATALOG/org.principles" ]; then
        process_file "$CATALOG/org.principles" "org baseline" 1
    fi

    # .principles files from the git root down to the start directory
    declare -a CHAIN=()
    dir="$START_DIR"
    for _ in 1 2 3 4 5 6 7 8 9 10 11; do
        [ -f "$dir/.principles" ] && CHAIN=("$dir" ${CHAIN[@]+"${CHAIN[@]}"})
        [ "$dir" = "$ROOT" ] && break
        parent="$(dirname "$dir")"
        [ "$parent" = "$dir" ] && break
        dir="$parent"
    done
    for dir in ${CHAIN[@]+"${CHAIN[@]}"}; do
        rel="${dir#$ROOT}"; rel="${rel#/}"
        label="${rel:+$rel/}.principles"
        process_file "$dir/.principles" "$label" 0
    done
fi

# ── finalize: waivers, cap ───────────────────────────────────────────────────────────────────
declare -a FINAL=()
for id in ${ORDER[@]+"${ORDER[@]}"}; do
    if [ -z "${ACTIVE[$id]+_}" ]; then
        [ -n "${EXCL_BY[$id]+_}" ] && note "EXCLUDED|$id|${EXCL_BY[$id]}"
        continue
    fi
    if [ -n "${WAIVE[$id]+_}" ]; then
        IFS='|' read -r w_until w_reason w_file <<< "${WAIVE[$id]}"
        if [[ ! "$w_until" < "$TODAY" ]]; then
            note "WAIVED|$id|$w_until|$w_reason|$w_file"
            continue
        fi
        note "EXPIRED|$id|$w_until|$w_reason|$w_file"
    fi
    FINAL+=("$id")
done
for id in "${!WAIVE[@]}"; do
    [ -z "${SEEN[$id]+_}" ] && note "WARN|waiver for ${id}: principle is not active (nothing to waive)"
done

if [ -n "$MAX_PRINCIPLES" ] && [ "${#FINAL[@]}" -gt "$MAX_PRINCIPLES" ]; then
    for drop_layer in 2 3; do
        [ "${#FINAL[@]}" -le "$MAX_PRINCIPLES" ] && break
        for (( i=${#FINAL[@]}-1; i>=0; i-- )); do
            id="${FINAL[$i]}"
            layer="${PC_LAYER[$id]:-2}"
            if [ "${#FINAL[@]}" -gt "$MAX_PRINCIPLES" ] \
               && [ -z "${LOCKED[$id]+_}" ] && [ "$layer" = "$drop_layer" ]; then
                note "TRIMMED|$id|$layer"
                unset 'FINAL[i]'
            fi
        done
        FINAL=(${FINAL[@]+"${FINAL[@]}"})
    done
fi

# ── output ───────────────────────────────────────────────────────────────────────────────────
case "$FORMAT" in
    ids)
        printf '%s\n' ${FINAL[@]+"${FINAL[@]}"}
        ;;
    full)
        for n in ${NOTES[@]+"${NOTES[@]}"}; do
            case "$n" in FILE\|*|GROUP\|*) printf '%s\n' "$n" ;; esac
        done
        for id in ${FINAL[@]+"${FINAL[@]}"}; do
            flags=""
            [ -n "${LOCKED[$id]+_}" ] && flags="locked"
            printf 'ACTIVE|%s|%s|%s\n' "$id" "${ADDED_BY[$id]}" "$flags"
        done
        for n in ${NOTES[@]+"${NOTES[@]}"}; do
            case "$n" in FILE\|*|GROUP\|*) ;; *) printf '%s\n' "$n" ;; esac
        done
        ;;
    explain)
        echo "Hierarchy (outermost first):"
        for n in ${NOTES[@]+"${NOTES[@]}"}; do
            case "$n" in FILE\|*) echo "  ${n#FILE|}" ;; esac
        done
        echo
        echo "Active (${#FINAL[@]}):"
        for id in ${FINAL[@]+"${FINAL[@]}"}; do
            extra=""
            [ -n "${LOCKED[$id]+_}" ] && extra="  [locked]"
            printf '  %-48s from %s%s\n' "$id" "${ADDED_BY[$id]}" "$extra"
        done
        echo
        for n in ${NOTES[@]+"${NOTES[@]}"}; do
            IFS='|' read -r kind a b c d <<< "$n"
            case "$kind" in
                EXCLUDED)      printf 'Excluded:      %s (by %s)\n' "$a" "$b" ;;
                REINSTATED)    printf 'Reinstated:    %s was excluded in %s and added back by %s\n' "$a" "$b" "$c" ;;
                LOCK-OVERRIDE) printf 'Lock held:     %s stays active; !%s in %s was ignored\n' "$a" "$a" "$b" ;;
                WAIVED)        printf 'Waived:        %s until %s - %s (%s)\n' "$a" "$b" "$c" "$d" ;;
                EXPIRED)       printf 'Waiver expired: %s on %s - %s (%s); principle is active again\n' "$a" "$b" "$c" "$d" ;;
                TRIMMED)       printf 'Trimmed:       %s (Layer %s, over :max_principles)\n' "$a" "$b" ;;
                WARN)          printf 'Warning:       %s\n' "$a" ;;
            esac
        done
        ;;
esac
