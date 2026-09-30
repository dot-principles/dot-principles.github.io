# .principles

[![License: MIT](https://img.shields.io/badge/tooling-MIT-green.svg)](https://opensource.org/licenses/MIT) [![License: CC BY-SA 4.0](https://img.shields.io/badge/principles-CC%20BY--SA%204.0-blue.svg)](https://creativecommons.org/licenses/by-sa/4.0/) [![GitHub release](https://img.shields.io/github/v/release/dot-principles/dot-principles.github.io)](https://github.com/dot-principles/dot-principles.github.io/releases)

**Choose which engineering principles your AI agent applies - per repo, per directory, per artifact type.**

> **Latest release:** [v0.15.0](https://github.com/dot-principles/dot-principles.github.io/releases/latest) - see [all releases](https://github.com/dot-principles/dot-principles.github.io/releases) and [CHANGELOG](CHANGELOG.md).
> **Docs site:** [dot-principles.github.io](https://dot-principles.github.io/) - Why, Examples, Getting Started, Commands, How It Works, Extending.
> This is a proof of concept - see [DISCLAIMER.md](DISCLAIMER.md).

## Why

AI coding agents already know SOLID, OWASP, DDD and the rest. They do not know which of them matter in *your* repo, in *this* subtree, for *this* kind of artifact. `.principles` fills that gap with plain-text files in version control. It works for code, docs, infrastructure, configuration, schemas and pipelines.

The workflow is **`dot-scout` → code → `dot-audit`**.

## How it works

Put a `.principles` file in the project root, and optionally in subdirectories:

```text
# Activate all Spring Boot principles (includes java)
@spring-boot

# Add a specific principle
CODE-OB-SERVICE-LEVEL-OBJECTIVES

# Suppress a principle for this subtree
!CODE-API-HATEOAS
```

The agent walks up from the file under review to the git root, merges the files (outermost first, innermost last) and applies the result. Inner files extend outer ones.

```text
my-project/
├── .principles                          # broad defaults
├── backend/.principles                  # adds backend groups
├── backend/src/payments/.principles     # adds security, drops a rule
└── docs/.principles                     # docs principles
```

Layers, syntax and the resolution algorithm are in [DESIGN.md §8](DESIGN.md#8-principles-file-format).

## Two commands

You speak to them in natural language. Use `/dot-scout` in Claude Code and Copilot, and `$dot-scout` in Codex.

- **`dot-scout`** detects the stack and artifact types, creates `.principles` files, and generates the review instruction files that agents use (`.github/instructions/` for Copilot, `REVIEW.md` for Claude).
- **`dot-audit`** reviews a scope against the active principles and groups findings by severity (Critical / High / Medium / Low).

```text
/dot-audit current changes          → what changed since the last commit
/dot-audit the payment module       → a subtree
/dot-audit DDD on src/orders        → force a group, ignore .principles files
```

See [Commands](https://dot-principles.github.io/commands) and the [demo walkthrough](demo/presentation.md).

## Quick start

Requires Bash 4+ and a premium model - see [REQUIREMENTS.md](REQUIREMENTS.md).

```bash
git clone https://github.com/dot-principles/dot-principles.github.io.git
./dot-principles.github.io/install.sh <project-dir>   # interactive: pick your tools

cd <project-dir>
git add .agents/ .claude/    # drop .claude/ if you did not select Claude Code
git commit -m "Add .principles AI commands and principle catalog"
```

Then run `/dot-scout` in your agent. Platform notes (Linux, macOS, Windows) and the `vendor` refresh command are in [INSTALL.md](INSTALL.md).

## Your own principles

You do not need a fork. Write an extra catalog (same structure as `principles/`) and register it in `~/.principles-extra`, in `<project>/.principles-extra`, or with `--extra-catalog`. Reference its IDs and groups from `.principles` like any built-in ones. This is the route for company standards and team conventions.

Start from [`templates/extra-catalog/`](templates/extra-catalog/) and read [INSTALL.md §10](INSTALL.md#10-installing-an-extra-catalog). A working example is [`dot-principles/example-catalog`](https://github.com/dot-principles/example-catalog).

## Catalog

375 principles in 32 namespaces (`CODE-*`, `SOLID-`, `GOF-`, `DDD-`, `OWASP-`, `ARCH-`, `DOC-` and more) and 53 groups. The namespace reference is in [DESIGN.md §2](DESIGN.md#2-catalog-structure) and the groups in [DESIGN.md §7](DESIGN.md#7-groups).

## More

- [CONTRIBUTING.md](CONTRIBUTING.md) - add a principle upstream
- [DESIGN.md](DESIGN.md) - architecture reference
- [CHANGELOG.md](CHANGELOG.md)
- License: principle texts [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), scripts and tooling [MIT](https://opensource.org/licenses/MIT). See [LICENSE-INTERPRETATION.md](LICENSE-INTERPRETATION.md) for practical use.
- Support: [Buy me a coffee](https://buymeacoffee.com/flemming.n.larsen)
