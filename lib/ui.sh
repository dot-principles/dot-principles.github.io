# ui.sh — User-facing commands for install.sh
# Sourced by install.sh. Defines: list_installed, show_usage, interactive_install.
# Requires: $SCRIPT_DIR, $TEMPLATE_DIR, $COMMAND_SOURCE_DIR, color variables,
# INSTALLED_TARGETS, read_install_cfg, mark_targets, install_from_template,
# install_vendor.

list_installed() {
    local project_dir="$1"
    echo -e "${BOLD}Installed .principles (project: $project_dir):${NC}"
    echo ""

    echo "AI Skills (.agents/skills/):"
    local skills_found=false
    while IFS= read -r file; do
        local command_name="${file#$COMMAND_SOURCE_DIR/}"; command_name="${command_name%.md}"
        local command_slug="${command_name//\//-}"
        local skill_file="$project_dir/.agents/skills/$command_slug/SKILL.md"
        if [ -f "$skill_file" ]; then
            echo -e "  ${GREEN}✓${NC} .agents/skills/$command_slug/SKILL.md"
            skills_found=true
        fi
    done < <(list_command_files)
    if [ "$skills_found" = false ]; then
        echo "  (none)"
    fi

    echo ""
    echo "Claude Code wrappers (.claude/commands/):"
    local claude_found=false
    while IFS= read -r file; do
        local command_name="${file#$COMMAND_SOURCE_DIR/}"; command_name="${command_name%.md}"
        local command_slug="${command_name//\//-}"
        if [ -f "$project_dir/.claude/commands/$command_name.md" ]; then
            echo -e "  ${GREEN}✓${NC} /${command_name//\//\:}"
            claude_found=true
        fi
    done < <(list_command_files)
    if [ "$claude_found" = false ]; then
        echo "  (none)"
    fi

    echo ""
    echo "Vendor catalog (.agents/principles-catalog/):"
    if [ -d "$project_dir/.agents/principles-catalog" ]; then
        echo -e "  ${GREEN}✓${NC} .agents/principles-catalog/"
    else
        echo "  (none)"
    fi

    echo ""
    echo "Review integration (emitted by /dot-scout at runtime):"
    read_install_cfg "$project_dir"
    local review_found=false
    if [ "${INSTALLED_TARGETS[copilot-review]:-}" = "1" ]; then
        echo -e "  ${GREEN}✓${NC} Copilot Code Review → .github/instructions/"
        review_found=true
    fi
    if [ "${INSTALLED_TARGETS[claude-review]:-}" = "1" ]; then
        echo -e "  ${GREEN}✓${NC} Claude Code Review  → REVIEW.md"
        review_found=true
    fi
    if [ "$review_found" = false ]; then
        echo "  (none — re-run installer to enable review targets)"
    fi
}

show_usage() {
    echo ""
    echo -e "Usage: $0 [${BOLD}<target>${NC}] ${BOLD}<dir>${NC}"
    echo ""
    echo -e "${BOLD}Interactive:${NC}"
    echo -e "  ${BOLD}<dir>${NC}               Select tools and review options interactively"
    echo ""
    echo -e "${BOLD}Targets:${NC}"
    echo -e "  ${BOLD}vendor${NC} <dir>        Update catalog + reinstall any previously installed wrappers"
    echo ""
    echo -e "${BOLD}Management:${NC}"
    echo -e "  ${BOLD}--list${NC} <dir>        Show what's installed in <dir>"
    echo -e "  ${BOLD}--help${NC}              Show this help"
    echo "  ./uninstall.sh <dir> Remove local assets from <dir>"
    echo ""
    echo -e "${DIM}Skills are ALWAYS installed to .agents/skills/ regardless of wrapper selection.${NC}"
    echo -e "${DIM}Tool-specific wrappers are optional and selected interactively:${NC}"
    echo -e "  Claude Code    → .claude/commands/   ${DIM}(thin wrappers)${NC}"
    echo -e "  Copilot CLI    → .agents/skills/     ${DIM}(native, no wrapper needed)${NC}"
    echo -e "  Copilot IDE    → .agents/skills/     ${DIM}(native, no wrapper needed)${NC}"
    echo -e "  Codex          → .agents/skills/     ${DIM}(native, no wrapper needed)${NC}"
    echo ""
    echo -e "${DIM}Review integration (controlled via interactive mode):${NC}"
    echo -e "  Copilot Code Review → .github/instructions/ ${DIM}(emitted by /dot-scout)${NC}"
    echo -e "  Claude Code Review  → REVIEW.md             ${DIM}(emitted by /dot-scout)${NC}"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./install.sh ~/projects/my-app           # Interactive"
    echo "  ./install.sh vendor ~/projects/my-app    # Sync catalog + reinstall"
    echo ""
    echo -e "${BOLD}Extra catalogs (corporate or personal principles):${NC}"
    echo -e "  ${BOLD}--extra-catalog${NC} <path>  Merge an additional principles directory into .agents/principles-catalog/"
    echo "                         Can be repeated. Paths in ~/.principles-extra and <dir>/.principles-extra"
    echo "                         are loaded automatically (one path per line, # for comments)."
    echo ""
    echo "  ./install.sh vendor ~/projects/my-app --extra-catalog ~/acme-principles"
    echo ""
    echo "  See INSTALL.md for corporate and personal setup instructions."
}

# Interactive tool selection
interactive_install() {
    local project_dir="$1"

    if ! [ -t 0 ]; then
        echo -e "${RED}Error: Interactive mode requires a terminal. Use 'vendor' target instead.${NC}"
        show_usage
        exit 1
    fi

    # Load existing install.cfg to preserve previous selections
    read_install_cfg "$project_dir"

    # ── Step 1: Select AI tools ───────────────────────────────────────────
    echo ""
    echo "Which AI tools do you use?"
    echo ""
    echo "  1) GitHub Copilot   (CLI / IDE / Code Review)  → .agents/skills/ [native]"
    echo "  2) Claude Code  → .claude/commands/ wrappers"
    echo "  3) Codex   → .agents/skills/ [native]"
    echo ""
    echo "  a) All of the above"
    echo "  q) Quit"
    echo ""
    printf "Select tools (e.g. 1 2, or 'a' for all): "
    read -r tool_selection

    if [ -z "$tool_selection" ] || [ "$tool_selection" = "q" ]; then
        echo "Cancelled."
        exit 0
    fi

    local do_copilot=false do_claude=false do_codex=false

    if [ "$tool_selection" = "a" ] || [ "$tool_selection" = "A" ]; then
        do_copilot=true; do_claude=true; do_codex=true
    else
        for token in $tool_selection; do
            case "$token" in
                1) do_copilot=true ;;
                2) do_claude=true ;;
                3) do_codex=true ;;
                *) echo -e "${YELLOW}Warning: Unknown selection '$token' — skipped${NC}" ;;
            esac
        done
    fi

    # ── Step 2: Review integration ────────────────────────────────────────
    local do_copilot_review=false do_claude_review=false
    if [ "$do_copilot" = true ] || [ "$do_claude" = true ]; then
        echo ""
        echo "Enable AI code review? (emitted by /dot-scout at runtime)"
        echo ""
        echo "  1) Copilot Code Review  → .github/instructions/"
        echo "  2) Claude Code Review   → REVIEW.md"
        echo "  3) Both"
        echo "  n) None"
        echo ""
        printf "Select (1-3 or n): "
        read -r review_choice
        case "${review_choice:-n}" in
            1) do_copilot_review=true ;;
            2) do_claude_review=true ;;
            3) do_copilot_review=true; do_claude_review=true ;;
            n|N|"") ;;
            *) echo -e "${YELLOW}Invalid choice — skipping review integration${NC}" ;;
        esac
    fi

    # ── Install: Skills (always) ──────────────────────────────────────────
    echo ""
    "$SCRIPT_DIR/uninstall.sh" --quiet --target agents "$project_dir"
    install_from_template "$TEMPLATE_DIR/agents" "$project_dir"
    echo ""

    # Remove legacy Copilot-local skills and prompts from pre-native installs.
    "$SCRIPT_DIR/uninstall.sh" --quiet --target copilot "$project_dir"
    echo ""

    # Remove stale Claude wrappers even when Claude is not selected this time.
    "$SCRIPT_DIR/uninstall.sh" --quiet --target claude "$project_dir"
    echo ""

    # ── Install: Claude Code wrappers ────────────────────────────────────
    if [ "$do_claude" = true ]; then
        install_from_template "$TEMPLATE_DIR/claude" "$project_dir"
        mark_targets claude
        echo ""
    fi

    # ── Install: Catalog ─────────────────────────────────────────────────
    "$SCRIPT_DIR/uninstall.sh" --quiet --target vendor "$project_dir"
    install_vendor "$project_dir"

    # ── Mark review targets ───────────────────────────────────────────────
    if [ "$do_copilot_review" = true ]; then
        mark_targets copilot-review
    fi
    if [ "$do_claude_review" = true ]; then
        mark_targets claude-review
    fi

    mark_targets vendor
    write_install_cfg "$project_dir"
    refresh_generated "$project_dir"

    # ── Summary ───────────────────────────────────────────────────────────
    local has_review=false
    if [ "${INSTALLED_TARGETS[copilot-review]:-}" = "1" ] || [ "${INSTALLED_TARGETS[claude-review]:-}" = "1" ]; then
        has_review=true
    fi
    if [ "$has_review" = true ]; then
        echo ""
        echo -e "${BOLD}Review integration enabled — run /dot-scout to emit review files:${NC}"
        [ "${INSTALLED_TARGETS[copilot-review]:-}" = "1" ] && echo "  Copilot Code Review  → .github/instructions/   (applyTo: frontmatter)"
        [ "${INSTALLED_TARGETS[claude-review]:-}" = "1" ]  && echo "  Claude Code Review   → REVIEW.md               (severity-grouped)"
    fi
}
