# .principles - System Design

This document describes the full architecture of the `.principles` hierarchy system for contributors and adopters.

---

## 1. Overview

**What it is:** A portable, project-local configuration system that tells AI agents which engineering principles apply to your project - whether the file being worked on is source code, documentation, infrastructure, configuration, a schema, or a pipeline. Similar in spirit to `.gitignore`, but for engineering guidance.

**Philosophy:** `.principles` does not teach the AI anything - the AI already knows SOLID, OWASP, DDD, and the rest. It *focuses and triggers* that knowledge: giving the AI context about which principles matter for this codebase, delivered via per-group principle files in `.github/instructions/` (Copilot Code Review) and a `REVIEW.md` (Claude Code Review). The AI instructions tell the agent how to behave; `.principles` tells it which engineering lens to apply.

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
  code/                  ← general catalog (110 principles across 11 sub-namespaces)
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
  ddd/                   ← Domain-Driven Design (13 principles)
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
  effective-java/        ← Effective Java (15 principles)
    catalog.yaml         ← description only
    static-factory.md    → EFFECTIVE-JAVA-STATIC-FACTORY
    ...
  code-smells/           ← Fowler code smells (22 principles)
    catalog.yaml         ← description only
    long-method.md       → CODE-SMELLS-LONG-METHOD
    feature-envy.md      → CODE-SMELLS-FEATURE-ENVY
    ...
  grasp/                 ← GRASP patterns (9 principles)
    catalog.yaml         ← description only
    information-expert.md → GRASP-INFORMATION-EXPERT
    low-coupling.md       → GRASP-LOW-COUPLING
    ...
  12factor/              ← Twelve-Factor App (12 principles)
    catalog.yaml         ← description only
    01-codebase.md       → 12FACTOR-01-CODEBASE
    02-dependencies.md   → 12FACTOR-02-DEPENDENCIES
    ...
  owasp/                 ← OWASP Top 10 (10 principles)
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

Each namespace contains two pre-compiled files that consolidate its audit guidance and inspection patterns into a single read per command invocation:

| File | Used by | Contains |
|------|---------|----------|
| `.context-audit.md` | `dot-audit` Phase 4 | Principle statement, Violations to detect - for all principles in the namespace |
| `.context-inspect.md` | `dot-audit` Phase 5 | Machine-executable pre-scan patterns (grep/awk/find commands) - for principles with deterministic inspection patterns |

The command reads one file per namespace and filters to only the entries in the final active set. This avoids reading N individual principle files.

**`code/` sub-namespace split:** Because the `code/` namespace contains 110 principles across 11 sub-namespaces, its context files are split per sub-namespace rather than held in a single file. Each of `code/api/`, `code/ar/`, `code/cc/`, `code/cs/`, `code/dx/`, `code/ob/`, `code/pf/`, `code/rl/`, `code/sec/`, `code/tp/`, and `code/ts/` has its own `.context-audit.md` and (where applicable) `.context-inspect.md`. The root `code/.context-*.md` files contain only a pointer comment listing the sub-namespace directories. `dot-audit` uses a longest-prefix-match table to resolve `CODE-<sub>-*` IDs to the correct sub-namespace file before falling back to `code/` for unrecognised sub-prefixes.

### `.agents/principles-catalog/` - vendored project subset

When `install.sh vendor <dir>` (or the interactive installer) is run, it copies the subset of `principles/` and `groups/` referenced by the project's `.principles` files into `<dir>/.agents/principles-catalog/`. This directory mirrors the structure of the full catalog but contains only the namespaces and groups the project actually uses. It also generates `index.tsv` - a flat pipe-delimited file listing every vendored principle in `ID|LAYER|SUMMARY` format, one line per principle. `dot-scout` reads this single file to resolve the active set without walking individual namespace files.

**Commit `.agents/principles-catalog/` to your repo.** The installed commands reference it as their data source. With it committed, every team member and CI environment gets the correct principle data without needing access to the `.principles` repo.

The `{{PRINCIPLES_DIRECTORY}}` placeholder in command source files resolves to `.agents/principles-catalog` at install time.

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
```

Three sources of extra catalogs are collected automatically during `install.sh vendor`:

| Order | Source | How |
|-------|--------|-----|
| 1 | `~/.principles-extra` | User-level; one path per line; applies to all projects |
| 2 | `<project>/.principles-extra` | Project-level; committed to the project repo |
| 3 | `--extra-catalog <path>` | CLI flag; repeatable; ad-hoc or CI use |

All sources are merged into `.agents/principles-catalog/` at vendor time. Registration is **first wins, in the order above**: built-in namespaces and groups are registered first and can never be overridden, and if two extra catalogs define the same namespace or group, the earlier source keeps it. A skipped namespace or group is reported with a warning and is left out of `index.tsv` too.

The `generate_compact_index()` step scans principle `.md` files from every extra catalog namespace that was registered, in addition to `$SCRIPT_DIR/principles`, so extra principles appear in `index.tsv` and are visible to `dot-scout`. `TEMPLATE.md` files are never indexed.

See [INSTALL.md §10](INSTALL.md#10-installing-an-extra-catalog) for setup instructions. A complete working example lives in `examples/personal-principles/`. A starter template lives in `templates/extra-catalog/`.

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

## 3. Per-group principle files

After `dot-scout` writes `.principles` files, its Phase 8 emits **per-group principle files** into `.github/instructions/` (for GitHub Copilot Code Review) and a single `REVIEW.md` at the git root (for Claude Code Review). Copilot files target specific file globs using tool-native frontmatter, giving each group its own context budget.

> **Numbering:** `dot-scout` and `dot-audit` number their phases independently. "Phases 8-10" in the tests and in `AGENTS.md` always means `dot-audit`'s gated fix, commit and pull-request workflow; `dot-scout` Phase 8 is the file emission described here.

The `**Summary:**` field from each principle file is extracted verbatim into `.agents/principles-catalog/index.tsv` by `install.sh vendor`; Phase 8 reads `index.tsv` once (not per-namespace files) to build all files in a single pass.

### File format

**Copilot Code Review** (`.github/instructions/<group>.instructions.md`):

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

**Claude Code Review** (`REVIEW.md` at the git root, one file, about 10,000 characters maximum):

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

The Critical section holds security and fail-fast principles, Important holds domain and architecture principles, Style holds code-quality principles. If the budget is exceeded, Style is truncated first.

The `<!-- generated by dot-scout` marker identifies files managed by `dot-scout`. Files without this marker are user-created and never touched. On re-run, stale marked files (from groups no longer active) are deleted.

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

### Delivery targets

| Path | Consumer | Naming | Scoping |
|------|----------|--------|---------|
| `.github/instructions/` | GitHub Copilot Code Review | `<group>.instructions.md` | `applyTo:` frontmatter |
| `REVIEW.md` (git root) | Claude Code Review | one file | severity sections |

Both tools auto-discover these files. No additional configuration is needed.

A `principles-core.instructions.md` file is always emitted with `applyTo: "**/*"`, containing Layer 1 universal principles, stack Layer 1 principles, and any bare IDs not belonging to an active group.

### Two-tier context system

Per-group files act as **tier 1** context - always present, always fast. They are the primary source for the `dot-audit` fast path and passive code-review integrations:

| Tier | Source | Loaded by |
|------|--------|-----------|
| 1 - Generated review files | `.github/instructions/` and `REVIEW.md`, emitted by `dot-scout` | `dot-audit` and passive code-review integrations |
| 2 - Namespace context | `.context-audit.md` per namespace | `dot-audit` Phase 4 |
| 3 - Inspection patterns | `.context-inspect.md` per namespace | `dot-audit` Phase 5 only |

`dot-audit` checks the generated files first (tier 1) then loads the relevant namespace context files (tier 2) for full principle guidance. Per-group files avoid tree-walking `.principles` files on every invocation.

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
| `Summary`              | One actionable sentence (max ~15 words). Used in per-group principle files. Required. |
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
| `globs`       | Optional. File path globs for per-group files. Defaults to `["**/*"]` if absent.     |
| `includes`    | Other group names to compose (resolved recursively). Globs are unioned from includes |
| `principles`  | List of principle IDs this group activates                                            |

### Composition

`includes` is resolved recursively. `spring-data-jpa` includes `spring-boot`, which includes `java` - the result is the full union of all three groups' principles.

**Cycle detection:** The system detects cycles in `includes` chains and raises an error rather than looping infinitely.

### Shipped Groups

| Group              | Includes         | Purpose                                         |
|--------------------|------------------|-------------------------------------------------|
| `solid`            | -                | All five SOLID principles                       |
| `gof`              | -                | All 27 GoF entries                              |
| `gof-creational`   | -                | 5 GoF creational patterns                       |
| `gof-structural`   | -                | 7 GoF structural patterns                       |
| `gof-behavioral`   | -                | 11 GoF behavioral patterns                      |
| `ddd`              | -                | 13 Domain-Driven Design building blocks         |
| `simple-design`    | -                | Kent Beck's 4 Rules of Simple Design            |
| `clean-arch`       | -                | 4 Clean Architecture principles                 |
| `effective-java`   | -                | 15 Effective Java best practices                |
| `code-smells`      | -                | 22 Fowler code smells                           |
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

# Exclusions - suppresses even if a group activates it
!CODE-API-HATEOAS
!CODE-TS-TEST-FIRST
```

| Syntax     | Meaning                                                                         |
|------------|---------------------------------------------------------------------------------|
| `# ...`    | Comment (ignored)                                                               |
| `:directive value` | Configuration directive (see below)                                    |
| `@name`    | Include all principles from `groups/name.yaml` (recursive)                      |
| `ID`       | Include a specific principle by ID                                              |
| `!ID`      | Exclude a principle (takes final precedence over everything, including Layer 1) |
| blank line | Ignored                                                                         |

### Directives

Lines starting with `:` are configuration directives:

| Directive | Example | Description |
|-----------|---------|-------------|
| `:max_principles` | `:max_principles 15` | Cap the total number of active principles. When trimming: Layer 1 is always retained, then Layer 3 risk-elevated, then Layer 2 context-dependent (dropped first). If Layer 1 alone exceeds the cap, the cap applies only to non-Layer-1 principles. |

IDs are matched case-insensitively.

### Hierarchy Walk Algorithm

Walk **up** from the file or directory being reviewed to the git repo root (detected by `.git/` presence) or a maximum of 10 levels.

Collect all `.principles` files encountered, ordered **root → target** (outermost first, innermost last).

**Resolution:**

1. `active = { Layer 1 universals }` - always seeded
2. For each `.principles` file (root → target):
   - Expand each `@group` recursively → union into active
   - Union bare IDs into active
   - Union `!ID` into exclusion set
3. `final = active MINUS exclusions`
4. Read full content of each ID's `.md` file from its catalog

**Key properties:**
- Inner `.principles` files extend (not replace) outer ones
- `!ID` exclusions suppress even Layer 1 principles
- The algorithm terminates at the git root, not the filesystem root

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
1. Seed with Layer 1 universals
2. Apply `/repo-root/.principles` → expand `@spring-boot` (→ includes `java`)
3. Apply `/repo-root/src/.principles` → add `CODE-OB-SERVICE-LEVEL-OBJECTIVES`, mark `CODE-API-HATEOAS` excluded
4. Apply `/repo-root/src/payments/.principles` → expand `@security-focused`
5. Subtract exclusion set: remove `CODE-API-HATEOAS`

---

## 9. Commands

### `dot-audit`

Reviews code against activated principles. Outputs findings grouped by severity. Supports explicit principle override via `--with <spec>`, `@<group>`, or `<spec> on <target>` syntax to force a specific principle set regardless of `.principles` files.

**Interactive use only.** `dot-audit` is a chat-based, on-demand command - run it in Copilot Chat, Claude Code, or any interactive AI session when you want a deep, targeted review with optional fix and PR workflow. It is not automatically invoked during pull request review; that role belongs to the per-group instruction files emitted by `dot-scout`.

**Phases:**

| Phase | Name                          | Description                                                                                    |
|-------|-------------------------------|------------------------------------------------------------------------------------------------|
| 1     | Parse Arguments               | Detects explicit spec (`--with`, `@group`, or `on` syntax); resolves target and artifact type  |
| 2     | Resolve Principles            | Explicit mode: resolves spec directly; normal mode: per-group files fast path, then tree walk   |
| 3     | Dynamic Detection (fallback)  | Only if explicit-mode is false and no `.principles` files found                                |
| 4     | Load Principle Content        | Reads one `.context-audit.md` per namespace (pre-compiled); for `CODE-<sub>-*` IDs reads per-sub-namespace file under `code/<sub>/`; filters to active IDs |
| 5     | Pre-Scan                      | Reads `.context-inspect.md` per namespace; runs bash commands to build pre-scan manifest       |
| 6     | Review                        | Guided review (hits) + semantic-only review + opportunistic findings                           |
| 7     | Output                        | Compact text report + `audit-output.json` written to repo root; reports principle source       |
| 8     | Fix *(optional, gated)*       | Asks "Would you like me to fix these findings?"; on approval creates a `fix-<slug>` branch and applies every finding's `fix` field |
| 9     | Commit *(optional, gated)*    | Presents commit message + PR body for review; offers re-run audit (if Medium+ findings), commit-only, commit-and-push, or exit    |
| 10    | Pull Request *(optional, gated)* | Asks "Shall I open a pull request?"; on approval creates a PR targeting the default branch |

**Gated workflow rules (Phases 8-10):** Each phase is a mandatory stop - the default is always to ask, never to proceed. Identifying issues ≠ permission to fix; fixing ≠ permission to commit; committing ≠ permission to push or open a PR. Silence or likely intent never count as approval.

**Re-audit loop (Phase 9 → Phase 5):** When the audit found at least one Medium or higher finding, Phase 9 offers a "Re-run audit" option (option 0). Choosing it jumps back to Phase 5 (Pre-Scan) using the same already-resolved target and principles, then re-runs Phases 6 and 7. This backward edge is conditional - it is not offered for low-only audits. The intent is to surface issues that were masked by the more prominent findings in the first pass. The branch from Phase 8.1 is reused; the pass number increments and is recorded in the eventual commit message.

> **Automatic vs. interactive review:** Copilot Code Review and Claude Code's automatic review use the per-group files from `dot-scout` (`.github/instructions/*.instructions.md`, `REVIEW.md`) - these are passive and post findings as review comments. They do not run `dot-audit` and cannot trigger Phases 8-10. The fix gate is intentionally interactive: you invoke `dot-audit` when you are ready to decide whether to apply fixes.

### `dot-scout`

Analyses a project directory and creates or updates `.principles` files, then writes the active principle list (`active.md`) and the generated review files (`.github/instructions/`, `REVIEW.md`).

**Phases:**

| Phase | Name               | Description                                                                                   |
|-------|--------------------|-----------------------------------------------------------------------------------------------|
| 1     | Resolve Target     | Resolves `$ARGUMENTS` or CWD as the target directory                                          |
| 2     | Detect Profile     | Detects language, framework, domain; analyses per-directory profiles                          |
| 3     | Propose Placements | Proposes `.principles` placements - root + overrides for test dirs, security dirs, submodules |
| 4     | Exclusion Density  | Checks each parent-level proposed entry against child profiles; demotes entries excluded in >50% of children to the child level; consolidates widespread individual exclusions to the parent level |
| 5     | Check Existing     | Merges additions only; never removes or touches `!exclusions`                                 |
| 6     | Write Files        | Creates or updates files; reports created/updated/unchanged per path                          |
| 7     | Emit active.md     | Writes flat `- ID: Summary` list of every active principle to `{{PRINCIPLES_DIRECTORY}}/active.md` |
| 8     | Emit Per-Group Files | Reads `index.tsv` to resolve active principles; emits per-group files to `.github/instructions/` and `REVIEW.md` with path-targeted frontmatter |

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

1. **AI skills** (`<dir>/.agents/skills/<slug>/SKILL.md`) - canonical skill files containing the full prompt. Discovered natively by Copilot CLI, Copilot IDE, Codex, and any tool that reads `.agents/skills/`.
2. **Vendor catalog** (`<dir>/.agents/principles-catalog/`) - the subset of `principles/` and `groups/` referenced by the project's `.principles` files, plus `index.tsv` (flat `ID|LAYER|SUMMARY` index).

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

**Review file:** `dot-scout` Phase 8 emits `REVIEW.md` at the git root for Claude Code Review. It is runtime-generated by `dot-scout` and not installed by `install.sh`; enable it with the `claude-review` target in the interactive installer.

### GitHub Copilot (native, no wrapper needed)

Both Copilot CLI and Copilot IDE discover `.agents/skills/` natively:
- **Copilot CLI** - discovers skills by scanning `.agents/skills/` for `SKILL.md` files; exposes them as `@<slug>` in the terminal
- **Copilot IDE** (VS Code / JetBrains / Visual Studio) - discovers skills and exposes them as `/skills:<slug>` in Copilot Chat

No wrapper files are written. The canonical skill at `.agents/skills/<slug>/SKILL.md` is the only file needed.

**Per-group files (Code Review):** `dot-scout` Phase 8 emits per-group principle files into `.github/instructions/` with `applyTo:` frontmatter. Copilot Code Review applies them when reviewing matching paths. Enable this via the review integration step in the interactive installer.

### Codex (native, no wrapper needed)

Codex discovers repo skills by scanning `.agents/skills/` from the current working directory up to the repo root. No wrapper files are written. The canonical skill at `.agents/skills/<slug>/SKILL.md` is the only file needed.

### Vendor (`./install.sh vendor <dir>`)

Copies the subset of `principles/` and `groups/` referenced by the project's `.principles` files into `<dir>/.agents/principles-catalog/`, and generates `<dir>/.agents/principles-catalog/index.tsv` - a pipe-delimited flat file (`ID|LAYER|SUMMARY`) of every vendored principle. Also reinstalls the skills. Commit `.agents/principles-catalog/` to the repo.

### Uninstall (`./uninstall.sh <dir>`)

Removes all assets written by `install.sh`:
- AI skills from `<dir>/.agents/skills/` (files with `generated-by: .principles` watermark)
- Command files from `<dir>/.claude/commands/` (files with `generated-by: .principles` watermark)
- Vendor catalog: `<dir>/.agents/principles-catalog/`
- Generated review files: `<dir>/.github/instructions/*.instructions.md` and `<dir>/REVIEW.md` (files with the `<!-- generated by dot-scout -->` marker)
- Legacy assets: `<dir>/.claude/rules/` files written by earlier `dot-scout` versions, `<!-- .principles:start/end -->` hub block from `AGENTS.md`/`CLAUDE.md` (if present from earlier installs), `<dir>/.principles-catalog/`, `<dir>/.github/skills/`, `<dir>/.github/prompts/`, compiled blocks from `AGENTS.md`/`CLAUDE.md`/`copilot-instructions.md`, legacy `~/.principles`

**Content-based detection:** All generated files are identified by the `generated-by: .principles` frontmatter watermark - not by matching current command names. This makes uninstall version-agnostic: files from renamed commands are cleaned up correctly. Legacy command names are checked as a fallback for pre-watermark installs.

On Windows, use `uninstall.ps1` or `uninstall.cmd`.

### Template system

The installer is template-driven. Each output format is defined by two files in `templates/<tool>/`:

```
templates/
├── agents/
│   ├── manifest.cfg          # Key=value config (output paths, patches)
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
| `version` | "0.15.0" | All |
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
