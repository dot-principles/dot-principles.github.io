#!/usr/bin/env bash
# check-evals.sh - Verify the review evaluation kit: the corpus matches its expected tables,
# evals/score.sh computes recall and precision correctly, and evals/prepare.sh builds a clean
# project for each arm.
# Usage: ./tests/check-evals.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SCORE="$REPO_ROOT/evals/score.sh"
PREPARE="$REPO_ROOT/evals/prepare.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

FAILURES=0
fail() { echo "FAIL [$1] $2"; FAILURES=$((FAILURES + 1)); }
has()  { grep -qF -- "$2" "$1" || fail "$3" "$1 lacks: $2"; }

# ── 1. corpus integrity ──────────────────────────────────────────────────────────────────────
for set in defects violations; do
    dir="$REPO_ROOT/evals/corpus/$set"
    exp="$REPO_ROOT/evals/expected/$set.tsv"
    [ -f "$exp" ] || { fail "corpus-$set" "missing $exp"; continue; }
    listed="$T/listed-$set"; : > "$listed"
    while IFS=$'\t' read -r case_id file start end kind label _; do
        [ "$case_id" = "case" ] && continue
        echo "$file" >> "$listed"
        if [ ! -f "$dir/$file" ]; then fail "corpus-$set" "$case_id: $file does not exist"; continue; fi
        lines="$(wc -l < "$dir/$file")"
        case "$kind" in
            defect|violation)
                if [ "$start" -lt 1 ] || [ "$start" -gt "$end" ] || [ "$end" -gt "$lines" ]; then
                    fail "corpus-$set" "$case_id: range $start-$end is outside $file ($lines lines)"
                fi ;;
            clean)
                if [ "$start" != 0 ] || [ "$end" != 0 ]; then fail "corpus-$set" "$case_id: clean rows use 0 0"; fi ;;
            *) fail "corpus-$set" "$case_id: unknown kind '$kind'" ;;
        esac
        if [ "$kind" = "violation" ] && ! grep -rqE "^# $label - " "$REPO_ROOT/principles"; then
            fail "corpus-$set" "$case_id: $label is not a principle in the catalog"
        fi
    done < "$exp"
    (cd "$dir" && find . -type f | sed 's|^\./||' | sort) > "$T/found-$set"
    sort "$listed" | diff -q - "$T/found-$set" > /dev/null \
        || fail "corpus-$set" "files under corpus/$set and rows in $set.tsv differ"
    # the corpus must not give the answer away
    if grep -rniE "bug|violat|principle|fixme|todo|wrong|vulnerab" "$dir" > /dev/null; then
        fail "corpus-$set" "a corpus file contains a hint ($(grep -rniEl 'bug|violat|principle|fixme|todo|wrong|vulnerab' "$dir" | head -1))"
    fi
done

# ── 2. score.sh arithmetic ───────────────────────────────────────────────────────────────────
printf 'case\tfile\tline_start\tline_end\tkind\tlabel\tdescription\n' > "$T/expected.tsv"
printf 'x1\ta/f.py\t10\t12\tdefect\tl1\td1\n'    >> "$T/expected.tsv"
printf 'x2\ta/g.py\t5\t5\tdefect\tl2\td2\n'       >> "$T/expected.tsv"
printf 'x3\ta/h.py\t1\t1\tdefect\tl3\td3\n'       >> "$T/expected.tsv"
printf 'x4\tc/clean.py\t0\t0\tclean\t-\tnone\n'    >> "$T/expected.tsv"
cat > "$T/findings.tsv" <<'EOF'
# one finding per line
a/f.py	11
/abs/proj/a/f.py	10
a/g.py	40	y
c/clean.py	3
a/h.py	20	n
ba/f.py	11
C:\proj\a\h.py	1
EOF
bash "$SCORE" --expected "$T/expected.tsv" --findings "$T/findings.tsv" --label t1 --tokens 5 --seconds 6 > "$T/out.txt"
has "$T/out.txt" "expected 3 | hit 2 | recall 67%" score-recall
has "$T/out.txt" "findings 7 | hits 2 | duplicates 1 | valid but unlisted 1 | not an issue 1 | unreviewed 2" score-counts
has "$T/out.txt" "precision strict 29% | with reviewed findings 43% | findings on clean files 1" score-precision
has "$T/out.txt" "missed: a/g.py:5-5 l2 (d2)" score-missed
has "$T/out.txt" "RESULT	t1	3	2	67%	7	2	1	1	29%	43%	1	-	5	6" score-result

printf 'a/f.py\t11\n' > "$T/one.tsv"
bash "$SCORE" --expected "$T/expected.tsv" --findings "$T/one.tsv" --tolerance 0 > "$T/tol.txt"
has "$T/tol.txt" "hit 1 | recall 33%" score-tolerance-inside
printf 'a/f.py\t14\n' > "$T/two.tsv"
bash "$SCORE" --expected "$T/expected.tsv" --findings "$T/two.tsv" --tolerance 0 > "$T/tol2.txt"
has "$T/tol2.txt" "hit 0 | recall 0%" score-tolerance-outside
bash "$SCORE" --expected "$T/expected.tsv" --findings "$T/two.tsv" --tolerance 0 --file-only > "$T/fo.txt"
has "$T/fo.txt" "hit 1 | recall 33%" score-file-only
: > "$T/empty.tsv"
bash "$SCORE" --expected "$T/expected.tsv" --findings "$T/empty.tsv" > "$T/none.txt"
has "$T/none.txt" "precision strict n/a" score-no-findings

if bash "$SCORE" --expected "$T/missing.tsv" --findings "$T/one.tsv" > /dev/null 2>&1; then
    fail score-missing-expected "a missing --expected file must fail"
fi

if command -v node > /dev/null 2>&1; then
    cat > "$T/audit.json" <<'EOF'
{"findings": [{"severity": "HIGH", "principle_id": "P-1", "title": "t", "file": "C:/proj/a/f.py", "line": 11, "description": "d", "fix": "f"}], "summary": {}}
EOF
    bash "$SCORE" --expected "$T/expected.tsv" --audit-json "$T/audit.json" > "$T/aj.txt"
    has "$T/aj.txt" "findings 1 | hits 1" score-audit-json
    bash "$SCORE" --expected "$T/expected.tsv" --audit-json "$T/audit.json" --save-findings "$T/saved.tsv" > /dev/null
    has "$T/saved.tsv" "C:/proj/a/f.py" score-save-findings
fi

# ── 3. prepare.sh ────────────────────────────────────────────────────────────────────────────
bash "$PREPARE" defects A "$T/pa" > /dev/null
[ "$(git -C "$T/pa" branch --show-current)" = "eval" ] || fail prepare-A "branch is not eval"
[ "$(git -C "$T/pa" rev-list --count HEAD)" = "2" ] || fail prepare-A "expected a base commit and a corpus commit"
[ -f "$T/pa/d01/pagination.py" ] || fail prepare-A "corpus not copied"
[ ! -e "$T/pa/.agents" ] || fail prepare-A "arm A must have no .agents directory"
[ ! -e "$T/pa/expected" ] || fail prepare-A "expected answers leaked into the project"

if bash "$PREPARE" defects A "$T/pa" > /dev/null 2>&1; then fail prepare-nonempty "must refuse a non-empty destination"; fi
if bash "$PREPARE" nosuch A "$T/pz" > /dev/null 2>&1; then fail prepare-badset "must refuse an unknown set"; fi
if bash "$PREPARE" defects Z "$T/pz" > /dev/null 2>&1; then fail prepare-badarm "must refuse an unknown arm"; fi

bash "$PREPARE" violations B "$T/pb" > /dev/null
[ -f "$T/pb/.agents/instructions/review.md" ] || fail prepare-B "review.md missing"
[ -f "$T/pb/REVIEW.md" ] || fail prepare-B "REVIEW.md missing"
[ ! -d "$T/pb/.agents/skills" ] || fail prepare-B "arm B must not have skills"
has "$T/pb/.agents/instructions/review.md" "CODE-SEC-VALIDATE-INPUT" prepare-B-principles

bash "$PREPARE" violations C "$T/pc" > /dev/null
[ -f "$T/pc/.agents/skills/dot-audit/SKILL.md" ] || fail prepare-C "dot-audit skill missing"
[ -f "$T/pc/.agents/instructions/review.md" ] || fail prepare-C "review.md missing"

# ── 4. run.sh with a stub claude ─────────────────────────────────────────────────────────────
if command -v node > /dev/null 2>&1; then
    cat > "$T/claude-stub" <<'EOF'
#!/usr/bin/env bash
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git diff main...eval"}}]}}'
echo '{"type":"result","result":"FINDING|d01/pagination.py|12|a\nFINDING|d02/tags.py|4|b","usage":{"input_tokens":10,"output_tokens":5},"duration_ms":4000,"total_cost_usd":0.01,"num_turns":2,"is_error":false}'
EOF
    chmod +x "$T/claude-stub"
    CLAUDE_BIN="$T/claude-stub" bash "$REPO_ROOT/evals/run.sh" defects A 1 "$T/out" > "$T/run.txt" 2>&1 || fail run-exit "run.sh failed: $(tail -3 "$T/run.txt")"
    has "$T/out/A-defects-1/score.txt" "expected 8 | hit 2 | recall 25%" run-score
    has "$T/out/A-defects-1/score.txt" "RESULT	A-defects-1	8	2	25%	2	2	0	0	100%	100%	0	17.24	15	4" run-result
    has "$T/out/A-defects-1/tools.txt" "git diff main...eval" run-tools
    if CLAUDE_BIN="$T/claude-stub" bash "$REPO_ROOT/evals/run.sh" defects A 1 "$T/out" > /dev/null 2>&1; then
        fail run-existing "run.sh must refuse an existing run directory"
    fi
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "All evals checks passed."
