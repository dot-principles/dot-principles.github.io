#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Flemming N. Larsen — https://github.com/dot-principles/principles
set -euo pipefail

# uninstall.sh — Remove .principles assets from supported AI coding tools
#
# Usage:
#   ./uninstall.sh <project>   # Remove local assets from <project>:
#                              #   Review files: .github/instructions/*.instructions.md (scout-generated)
#                              #                 REVIEW.md (scout-generated)
#                              #                 .claude/rules/*.md (legacy scout output)
#                              #   AI Skills:   .agents/skills/<name>/SKILL.md
#                              #   Claude Code: <project>/.claude/commands/<name>.md
#                              #   Vendor:      .agents/principles-catalog/
#                              #   Legacy:      AGENTS.md / CLAUDE.md (.principles:start block)
#                              #                .claude/rules/principles.md
#                              #                .ai/principles.md (hub pattern)
#   ./uninstall.sh --help      # Show this help

# Convert a Windows-style path (C:\... or C:/...) to a path the current bash understands.
# Under WSL, uses wslpath. Under Git Bash / native Linux/macOS, returns the path unchanged.
normalize_path() {
    local p="$1"
    if [[ -n "$p" && "$p" =~ ^[A-Za-z]:[/\\] ]]; then
        if command -v wslpath &>/dev/null; then
            wslpath -u "$p"
            return
        fi
    fi
    printf '%s' "$p"
}

normalize_directory_path() {
    local dir
    dir="$(normalize_path "$1")"
    if [ -z "$dir" ]; then
        printf '%s' "$dir"
        return
    fi

    case "$dir" in
        /|[A-Za-z]:/)
            printf '%s' "$dir"
            return
            ;;
    esac

    while [ "${dir%/}" != "$dir" ]; do
        dir="${dir%/}"
    done

    printf '%s' "$dir"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUIET=false
TARGET=""
_args=()
_skip_next=false
for _arg in "$@"; do
    if [ "$_skip_next" = true ]; then
        TARGET="$_arg"
        _skip_next=false
        continue
    fi
    case "$_arg" in
        --quiet|-q) QUIET=true ;;
        --target) _skip_next=true ;;
        *) _args+=("$_arg") ;;
    esac
done
set -- "${_args[@]+"${_args[@]}"}"

# Output helper — suppressed in --quiet mode (errors always print via stderr)
qecho() { [ "$QUIET" = false ] && echo -e "$@" || true; }

COMMAND_SOURCE_DIR="$SCRIPT_DIR/commands"

# Command names that were used in previous versions and may still be installed.
# These are removed in addition to any names found in COMMAND_SOURCE_DIR.
# TODO: Remove this list once enough time has passed for users to have upgraded
#       (added in v0.10.0 after rename from audit/prime/scout → dot-audit/dot-prime/dot-scout).
LEGACY_COMMAND_NAMES=("audit" "prime" "scout" "dot-audit" "dot-prime" "dot-scout")

PROJECT_DIR=""
if [ -n "${1:-}" ] && [[ "${1:-}" != --* ]]; then
    PROJECT_DIR="$(normalize_directory_path "$1")"
fi

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

NEUTRAL="${DIM}-${NC}"

cleanup_dir_if_empty() {
    local dir="$1"

    if [ -d "$dir" ] && [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        rmdir "$dir"
    fi
}

# Match both the original unversioned watermark and current versioned forms.
# This keeps upgrades able to remove generated assets from any prior release.
is_principles_generated_file() {
    local file="$1"
    grep -qE '^generated-by: "?\.principles( v[^"]+)?"?$' "$file" 2>/dev/null
}

print_header() {
    qecho ""
    qecho "${BOLD}.principles uninstaller${NC}"
    qecho "───────────────────────────"
}

show_usage() {
    print_header
    echo ""
    echo -e "Usage: $0 ${BOLD}<dir>${NC}"
    echo ""
    echo "Removes .principles assets for all AI coding tools and vendor catalog."
    echo ""
    echo -e "  ${BOLD}<dir>${NC}               Remove local assets from <dir>:"
    echo -e "                        ${DIM}AI Skills:${NC}       .agents/skills/<name>/SKILL.md"
    echo -e "                        ${DIM}Claude wrappers:${NC} .claude/commands/<name>.md"
    echo -e "                        ${DIM}Vendor:${NC}          .agents/principles-catalog/"
    echo -e "                        ${DIM}Legacy:${NC}          AGENTS.md / CLAUDE.md (.principles:start block, if present)"
    echo -e "                        ${DIM}Scout files:${NC}     .github/instructions/*.instructions.md"
    echo -e "                                         REVIEW.md (scout-generated)"
    echo -e "                                         .claude/rules/*.md (legacy scout output)"
    echo ""
    echo "Options:"
    echo -e "  ${BOLD}--help${NC}              Show this help"
    echo -e "  ${BOLD}--target <name>${NC}     Only remove assets for one target"
    echo "                      (compiled | claude | copilot | agents | vendor)"
}

uninstall_claude() {
    local project_dir="$1"
    local target_dir="$project_dir/.claude/commands"

    qecho "${BOLD}Removing Claude Code slash commands (local: $project_dir)...${NC}"

    local count=0
    local file

    # Content-based detection: remove any command file bearing the .principles watermark
    if [ -d "$target_dir" ]; then
        while IFS= read -r file; do
            [ -f "$file" ] || continue
            if is_principles_generated_file "$file"; then
                rm "$file"
                count=$((count + 1))
                local rel="${file#$target_dir/}"; rel="${rel%.md}"
                qecho "  ${GREEN}✓${NC} /${rel//\//\:}"
            fi
        done < <(find "$target_dir" -name "*.md" -type f 2>/dev/null | sort)
    fi

    # Fallback: remove legacy command names (pre-watermark installs)
    local legacy_name
    for legacy_name in "${LEGACY_COMMAND_NAMES[@]}"; do
        local legacy_file="$target_dir/${legacy_name}.md"
        if [ -f "$legacy_file" ]; then
            rm "$legacy_file"
            count=$((count + 1))
            qecho "  ${GREEN}✓${NC} /$legacy_name (legacy)"
        fi
    done

    # Current namespaced layout from releases that predate retired-command cleanup.
    local retired_path
    for retired_path in "dot/prime.md"; do
        local retired_file="$target_dir/$retired_path"
        if [ -f "$retired_file" ]; then
            rm "$retired_file"
            count=$((count + 1))
            qecho "  ${GREEN}✓${NC} /${retired_path%.md} (retired)"
        fi
    done

    if [ $count -eq 0 ]; then
        qecho "  ${NEUTRAL} No current commands found to remove."
    else
        qecho ""
        qecho "Removed ${GREEN}$count${NC} commands."
    fi

    # Clean up any empty subdirectories left behind (e.g. dot/)
    if [ -d "$target_dir" ]; then
        find "$target_dir" -mindepth 1 -type d | sort -r | while IFS= read -r subdir; do
            cleanup_dir_if_empty "$subdir"
        done
    fi
    cleanup_dir_if_empty "$target_dir"
    cleanup_dir_if_empty "$project_dir/.claude"
}

uninstall_copilot() {
    local project_dir="$1"
    uninstall_copilot_local "$project_dir"
}

uninstall_copilot_local() {
    local project_dir="$1"
    local target_file="$project_dir/.github/copilot-instructions.md"
    local prompts_dir="$project_dir/.github/prompts"
    local skills_dir="$project_dir/.github/skills"

    qecho "${BOLD}Removing GitHub Copilot instructions...${NC}"

    if [ ! -f "$target_file" ]; then
        qecho "  ${NEUTRAL} No Copilot instructions found to remove."
    else
        local temp_file
        temp_file="$(mktemp)"

        awk '
            BEGIN { in_block=0; removed=0 }
            /^<!-- .principles: begin -->$/ { in_block=1; removed=1; next }
            /^<!-- .principles: end -->$/   { if (in_block) { in_block=0; next } }
            !in_block { print }
            END { exit removed ? 0 : 1 }
        ' "$target_file" > "$temp_file" || {
            rm -f "$temp_file"
            qecho "  ${NEUTRAL} No .principles Copilot instructions found to remove."
            temp_file=""
        }

        if [ -n "${temp_file:-}" ]; then
            # Trim trailing blank lines left after block removal
            awk '{lines[NR]=$0; if(/[^[:space:]]/) last=NR} END{for(i=1;i<=last;i++) print lines[i]}' \
                "$temp_file" > "${temp_file}.t" && mv "${temp_file}.t" "$temp_file"

            if grep -q '[^[:space:]]' "$temp_file"; then
                mv "$temp_file" "$target_file"
                qecho "  ${GREEN}✓${NC} .github/copilot-instructions.md (removed .principles block)"
            else
                rm -f "$temp_file" "$target_file"
                qecho "  ${GREEN}✓${NC} .github/copilot-instructions.md"
            fi
        fi
    fi

    qecho ""
    qecho "${BOLD}Removing GitHub Copilot skills...${NC}"

    local skill_count=0
    local file

    # Content-based detection: remove skill dirs whose SKILL.md bears the .principles watermark
    if [ -d "$skills_dir" ]; then
        for file in "$skills_dir"/*/SKILL.md; do
            [ -f "$file" ] || continue
            if is_principles_generated_file "$file"; then
                local skill_dir
                skill_dir="$(dirname "$file")"
                rm -rf "$skill_dir"
                skill_count=$((skill_count + 1))
                qecho "  ${GREEN}✓${NC} .github/skills/$(basename "$skill_dir")/"
            fi
        done
    fi

    # Fallback: remove legacy skill dirs (pre-watermark installs)
    local legacy_name
    for legacy_name in "${LEGACY_COMMAND_NAMES[@]}"; do
        local legacy_skill_dir="$skills_dir/$legacy_name"
        if [ -d "$legacy_skill_dir" ]; then
            rm -rf "$legacy_skill_dir"
            skill_count=$((skill_count + 1))
            qecho "  ${GREEN}✓${NC} .github/skills/$legacy_name/ (legacy)"
        fi
    done

    if [ $skill_count -eq 0 ]; then
        qecho "  ${NEUTRAL} No Copilot skills found to remove."
    fi

    qecho ""
    qecho "${BOLD}Removing GitHub Copilot prompt commands...${NC}"

    local prompt_count=0

    # Content-based detection: remove prompt files bearing the .principles watermark
    if [ -d "$prompts_dir" ]; then
        for file in "$prompts_dir/"*.prompt.md; do
            [ -f "$file" ] || continue
            if is_principles_generated_file "$file"; then
                rm "$file"
                prompt_count=$((prompt_count + 1))
                qecho "  ${GREEN}✓${NC} .github/prompts/$(basename "$file")"
            fi
        done
    fi

    # Fallback: remove legacy prompt files (pre-watermark installs)
    for legacy_name in "${LEGACY_COMMAND_NAMES[@]}"; do
        local legacy_prompt="$prompts_dir/${legacy_name}.prompt.md"
        if [ -f "$legacy_prompt" ]; then
            rm "$legacy_prompt"
            prompt_count=$((prompt_count + 1))
            qecho "  ${GREEN}✓${NC} .github/prompts/${legacy_name}.prompt.md (legacy)"
        fi
    done

    if [ $prompt_count -eq 0 ]; then
        qecho "  ${NEUTRAL} No Copilot prompt commands found to remove."
    fi

    cleanup_dir_if_empty "$skills_dir"
    cleanup_dir_if_empty "$prompts_dir"
    cleanup_dir_if_empty "$project_dir/.github"
}

uninstall_agents_skills() {
    local project_dir="$1"
    local skills_dir="$project_dir/.agents/skills"

    qecho "${BOLD}Removing AI skills (.agents/skills/)...${NC}"

    local skill_count=0
    local file

    # Content-based detection: remove skill dirs whose SKILL.md bears the .principles watermark
    if [ -d "$skills_dir" ]; then
        for file in "$skills_dir"/*/SKILL.md; do
            [ -f "$file" ] || continue
            if is_principles_generated_file "$file"; then
                local skill_dir
                skill_dir="$(dirname "$file")"
                rm -rf "$skill_dir"
                skill_count=$((skill_count + 1))
                qecho "  ${GREEN}✓${NC} .agents/skills/$(basename "$skill_dir")/"
            fi
        done
    fi

    # Fallback: remove legacy skill dirs (pre-watermark installs)
    local legacy_name
    for legacy_name in "${LEGACY_COMMAND_NAMES[@]}"; do
        local legacy_skill_dir="$skills_dir/$legacy_name"
        if [ -d "$legacy_skill_dir" ]; then
            rm -rf "$legacy_skill_dir"
            skill_count=$((skill_count + 1))
            qecho "  ${GREEN}✓${NC} .agents/skills/$legacy_name/ (legacy)"
        fi
    done

    if [ $skill_count -eq 0 ]; then
        qecho "  ${NEUTRAL} No AI skills found to remove."
    fi

    cleanup_dir_if_empty "$skills_dir"
    cleanup_dir_if_empty "$project_dir/.agents"
}

uninstall_compiled_blocks() {
    local project_dir="$1"

    qecho "${BOLD}Removing per-group principle files and legacy compiled blocks...${NC}"

    local found=false

    # dot-scout marks its output with "<!-- generated by dot-scout" (v0.13.0+) or the
    # legacy "<!-- generated by /dot-scout"; files without a marker are user-created.
    local scout_marker='<!-- generated by /\?dot-scout'

    # Per-group files in .github/instructions/ — remove scout-generated files only
    local instructions_dir="$project_dir/.github/instructions"
    if [ -d "$instructions_dir" ]; then
        local file
        for file in "$instructions_dir"/*.instructions.md; do
            [ -f "$file" ] || continue
            if grep -q "$scout_marker" "$file" 2>/dev/null; then
                rm "$file"
                found=true
                qecho "  ${GREEN}✓${NC} .github/instructions/$(basename "$file")"
            fi
        done
        cleanup_dir_if_empty "$instructions_dir"
    fi

    # REVIEW.md at the project root (Claude Code Review) — remove only if scout-generated
    local review_file="$project_dir/REVIEW.md"
    if [ -f "$review_file" ] && grep -q "$scout_marker" "$review_file" 2>/dev/null; then
        rm "$review_file"
        found=true
        qecho "  ${GREEN}✓${NC} REVIEW.md"
    fi

    # Legacy per-group files in .claude/rules/ — remove scout-generated files only
    local rules_dir="$project_dir/.claude/rules"
    if [ -d "$rules_dir" ]; then
        local file
        for file in "$rules_dir"/*.md; do
            [ -f "$file" ] || continue
            if grep -q "$scout_marker" "$file" 2>/dev/null; then
                rm "$file"
                found=true
                qecho "  ${GREEN}✓${NC} .claude/rules/$(basename "$file")"
            fi
        done
        cleanup_dir_if_empty "$rules_dir"
        cleanup_dir_if_empty "$project_dir/.claude"
    fi

    # Legacy: .claude/rules/principles.md — remove file entirely if it was created by scout
    local claude_rules="$project_dir/.claude/rules/principles.md"
    if [ -f "$claude_rules" ]; then
        rm "$claude_rules"
        found=true
        qecho "  ${GREEN}✓${NC} .claude/rules/principles.md (legacy)"
        cleanup_dir_if_empty "$project_dir/.claude/rules"
        cleanup_dir_if_empty "$project_dir/.claude"
    fi

    # Legacy: .ai/principles.md — remove file, remove row from AGENTS.md table
    local ai_principles="$project_dir/.ai/principles.md"
    if [ -f "$ai_principles" ]; then
        rm "$ai_principles"
        found=true
        qecho "  ${GREEN}✓${NC} .ai/principles.md (legacy)"
        cleanup_dir_if_empty "$project_dir/.ai"

        # Remove the reference row from AGENTS.md if present
        local agents_file="$project_dir/AGENTS.md"
        if [ -f "$agents_file" ] && grep -q "\.ai/principles\.md" "$agents_file"; then
            local tmp
            tmp="$(mktemp)"
            grep -v "\.ai/principles\.md" "$agents_file" > "$tmp"
            mv "$tmp" "$agents_file"
            qecho "  ${GREEN}✓${NC} AGENTS.md (removed .ai/principles.md reference)"
        fi
    fi

    # Legacy: AGENTS.md — strip compiled block if injected directly
    local agents_file="$project_dir/AGENTS.md"
    if [ -f "$agents_file" ] && grep -q "^<!-- .principles: begin" "$agents_file"; then
        local tmp result_file
        tmp="$(mktemp)"
        awk '
            BEGIN { in_block=0; removed=0 }
            /^<!-- \.principles: begin/ { in_block=1; removed=1; next }
            /^<!-- \.principles: end -->$/ { if (in_block) { in_block=0; next } }
            !in_block { print }
            END { exit removed ? 0 : 1 }
        ' "$agents_file" > "$tmp" && {
            result_file="$(mktemp)"
            awk '{lines[NR]=$0; if(/[^[:space:]]/) last=NR} END{for(i=1;i<=last;i++) print lines[i]}' \
                "$tmp" > "$result_file"
            if grep -q '[^[:space:]]' "$result_file"; then
                mv "$result_file" "$agents_file"
            else
                rm -f "$result_file" "$agents_file"
            fi
            rm -f "$tmp"
            found=true
            qecho "  ${GREEN}✓${NC} AGENTS.md (removed .principles block, legacy)"
        } || rm -f "$tmp"
    fi

    # Legacy: CLAUDE.md — strip compiled block if injected directly
    local claude_file="$project_dir/CLAUDE.md"
    if [ -f "$claude_file" ] && grep -q "^<!-- .principles: begin" "$claude_file"; then
        local tmp result_file
        tmp="$(mktemp)"
        awk '
            BEGIN { in_block=0; removed=0 }
            /^<!-- \.principles: begin/ { in_block=1; removed=1; next }
            /^<!-- \.principles: end -->$/ { if (in_block) { in_block=0; next } }
            !in_block { print }
            END { exit removed ? 0 : 1 }
        ' "$claude_file" > "$tmp" && {
            result_file="$(mktemp)"
            awk '{lines[NR]=$0; if(/[^[:space:]]/) last=NR} END{for(i=1;i<=last;i++) print lines[i]}' \
                "$tmp" > "$result_file"
            if grep -q '[^[:space:]]' "$result_file"; then
                mv "$result_file" "$claude_file"
            else
                rm -f "$result_file" "$claude_file"
            fi
            rm -f "$tmp"
            found=true
            qecho "  ${GREEN}✓${NC} CLAUDE.md (removed .principles block, legacy)"
        } || rm -f "$tmp"
    fi

    if [ "$found" = false ]; then
        qecho "  ${NEUTRAL} No per-group files or compiled blocks found to remove."
    fi
}

# Remove the legacy <!-- .principles:start --> hub block from AGENTS.md and CLAUDE.md (if present).
uninstall_hub_blocks() {
    local project_dir="$1"
    local found=false

    for hub_file in "$project_dir/AGENTS.md" "$project_dir/CLAUDE.md"; do
        [ -f "$hub_file" ] || continue
        grep -q "^<!-- .principles:start -->$" "$hub_file" 2>/dev/null || continue

        local tmp result_file
        tmp="$(mktemp)"
        awk '
            BEGIN { in_block=0; removed=0 }
            /^<!-- \.principles:start -->$/ { in_block=1; removed=1; next }
            /^<!-- \.principles:end -->$/   { if (in_block) { in_block=0; next } }
            !in_block { print }
            END { exit removed ? 0 : 1 }
        ' "$hub_file" > "$tmp" && {
            result_file="$(mktemp)"
            awk '{lines[NR]=$0; if(/[^[:space:]]/) last=NR} END{for(i=1;i<=last;i++) print lines[i]}' \
                "$tmp" > "$result_file"
            local rel_name
            rel_name="$(basename "$hub_file")"
            if grep -q '[^[:space:]]' "$result_file"; then
                mv "$result_file" "$hub_file"
            else
                rm -f "$result_file" "$hub_file"
            fi
            rm -f "$tmp"
            found=true
            qecho "  ${GREEN}✓${NC} $rel_name (removed .principles hub block)"
        } || rm -f "$tmp"
    done

    [ "$found" = false ] && qecho "  ${NEUTRAL} No hub blocks found to remove."
}

uninstall_vendor() {
    local project_dir="$1"

    qecho "${BOLD}Removing vendor catalog...${NC}"

    local found=false
    if [ -d "$project_dir/.agents/principles-catalog" ]; then
        rm -rf "$project_dir/.agents/principles-catalog"
        qecho "  ${GREEN}✓${NC} Removed .agents/principles-catalog/"
        cleanup_dir_if_empty "$project_dir/.agents"
        found=true
    fi
    if [ -d "$project_dir/.principles-catalog" ]; then
        rm -rf "$project_dir/.principles-catalog"
        qecho "  ${GREEN}✓${NC} Removed .principles-catalog/ (legacy)"
        found=true
    fi
    if [ "$found" = false ]; then
        qecho "  ${NEUTRAL} No vendor catalog found to remove."
    fi
}

require_project_dir() {
    if [ -z "$PROJECT_DIR" ]; then
        echo -e "${RED}Error: A project directory is required.${NC}"
        echo "Usage: $0 <dir>"
        exit 1
    fi
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}Error: Directory '$PROJECT_DIR' does not exist.${NC}"
        exit 1
    fi
}

run_uninstall() {
    require_project_dir

    print_header
    qecho ""

    if [ -z "$TARGET" ] || [ "$TARGET" = "compiled" ]; then
        uninstall_compiled_blocks "$PROJECT_DIR"
        qecho ""
    fi
    if [ -z "$TARGET" ] || [ "$TARGET" = "claude" ]; then
        uninstall_claude "$PROJECT_DIR"
        qecho ""
    fi
    if [ -z "$TARGET" ] || [ "$TARGET" = "copilot" ]; then
        uninstall_copilot "$PROJECT_DIR"
        qecho ""
    fi
    if [ -z "$TARGET" ] || [ "$TARGET" = "agents" ] || [ "$TARGET" = "codex" ]; then
        uninstall_agents_skills "$PROJECT_DIR"
        qecho ""
    fi
    if [ -z "$TARGET" ] || [ "$TARGET" = "vendor" ]; then
        uninstall_vendor "$PROJECT_DIR"
        qecho ""
    fi

    # Remove hub blocks from AGENTS.md and CLAUDE.md (new-style <!-- .principles:start --> blocks)
    if [ -z "$TARGET" ] || [ "$TARGET" = "compiled" ]; then
        uninstall_hub_blocks "$PROJECT_DIR"
        qecho ""
    fi

    # Remove legacy ~/.principles if it exists
    if [ -d "$HOME/.principles" ]; then
        rm -rf "$HOME/.principles"
        qecho "  ${GREEN}✓${NC} Removed legacy ~/.principles (no longer used)"
        qecho ""
    fi

    qecho "Done."
}

case "${1:-}" in
    --help|-h)
        show_usage
        ;;
    "")
        echo -e "${RED}Error: A project directory is required.${NC}"
        echo "Usage: $0 <dir>"
        exit 1
        ;;
    *)
        if [[ "$1" == -* ]]; then
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
        fi

        run_uninstall
        ;;
esac
