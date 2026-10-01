# vendor.sh — Catalog vendoring helpers for install.sh
# Sourced by install.sh. Defines: generate_compact_index, vendor_namespace_context_files,
# vendor_extra_catalog, install_vendor.
# Requires: $SCRIPT_DIR, color variables, REGISTERED_NAMESPACES, REGISTERED_GROUPS,
# EXTRA_CATALOGS_CLI, expand_path.

generate_compact_index() {
    local catalog_dir="$1"
    shift
    local index_file="$catalog_dir/index.tsv"
    local tmp="$index_file.tmp"

    {
        find "$SCRIPT_DIR/principles" -name "*.md" \
            ! -name ".context-*.md" \
            ! -name "TEMPLATE.md" \
            ! -name "AUDIT-SCOPE.md" \
            ! -name "INDEX.md" \
            ! -name "README.md" \
            ! -name "catalog.yaml" | sort
        for extra in "$@"; do
            [ -d "$extra/principles" ] || continue
            # Index only namespaces that vendor_extra_catalog registered from this extra;
            # namespaces skipped for a collision (or never vendored) stay out of index.tsv.
            local label="${extra/#$HOME/\~}"
            find "$extra/principles" -name "*.md" \
                ! -name ".context-*.md" \
                ! -name "TEMPLATE.md" \
                ! -name "AUDIT-SCOPE.md" \
                ! -name "INDEX.md" \
                ! -name "README.md" \
                ! -name "catalog.yaml" | sort | while IFS= read -r ef; do
                local ns
                ns="$(dirname "${ef#$extra/principles/}")"
                if [ "${REGISTERED_NAMESPACES[$ns]:-}" = "$label" ] \
                    || [ "${REGISTERED_NAMESPACES[$(dirname "$ns")]:-}" = "$label" ]; then
                    echo "$ef"
                fi
            done
        done
    } | tr '\n' '\0' | xargs -0 awk '
        # One awk process for all principle files (a process per file is very slow on Windows).
        # Header contract: line 1 "# ID - Title" (uppercase ID), "**Layer:** N", "**Summary:** ...".
        function flush() { if (id != "" && layer != "" && summary != "") printf "%s|%s|%s\n", id, layer, summary }
        FNR == 1 {
            if (NR > 1) flush()
            id = ""; layer = ""; summary = ""
            first = $0; sub(/\r$/, "", first)
            if (first ~ /^# [A-Z0-9][A-Z0-9_-]* /) { split(first, parts, " "); id = parts[2] }
        }
        { line = $0; sub(/\r$/, "", line) }
        layer == "" && line ~ /^\*\*Layer:\*\* [0-9]/ { layer = substr(line, 12, 1) }
        summary == "" && line ~ /^\*\*Summary:\*\* / { summary = substr(line, 14) }
        END { flush() }
    ' | sort -u > "$tmp"

    mv "$tmp" "$index_file"
    echo -e "  ${GREEN}✓${NC} index.tsv ($(wc -l < "$index_file") principles)"
}

# Copy context files from one namespace directory into the catalog.
# Returns 0 on success, 1 if namespace is invalid (missing catalog.yaml).
vendor_namespace_context_files() {
    local ns_dir="$1"
    local principles_dst="$2"
    local rel="$3"

    if [ ! -f "$ns_dir/catalog.yaml" ]; then
        echo -e "  ${YELLOW}⚠${NC} Extra catalog: namespace '$rel' has no catalog.yaml (skipping)"
        return 1
    fi

    local dst="$principles_dst/$rel"
    mkdir -p "$dst"
    for context_file in ".context-audit.md" ".context-inspect.md" ".context-scout.md" "catalog.yaml"; do
        [ -f "$ns_dir/$context_file" ] && cp "$ns_dir/$context_file" "$dst/"
    done
    return 0
}

# Merge one extra catalog directory into the vendored catalog.
vendor_extra_catalog() {
    local extra_dir="$1"
    local catalog_dir="$2"
    local label="${extra_dir/#$HOME/\~}"

    if [ ! -d "$extra_dir" ]; then
        echo -e "  ${YELLOW}⚠${NC} Extra catalog not found: $label (skipping)"
        return
    fi

    echo -e "  ${BOLD}Extra:${NC} $label"
    local principles_dst="$catalog_dir/principles"
    local ns_count=0
    local group_count=0

    # Merge principles namespaces (1-level and 2-level deep, matching built-in behavior)
    if [ -d "$extra_dir/principles" ]; then
        local principles_src="$extra_dir/principles"
        for ns_dir in "$principles_src"/*/ "$principles_src"/*/*/; do
            [ -d "$ns_dir" ] || continue
            local rel
            rel="${ns_dir#$principles_src/}"
            rel="${rel%/}"

            if [ "${REGISTERED_NAMESPACES[$rel]+_}" ]; then
                echo -e "    ${YELLOW}⚠${NC} Namespace '$rel' already registered from '${REGISTERED_NAMESPACES[$rel]}' (skipping)"
                continue
            fi

            if vendor_namespace_context_files "$ns_dir" "$principles_dst" "$rel"; then
                REGISTERED_NAMESPACES["$rel"]="$label"
                echo -e "    ${GREEN}✓${NC} principles/$rel/"
                ns_count=$((ns_count + 1))
            fi
        done
    fi

    # Merge groups (individual files, with conflict detection)
    if [ -d "$extra_dir/groups" ]; then
        local groups_dst="$catalog_dir/groups"
        mkdir -p "$groups_dst"
        for group_file in "$extra_dir/groups"/*.yaml; do
            [ -f "$group_file" ] || continue
            local group_name
            group_name="${group_file##*/}"
            group_name="${group_name%.yaml}"

            if [ "${REGISTERED_GROUPS[$group_name]+_}" ]; then
                echo -e "    ${YELLOW}⚠${NC} Group '$group_name' already registered from '${REGISTERED_GROUPS[$group_name]}' (skipping)"
                continue
            fi

            cp "$group_file" "$groups_dst/"
            REGISTERED_GROUPS["$group_name"]="$label"
            echo -e "    ${GREEN}✓${NC} groups/$group_name.yaml"
            group_count=$((group_count + 1))
        done
    fi

    if [ "$ns_count" -eq 0 ] && [ "$group_count" -eq 0 ]; then
        if [ ! -d "$extra_dir/principles" ] && [ ! -d "$extra_dir/groups" ]; then
            echo -e "    ${YELLOW}⚠${NC} No principles/ or groups/ directory found in $label"
        fi
    fi
}

# ── org baseline: `:extends <source>[@ref]` in the project's root .principles ──────────────────
# A source is a local directory or a git repository (https, ssh, file, scp-like, or ending in
# .git). Git sources must be pinned with @<tag-or-commit>; the resolved commit is recorded in
# principles.lock. The source has the layout of an extra catalog (principles/, groups/) plus an
# optional org.principles file, which becomes the outermost layer of every hierarchy.
EXTENDS_DIRS=()
EXTENDS_LOCK=()
EXTENDS_TMP=""

is_git_source() {
    case "$1" in
        http://*|https://*|ssh://*|git://*|file://*|*.git) return 0 ;;
        *@*:*) [[ "$1" != /* && ! "$1" =~ ^[A-Za-z]:[/\] ]] && return 0 ;;
    esac
    return 1
}

# Split "<source>@<ref>" on the last @ when what follows looks like a ref (no / or :).
split_extends_ref() {
    local spec="$1"
    EXT_SRC="$spec"; EXT_REF=""
    if [[ "$spec" == *@* ]]; then
        local tail="${spec##*@}"
        if [[ -n "$tail" && "$tail" != */* && "$tail" != *:* ]]; then
            EXT_SRC="${spec%@*}"; EXT_REF="$tail"
        fi
    fi
}

resolve_extends() {
    local project_dir="$1"
    EXTENDS_DIRS=(); EXTENDS_LOCK=(); EXTENDS_TMP=""
    local file="$project_dir/.principles"
    [ -f "$file" ] || return 0
    local line spec n=0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^:extends[[:space:]]+(.+)$ ]] || continue
        spec="${BASH_REMATCH[1]}"
        spec="${spec%"${spec##*[![:space:]]}"}"
        split_extends_ref "$spec"
        n=$((n + 1))
        if is_git_source "$EXT_SRC"; then
            if [ -z "$EXT_REF" ]; then
                echo -e "${RED}Error: :extends $EXT_SRC must be pinned, e.g. $EXT_SRC@v1.0.0 (a tag or commit).${NC}" >&2
                exit 1
            fi
            command -v git >/dev/null 2>&1 || { echo -e "${RED}Error: git is required for :extends $EXT_SRC${NC}" >&2; exit 1; }
            [ -n "$EXTENDS_TMP" ] || EXTENDS_TMP="$(mktemp -d)"
            local dest="$EXTENDS_TMP/$n"
            echo -e "  ${BOLD}Extends:${NC} $EXT_SRC @ $EXT_REF"
            if ! git clone --quiet --depth 1 --branch "$EXT_REF" "$EXT_SRC" "$dest" 2>/dev/null; then
                # not a branch or tag name: a commit needs the full history
                rm -rf "$dest"
                if ! git clone --quiet "$EXT_SRC" "$dest" 2>/dev/null \
                   || ! git -C "$dest" checkout --quiet "$EXT_REF" 2>/dev/null; then
                    echo -e "${RED}Error: could not fetch $EXT_SRC at $EXT_REF${NC}" >&2
                    exit 1
                fi
            fi
            local commit; commit="$(git -C "$dest" rev-parse HEAD)"
            EXTENDS_DIRS+=("$dest")
            EXTENDS_LOCK+=("extends $EXT_SRC ref=$EXT_REF commit=$commit")
        else
            local dir; dir="$(expand_path "$EXT_SRC")"
            [[ "$dir" = /* || "$dir" =~ ^[A-Za-z]:[/\] ]] || dir="$project_dir/$dir"
            if [ ! -d "$dir" ]; then
                echo -e "${RED}Error: :extends directory not found: $EXT_SRC${NC}" >&2
                exit 1
            fi
            echo -e "  ${BOLD}Extends:${NC} $EXT_SRC (local)"
            EXTENDS_DIRS+=("$dir")
            EXTENDS_LOCK+=("extends $EXT_SRC local")
        fi
    done < "$file"
}

# Copy the org baseline into the catalog, write principles.lock, remove temporary clones.
finish_extends() {
    local catalog_dir="$1"
    rm -f "$catalog_dir/org.principles" "$catalog_dir/principles.lock"
    if [ "${#EXTENDS_DIRS[@]}" -gt 0 ]; then
        local i lock_src
        {
            echo "# .principles principles.lock - the org baselines this catalog was built from."
            echo "# Auto-generated by install.sh vendor. Commit it; review changes like any dependency bump."
            for i in "${!EXTENDS_DIRS[@]}"; do
                lock_src="${EXTENDS_DIRS[$i]}/org.principles"
                if [ -f "$lock_src" ]; then
                    echo "${EXTENDS_LOCK[$i]} org-principles=$(cksum < "$lock_src" | cut -d' ' -f1)"
                else
                    echo "${EXTENDS_LOCK[$i]}"
                fi
            done
        } > "$catalog_dir/principles.lock"
        for i in "${!EXTENDS_DIRS[@]}"; do
            lock_src="${EXTENDS_DIRS[$i]}/org.principles"
            [ -f "$lock_src" ] || continue
            {
                echo "# from ${EXTENDS_LOCK[$i]#extends }"
                cat "$lock_src"
                echo
            } >> "$catalog_dir/org.principles"
        done
        echo -e "  ${GREEN}✓${NC} principles.lock$([ -f "$catalog_dir/org.principles" ] && echo ", org.principles")"
    fi
    [ -z "$EXTENDS_TMP" ] || rm -rf "$EXTENDS_TMP"
    EXTENDS_TMP=""
}

install_vendor() {
    local project_dir="$1"

    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Error: Directory '$project_dir' does not exist.${NC}"; exit 1
    fi

    # --- Collect extra catalog paths ---
    # The org baseline (:extends) registers first, so its namespaces win over user-level extras.
    resolve_extends "$project_dir"
    local extra_catalogs=("${EXTENDS_DIRS[@]+"${EXTENDS_DIRS[@]}"}")

    # 1. User config: ~/.principles-extra
    local user_cfg="$HOME/.principles-extra"
    if [ -f "$user_cfg" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            local ep
            ep="$(expand_path "$line")"
            [[ -z "$ep" || "$ep" =~ ^# ]] && continue
            extra_catalogs+=("$ep")
        done < "$user_cfg"
    fi

    # 2. Project config: <project_dir>/.principles-extra
    local proj_cfg="$project_dir/.principles-extra"
    if [ -f "$proj_cfg" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            local ep
            ep="$(expand_path "$line")"
            [[ -z "$ep" || "$ep" =~ ^# ]] && continue
            # Resolve relative paths against the project directory
            if [[ ! "$ep" = /* ]]; then
                ep="$project_dir/$ep"
            fi
            extra_catalogs+=("$ep")
        done < "$proj_cfg"
    fi

    # 3. CLI flags (already expanded by arg parsing)
    if [ "${#EXTRA_CATALOGS_CLI[@]}" -gt 0 ]; then
        for p in "${EXTRA_CATALOGS_CLI[@]}"; do
            extra_catalogs+=("$p")
        done
    fi

    echo -e "${BOLD}Vendoring catalog to: $project_dir/.agents/principles-catalog/${NC}"

    local catalog_dir="$project_dir/.agents/principles-catalog"
    mkdir -p "$catalog_dir"

    # Reset registries — built-in namespaces are registered first to prevent shadowing
    REGISTERED_NAMESPACES=()
    REGISTERED_GROUPS=()

    for dir in "$SCRIPT_DIR/principles"/*/ "$SCRIPT_DIR/principles"/*/*/; do
        [ -d "$dir" ] || continue
        local rel="${dir#$SCRIPT_DIR/principles/}"; rel="${rel%/}"
        REGISTERED_NAMESPACES["$rel"]="built-in"
    done
    for f in "$SCRIPT_DIR/groups"/*.yaml; do
        [ -f "$f" ] || continue
        local g="${f##*/}"; g="${g%.yaml}"
        REGISTERED_GROUPS["$g"]="built-in"
    done

    find "$SCRIPT_DIR/groups" -name "*.yaml" -type f | while IFS= read -r f; do
        mkdir -p "$catalog_dir/groups"
        cp "$f" "$catalog_dir/groups/"
    done
    find "$SCRIPT_DIR/layers" -not -name "INDEX.md" -not -name "README.md" | while IFS= read -r f; do
        [ -f "$f" ] || continue
        local rel="${f#$SCRIPT_DIR/layers/}"
        mkdir -p "$(dirname "$catalog_dir/layers/$rel")"
        cp "$f" "$catalog_dir/layers/$rel"
    done
    echo -e "  ${GREEN}✓${NC} groups/"
    echo -e "  ${GREEN}✓${NC} layers/"

    # Scripts the commands run (resolve, emit, context, prescan) and the tooling version.
    # They live next to the catalog so they work inside the adopter's project.
    mkdir -p "$catalog_dir/bin"
    for script in principles-common.sh resolve.sh emit.sh context.sh prescan.sh; do
        [ -f "$SCRIPT_DIR/lib/$script" ] && cp "$SCRIPT_DIR/lib/$script" "$catalog_dir/bin/$script"
    done
    [ -f "$SCRIPT_DIR/VERSION" ] && cp "$SCRIPT_DIR/VERSION" "$catalog_dir/VERSION"
    echo -e "  ${GREEN}✓${NC} bin/"

    local principles_src="$SCRIPT_DIR/principles"
    local principles_dst="$catalog_dir/principles"
    mkdir -p "$principles_dst"

    for dir in "$principles_src"/*/ "$principles_src"/*/*/; do
        [ -d "$dir" ] || continue
        local rel
        rel="${dir#$principles_src/}"
        rel="${rel%/}"
        local dst="$principles_dst/$rel"
        local copied=false
        for context_file in ".context-audit.md" ".context-inspect.md" ".context-scout.md" "catalog.yaml"; do
            if [ -f "$dir/$context_file" ]; then
                mkdir -p "$dst"
                cp "$dir/$context_file" "$dst/"
                copied=true
            fi
        done
        if [ "$copied" = true ]; then
            echo -e "  ${GREEN}✓${NC} principles/$rel/"
        fi
    done

    for top_file in "TEMPLATE.md" "AUDIT-SCOPE.md" "catalog.yaml"; do
        if [ -f "$principles_src/$top_file" ]; then
            cp "$principles_src/$top_file" "$principles_dst/"
            echo -e "  ${GREEN}✓${NC} principles/$top_file"
        fi
    done

    # Merge extra catalogs
    if [ "${#extra_catalogs[@]}" -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Merging extra catalogs...${NC}"
        for extra_dir in "${extra_catalogs[@]}"; do
            vendor_extra_catalog "$extra_dir" "$catalog_dir"
        done
    fi

    generate_compact_index "$catalog_dir" "${extra_catalogs[@]+"${extra_catalogs[@]}"}"
    finish_extends "$catalog_dir"

    echo ""
    echo "Catalog vendored to $catalog_dir"
    echo "Skills resolve principles from .agents/principles-catalog/ (relative to git root)."
}

# Regenerate the review files after a vendor run, but only for projects that were scouted before
# (vendor wipes the catalog directory, including active.md). Uses the tools recorded in install.cfg.
refresh_generated() {
    local project_dir="$1"
    local catalog_dir="$project_dir/.agents/principles-catalog"
    [ -f "$catalog_dir/bin/emit.sh" ] || return 0
    local scouted=false
    [ -f "$project_dir/.agents/instructions/review.md" ] && scouted=true
    [ "${INSTALLED_TARGETS[scout]:-}" = "1" ] && scouted=true
    [ "$scouted" = true ] || return 0
    [ -f "$project_dir/.principles" ] || return 0
    if bash "$catalog_dir/bin/emit.sh" --root "$project_dir" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} refreshed generated review files (active.md, review.md, ...)"
    else
        echo -e "  ${YELLOW}⚠${NC} could not refresh generated review files; run /dot-scout"
    fi
}
