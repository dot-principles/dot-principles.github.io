# .principles - System Design

This document describes the full architecture of the `.principles` hierarchy system for contributors and adopters.

---

## 1. Overview

**What it is:** A portable, project-local configuration system that tells AI agents which engineering principles apply to your project - whether the file being worked on is source code, documentation, infrastructure, configuration, a schema, or a pipeline. Similar in spirit to `.gitignore`, but for engineering guidance.

**Philosophy:** `.principles` does not teach the AI anything - the AI already knows SOLID, OWASP, DDD, and the rest. It *focuses and triggers* that knowledge: giving the AI context about which principles matter for this codebase, delivered through generated review files: `.github/instructions/` (Copilot Code Review), `REVIEW.md` (Claude Code Review) and an agent-neutral `.agents/instructions/review.md` that a short block in `AGENTS.md` points to (Claude Code, Codex CLI, Copilot CLI and other agents that read `AGENTS.md`). The AI instructions tell the agent how to behave; `.principles` tells it which engineering lens to apply.

> See [DISCLAIMER.md](DISCLAIMER.md) - this is a proof of concept. Groups are opinionated, gaps exist, and the catalog is not exhaustive.

**Who it is for:**
- **Developers** who want consistent, principle-driven code review and generation across all their projects
- **Teams** who want shared principle sets tailored to their stack (e.g., Spring Boot, React, microservices)
- **Organizations** who want to add company-specific principles alongside the shipped catalog

**How it works:**
1. A catalog of principles lives in `principles/` (shipped with this repo), organized by namespace
2. Companies add their own catalogs in `principles/<namespace>/`
3. Projects place `.principles` files in their directories to declare which principles apply
4. The AI resolves a hierarchy of `.principles` files (innermost overrides outermost) and reads the full principle content before coding or reviewing
5. The artifact type of the file being reviewed is detected (code, docs, config, infra, schema, pipeline) and the matching principle stack from `layers/<type>/` is loaded

**"X as Code":** `.principles` is built for the "X as Code" world - *docs as code*, *infrastructure as code*, *configuration as code*, *pipeline as code*, *schema as code*. All of these are plain text in version control, and all of them benefit from principled review. The system ships with dedicated artifact stacks for each type (see Section 5).

**Plain-Text-as-Code:** This repo is itself a **[Plain-Text-as-Code](https://github.com/Plain-Text-as-Code)** system. Every artefact is plain text in version control - diffable, composable, portable, and natively readable by both humans and AI tools. Principle files are Markdown, group files are YAML, and the catalog is YAML. No binary formats, no generated code, no lock-in.

### Public documentation layer

The repository contains an in-repo public documentation site built with VitePress: `content/` holds the visitor-facing pages, `.vitepress/` the configuration. `README.md`, `INSTALL.md`, `DESIGN.md`, and `demo/presentation.md` stay canonical; the site links to them rather than copying them. Ownership rules and the rationale are in [docs/README.md](docs/README.md) and [ADR-0001](docs/decisions/0001-public-docs-site.md).

---

## 2. Catalog structure

The `principles/` directory is a **namespace container**. Each subdirectory is a namespace with its own catalog.

```
principles/
  code/                  ← general catalog
    catalog.yaml         ← description only
    api/
      standard-http-methods.md
    ar/
    cc/
    cs/
      dry.md
    dx/
    ob/
    pf/
    rl/
    sec/
      validate-input.md
    tp/
    ts/
    ...
  solid/                 ← SOLID principles (5 principles)
    catalog.yaml         ← description only
    srp.md               → SOLID-SRP
    ocp.md               → SOLID-OCP
    lsp.md               → SOLID-LSP
    isp.md               → SOLID-ISP
    dip.md               → SOLID-DIP
  gof/                   ← Gang of Four (27 entries)
    catalog.yaml         ← description only
    strategy.md          → GOF-STRATEGY
    observer.md          → GOF-OBSERVER
    ...
  ddd/                   ← Domain-Driven Design
    catalog.yaml         ← description only
    aggregate.md         → DDD-AGGREGATE
    repository.md        → DDD-REPOSITORY
    ...
  simple-design/         ← Kent Beck's 4 Rules (4 principles)
    catalog.yaml         ← description only
    passes-tests.md      → SIMPLE-DESIGN-PASSES-TESTS
    ...
  clean-arch/            ← Clean Architecture (4 principles)
    catalog.yaml         ← description only
    dependency-rule.md   → CLEAN-ARCH-DEPENDENCY-RULE
    ...
  effective-java/        ← Effective Java
    catalog.yaml         ← description only
    static-factory.md    → EFFECTIVE-JAVA-STATIC-FACTORY
    ...
  code-smells/           ← Fowler code smells
    catalog.yaml         ← description only
    long-method.md       → CODE-SMELLS-LONG-METHOD
    feature-envy.md      → CODE-SMELLS-FEATURE-ENVY
    ...
  grasp/                 ← GRASP patterns (9 principles)
    catalog.yaml         ← description only
    information-expert.md → GRASP-INFORMATION-EXPERT
    low-coupling.md       → GRASP-LOW-COUPLING
    ...
  12factor/              ← Twelve-Factor App
    catalog.yaml         ← description only
    01-codebase.md       → 12FACTOR-01-CODEBASE
    02-dependencies.md   → 12FACTOR-02-DEPENDENCIES
    ...
  owasp/                 ← OWASP Top 10
    catalog.yaml         ← description only
    01-broken-access-control.md  → OWASP-01-BROKEN-ACCESS-CONTROL
    02-cryptographic-failures.md → OWASP-02-CRYPTOGRAPHIC-FAILURES
    ...
  corp/                  ← example: company-added namespace
    catalog.yaml         ← description only
    corp-0001.md
  arch/                  ← example: architecture principles
    catalog.yaml         ← description only
    xx/
      yy/
        yy-01.md
```

### Pre-compiled context files

Each namespace contains two files that hold its audit guidance and inspection patterns:

| File | Used by | Contains |
|------|---------|----------|
| `.context-audit.md` | `bin/context.sh` (`dot-audit` Phase 4) | Principle statement, Violations to detect - one `### ID` entry per principle in the namespace |
| `.context-inspect.md` | `bin/prescan.sh` (`dot-audit` Phase 5) | Machine-executable pre-scan patterns (grep/awk/find commands) - for principles with deterministic inspection patterns |

`context.sh` prints only the entries for the IDs it is given, so a review loads the active principles' guidance and not whole namespace files. `prescan.sh` runs every pattern of the active principles in one call.

**`code/` sub-namespace split:** Because the `code/` namespace is large and divided into sub-namespaces, its context files are split per sub-namespace rather than held in a single file. Each of `code/api/`, `code/ar/`, `code/cc/`, `code/cs/`, `code/dx/`, `code/ob/`, `code/pf/`, `code/rl/`, `code/sec/`, `code/tp/`, and `code/ts/` has its own `.context-audit.md` and (where applicable) `.context-inspect.md`. The root `code/.context-*.md` files contain only a pointer comment. The scripts find an ID's entry by scanning the context files, so no ID-to-directory table is needed.

### `.agents/principles-catalog/` - vendored project subset

When `install.sh vendor <dir>` (or the interactive installer) is run, it writes `<dir>/.agents/principles-catalog/`:

| Path | Contents |
|------|----------|
| `groups/`, `layers/`, `principles/<ns>/.context-*.md` | The groups, layer stacks and per-namespace context files the commands read. Individual principle files are not copied. |
| `index.tsv` | One line per principle in `ID\|LAYER\|SUMMARY` format, built from each principle file's header |
| `bin/` | The scripts the commands run: `resolve.sh`, `emit.sh`, `context.sh`, `prescan.sh` and `principles-common.sh` (see [§9](#scripts)) |
| `VERSION` | The tooling version, used in the `generated by dot-scout` markers |
| `install.cfg` | Installed targets (`copilot-review`, `claude-review`, `scout`, ...) and the stacks `dot-scout` detected (`stack-docs`, ...) |
| `org.principles`, `principles.lock` | Only with `:extends`: the org baseline and where it came from (see below) |
| `active.md` | Written by `dot-scout`/`emit.sh`: every active principle with its summary |

**Commit `.agents/principles-catalog/` to your repo.** The installed commands read it as their data source. With it committed, every team member and CI environment gets the correct principle data and scripts without needing access to the `.principles` repo.

The `{{PRINCIPLES_DIRECTORY}}` placeholder in command source files resolves to `.agents/principles-catalog` at install time.

On a project that was scouted before, `install.sh vendor` finishes by running `emit.sh`, because vendoring replaces the catalog directory (including `active.md`). The generated review files then match the new catalog and tooling version.

### Extra Catalog Sources

Corporations and individual users can plug in their own principle namespaces **without forking this repo**. An extra catalog is a directory with the same structure as `principles/` in this repo:

```
my-principles/
  principles/
    acme/           ← unique namespace (IDs become ACME-*)
      catalog.yaml
      .context-audit.md
      acme-0001.md
  groups/
    acme-backend.yaml
  org.principles    ← optional: org baseline (see "Org baseline" below)
```

Sources of extra catalogs are collected automatically during `install.sh vendor`:

| Order | Source | How |
|-------|--------|-----|
| 1 | `:extends` in the project's root `.principles` | Org baseline; a local directory or a pinned git repository |
| 2 | `~/.principles-extra` | User-level; one path per line; applies to all projects |
| 3 | `<project>/.principles-extra` | Project-level; committed to the project repo. Relative paths resolve against the project directory |
| 4 | `--extra-catalog <path>` | CLI flag; repeatable; ad-hoc or CI use |

All sources are merged into `.agents/principles-catalog/` at vendor time. Registration is **first wins, in the order above**: built-in namespaces and groups are registered first and can never be overridden, and if two extra catalogs define the same namespace or group, the earlier source keeps it - so an org baseline wins over a developer's personal catalog. A skipped namespace or group is reported with a warning and is left out of `index.tsv` too.

The `generate_compact_index()` step builds `index.tsv` with one awk pass over the principle `.md` files of the built-in catalog and of every extra catalog namespace that was registered. `TEMPLATE.md` files are never indexed.

See [INSTALL.md §10](INSTALL.md#10-installing-an-extra-catalog) for setup instructions. A complete working example lives in `examples/personal-principles/` (this repository registers it in its own `.principles-extra` for the `@ptac` group). A starter template lives in `templates/extra-catalog/`.

### Org baseline (`:extends`)

An organization can give every repository the same standards, and make some of them non-negotiable, by publishing an extra catalog with an `org.principles` file at its root and referencing it from each project's root `.principles`:

```
:extends https://git.acme.com/acme-principles.git@v1.4.0
@acme-backend
```

- **Source:** a local directory, or a git repository (`https://`, `ssh://`, `file://`, scp-like `git@host:org/repo.git`, or any URL ending in `.git`). A git source **must be pinned** with `@<tag-or-commit>`; an unpinned source, a missing directory or an unknown ref stops `install.sh vendor` with an error. Nothing is skipped silently.
- **What vendoring does:** the source is merged like any extra catalog (first in the order above), its `org.principles` is copied to `.agents/principles-catalog/org.principles`, and `principles.lock` records the source, the ref, the resolved commit and a checksum of `org.principles`. Commit both files; a change to the baseline then shows up as a reviewable diff.
- **In the hierarchy:** `org.principles` is the outermost layer, before the root `.principles`. It can `:lock` principles that no project can drop (see [§8](#8-principles-file-format)).
- **Several `:extends` lines** are allowed; their `org.principles` files are concatenated in order.

### `.context-inspect.md` Format

Pre-compiled inspection patterns for `dot-audit` Phase 5 (Pre-Scan). Each principle's entry contains bash commands that produce `file:line:match` output:

```markdown
# .principles inspect context - <namespace>
# Machine-executable pre-scan patterns per principle

### CODE-SEC-VALIDATE-INPUT

- `grep -rnE 'eval\(|exec\(' --include="*.py" $TARGET` | HIGH | Direct eval/exec calls
- `grep -rnE '\.query\(.*\+' --include="*.py" $TARGET` | HIGH | String concat in queries
```

Format: `` - `command` | SEVERITY_HINT | description ``

- `$TARGET` is replaced with the actual scan path at runtime
- Commands must use only POSIX + bash 4+ tools: `grep`, `find`, `wc`, `awk`, `sort`
- Principles without inspection patterns are absent from this file and are handled by LLM-only reasoning

### `catalog.yaml` Schema

Each namespace root must have a `catalog.yaml` with a single field:

```yaml
# principles/<namespace>/catalog.yaml
description: "Human-readable description of this namespace"
```

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Yes | Human-readable description of the namespace |

The namespace is the directory name. IDs are derived from file paths (see Section 5) - no explicit `namespace` or `id-prefix` fields are needed. The system discovers all `principles/*/catalog.yaml` files automatically.

---

## 3. Generated review files

`dot-scout` ends by running `bin/emit.sh`, which resolves the active principles and writes everything the review tools read. The script is deterministic - the same `.principles` files and catalog always produce byte-identical output - and `install.sh vendor` runs it again after an upgrade.

| Path | Consumer | Written when |
|------|----------|--------------|
| `<catalog>/active.md` | `dot-audit`, humans | always |
| `.agents/instructions/review.md` | Any agent that reads `AGENTS.md` (Claude Code, Codex CLI, Copilot CLI, ...) | always |
| `AGENTS.md` (managed block) | The same agents | always |
| `.github/instructions/<group>.instructions.md` | GitHub Copilot Code Review | `copilot-review` in `install.cfg` (or signal files) |
| `REVIEW.md` | Claude Code Review | `claude-review` in `install.cfg` (or signal files) |

> **Numbering:** `dot-scout` and `dot-audit` number their phases independently. "Phases 8-10" in the tests and in `AGENTS.md` always means `dot-audit`'s gated fix, commit and pull-request workflow.

The active set is the union of the set resolved for every directory that has a `.principles` file (or for the root alone if there are none). It therefore lists what applies anywhere in the repo; per-path precision is available with `resolve.sh --format explain <path>`.

### Agent-neutral review instructions

`.agents/instructions/review.md` holds the review procedure and the active principles grouped as Critical, Important and Style, plus any waivers and locked principles. It carries a `principles-hash` of the resolved result. An agent that is asked to review follows the short block that `emit.sh` keeps in `AGENTS.md`:

```markdown
<!-- .principles:start -->
## Code review

When asked to review code or changes, follow `.agents/instructions/review.md`. ...
<!-- .principles:end -->
```

`review.md` tells the agent to run `bash .agents/principles-catalog/bin/emit.sh --check` first (exit 1 means a `.principles` file or the catalog changed, so the list is stale and `/dot-scout` or `emit.sh` should refresh it), and to run `bin/context.sh <ID>...` for the details of the principles that matter for the change. This is what makes a review work in any agent without a tool-specific command.

If `AGENTS.md` exists, only the block between the markers is created or updated; everything else is left alone. If it does not exist, it is created with the block. `uninstall.sh` removes the block (and the file, if nothing else is left).

### File formats

**Copilot Code Review** (`.github/instructions/<group>.instructions.md`), one file per active `@group`, containing the group's principles (including those of the groups it includes) that are active:

```markdown
<!-- generated by dot-scout vVERSION - do not edit manually, re-run dot-scout to refresh -->
---
applyTo:
  - "**/*.java"
---
# Group Name Principles

- PRINCIPLE-ID: Summary text here
- PRINCIPLE-ID: Summary text here
```

Copilot Code Review truncates a file at 4,000 characters, so a larger group is split at line boundaries into `<group>-1.instructions.md`, `<group>-2.instructions.md`, ..., each with its own header. A `principles-core.instructions.md` file (`applyTo: "**/*"`) holds the universal principles, the Layer 1 principles of the detected stacks, and active principles that belong to no `@group`.

**Claude Code Review** (`REVIEW.md` at the git root, about 10,000 characters maximum):

```markdown
<!-- generated by dot-scout vVERSION - do not edit manually, re-run dot-scout to refresh -->
# Code Review Rules

## Critical - Always flag these
- PRINCIPLE-ID: Summary text here

## Important - Flag when violated
- PRINCIPLE-ID: Summary text here

## Style - Flag as nits
- PRINCIPLE-ID: Summary text here
```

Critical holds security and fail-fast principles and every principle **locked** by the organization; Important holds domain, architecture and concurrency principles; Style holds the rest. If the budget is exceeded, Style is truncated first.

The `<!-- generated by dot-scout` marker identifies files managed by `dot-scout`. Files without this marker are user-created and never touched. On re-run, marked files that no longer apply (a group was removed, a tool was disabled) are deleted.

### Group-to-glob mapping

Each group YAML file has an optional `globs:` field that defines which file types its principles target:

| Category | Groups | Globs |
|----------|--------|-------|
| Language | `java`, `typescript`, `python`, `go`, etc. | Language-specific extensions (`**/*.java`, `**/*.py`, etc.) |
| Framework | `spring-boot`, `react`, `django`, etc. | Inherited from language group via `includes:` |
| Infrastructure | `container` | `Dockerfile`, `docker-compose.yml`, `**/*.yaml`, `**/*.yml` |
| Pipeline | `pipeline`, `cd` | `.github/workflows/**`, `Jenkinsfile`, etc. |
| Docs | `docs`, `docs-as-code` | `**/*.md`, `**/*.adoc`, `**/*.rst` |
| Schema | `schema` | `**/*.proto`, `**/*.graphql`, `**/openapi.yaml`, etc. |
| Cross-cutting | `microservices`, `solid`, `ddd`, etc. | No `globs:` field - defaults to `**/*` |

Groups that `includes:` other groups inherit the included group's `globs:` (union of all).

### Context tiers

| Tier | Source | Loaded by |
|------|--------|-----------|
| 1 - Generated review files | `review.md`, `.github/instructions/`, `REVIEW.md` | Any agent, passively; `dot-audit` reads the active set through `resolve.sh` |
| 2 - Namespace context | `.context-audit.md` per namespace | `bin/context.sh` (`dot-audit` Phase 4) - only the requested entries |
| 3 - Inspection patterns | `.context-inspect.md` per namespace | `bin/prescan.sh` (`dot-audit` Phase 5) |

---

## 4. Artifact types and stacks

The layer model is not a single three-layer stack - it is a family of stacks, one per artifact type. The correct stack is selected by detecting the artifact type of the file being reviewed.

Within each stack:

| Layer | When | What |
|-------|------|------|
| **Universal (cross-stack)** | Always, for all artifact types | DRY, KISS, YAGNI, naming, reveals intention, ADRs |
| **Layer 1 - Universal** | Always, for the matched artifact type | Non-negotiable principles for that type (code: SOLID, fail-fast; docs: `DOC-PURPOSE`, `DOC-MINIMAL`) |
| **Layer 2 - Contextual** | Based on content signals | API design, concurrency, data modeling, tutorial vs. reference docs |
| **Layer 3 - Risk-elevated** | Based on risk signals | Security, performance, backward compatibility (code and infra stacks only) |

### Artifact Types (`layers/artifact-types.yaml`)

`layers/artifact-types.yaml` defines:
- **Universal principles** - active for all artifact types regardless of stack
- **Artifact type definitions** - each with a description, a stack name, and detection signals (file extensions, filenames, path patterns)

Detection precedence resolves ambiguity: more specific matches win. For example, `Chart.yaml` matches the `infra` type (not `config`) because `infra` signals are evaluated before `config` signals for Helm charts.

### Stacks (`layers/<stack>/`)

Each stack lives in its own subdirectory under `layers/` and contains 2-3 files:

| File | Purpose |
|------|---------|
| `layer-1-universal.md` | Always active for this artifact type - a table of principles with ID, title, and one-line summary |
| `layer-2-contexts.yaml` | Context-activated principles, triggered by content signals within the file |
| `layer-3-risk-signals.yaml` | Risk-elevated principles (code and infra stacks only) |

### Shipped Stacks

| Stack | Directory | Layers |
|-------|-----------|--------|
| **code** | `layers/code/` | 3 (universal → contextual → risk) |
| **docs** | `layers/docs/` | 2 (universal → contextual) |
| **config** | `layers/config/` | 2 (universal → contextual) |
| **infra** | `layers/infra/` | 3 (universal → contextual → risk) |
| **schema** | `layers/schema/` | 2 (universal → contextual) |
| **pipeline** | `layers/pipeline/` | 2 (universal → contextual) |

### Universal Principles

These six principles appear in `artifact-types.yaml` and are injected into every activation regardless of stack:

| ID | Why universal |
|----|---------------|
| `SIMPLE-DESIGN-REVEALS-INTENTION` | Clarity of expression applies to code, docs, config, and schema equally |
| `CODE-CS-DRY` | Repetition creates drift in every artifact type |
| `CODE-CS-KISS` | Simplicity is the goal across all artifact types |
| `CODE-CS-YAGNI` | Avoid speculative complexity in all artifacts |
| `CODE-DX-NAMING` | Names reveal intent in code, schema fields, config keys, and pipeline jobs |
| `ARCH-DECISION-RECORDS` | Architectural decisions should be recorded wherever architecture is expressed |

### Layer field on principle files

The `**Layer:**` frontmatter field on principle files refers to the layer within the principle's home stack:
- Layer 1 = always active for that artifact type (universal within stack)
- Layer 2 = context-dependent (activated by content signals)
- Layer 3 = risk-elevated (activated by risk signals)

Principles in the universal set (above) are considered "stack-universal" rather than stack Layer 1 - they activate regardless of which stack is selected.

---

## 5. ID derivation


IDs are **derived from file path** - no separate ID field is needed in the file itself.

### Algorithm

1. Take the path **relative to `principles/`**
2. Split by `/`, drop `.md` extension from the last segment
3. Each **directory** segment → uppercased ID part
4. **Filename** → strip the `<parent-dir-name>-` prefix (case-insensitive), use the remainder as the final ID part
5. Join all parts with `-`

### Examples

| File path (relative to `principles/`) | ID                               |
|---------------------------------------|----------------------------------|
| `solid/srp.md`                        | `SOLID-SRP`                      |
| `gof/strategy.md`                     | `GOF-STRATEGY`                   |
| `ddd/aggregate.md`                    | `DDD-AGGREGATE`                  |
| `code-smells/feature-envy.md`         | `CODE-SMELLS-FEATURE-ENVY`       |
| `grasp/low-coupling.md`               | `GRASP-LOW-COUPLING`             |
| `12factor/01-codebase.md`             | `12FACTOR-01-CODEBASE`           |
| `owasp/01-broken-access-control.md`   | `OWASP-01-BROKEN-ACCESS-CONTROL` |
| `code/api/standard-http-methods.md`   | `CODE-API-STANDARD-HTTP-METHODS` |
| `code/sec/validate-input.md`          | `CODE-SEC-VALIDATE-INPUT`        |
| `corp/corp-0001.md`                   | `CORP-0001`                      |
| `arch/xx/yy/yy-01.md`                 | `ARCH-XX-YY-01`                  |

### Step-by-step: `code/api/standard-http-methods.md`

1. Segments: `code`, `api`, `standard-http-methods`
2. Dir segments uppercased: `CODE`, `API`
3. Filename `standard-http-methods` → does not start with `api-`, use verbatim: `STANDARD-HTTP-METHODS`
4. Join: `CODE-API-STANDARD-HTTP-METHODS`

### Step-by-step: `arch/xx/yy/yy-01.md`

1. Segments: `arch`, `xx`, `yy`, `yy-01`
2. Dir segments: `ARCH`, `XX`, `YY`
3. Filename `yy-01` → strip `yy-` prefix → `01`
4. Join: `ARCH-XX-YY-01`

---

## 6. Principle file schema

Every principle file follows this template:

````markdown
# [ID] - [Title]

**Layer:** [1 | 2 | 3]
**Categories:** [comma-separated]
**Applies-to:** [all | comma-separated - languages, platforms, domains, or contexts]
**Summary:** [One actionable sentence - max ~15 words, written as a rule]

## Principle

[Clear, authoritative statement of the principle in 1-3 sentences.]

## Why it matters

[Explanation of the consequences of ignoring this principle - bugs, maintenance debt, security risks, etc.]

## Violations to detect

- [Specific code pattern that violates this principle]
- [Another violation pattern]

## Inspection

<!-- Optional - see "Inspection" field guidance below. -->

## Good practice

```[language]
// Example showing correct application
```

## Sources

- [Author, *Title*, Publisher, Year. ISBN/DOI/URL]
````

### Fields

| Field                  | Description                                                                |
|------------------------|----------------------------------------------------------------------------|
| `Layer`                | 1 = always active, 2 = context-dependent, 3 = risk-elevated                |
| `Categories`           | Semantic tags for detection (e.g., `api-design`, `security`, `testing`)    |
| `Applies-to`           | `all` or specific languages, platforms, domains, or architectural contexts |
| `Summary`              | One actionable sentence (max ~15 words). Used in the generated review files. Required. |
| `Violations to detect` | Concrete patterns for AI to look for during review                         |
| `Inspection`           | Optional. Machine-executable pre-scan commands for `dot-audit` Phase 5. See guidance below |
| `Good practice`        | Positive example (AI uses this for generation guidance)                    |
| `Sources`              | At least one verifiable published source                                   |

> **Header is parsed.** `install.sh vendor` builds `index.tsv` from the first line (`# ID - Title`, uppercase ID followed by a space), `**Layer:**` and `**Summary:**` (colon inside the bold). A file missing any of the three is silently left out of the index, so `dot-scout` never sees it.

**Diagrams:** Include a `mermaid` code block in the *Good practice* section whenever the concept has a structural form (class hierarchies, relationships, flows). Mermaid adds machine-readable semantics. If you can draw it, draw it.

### `## Inspection` - When to Add

The `## Inspection` section is **optional**. It contains bash commands that `dot-audit` Phase 5 runs to flag likely violations *before* the LLM reads the code. Not every principle is a good fit.

**Add inspection patterns when** the violation has a textual signature that grep/awk/find can match reliably - e.g., `eval(`, empty `catch {}` blocks, files over 300 lines. These are surface-level patterns that narrow the search space for the LLM.

**Do not add inspection patterns when** the violation requires understanding intent, context, or design - e.g., whether a class has too many responsibilities (SRP beyond line count), whether an abstraction is premature (YAGNI), whether naming reveals intent, or whether a system follows Postel's Law. These are **semantic-only** principles that only an LLM can evaluate.

**Rule of thumb:** if you cannot write a grep pattern that produces fewer than ~30% false positives on a typical codebase, leave the section empty. A noisy pre-scan is worse than none.

**Format:** each entry is a fenced command, a severity hint, and a short description:

```
- `grep -rnE 'eval\(' --include="*.py" $TARGET` | HIGH | Direct eval calls
```

- `$TARGET` is replaced with the scan path at runtime
- Commands must use only POSIX + bash 4+ tools: `grep`, `find`, `wc`, `awk`, `sort`
- Output should be `file:line:match` format (`grep -rn` default)
- When adding patterns, also add the entry to the namespace's `.context-inspect.md`

---

## 7. Groups

Groups bundle related principles under a reusable name. They enable one-line activation of a full principle set for a technology.

### Group File Schema (`groups/<name>.yaml`)

```yaml
name: spring-boot
description: "Spring Boot REST APIs and dependency injection"

globs:
  - "**/*.java"

includes:
  - java              # resolved from groups/java.yaml

principles:
  - CODE-API-STANDARD-HTTP-METHODS
  - CODE-API-HATEOAS
  - CODE-SEC-VALIDATE-INPUT
  - ARCH-STATELESS-FIRST
```

| Field         | Description                                                                          |
|---------------|--------------------------------------------------------------------------------------|
| `name`        | Must match filename (without `.yaml`)                                                |
| `description` | Human-readable summary                                                               |
| `globs`       | Optional. File path globs for the generated Copilot files. Defaults to `["**/*"]` if absent.     |
| `includes`    | Other group names to compose (resolved recursively). Globs are unioned from includes |
| `principles`  | List of principle IDs this group activates                                            |

### Composition

`includes` is resolved recursively. `spring-data-jpa` includes `spring-boot`, which includes `java` - the result is the full union of all three groups' principles.

**Cycle detection:** The system detects cycles in `includes` chains and raises an error rather than looping infinitely.

### Shipped Groups

| Group              | Includes         | Purpose                                         |
|--------------------|------------------|-------------------------------------------------|
| `solid`            | -                | All five SOLID principles                       |
| `gof`              | -                | All Gang of Four patterns                       |
| `gof-creational`   | -                | GoF creational patterns                         |
| `gof-structural`   | -                | GoF structural patterns                         |
| `gof-behavioral`   | -                | GoF behavioral patterns                         |
| `ddd`              | -                | Domain-Driven Design building blocks            |
| `simple-design`    | -                | Kent Beck's 4 Rules of Simple Design            |
| `clean-arch`       | -                | Clean Architecture principles                   |
| `effective-java`   | -                | Effective Java best practices                   |
| `code-smells`      | -                | Fowler code smells                              |
| `grasp`            | -                | All nine GRASP responsibility patterns          |
| `12factor`         | -                | All twelve Twelve-Factor App practices          |
| `owasp`            | -                | OWASP Top 10 (2021) security risks              |
| `java`             | effective-java   | Java language fundamentals                      |
| `typescript`       | -                | TypeScript type safety and patterns             |
| `python`           | -                | Python readability and Pythonic patterns        |
| `go`               | -                | Go composition and concurrency                  |
| `csharp`           | solid            | C# OOP and async patterns                       |
| `rust`             | -                | Rust ownership and type safety                  |
| `spring-boot`      | java             | Spring Boot REST and DI                         |
| `spring-data-jpa`  | spring-boot, ddd | JPA repositories and aggregates                 |
| `react`            | typescript       | React components and hooks                      |
| `angular`          | typescript       | Angular components and DI                       |
| `django`           | python           | Django models and views                         |
| `fastapi`          | python           | FastAPI async endpoints                         |
| `microservices`    | -                | Inter-service resilience and observability      |
| `security-focused` | owasp            | Security-heavy codebases                        |

### Rules

- Groups are **additive only** - no exclusions inside groups
- Exclusion is a per-project human decision in `.principles` files
- Groups ship in `groups/` at repo root

---

## 8. `.principles` file format

Plain text. One entry per line. Filesystem mtime is the implicit last-modified timestamp.

### Syntax

```
# This is a comment (ignored)

# Groups - prefixed with @
@spring-boot
@company-arch

# Bare IDs - direct includes
CODE-OB-SERVICE-LEVEL-OBJECTIVES
CORP-0001

# Exclusions - remove a principle that an outer file or a group in this file activated
!CODE-API-HATEOAS
!@docs                       # a whole group
```

| Syntax     | Meaning                                                                         |
|------------|---------------------------------------------------------------------------------|
| `# ...`    | Comment (ignored)                                                               |
| `:directive value` | Configuration directive (see below)                                    |
| `@name`    | Include all principles from `groups/name.yaml` (recursive)                      |
| `ID`       | Include a specific principle by ID                                              |
| `!ID`      | Exclude a principle, including a Layer 1 one. It removes what outer files and groups added; a deeper file can add it back. Principles locked by an org baseline cannot be excluded |
| `!@name`   | Exclude every principle of a group                                              |
| blank line | Ignored                                                                         |

IDs and group names are matched case-insensitively. Windows line endings are accepted.

### Directives

Lines starting with `:` are configuration directives:

| Directive | Where | Description |
|-----------|-------|-------------|
| `:max_principles N` | any | Cap the number of active principles. Layer 2 principles are dropped first (last in order first), then Layer 3. Layer 1 and locked principles are never dropped, so the cap can be exceeded by them. |
| `:extends <source>[@ref]` | root `.principles` | Merge an org baseline when the catalog is vendored (see [§2](#org-baseline-extends)). Ignored by `resolve.sh`. |
| `:lock ID` or `:lock @group` | `org.principles` only | The principle is always active. A `!ID` or `!@group` in a project cannot remove it; the attempt is reported (`LOCK-OVERRIDE`). In a project `.principles` file, `:lock` is ignored with a warning. |
| `:waive ID until YYYY-MM-DD "reason"` | any | A dated, documented exception. The principle is not active until the date (inclusive); on the next day it is active again (`EXPIRED`). The reason is required. A waiver is honoured even for a locked principle - it is the only way out of a lock, and every review report lists it. A malformed waiver is ignored with a warning, so the principle stays active. |

Locks and waivers give governance without making projects unable to deal with reality: an organization decides what is required, a team can still record a time-limited exception, and nothing disappears silently.

### Hierarchy Walk Algorithm

Walk **up** from the file or directory being reviewed to the git repo root (detected by `.git/` presence) or a maximum of 10 levels.

Collect all `.principles` files encountered, ordered **root → target** (outermost first, innermost last). If `.agents/principles-catalog/org.principles` exists it comes first of all.

**Resolution** (implemented by `bin/resolve.sh`):

1. `active = {}`; with `--seed <type>`: the universal principles and the Layer 1 principles of that artifact type
2. For each file (org baseline, then root → target), in this order:
   - `:lock` (org baseline) → add and mark as locked; `:waive` → record; `:max_principles` → remember
   - **Additions:** expand each `@group` recursively and add bare IDs to `active` (insertion order is kept; cycles are cut with a warning). A principle that an outer file excluded and this file adds is *reinstated*.
   - **Exclusions:** `!ID` / `!@group` remove the principle from `active`, except locked principles
3. `final = active MINUS unexpired waivers`
4. Apply `:max_principles` to `final`

**Key properties:**
- Inner `.principles` files extend (not replace) outer ones
- **The deepest file that mentions a principle decides.** An outer `!ID` or `!@group` removes it; a deeper `@group` or ID adds it back (`REINSTATED` in the output). Within one file, exclusions win over additions whatever the line order, so `!@kotlin` and `@java` in the same file remove the shared principles.
- An exclusion of a principle that is not active yet does nothing and does not bind a later addition
- `!ID` suppresses even Layer 1 principles, unless an org baseline locked them
- A `!ID` in an outer file is therefore not a ban for the whole tree: a deeper group that contains the principle adds it back. Use an org baseline `:lock` for requirements that no project can drop
- The algorithm terminates at the git root, not the filesystem root
- **Explicit mode** (`resolve.sh --spec "ddd, solid"`, used by `dot-audit DDD on src/`) replaces the whole hierarchy with the named groups and IDs; an unknown item is an error

`resolve.sh --format explain <path>` prints the result for a path with the file that added, excluded, locked or waived each principle (`dot-scout --explain <path>` runs it).

### Example Hierarchy

```
/repo-root/
  .principles          ← root file: @spring-boot
  src/
    .principles        ← adds CODE-OB-SERVICE-LEVEL-OBJECTIVES, !CODE-API-HATEOAS
    payments/
      .principles      ← adds @security-focused
```

When reviewing `/repo-root/src/payments/PaymentService.java`:
1. Apply the org baseline, if any (its locked principles are now active)
2. Apply `/repo-root/.principles` → expand `@spring-boot` (→ includes `java`)
3. Apply `/repo-root/src/.principles` → add `CODE-OB-SERVICE-LEVEL-OBJECTIVES`, remove `CODE-API-HATEOAS`
4. Apply `/repo-root/src/payments/.principles` → expand `@security-focused` (it would bring `CODE-API-HATEOAS` back if that group contained it)

A monorepo with several languages shows why the order matters. The root has `@kotlin`; `bot-api/.principles` has `!@kotlin`; `bot-api/java/.principles` has `@java`. In `bot-api/java`, the exclusion removed `kotlin` (which includes `java` and `source-code`), and the deeper `@java` adds the Java and shared principles back. Writing `!@kotlin` and `@java` in the *same* file would not work, because the exclusion wins inside its own file.

---

## 9. Commands

The commands separate judgement from mechanics. The agent profiles the project, places `.principles` files and reviews code; everything deterministic (resolving the hierarchy, writing generated files, picking context, running grep patterns) is a script in `.agents/principles-catalog/bin/` that the agent runs once and reads the output of.

### `dot-audit`

Reviews code against activated principles. Outputs findings grouped by severity. Supports explicit principle override via `--with <spec>`, `@<group>`, or `<spec> on <target>` syntax to force a specific principle set regardless of `.principles` files.

`dot-audit` is a chat-based, on-demand command - run it when you want a deep, targeted review with an optional fix and PR workflow. Copilot Code Review and Claude Code Review do not run it; they use the generated review files. Any agent can run the same procedure by following `.agents/instructions/review.md`, which uses the same scripts.

The command is split in two files: `SKILL.md` (Phases 1-7, the review) and `fix-flow.md` (Phases 8-10, the gated workflow), which is installed next to it and read only when there are findings. In `commands/dot/` they are `audit.md` and `.audit-fix-flow.md`.

**Phases:**

| Phase | Name                          | Description                                                                                    |
|-------|-------------------------------|------------------------------------------------------------------------------------------------|
| 1     | Parse Arguments               | Detects explicit spec (`--with`, `@group`, or `on` syntax); resolves target and artifact type; loads git context only when needed |
| 2     | Resolve Principles            | `emit.sh --check` (refresh if stale), then `resolve.sh --seed <type> <dir>` or `resolve.sh --spec "<spec>"`. Reports `WAIVED`, `LOCK-OVERRIDE` and warnings |
| 3     | Dynamic Detection (fallback)  | Only if explicit-mode is false and the project has no `.principles` files                      |
| 4     | Load Principle Content        | One `context.sh <ID>...` call: statement and violations of the active principles only          |
| 5     | Pre-Scan                      | One `prescan.sh` call: every inspection pattern of the active principles; yields hits and which principles are semantic-only |
| 6     | Review                        | Guided review (hits) + semantic review (each file read once) + opportunistic findings          |
| 7     | Output                        | Compact text report + `audit-output.json` written to repo root; reports principle source, locked principles and waivers |
| 8     | Fix *(optional, gated)*       | Asks "Would you like me to fix these findings?"; on approval creates a `fix-<slug>` branch and applies every finding's `fix` field |
| 9     | Commit *(optional, gated)*    | Presents commit message + PR body for review; offers re-run audit (if Medium+ findings), commit-only, commit-and-push, or exit    |
| 10    | Pull Request *(optional, gated)* | Asks "Shall I open a pull request?"; on approval creates a PR targeting the default branch |

**Gated workflow rules (Phases 8-10):** Each phase is a mandatory stop - the default is always to ask, never to proceed. Identifying issues ≠ permission to fix; fixing ≠ permission to commit; committing ≠ permission to push or open a PR. Silence or likely intent never count as approval. The rules are stated in both files and regression-tested (`tests/check-audit-gates.sh`).

**Re-audit loop (Phase 9 → Phase 5):** When the audit found at least one Medium or higher finding, Phase 9 offers a "Re-run audit" option (option 0). Choosing it jumps back to Phase 5 (Pre-Scan) using the same already-resolved target and principles, then re-runs Phases 6 and 7. This backward edge is conditional - it is not offered for low-only audits. The branch from Phase 8 is reused; the pass number increments and is recorded in the eventual commit message.

**Governance in the report:** a `LOCK-OVERRIDE` (a project tried to exclude a principle its organization locked) is reported as a HIGH finding with principle ID `GOVERNANCE-LOCK`; waived principles are not reviewed and are listed with their date and reason; `audit-output.json` carries `locked_principles` and `waived`.

### `dot-scout`

Analyses a project directory, creates or updates `.principles` files, then generates the review files (see [§3](#3-generated-review-files)). `dot-scout --explain <path>` shows the active principles for a path and which file added, excluded, locked or waived each; `--yes` skips the one confirmation question.

**Phases:**

| Phase | Name               | Description                                                                                   |
|-------|--------------------|-----------------------------------------------------------------------------------------------|
| 1     | Resolve Target     | Resolves `$ARGUMENTS` or CWD as the target directory; checks that the vendored catalog and scripts exist (otherwise stops and tells the user to run `install.sh vendor`); loads `.context-scout.md` detection rules from extra catalogs |
| 2     | Detect Profile     | Detects language, framework, domain; analyses per-directory profiles                          |
| 3     | Propose Placements | Proposes `.principles` placements - root + overrides for test dirs, security dirs, submodules; checks exclusion density (demotes entries excluded in >50% of children, consolidates widespread exclusions); never proposes `!ID` for a locked principle; **one** confirmation |
| 4     | Check Existing     | Merges additions only; never removes or touches `!exclusions`                                 |
| 5     | Write Files        | Creates or updates files; reports created/updated/unchanged per path                          |
| 6     | Emit Generated Files | One `emit.sh --stacks <stacks>` call: `active.md`, `review.md`, the `AGENTS.md` block, and the Copilot and Claude files for the enabled tools |

### Scripts

`lib/*.sh` in this repository, vendored into `<project>/.agents/principles-catalog/bin/` so they run inside an adopter's project. They need Bash 4+ and print a clear message otherwise (macOS: `brew install bash`). They use shell builtins on hot paths because starting a process per line is slow on Windows.

| Script | Purpose |
|--------|---------|
| `resolve.sh <path>` | Resolves the active principles for a path (see [§8](#8-principles-file-format)). `--format full\|ids\|explain`, `--seed <type>`, `--spec <list>`. Full format is one pipe-delimited record per line: `FILE`, `GROUP`, `ACTIVE\|ID\|added-by\|flags`, `EXCLUDED`, `LOCK-OVERRIDE`, `WAIVED`, `EXPIRED`, `TRIMMED`, `WARN` |
| `emit.sh` | Writes the generated files from the resolved result. `--check` exits 1 if `review.md` is stale: it hashes the inputs (the `.principles` files, the org baseline, the catalog's groups, layers and index, the stacks, and the date when a `:waive` exists) and never resolves, so it is cheap enough to run before every review. `--dry-run` writes nothing; `--tools`, `--stacks` (remembered in `install.cfg` and in `review.md`'s header), `--no-agents` |
| `context.sh <ID>...` | Prints the `.context-audit.md` entries for the given IDs (`--active` for every active ID) |
| `prescan.sh <target>` | Runs the inspection patterns of the active principles; prints `HIT`, `INSPECTED` and `SEMANTIC` records. Hits in git-ignored files and build or dependency directories are dropped |
| `principles-common.sh` | Shared helpers (sourced, not run) |

The scripts are covered by `tests/check-resolve.sh`, `tests/check-emit.sh` and `tests/check-prescan.sh`; `tests/check-vendor-refresh.sh` covers the vendored copy.

Whether a review that uses these scripts and principles beats the agent's own review is measured by the evaluation kit in `evals/`, not assumed: the same seeded files are reviewed under three arms and scored against answer tables kept outside the reviewed project (`evals/README.md`, `tests/check-evals.sh`).

---

## 10. Installer targets

`install.sh` deploys the two commands (`dot-scout`, `dot-audit`) to supported AI tool families. The installer is **template-driven** - skill content is defined in `templates/agents/` (canonical); tool-specific wrappers in `templates/claude/`.

**Prerequisites:** Bash 4+. See [REQUIREMENTS.md](REQUIREMENTS.md). On Windows, use `install.ps1` (PowerShell) or `install.cmd` (CMD) - thin wrappers that detect bash and forward all arguments to `install.sh`. See [INSTALL.md](INSTALL.md) for platform-specific instructions.

Install is **repo-local only** - a `<dir>` argument is always required. There is no global install.

| Command | What it does |
|---|---|
| `./install.sh <dir>` | Interactive: select tool wrappers + review integration |
| `./install.sh vendor <dir>` | Sync catalog + reinstall previously recorded wrappers |
| `./install.sh --list <dir>` | Show what's installed in `<dir>` |

**Skills are always installed** to `.agents/skills/` regardless of which wrappers are selected. Tool-specific wrappers are optional.

### Always installed

Every install (interactive or `vendor`) always writes:

1. **AI skills** (`<dir>/.agents/skills/<slug>/SKILL.md`, plus `fix-flow.md` for `dot-audit`) - canonical skill files containing the full prompt. Discovered natively by Copilot CLI, Copilot IDE, Codex, and any tool that reads `.agents/skills/`.
2. **Vendor catalog** (`<dir>/.agents/principles-catalog/`) - groups, layers, per-namespace context files, `index.tsv` (flat `ID|LAYER|SUMMARY` index), the `bin/` scripts and `VERSION` (see [§2](#agentsprinciples-catalog---vendored-project-subset)).

### Claude Code wrappers (optional)

Selected via interactive installer. Writes thin wrapper files to `<dir>/.claude/commands/`:

```markdown
---
<frontmatter from source>
generated-by: .principles
---

Follow the instructions in `.agents/skills/<slug>/SKILL.md`.
```

Claude Code discovers slash commands by scanning `.claude/commands/` for `.md` files. The wrapper delegates to the canonical skill so Claude reads the full content from `.agents/skills/`.

**Review file:** `emit.sh` (run by `dot-scout`) writes `REVIEW.md` at the git root for Claude Code Review. It is generated, not installed by `install.sh`; enable it with the `claude-review` target in the interactive installer. Claude Code also follows the `AGENTS.md` block and `.agents/instructions/review.md` that every scouted project gets.

### GitHub Copilot (native, no wrapper needed)

Both Copilot CLI and Copilot IDE discover `.agents/skills/` natively:
- **Copilot CLI** - discovers skills by scanning `.agents/skills/` for `SKILL.md` files; exposes them as `@<slug>` in the terminal
- **Copilot IDE** (VS Code / JetBrains / Visual Studio) - discovers skills and exposes them as `/skills:<slug>` in Copilot Chat

No wrapper files are written. The canonical skill at `.agents/skills/<slug>/SKILL.md` is the only file needed.

**Review files (Code Review):** `emit.sh` (run by `dot-scout`) writes per-group files into `.github/instructions/` with `applyTo:` frontmatter. Copilot Code Review applies them when reviewing matching paths. Enable this via the review integration step in the interactive installer.

### Codex (native, no wrapper needed)

Codex discovers repo skills by scanning `.agents/skills/` from the current working directory up to the repo root. No wrapper files are written. The canonical skill at `.agents/skills/<slug>/SKILL.md` is the only file needed.

### Vendor (`./install.sh vendor <dir>`)

Writes `<dir>/.agents/principles-catalog/` (see [§2](#agentsprinciples-catalog---vendored-project-subset)): the groups, layers and context files, `index.tsv`, the `bin/` scripts, `VERSION`, and - when the project's root `.principles` has `:extends` - `org.principles` and `principles.lock`. Also reinstalls the skills. If the project was scouted before, it then runs `emit.sh` so the generated review files match the new catalog. Commit `.agents/principles-catalog/` to the repo.

### Uninstall (`./uninstall.sh <dir>`)

Removes all assets written by `install.sh` and `dot-scout`:
- AI skills from `<dir>/.agents/skills/` (skill directories whose `SKILL.md` has the `generated-by: .principles` watermark, including `fix-flow.md`)
- Command files from `<dir>/.claude/commands/` (files with `generated-by: .principles` watermark)
- Vendor catalog: `<dir>/.agents/principles-catalog/`
- Generated review files: `<dir>/.github/instructions/*.instructions.md`, `<dir>/REVIEW.md` and `<dir>/.agents/instructions/review.md` (files with the `<!-- generated by dot-scout -->` marker)
- The `<!-- .principles:start -->` block in `AGENTS.md` (and `CLAUDE.md`); the file is deleted if nothing else is left
- Legacy assets: `<dir>/.claude/rules/` files written by earlier `dot-scout` versions, `<dir>/.principles-catalog/`, `<dir>/.github/skills/`, `<dir>/.github/prompts/`, compiled blocks from `AGENTS.md`/`CLAUDE.md`/`copilot-instructions.md`, legacy `~/.principles`

**`--purge`** additionally removes what plain uninstall keeps because it is the user's: every `.principles` file (not inside `node_modules`, `build`, `dist`, `.gradle`, `.idea`, nested repositories or git worktrees), the project-level `.principles-extra`, `audit-output.json` when it contains `principle_source` (so a file that `dot-audit` did not write is kept), and the `# Generated by .principles` block in `.gitignore`. It cannot be combined with `--target`. `--purge --dry-run` lists these and changes nothing. After a purge, mentions of `.principles`, `dot-scout` and `dot-audit` left in the project's files are listed, never edited. Without `--purge`, uninstall says that the `.principles` files were kept.

**Content-based detection:** All generated files are identified by the `generated-by: .principles` frontmatter watermark or the `generated by dot-scout` marker - not by matching current command names. This makes uninstall version-agnostic: files from renamed commands are cleaned up correctly. Legacy command names are checked as a fallback for pre-watermark installs. Files you wrote yourself are never touched.

On Windows, use `uninstall.ps1` or `uninstall.cmd`.

### Template system

The installer is template-driven. Each output format is defined by two files in `templates/<tool>/`:

```
templates/
├── agents/
│   ├── manifest.cfg          # Key=value config (output paths, patches, SUPPORT_FILES)
│   └── wrapper.md            # Full-content skill template
├── claude/
│   ├── manifest.cfg
│   └── wrapper.md            # Thin wrapper template (single redirect line)
└── extra-catalog/            # Starter scaffold for custom extra-catalogs
```

**`manifest.cfg`** - bash-sourceable key=value config:
- `TOOL_ID` - unique identifier (e.g. `agents`, `claude`)
- `TOOL_LABEL` - human-readable name for installer output
- `OUTPUT_DIR` - target directory pattern (may contain `{{COMMAND_SLUG}}`)
- `OUTPUT_FILE` - target filename pattern (may contain `{{COMMAND_SLUG}}`)
- `PATCHES` - optional sed expressions applied to the command body
- `SUPPORT_FILES` - `1` installs reference files next to the output: `commands/dot/.<command>-<name>.md` becomes `<name>.md` in the same directory (for example `.audit-fix-flow.md` → `.agents/skills/dot-audit/fix-flow.md`). The command reads them on demand, which keeps the main file small. Dot-prefixed files are not commands themselves.

**`wrapper.md`** - output skeleton using placeholders:
- `{{COMMAND_NAME}}` - the command path relative to `commands/` without extension (e.g. `dot/audit`)
- `{{COMMAND_SLUG}}` - flat slug derived from the path (slashes → dashes, e.g. `dot-audit`)
- `{{FRONTMATTER}}` - replaced with the frontmatter fields from the source command file
- `{{COMMAND_BODY}}` - replaced with the command content (everything after the source frontmatter)

#### Frontmatter fields

| Field | Example | Present in |
|-------|---------|------------|
| `description` | "Review a file, directory, or inline code against..." | All |
| `argument-hint` | "[file\|directory\|inline-code]..." | All |
| `allowed-tools` | "Read, Write, Glob, Grep, Bash" | All |
| `version` | "0.16.0" | All |
| `authors` | "Flemming N. Larsen (...)" | All |
| `generated-by` | `.principles` | All |
| `name` | "dot-audit" | Agents (canonical skills) |
| `license` | "MIT" | Agents (canonical skills) |

The `generated-by: .principles` watermark is defined in each `wrapper.md` and used by `uninstall.sh` for content-based file detection.

#### Adding a New AI Tool

To add a thin wrapper for a new AI tool:
1. Create `templates/<newtool>/manifest.cfg` with the output directory and filename pattern
2. Create `templates/<newtool>/wrapper.md` - for a thin wrapper, the body is just `Follow the instructions in .agents/skills/{{COMMAND_SLUG}}/SKILL.md.`
3. Wire up a call to `install_from_template "$TEMPLATE_DIR/<newtool>" "$project_dir"` in `lib/ui.sh`

If the tool reads `.agents/skills/` natively (like Copilot CLI/IDE and Codex), no wrapper template is needed at all.

---

## 11. Adding a new namespace

To add a company-specific namespace alongside the shipped `code` catalog:

1. **Create the namespace directory:**
   ```bash
   mkdir -p principles/corp
   ```

2. **Create `principles/corp/catalog.yaml`:**
   ```yaml
   description: "Acme Corp engineering standards"
   ```

3. **Add principle files** following the file schema (Section 6):
   ```
   principles/corp/corp-0001.md    → CORP-0001
   principles/corp/infra/infra-001.md → CORP-INFRA-001
   ```

4. **Reference in `.principles` files:**
   ```
   CORP-0001
   CORP-INFRA-001
   ```

The system discovers all `principles/*/catalog.yaml` files automatically. The namespace is the directory name and IDs are derived from file paths.

---

## 12. ID format guidance

### Naming Conventions

- Namespace prefix: uppercase, short (2-6 chars) - `CODE`, `CORP`, `ARCH`
- Category segment: 2-4 uppercase chars - `SD`, `API`, `SEC`, `AR`
- Named files: the full filename is used verbatim as the final ID segment (e.g., `solid/srp.md` → `SOLID-SRP`, `code/api/standard-http-methods.md` → `CODE-API-STANDARD-HTTP-METHODS`, `owasp/01-broken-access-control.md` → `OWASP-01-BROKEN-ACCESS-CONTROL`). Numeric prefixes work the same way (e.g., `12factor/01-codebase.md` → `12FACTOR-01-CODEBASE`).
- Prefer descriptive slugs to opaque numbers - `validate-input.md` is immediately clear; `sec-001.md` is not.
- Avoid: special characters, spaces, mixed case

### Depth Recommendations

| Depth                  | Use when                            | Example              |
|------------------------|-------------------------------------|----------------------|
| 2 levels: `NS/CAT`     | ≤20 principles per category         | `SOLID-SRP`          |
| 3 levels: `NS/CAT/SUB` | Large category needing sub-grouping | `CODE-API-STANDARD-HTTP-METHODS` |

Keep paths shallow. Deep nesting makes IDs hard to read and reference.

### When to Add a New Category

Add a new category directory when:
- The topic is distinct enough to warrant its own group (e.g., `security`, `testing`)
- You have at least 3 principles in the category
- Existing categories don't fit well

---

## 13. Contributing principles

See [CONTRIBUTING.md](CONTRIBUTING.md) for requirements, process, and source guidelines.
