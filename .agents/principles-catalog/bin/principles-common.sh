# SPDX-License-Identifier: MIT
# principles-common.sh — Shared helpers for resolve.sh, emit.sh, context.sh and prescan.sh.
# Sourced, never executed. These scripts are vendored together into
# <project>/.agents/principles-catalog/bin/ so they run inside an adopter's project.

if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "principles: Bash 4+ is required (found ${BASH_VERSION:-unknown}). On macOS: brew install bash" >&2
    exit 2
fi

PC_BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print the items of a top-level list key of a simple group YAML file.
# Usage: pc_yaml_list <file> <key>
pc_yaml_list() {
    awk -v key="$2" '
        { sub(/\r$/, "") }
        /^[A-Za-z_]+:/ { sect = ($0 ~ "^" key ":") ? 1 : 0; next }
        sect && /^[[:space:]]*-[[:space:]]+/ {
            v = $0; sub(/^[[:space:]]*-[[:space:]]+/, "", v); sub(/[[:space:]]*#.*$/, "", v)
            gsub(/^["'\'']|["'\'']$/, "", v); if (v != "") print v
        }' "$1"
}

# Absolute directory of a path (the path itself if it is a directory).
pc_abs_dir() {
    local p="$1"
    [ -d "$p" ] || p="$(dirname "$p")"
    (cd "$p" 2>/dev/null && pwd) || { echo "principles: no such path: $1" >&2; return 1; }
}

# Git root for a directory (walks up at most 11 levels); falls back to the directory itself.
pc_git_root() {
    local dir="$1" parent
    for _ in 1 2 3 4 5 6 7 8 9 10 11; do
        if [ -e "$dir/.git" ]; then echo "$dir"; return 0; fi
        parent="$(dirname "$dir")"
        [ "$parent" = "$dir" ] && break
        dir="$parent"
    done
    echo "$1"
}

# Catalog directory: the parent of bin/ when run from a vendored catalog, else <root>/.agents/...
# Usage: pc_default_catalog <root>
pc_default_catalog() {
    local parent
    parent="$(dirname "$PC_BIN_DIR")"
    if [ -d "$parent/groups" ] && [ -f "$parent/index.tsv" ]; then
        echo "$parent"
    else
        echo "$1/.agents/principles-catalog"
    fi
}

# Load index.tsv (ID|LAYER|SUMMARY) into the global maps PC_LAYER and PC_SUMMARY.
pc_load_index() {
    declare -gA PC_LAYER=() PC_SUMMARY=()
    local idx="$1/index.tsv" id layer summary
    [ -f "$idx" ] || return 0
    while IFS='|' read -r id layer summary; do
        [ -z "$id" ] && continue
        id="${id^^}"
        PC_LAYER["$id"]="$layer"
        PC_SUMMARY["$id"]="${summary%$'\r'}"   # builtins only: a subshell per line is slow on Windows
    done < "$idx"
}

# Print "ID" lines of a group including its includes (cycle-safe). Problems are printed in-band
# as "#WARN|message" lines so callers running this in a subshell do not lose them.
# Usage: pc_group_ids <catalog> <group> [include-stack]
pc_group_ids() {
    local cat="$1" name="${2,,}" stack="${3:-}"
    local file="$cat/groups/$name.yaml"
    case ",$stack," in *",$name,"*) echo "#WARN|include cycle at group '$name' (cut)"; return 0 ;; esac
    if [ ! -f "$file" ]; then echo "#WARN|unknown group '$name'"; return 0; fi
    local inc
    while IFS= read -r inc; do
        [ -n "$inc" ] && pc_group_ids "$cat" "$inc" "$stack,$name"
    done < <(pc_yaml_list "$file" includes)
    pc_yaml_list "$file" principles
}

# Print the union of explicitly declared globs of a group and everything it includes.
# Usage: pc_group_globs <catalog> <group> [include-stack]
pc_group_globs() {
    local cat="$1" name="${2,,}" stack="${3:-}"
    local file="$cat/groups/$name.yaml"
    case ",$stack," in *",$name,"*) return 0 ;; esac
    [ -f "$file" ] || return 0
    local inc
    while IFS= read -r inc; do
        [ -n "$inc" ] && pc_group_globs "$cat" "$inc" "$stack,$name"
    done < <(pc_yaml_list "$file" includes)
    pc_yaml_list "$file" globs
}

# Today as YYYY-MM-DD (PRINCIPLES_TODAY overrides, for tests).
pc_today() { echo "${PRINCIPLES_TODAY:-$(date +%F)}"; }
