# evals - Index

| Path | Description |
|---|---|
| [README.md](README.md) | How to run and score a review evaluation, and how to read the result |
| [prepare.sh](prepare.sh) | Builds a fresh project for one run (arm A, B or C) outside this repository |
| [run.sh](run.sh) | Runs one review headlessly with `claude -p`, extracts the findings and scores them |
| [extract-run.js](extract-run.js) | Reads the stream from `claude -p`: final answer, tool calls, tokens, seconds, cost |
| [score.sh](score.sh) | Scores one run: recall, precision, duplicates, findings on clean files |
| `corpus/defects/` | Files with seeded bugs, plus clean files |
| `corpus/violations/` | Files with one seeded principle violation each, plus clean files |
| `expected/` | The answer tables, kept out of the project the agent reviews |
