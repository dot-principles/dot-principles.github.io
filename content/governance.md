# Governance

An organization usually wants two things at once: every team follows the same standards, and a team can still deal with a legacy corner or a hard deadline. `.principles` supports both with an org baseline, locks and waivers. Everything is plain text in version control, so a change to a standard is a reviewable diff.

## The org baseline

Publish your standards as an [extra catalog](extending.md) with one addition, an `org.principles` file at its root:

```text
acme-principles/
├── principles/acme/          your principles (IDs become ACME-*)
├── groups/acme-backend.yaml  a group that bundles them with built-in ones
└── org.principles            what the organization requires
```

Each project references it from its root `.principles`, pinned to a tag or commit:

```text
:extends https://git.acme.com/acme-principles.git@v1.4.0
@acme-backend
```

When you run `./install.sh vendor <project>`, the baseline is fetched, merged into the project's catalog, and recorded in `.agents/principles-catalog/principles.lock` with the source, the tag and the exact commit. Commit both. Moving to a new baseline version is then a visible change in a pull request, like any dependency update.

A git source must be pinned. An unpinned source, a missing directory or an unknown tag stops the install with an error; nothing is skipped silently.

The baseline is the outermost layer: its principles apply before the project's own `.principles` files, and its namespaces win over a developer's personal catalog.

## Locks

In `org.principles`, `:lock` makes a principle required:

```text
# org.principles
:lock ACME-NO-HARDCODED-SECRETS
:lock @acme-security
```

A locked principle is always active. If a project writes `!ACME-NO-HARDCODED-SECRETS`, the exclusion is ignored and `dot-audit` reports it as a finding, so the attempt is visible. Reviews also list locked principles in the Critical section.

`:lock` is only honoured in `org.principles`. In a project's own `.principles` file it is ignored with a warning.

## Waivers

Sometimes a rule cannot be met yet. A team records that, with a reason and an end date:

```text
# services/legacy-billing/.principles
:waive ACME-API-VERSIONING until 2026-12-31 "legacy API, replaced in Q4, see ADR-12"
```

Until the date, the principle is not reviewed in that subtree. The day after, it applies again and the review says the waiver expired. The reason is required; a waiver without one, or with a malformed date, is ignored, so the principle stays on.

A waiver works even for a locked principle. That is the point: the only way past a lock is a dated, documented exception, and every review report lists it.

| You want to | Use |
|---|---|
| Drop a principle in one subtree | `!ID` (not possible for locked principles). A deeper directory can add it back with a group or an ID |
| Make a principle required everywhere | `:lock ID` in `org.principles` |
| Pause a principle for a while, with a reason | `:waive ID until YYYY-MM-DD "reason"` |

## See what applies

```text
/dot-scout --explain src/payments
```

prints the active principles for a path and which file added, excluded, locked or waived each one.

## Reviews in any agent

`dot-scout` writes `.agents/instructions/review.md` and a short block in `AGENTS.md` that points to it. Claude Code, Codex CLI, Copilot CLI and other agents that read `AGENTS.md` follow it when asked to review a change, including locked principles and waivers. It carries a hash of the resolved principles: an agent runs `emit.sh --check` first and refreshes the file if a `.principles` file or the catalog changed.

For CI, keep `.agents/` and the generated files committed, and run `bash .agents/principles-catalog/bin/emit.sh --check` in a job. A non-zero exit means the generated files no longer match the `.principles` files.

## Reference

- [`.principles` syntax and directives](https://github.com/dot-principles/dot-principles.github.io/blob/main/DESIGN.md#8-principles-file-format)
- [Org baseline in the design reference](https://github.com/dot-principles/dot-principles.github.io/blob/main/DESIGN.md#org-baseline-extends)
