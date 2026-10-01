#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# run.sh - Run one review headlessly with `claude -p` and score it. Builds the project with
# prepare.sh, asks for the review, extracts the findings and calls score.sh.
#
# Usage: run.sh <set> <arm> <rep> <outdir> [--model NAME] [--budget USD]
#
#   <set>      defects | violations
#   <arm>      A | B | C (see README.md)
#   <rep>      Repetition number, used in the run name
#   <outdir>   Directory that receives <arm>-<set>-<rep>/ with the project, the raw stream,
#              result.txt, findings.tsv, meta.txt and score.txt (line level) and score-file.txt
#   --model    Model for every run (default sonnet); keep it the same across arms
#   --budget   Maximum spend per run in USD (default 3)
#
# Needs the claude CLI and node. CLAUDE_BIN overrides the command. Every run draws on your own
# Claude allowance: about 50,000 to 340,000 tokens per run on the corpus. The agent is told to
# end with FINDING|<path>|<line>|<description> lines; arm C follows .agents/skills/dot-audit/SKILL.md
# because Claude Code does not load .agents/skills as slash commands.
set -uo pipefail

[ $# -ge 4 ] || { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
SET="$1"; ARM="$2"; REP="$3"; OUT="$4"; shift 4
MODEL="sonnet"; BUDGET="3"
while [ $# -gt 0 ]; do
    case "$1" in
        --model)  MODEL="$2"; shift 2 ;;
        --budget) BUDGET="$2"; shift 2 ;;
        *)        echo "run.sh: unknown argument $1" >&2; exit 2 ;;
    esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_BIN:-claude}"
command -v node > /dev/null 2>&1 || { echo "run.sh: node is required to read the claude output" >&2; exit 2; }
command -v "$CLAUDE" > /dev/null 2>&1 || { echo "run.sh: $CLAUDE not found" >&2; exit 2; }

RUN="$OUT/$ARM-$SET-$REP"
[ ! -e "$RUN" ] || { echo "run.sh: $RUN already exists" >&2; exit 2; }
mkdir -p "$RUN"
bash "$HERE/prepare.sh" "$SET" "$ARM" "$RUN/project" > "$RUN/prepare.txt" 2>&1 \
    || { echo "run.sh: prepare.sh failed, see $RUN/prepare.txt" >&2; exit 1; }

FMT='Finish with one line per problem, in exactly this form and with nothing after them: FINDING|<path from the repository root>|<line number>|<short description>. The line number is the line in that file itself: read the file to get it, never count lines in a combined listing or a diff. If you find nothing, write NO-FINDINGS. Do not modify any files and do not ask questions.'
if [ "$ARM" = "C" ]; then
    PROMPT="Follow the instructions in .agents/skills/dot-audit/SKILL.md to audit the whole project (target .). Report only: do not fix, commit or push. $FMT"
else
    PROMPT="Review the changes on branch eval compared to main in this repository (git diff main...eval) and find real problems. $FMT"
fi

( cd "$RUN/project" && "$CLAUDE" -p "$PROMPT" --model "$MODEL" --output-format stream-json --verbose \
    --strict-mcp-config --permission-mode acceptEdits --max-budget-usd "$BUDGET" --no-session-persistence \
    --allowedTools "Read" "Glob" "Grep" "Write" "Skill" "Bash(git:*)" "Bash(bash:*)" "Bash(cat:*)" "Bash(ls:*)" "Bash(wc:*)" "Bash(grep:*)" \
    > "$RUN/stream.jsonl" 2> "$RUN/stderr.txt" < /dev/null ) || echo "run.sh: claude exited non-zero, see $RUN/stderr.txt" >&2

node "$HERE/extract-run.js" "$RUN/stream.jsonl" "$RUN"
awk -F'|' '/^FINDING\|/ { gsub(/\r/, ""); printf "%s\t%s\t\t%s\n", $2, $3, $4 }' "$RUN/result.txt" > "$RUN/findings.tsv"
# shellcheck disable=SC1091
. "$RUN/meta.txt"
score() { bash "$HERE/score.sh" --expected "$HERE/expected/$SET.tsv" --findings "$RUN/findings.tsv" \
    --corpus "$HERE/corpus/$SET" --label "$ARM-$SET-$REP" --tokens "$tokens" --seconds "$seconds" "$@"; }
score > "$RUN/score.txt"
score --file-only > "$RUN/score-file.txt"
echo "line level:"; cat "$RUN/score.txt"
echo "file level:"; cat "$RUN/score-file.txt"
