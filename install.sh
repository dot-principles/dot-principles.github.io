#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Flemming N. Larsen — https://github.com/dot-principles/principles
set -euo pipefail

# install.sh — Deploy .principles to AI coding tools
#
# Usage:
#   ./install.sh <dir>              # Interactive: select which tool wrappers to install
#   ./install.sh vendor <dir>       # Sync catalog only; re-installs any previously recorded wrappers
#   ./install.sh --list <dir>       # Show what's installed in <dir>
#   ./uninstall.sh <dir>            # Remove all installed assets from <dir>
#
# Skills are ALWAYS installed to <dir>/.agents/skills/ regardless of wrapper selection.
# All install targets accept --extra-catalog <path> to include a local principles catalog.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')"
COMMAND_SOURCE_DIR="$SCRIPT_DIR/commands"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# Colors (if terminal supports them)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    DIM='\033[0;90m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BOLD='' DIM='' NC=''
fi

# shellcheck source=lib/path-utils.sh
source "$SCRIPT_DIR/lib/path-utils.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/template.sh
source "$SCRIPT_DIR/lib/template.sh"
# shellcheck source=lib/vendor.sh
source "$SCRIPT_DIR/lib/vendor.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

# Main
print_header

# Strip --extra-catalog <path> pairs from args before subcommand dispatch.
# Paths are expanded (~ → $HOME) and stored in EXTRA_CATALOGS_CLI.
_cleaned_args=()
_skip_next=false
for _arg in "$@"; do
    if [ "$_skip_next" = true ]; then
        EXTRA_CATALOGS_CLI+=("$(expand_path "$_arg")")
        _skip_next=false
    elif [ "$_arg" = "--extra-catalog" ]; then
        _skip_next=true
    else
        _cleaned_args+=("$_arg")
    fi
done
if [ "${#_cleaned_args[@]}" -gt 0 ]; then
    set -- "${_cleaned_args[@]}"
else
    set --
fi

# Detect whether arg 1 is a known target or a directory (for interactive mode).
# If arg 1 is a directory that exists (and not a known target), treat as interactive.
ARG1="${1:-}"
ARG2="${2:-}"

require_dir() {
    local dir="$1"
    if [ -z "$dir" ]; then
        echo -e "${RED}Error: A project directory is required.${NC}"
        echo "Usage: $0 <tool> <dir>"
        exit 1
    fi
}

is_known_target() {
    case "$1" in
        vendor|--list|-l|--help|-h) return 0 ;;
        *) return 1 ;;
    esac
}


if [ -n "$ARG1" ] && ! is_known_target "$ARG1" && [ -d "$(normalize_directory_path "$ARG1")" ]; then
    # Interactive mode: first arg is a directory
    DIR_ARG="$(normalize_directory_path "$ARG1")"
    interactive_install "$DIR_ARG"
else
    DIR_ARG="$(normalize_directory_path "$ARG2")"

    case "$ARG1" in
        vendor)
            require_dir "$DIR_ARG"
            read_install_cfg "$DIR_ARG"

            # Skills are always installed; re-install them unconditionally
            "$SCRIPT_DIR/uninstall.sh" --quiet --target agents "$DIR_ARG"
            install_from_template "$TEMPLATE_DIR/agents" "$DIR_ARG"
            echo ""

            # Remove legacy Copilot-local skills and prompts from pre-native installs.
            "$SCRIPT_DIR/uninstall.sh" --quiet --target copilot "$DIR_ARG"
            echo ""

            # Remove stale Claude wrappers even when an older install has no target record.
            "$SCRIPT_DIR/uninstall.sh" --quiet --target claude "$DIR_ARG"
            echo ""

            # Re-install any previously recorded wrappers
            if [ "${INSTALLED_TARGETS[claude]:-}" = "1" ]; then
                install_from_template "$TEMPLATE_DIR/claude" "$DIR_ARG"
                echo ""
            fi
            "$SCRIPT_DIR/uninstall.sh" --quiet --target vendor "$DIR_ARG"
            install_vendor "$DIR_ARG"
            mark_targets vendor
            write_install_cfg "$DIR_ARG"
            refresh_generated "$DIR_ARG"
            ;;
        --list|-l)
            require_dir "$DIR_ARG"
            list_installed "$DIR_ARG"
            ;;
        --help|-h)
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            echo -e "${RED}Unknown target: $ARG1${NC}"
            show_usage
            exit 1
            ;;
    esac
fi

echo ""
echo "Done."
