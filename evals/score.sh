#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# score.sh - Score one review run against the expected findings of a corpus set.
#
# Usage: score.sh --expected FILE (--findings FILE | --audit-json FILE) [options]
#
#   --expected FILE     evals/expected/<set>.tsv
#   --findings FILE     Findings of the run, one per line: file<TAB>line[<TAB>valid[<TAB>text]]
#                       valid is y (a real issue the table does not list), n (not an issue) or
#                       empty (not reviewed yet). Blank lines and lines starting with # are ignored.
#   --audit-json FILE   An audit-output.json written by dot-audit (needs node)
#   --save-findings FILE  With --audit-json: also write the findings as TSV, to mark valid and n
#   --corpus DIR        Corpus set directory; adds findings per 1,000 lines
#   --tolerance N       Lines a finding may be away from the expected range (default 3)
#   --file-only         A finding on an expected file is a hit, whatever its line. Use it when the
#                       agent counts lines unreliably; every case is one small file with one issue
#   --label TEXT        Name of the run, repeated in the RESULT line
#   --tokens N          Token count of the run, repeated in the RESULT line
#   --seconds N         Duration of the run, repeated in the RESULT line
#
# A finding counts as a hit when its file ends with the expected file and its line is inside the
# expected range plus the tolerance. Only the first finding on an expected item counts; the others
# are duplicates. Findings on clean files and findings outside every range are false positives
# unless marked valid. The last output line is RESULT<TAB>... for aggregating runs.
set -euo pipefail

EXPECTED=""; FINDINGS=""; AUDIT_JSON=""; SAVE=""; CORPUS=""; FILEONLY=0; TOL=3; LABEL="-"; TOKENS="-"; SECONDS_ARG="-"
while [ $# -gt 0 ]; do
    case "$1" in
        --expected)   EXPECTED="$2"; shift 2 ;;
        --findings)   FINDINGS="$2"; shift 2 ;;
        --audit-json) AUDIT_JSON="$2"; shift 2 ;;
        --save-findings) SAVE="$2"; shift 2 ;;
        --corpus)     CORPUS="$2"; shift 2 ;;
        --tolerance)  TOL="$2"; shift 2 ;;
        --file-only)  FILEONLY=1; shift ;;
        --label)      LABEL="$2"; shift 2 ;;
        --tokens)     TOKENS="$2"; shift 2 ;;
        --seconds)    SECONDS_ARG="$2"; shift 2 ;;
        -h|--help)    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "score.sh: unknown argument $1" >&2; exit 2 ;;
    esac
done

[ -f "$EXPECTED" ] || { echo "score.sh: --expected FILE is required and must exist" >&2; exit 2; }
if [ -n "$AUDIT_JSON" ]; then
    [ -f "$AUDIT_JSON" ] || { echo "score.sh: no such file: $AUDIT_JSON" >&2; exit 2; }
    command -v node >/dev/null 2>&1 || { echo "score.sh: --audit-json needs node; write a --findings TSV instead" >&2; exit 2; }
    FINDINGS="$(mktemp)"; trap 'rm -f "$FINDINGS"' EXIT
    node -e 'const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        for (const f of j.findings || [])
            console.log([f.file, f.line, "", ((f.principle_id || "") + " " + (f.title || "")).trim()].join("\t"));' \
        "$AUDIT_JSON" > "$FINDINGS"
    if [ -n "$SAVE" ]; then cp "$FINDINGS" "$SAVE"; fi
fi
[ -f "$FINDINGS" ] || { echo "score.sh: --findings FILE or --audit-json FILE is required" >&2; exit 2; }

KLOC="-"
if [ -n "$CORPUS" ]; then
    [ -d "$CORPUS" ] || { echo "score.sh: no such directory: $CORPUS" >&2; exit 2; }
    lines=0
    while IFS=$'\t' read -r _ file _; do
        [ "$file" = "file" ] && continue
        [ -f "$CORPUS/$file" ] && lines=$((lines + $(wc -l < "$CORPUS/$file")))
    done < "$EXPECTED"
    KLOC="$lines"
fi

awk -F'\t' -v fileonly="$FILEONLY" -v tol="$TOL" -v label="$LABEL" -v tokens="$TOKENS" -v secs="$SECONDS_ARG" -v loc="$KLOC" '
function norm(p) { gsub(/\\/, "/", p); sub(/^\.\//, "", p); return p }
function pct(a, b) { return b > 0 ? sprintf("%.0f%%", 100 * a / b) : "n/a" }
function ratio(a, b) { return b > 0 ? sprintf("%.2f", a / b) : "n/a" }
FNR == 1 { fileno++ }
fileno == 1 {
    if (FNR == 1) next
    n++; efile[n] = $2; es[n] = $3 + 0; ee[n] = $4 + 0; ekind[n] = $5; elabel[n] = $6; edesc[n] = $7
    if ($5 != "clean") expected++
    next
}
/^#/ || /^[ \t]*$/ { next }
{
    total++
    f = norm($1); ln = $2 + 0; valid = tolower($3)
    matched = 0; onclean = 0
    for (i = 1; i <= n; i++) {
        suffix = efile[i]
        if (f != suffix && substr(f, length(f) - length(suffix)) != "/" suffix) continue
        if (ekind[i] == "clean") { onclean = 1; continue }
        if (fileonly || (ln >= es[i] - tol && ln <= ee[i] + tol)) {
            if (hit[i]) { dup++ } else { hit[i] = 1; hits++; tp++ }
            matched = 1; break
        }
    }
    if (matched) next
    if (valid == "y") validx++
    else if (valid == "n") rejected++
    else unreviewed++
    if (onclean && valid != "y") fpclean++
}
END {
    printf "run: %s\n", label
    printf "expected %d | hit %d | recall %s\n", expected, hits, pct(hits, expected)
    printf "findings %d | hits %d | duplicates %d | valid but unlisted %d | not an issue %d | unreviewed %d\n", total, tp, dup, validx, rejected, unreviewed
    printf "precision strict %s | with reviewed findings %s | findings on clean files %d\n", pct(tp, total), pct(tp + validx, total), fpclean
    if (loc != "-") printf "findings per 1,000 lines %s\n", ratio(total * 1000, loc)
    for (i = 1; i <= n; i++) if (ekind[i] != "clean" && !hit[i]) printf "missed: %s:%d-%d %s (%s)\n", efile[i], es[i], ee[i], elabel[i], edesc[i]
    printf "RESULT\t%s\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%d\t%s\t%s\t%s\n", label, expected, hits, pct(hits, expected), total, tp, dup, validx, pct(tp, total), pct(tp + validx, total), fpclean, (loc != "-" ? ratio(total * 1000, loc) : "-"), tokens, secs
}
' "$EXPECTED" "$FINDINGS"
