# AI Agent Instructions

This is the **dot-principles** repository - a curated catalog of software engineering
principles and the tooling (`dot-scout`, `dot-audit`) that makes them
accessible to AI coding agents across all artifact types.

> **Taste your own medicine.** This repo enforces its own principles on itself.
> `.principles` files are active, Copilot review instructions are generated, and every
> AI-assisted change must pass the checks below before merging.

---

## Setup

If dot-principles tooling is not installed globally, vendor the catalog locally first:

```bash
./install.sh vendor .
```

This creates `.agents/principles-catalog/` at the repo root, which the commands below require.

---

## Documentation - keep these files current

Every change must update the relevant documentation files:

| File | When to update |
|------|----------------|
| **`README.md`** | Any user-facing change: new commands, changed install steps, new groups, changed `.principles` format |
| **`CHANGELOG.md`** | Every change - follow the existing `## [version] - YYYY-MM-DD` format; add entries under the appropriate release heading |
| **`DESIGN.md`** | Any structural or architectural change: new command phases, changes to the `.principles` hierarchy rules, principle schema changes, new artifact types |
| **`demo/presentation.md`** | Any change that affects the end-to-end user experience: new commands, changed workflow steps, new output format, updated install flow |

---

## Before any release

Complete every step below; a pushed tag is not a published GitHub Release.

1. Run `dot-scout` to re-analyse this repo and refresh the generated principle files:

   ```
   /dot-scout       # Claude / Copilot
   $dot-scout       # Codex
   ```

2. Confirm generated files are up to date and commit them:
   - `.github/instructions/*.instructions.md`
   - `REVIEW.md` (if Claude is active)
   - `.principles` files at any updated paths

3. Prepare the main-repository release:
   - Bump `VERSION`.
   - Move the completed `Unreleased` entries into `## [vVERSION] - YYYY-MM-DD` in
     `CHANGELOG.md` and update its comparison links.
   - Update the README's latest-release reference and all generated version markers.
   - Run the required checks, commit the release changes, and create the annotated
     `vVERSION` tag.

4. Push the main repository commit and tag:

   ```bash
   VERSION="$(tr -d '[:space:]' < VERSION)"
   TAG="v$VERSION"
   git push origin main "$TAG"
   ```

5. Publish the GitHub Release object for the tag. A tag alone does not update the
   repository's latest-release badge:

   ```bash
   VERSION="$(tr -d '[:space:]' < VERSION)"
   TAG="v$VERSION"
   gh release create "$TAG" \
     --repo dot-principles/dot-principles.github.io \
     --title "$TAG" \
     --generate-notes
   test "$(gh api repos/dot-principles/dot-principles.github.io/releases/latest --jq '.tag_name')" = "$TAG"
   ```

   If `gh` is unavailable or either command fails, stop and report the release as
   incomplete; do not claim that pushing the tag completed it.

6. Update the [dot-principles organization profile](https://github.com/dot-principles):
   - In the `dot-principles/.github` repository (the sibling checkout is
     `../dot-principles-github` when working from this repository), run `dot-scout`.
   - Update `profile/README.md` with the new release version, status, workflow, and
     any other public-facing changes; remove references to retired commands.
   - Commit and push the organization-profile update to its `main` branch.

7. Verify the handoff:
   - `gh api repos/dot-principles/dot-principles.github.io/releases/latest --jq '.tag_name'`
     returns `vVERSION`.
   - The organization profile source at
     `https://raw.githubusercontent.com/dot-principles/.github/main/profile/README.md`
     contains `vVERSION` and no retired-command references.

---

## Before merging changes to `principles/` or `commands/`

Run `dot-audit` on the affected paths:

```
/dot-audit principles/<changed-dir>    # Claude / Copilot
/dot-audit commands/

$dot-audit principles/<changed-dir>    # Codex
$dot-audit commands/
```

All findings must be resolved or explicitly accepted (with rationale) before merging.

---

## Tests

Run the regression tests before pushing:

```bash
./tests/check-audit-gates.sh
bash tests/check-retired-prime.sh
bash tests/check-extra-index.sh
bash tests/check-uninstall-generated.sh
bash tests/check-stale-docs.sh
bash tests/check-resolve.sh
bash tests/check-emit.sh
bash tests/check-extends.sh
bash tests/check-vendor-refresh.sh
bash tests/check-uninstall-purge.sh
bash tests/check-prescan.sh
```

All checks must pass (exit 0). These tests verify that the interactive audit workflow
gates (Phases 8-10 of `dot-audit`) remain intact, retired command assets are removed on
upgrade, `index.tsv` lists only vendored extra-catalog principles, uninstall removes
scout-generated review files, the docs do not describe removed behaviour, principle
resolution (hierarchy, org lock, waivers) and the generated review files are correct and
deterministic, `:extends` vendors an org baseline, and `vendor` keeps scouted projects' files current.

---

## Active principles

This repo has `.principles` files that define which principles govern AI-assisted work
here. The generated Copilot review instruction files live in `.github/instructions/`.

The active set covers: documentation quality (`@docs`), shell script hygiene (`@source-code`), and plain-text practices (`@ptac`).

<!-- .principles:start -->
## Code review

<!-- generated by dot-scout - do not edit; re-run dot-scout to refresh -->
When asked to review code or changes, follow `.agents/instructions/review.md`. It is generated
from this repository's `.principles` files. Run `bash .agents/principles-catalog/bin/emit.sh --check`
first; if it reports stale files, run `/dot-scout`.
<!-- .principles:end -->
