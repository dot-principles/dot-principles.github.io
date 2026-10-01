# `.principles`

Engineering principles are useful only when the right ones are in front of the agent at the moment it writes or reviews a file.

`.principles` is a plain-text framework for doing exactly that. It lets a project declare which engineering principles matter in each part of the tree, then gives AI coding agents a focused rule set before they write code and a stronger review lens after they do.

This is not a replacement for specs, tests, or human judgment. It is the missing layer between generic model knowledge and your repo's actual standards.

## Start here

- [Why `.principles`](why.md) - what problem it solves and why this matters now
- [Examples](examples.md) - walk through the demo and the full workflow
- [Getting Started](getting-started.md) - install it, vendor the catalog, and run the first commands
- [Commands](commands.md) - see what `dot-scout` and `dot-audit` each do
- [How It Works](how-it-works.md) - understand the hierarchy, artifact types, and resolution model
- [Extending](extending.md) - add your own catalog without forking the project
- [Governance](governance.md) - org baseline, locks and waivers for organizations

## What makes it different

- It is **plain-text and Git-native**. Principle files are Markdown. Selection files are tiny `.principles` files.
- It works across **more than source code**: docs, infra, config, schemas, and pipelines.
- It is **hierarchical**. A repo root can set broad defaults, while subdirectories add or suppress rules where local context differs.
- It is **agent-oriented**. `dot-scout` configures the principle map and generates review instructions any agent can follow; `dot-audit` checks the result afterward.
- It is **built for organizations**. An org baseline can lock principles and give teams a documented, time-limited way to pause them.

## Canonical deep references

The public site is the guided path. These files remain the canonical deep references:

- [`INSTALL.md`](https://github.com/dot-principles/dot-principles.github.io/blob/main/INSTALL.md) - full installation and platform guide
- [`DESIGN.md`](https://github.com/dot-principles/dot-principles.github.io/blob/main/DESIGN.md) - architecture, schemas, hierarchy rules, and command design
- [`presentation.md`](https://github.com/dot-principles/dot-principles.github.io/blob/main/demo/presentation.md) - step-by-step user workflow walkthrough
- [`README.md`](https://github.com/dot-principles/dot-principles.github.io/blob/main/README.md) - concise GitHub-native entry point
