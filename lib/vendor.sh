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
    } | while IFS= read -r f; do

        local id layer summary
        id="$(head -1 "$f" | sed 's/^# \([A-Z0-9][A-Z0-9_-]*\) .*/\1/')"
        layer="$(grep -m1 '^\*\*Layer:\*\*' "$f" | sed 's/\*\*Layer:\*\* \([0-9]\).*/\1/')"
        summary="$(grep -m1 '^\*\*Summary:\*\*' "$f" | sed 's/^\*\*Summary:\*\* //')"

        if [ -n "$id" ] && [ -n "$layer" ] && [ -n "$summary" ]; then
            printf '%s|%s|%s\n' "$id" "$layer" "$summary"
        fi
    done | sort -u > "$tmp"

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

install_vendor() {
    local project_dir="$1"

    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Error: Directory '$project_dir' does not exist.${NC}"; exit 1
    fi

    # --- Collect extra catalog paths ---
    local extra_catalogs=()

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

    echo ""
    echo "Catalog vendored to $catalog_dir"
    echo "Skills resolve principles from .agents/principles-catalog/ (relative to git root)."
}
