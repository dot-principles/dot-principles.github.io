# tests - Index

| File | Description |
|---|---|
| [check-audit-gates.sh](check-audit-gates.sh) | Audit gate regression test (bash) |
| [check-audit-gates.ps1](check-audit-gates.ps1) | Audit gate regression test (PowerShell) |
| [check-retired-prime.sh](check-retired-prime.sh) | Retired command upgrade migration test |
| [check-extra-index.sh](check-extra-index.sh) | `index.tsv` lists only vendored extra-catalog principles |
| [check-uninstall-generated.sh](check-uninstall-generated.sh) | Uninstall removes scout-generated review files, keeps user files |
| [check-stale-docs.sh](check-stale-docs.sh) | Docs do not describe removed or retired behaviour |
| [check-resolve.sh](check-resolve.sh) | `lib/resolve.sh`: hierarchy, groups, org lock, waivers, cap, seed, `--spec` |
| [check-emit.sh](check-emit.sh) | `lib/emit.sh`: generated review files, 4,000-character split, cleanup, staleness check |
| [check-extends.sh](check-extends.sh) | `:extends` org baseline: local and pinned git sources, `principles.lock`, errors |
| [check-vendor-refresh.sh](check-vendor-refresh.sh) | `vendor` keeps scouted projects' generated files current |
| [check-uninstall-purge.sh](check-uninstall-purge.sh) | `uninstall.sh --purge`: removes `.principles` files and leftovers, keeps what is not yours, `--dry-run` |
| [check-evals.sh](check-evals.sh) | `evals/`: corpus matches the answer tables, `score.sh` arithmetic, `prepare.sh` arms, `run.sh` with a stub `claude` |
| [check-prescan.sh](check-prescan.sh) | `lib/prescan.sh`: hits, INSPECTED/SEMANTIC records, build output and git-ignored files dropped |
