# evals

Measures whether a review that uses `.principles` finds more real problems than the agent's own review, and at what cost. The kit is small and the corpus is synthetic, so it shows a difference in kind and size, not a general ranking.

## Arms

| Arm | What the agent gets | How to start the review |
|-----|---------------------|-------------------------|
| A | Nothing but the code | The agent's own review of branch `eval` against `main` |
| B | `.agents/instructions/review.md`, `AGENTS.md` block and `REVIEW.md` | The same review as A |
| C | B plus the `dot-audit` and `dot-scout` skills | `dot-audit` on the project root |

## Corpus

Each set holds one Python file per case plus two files without a seeded problem. Files carry no hints; the answers are in `expected/`, outside the project the agent sees.

| Set | Seeded problems | Source of the answers |
|-----|-----------------|-----------------------|
| `defects` | Real bugs: off-by-one, mutable default, SQL injection, resource leak, identity comparison, division by zero, time zone, path traversal | `expected/defects.tsv`, defined by what breaks, not by a principle |
| `violations` | One principle violation per case: fail fast, broad `except`, secret in code, unvalidated input, naming, duplication, long function, shared mutable state | `expected/violations.tsv`, labelled with the principle ID |

The kit uses synthetic cases because most past fixes in this repository change prose or installer behaviour, not code a reviewer can find in one file.

## Run an evaluation

1. Build a fresh project for the run. Use a new directory every time:

   ```bash
   bash evals/prepare.sh defects A /tmp/run-A1
   ```

2. Open the agent in that directory in a new session, with the same model for every run. Start the review as shown in the arm table. Do not say what is seeded.
3. Save the findings and note the tokens and seconds. For arms A and B write a TSV with one finding per line (`file`, `line`, optional `y` or `n`, optional text), separated by tabs. For arm C use the `audit-output.json` that `dot-audit` wrote in the project root.
4. Score the run:

   ```bash
   bash evals/score.sh --expected evals/expected/defects.tsv --findings run-A1.tsv \
       --corpus evals/corpus/defects --label A-defects-1 --tokens 41000 --seconds 95
   bash evals/score.sh --expected evals/expected/defects.tsv --audit-json audit-output.json \
       --save-findings run-C1.tsv --corpus evals/corpus/defects --label C-defects-1
   ```

   Agents count lines unreliably, so also score with `--file-only` and report both: each case is one small file with one issue.
5. Open the findings TSV and mark each finding that is not a hit with `y` (a real issue the table does not list) or `n`. Score again to get precision over reviewed findings.
6. Repeat each arm and set three times and compare. Lines starting with `RESULT` have a fixed column order: label, expected, hit, recall, findings, hits, duplicates, valid but unlisted, strict precision, reviewed precision, findings on clean files, findings per 1,000 lines, tokens, seconds.

### Run it headlessly

`run.sh` does steps 1 to 4 for you with `claude -p`: it builds the project, asks for the review, extracts the findings and scores them at line and file level. It needs the `claude` CLI and `node`, and every run draws on your own Claude allowance (roughly 50,000 to 340,000 tokens per run on this corpus). Start with a few runs and check the cost before launching all 18.

```bash
bash evals/run.sh defects A 1 /tmp/evals --model sonnet
```

The run directory keeps the raw stream, `tools.txt` (what the agent read, for example `review.md`), `meta.txt` (tokens, seconds, cost) and both scores. Claude Code does not load `.agents/skills` as slash commands, so arm C is told to follow `SKILL.md` directly.

To see which part of arm C gives the gain, repeat arm C with the pre-scan skipped, and with `context.sh` not used, by telling the agent so at the start.

## Decide

Decide before the first run and do not change it afterwards:

- Integrate `dot-audit` with the agent's review only if arm C has higher recall than arm A on `defects` or on `violations`, and no more than about twice as many findings that are neither hits nor valid.
- Otherwise keep `dot-audit` for governance (locks, waivers) and the pre-scan, and drop the claim that it improves review quality.

## Limits

- Both sets are easy for a current model: in a first run (three runs per arm and set, Sonnet) every arm found all eight seeded problems at file level. Recall cannot separate the arms until the corpus is harder.
- Python only, one file per case, eight seeded problems per set. A difference of one case is not significant.
- The cases are written by the maintainers of the principles. Recall on `violations` shows that a principle is applied, not that applying it is worth the cost.
- `AGENTS.md` is read by some agents and not by others. Arm B relies on `REVIEW.md` for Claude Code; check what your agent loads before comparing.

`tests/check-evals.sh` verifies the corpus, the scoring and `prepare.sh`.
