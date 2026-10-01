# template.sh — Template-driven installer helpers for install.sh
# Sourced by install.sh. Defines: print_header, list_command_files,
# extract_frontmatter_body, extract_command_body, install_from_template.
# Requires: $SCRIPT_DIR, $VERSION, $COMMAND_SOURCE_DIR, $TEMPLATE_DIR, color variables.

print_header() {
    echo ""
    echo -e "${BOLD}.principles installer${NC}"
    echo "─────────────────────────"
}

# List installable command source files, excluding navigation docs and dot-files.
list_command_files() {
    find "$COMMAND_SOURCE_DIR" -name "*.md" \
        -not -name "INDEX.md" \
        -not -name "README.md" \
        -not -name ".*" \
        -type f | sort
}

# Extract the YAML frontmatter body (lines between the --- delimiters, exclusive).
extract_frontmatter_body() {
    local source_file="$1"
    awk '
        BEGIN { in_fm = 0; saw_fm = 0 }
        NR == 1 && $0 == "---" { in_fm = 1; saw_fm = 1; next }
        in_fm && $0 == "---" { in_fm = 0; next }
        in_fm { print }
    ' "$source_file"
}

# Extract everything after the closing --- of the leading frontmatter.
extract_command_body() {
    local source_file="$1"
    awk '
        BEGIN { in_fm = 0; saw_fm = 0; done_fm = 0 }
        NR == 1 && $0 == "---" { in_fm = 1; saw_fm = 1; next }
        in_fm && $0 == "---" { in_fm = 0; done_fm = 1; next }
        done_fm { print }
    ' "$source_file"
}

# Install commands for one tool using its template directory.
# Usage: install_from_template <template_dir> <project_dir>
install_from_template() {
    local template_dir="$1"
    local project_dir="$2"

    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Error: Directory '$project_dir' does not exist.${NC}"
        exit 1
    fi

    # Source the manifest (sets TOOL_ID, TOOL_LABEL, OUTPUT_DIR, OUTPUT_FILE, PATCHES)
    local TOOL_ID="" TOOL_LABEL="" OUTPUT_DIR="" OUTPUT_FILE="" PATCHES="" INSTALL_SUBCOMMAND="" SUPPORT_FILES=""
    # shellcheck disable=SC1090
    source "$template_dir/manifest.cfg"
    # Strip trailing CR in case manifest has Windows line endings (CRLF)
    TOOL_ID="${TOOL_ID%$'\r'}"

    local wrapper_file="$template_dir/wrapper.md"
    if [ ! -f "$wrapper_file" ]; then
        echo -e "${RED}Error: Missing wrapper.md in $template_dir${NC}"
        exit 1
    fi

    echo -e "${BOLD}Installing $TOOL_LABEL commands (local: $project_dir)...${NC}"

    local count=0
    local file

    while IFS= read -r file; do
        [ -f "$file" ] || continue
        local command_name command_slug
        command_name="${file#$COMMAND_SOURCE_DIR/}"
        command_name="${command_name%.md}"
        command_slug="${command_name//\//-}"

        # Temp files for intermediate content
        local tmp_fm tmp_body tmp_output
        tmp_fm="$(mktemp)"
        tmp_body="$(mktemp)"
        tmp_output="$(mktemp)"

        # 1. Extract frontmatter and command body from source into temp files
        extract_frontmatter_body "$file" > "$tmp_fm"
        extract_command_body "$file" > "$tmp_body"

        # 2. Apply standard substitutions to frontmatter
        sed -i -e "s|{{VERSION}}|$VERSION|g" "$tmp_fm"

        # 3. Apply standard substitutions to command body
        sed -i \
            -e "s|{{PRINCIPLES_DIRECTORY}}|.agents/principles-catalog|g" \
            -e "s|{{VERSION}}|$VERSION|g" \
            "$tmp_body"

        # 4. Apply tool-specific patches (if any)
        if [ -n "$PATCHES" ]; then
            sed -i -e "$PATCHES" "$tmp_body"
        fi

        # 5. Expand wrapper template: replace placeholders with file contents
        #    Process line by line: {{COMMAND_NAME}} is inline, {{FRONTMATTER}}
        #    and {{COMMAND_BODY}} replace the entire line with file contents.
        while IFS= read -r line || [ -n "$line" ]; do
            local expanded
            expanded="${line//\{\{COMMAND_NAME\}\}/$command_name}"
            expanded="${expanded//\{\{COMMAND_SLUG\}\}/$command_slug}"
            expanded="${expanded//\{\{VERSION\}\}/$VERSION}"
            if [[ "$expanded" == *'{{FRONTMATTER}}'* ]]; then
                # Output prefix before {{FRONTMATTER}}, then file, then suffix
                local prefix="${expanded%%\{\{FRONTMATTER\}\}*}"
                local suffix="${expanded#*\{\{FRONTMATTER\}\}}"
                [ -n "$prefix" ] && printf '%s' "$prefix"
                cat "$tmp_fm"
                [ -n "$suffix" ] && printf '%s\n' "$suffix"
            elif [[ "$expanded" == *'{{COMMAND_BODY}}'* ]]; then
                local prefix="${expanded%%\{\{COMMAND_BODY\}\}*}"
                local suffix="${expanded#*\{\{COMMAND_BODY\}\}}"
                [ -n "$prefix" ] && printf '%s' "$prefix"
                cat "$tmp_body"
                [ -n "$suffix" ] && printf '%s' "$suffix"
            else
                printf '%s\n' "$expanded"
            fi
        done < "$wrapper_file" > "$tmp_output"

        # 6. Resolve output path and write
        local resolved_dir resolved_file
        resolved_dir="$(echo "$OUTPUT_DIR" | sed "s|{{COMMAND_NAME}}|$command_name|g; s|{{COMMAND_SLUG}}|$command_slug|g")"
        resolved_file="$(echo "$OUTPUT_FILE" | sed "s|{{COMMAND_NAME}}|$command_name|g; s|{{COMMAND_SLUG}}|$command_slug|g")"

        local target_path="$project_dir/$resolved_dir"
        mkdir -p "$(dirname "$target_path/$resolved_file")"
        cp "$tmp_output" "$target_path/$resolved_file"

        rm -f "$tmp_fm" "$tmp_body" "$tmp_output"

        # 7. Reference files: commands/<dir>/.<command>-<name>.md is installed next to the output
        #    as <name>.md (for example .audit-fix-flow.md -> fix-flow.md). Only for templates that
        #    set SUPPORT_FILES=1. The command reads them on demand, so the main file stays small.
        if [ "${SUPPORT_FILES%$'\r'}" = "1" ]; then
            local ref_base ref_dir ref ref_name
            ref_base="$(basename "$file" .md)"
            ref_dir="$(dirname "$file")"
            for ref in "$ref_dir"/."$ref_base"-*.md; do
                [ -f "$ref" ] || continue
                ref_name="$(basename "$ref")"
                ref_name="${ref_name#.$ref_base-}"
                sed -e "s|{{PRINCIPLES_DIRECTORY}}|.agents/principles-catalog|g"                     -e "s|{{VERSION}}|$VERSION|g" "$ref" > "$target_path/$ref_name"
            done
        fi

        count=$((count + 1))
        local display_name
        if [ "$TOOL_ID" = "claude" ]; then
            display_name="${command_name//\//:}"
        else
            display_name="$command_slug"
        fi
        echo -e "  ${GREEN}✓${NC} $display_name"
    done < <(list_command_files)

    echo ""
    echo -e "Installed ${BOLD}$count${NC} commands to $resolved_dir"
}
