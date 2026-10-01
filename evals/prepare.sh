#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# prepare.sh - Build a fresh project for one review run, outside this repository so that the
# agent cannot read the expected findings.
#
# Usage: prepare.sh <set> <arm> <dest>
#
#   <set>    defects | violations (a directory under evals/corpus)
#   <arm>    A  no principles: the agent's own review
#            B  generated review files only (review.md, AGENTS.md block, REVIEW.md); no skills
#            C  B plus the dot-audit and dot-scout skills
#   <dest>   Directory to create; it must not exist or must be empty
#
# The corpus is committed on branch "eval", one commit after the base commit, so a review of the
# branch sees every corpus file as added. Arms B and C vendor the catalog from this repository
# into <dest>/.agents/principles-catalog and activate the principles listed below.
set -euo pipefail

[ $# -eq 3 ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
SET="$1"; ARM="$2"; DEST="$3"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORPUS="$ROOT/evals/corpus/$SET"

[ -d "$CORPUS" ] || { echo "prepare.sh: no corpus set '$SET' (expected a directory under evals/corpus)" >&2; exit 2; }
case "$ARM" in A|B|C) ;; *) echo "prepare.sh: arm must be A, B or C" >&2; exit 2 ;; esac
if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST")" ]; then
    echo "prepare.sh: $DEST exists and is not empty" >&2; exit 2
fi
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

git -C "$DEST" init -q -b main
git -C "$DEST" config user.name "eval"
git -C "$DEST" config user.email "eval@example.invalid"
git -C "$DEST" config core.autocrlf false

if [ "$ARM" != "A" ]; then
    case "$SET" in
        defects)    printf '@python\n' > "$DEST/.principles" ;;
        violations) printf '@python\nCODE-SEC-VALIDATE-INPUT\n' > "$DEST/.principles" ;;
        *)          echo "prepare.sh: no principle set defined for '$SET'" >&2; exit 2 ;;
    esac
    bash "$ROOT/install.sh" vendor "$DEST" > /dev/null
    bash "$DEST/.agents/principles-catalog/bin/emit.sh" --root "$DEST" --tools claude --stacks code > /dev/null
    if [ "$ARM" = "B" ]; then rm -rf "$DEST/.agents/skills"; fi
fi

[ -n "$(git -C "$DEST" status --porcelain)" ] || : > "$DEST/.gitkeep"
git -C "$DEST" add -A
git -C "$DEST" commit -q -m "base"
git -C "$DEST" switch -q -c eval
cp -R "$CORPUS"/. "$DEST"/
git -C "$DEST" add -A
git -C "$DEST" commit -q -m "corpus: $SET"
echo "ready: $DEST (arm $ARM, set $SET, branch eval)"
