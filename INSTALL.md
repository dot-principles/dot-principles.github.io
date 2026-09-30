# Installation

This guide covers installing `.principles` on Linux, macOS, and Windows.

---

## Prerequisites

- **Bash 4+** - required by `install.sh` / `uninstall.sh`
- **AI model** - Claude Haiku 4.5+, GPT-4.1+, or equivalent

See [REQUIREMENTS.md](REQUIREMENTS.md) for platform-specific setup and model compatibility details.

---

## 1. Clone the repo

```bash
git clone https://github.com/dot-principles/dot-principles.github.io.git
cd dot-principles
```

---

## 2. Install into your project

`.principles` is a **repo-local** install - there is no global install. A `<dir>` argument is always required. The installer is interactive: it asks which AI tools you use (Copilot, Claude Code, Codex) and whether to enable review integration (Copilot Code Review, Claude Code Review).

| Command | What it does |
|---------|--------------|
| `./install.sh <dir>` | Interactive first install: choose tools and review integration |
| `./install.sh vendor <dir>` | Non-interactive refresh: reinstalls the skills and re-vendors the catalog, keeping the choices recorded in `.agents/principles-catalog/install.cfg` |
| `./install.sh --list <dir>` | Show what is installed in `<dir>` |

### Linux / macOS

```bash
./install.sh <project-dir>
```

### Windows

Windows users need bash on `PATH`. The repo ships thin wrapper scripts for both PowerShell and Command Prompt that detect bash and forward arguments to the real `install.sh`.

**Step 1 - get bash.** Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash). WSL, MSYS2, and Cygwin also work as long as `bash` is on `PATH`.

**Step 2 - run the wrapper.**

**PowerShell:**

```powershell
.\install.ps1 C:\projects\my-app
```

**Command Prompt:**

```cmd
install.cmd C:\projects\my-app
```

> **Path note:** `install.cmd` / `uninstall.cmd` normalize backslashes to forward slashes before calling bash. `install.ps1` / `uninstall.ps1` convert `C:\...` paths to a bash-friendly absolute path.

---

## 3. What gets installed

The installer writes the following into `<dir>`:

| File | Installed | Purpose |
|------|-----------|---------|
| `.agents/skills/dot-scout/SKILL.md`, `.agents/skills/dot-audit/SKILL.md` | Always | The two commands. Copilot CLI, Copilot IDE and Codex read `.agents/skills/` natively (`/dot-scout` in Copilot, `$dot-scout` in Codex) |
| `.agents/principles-catalog/` | Always | Vendored principle data (see Section 4) |
| `.claude/commands/dot-scout.md`, `.claude/commands/dot-audit.md` | If you select Claude Code | Thin `/dot-scout` and `/dot-audit` slash commands that delegate to the skills |

`dot-scout` later writes the `.principles` files, `.agents/principles-catalog/active.md` and, for the review integrations you enabled, `.github/instructions/*.instructions.md` (Copilot) and `REVIEW.md` (Claude).

**Commit these files** so every team member and CI environment gets the commands and catalog:

```bash
cd <project-dir>
git add .agents/
git add .claude/     # only if you selected Claude Code
git commit -m "Add .principles AI commands and principle catalog"
```

---

## 4. Vendor subcommand - `.agents/principles-catalog/`

The `vendor` subcommand copies the principle catalog data the commands need into `<dir>/.agents/principles-catalog/`:

```bash
./install.sh vendor <project-dir>
```

The interactive installer runs `vendor` automatically. Run it manually after upgrading `.principles`, or after adding or changing an extra catalog.

As part of vendoring, `install.sh vendor` also generates `<dir>/.agents/principles-catalog/index.tsv` - a pipe-delimited flat file (`ID|LAYER|SUMMARY`, one line per principle) covering every vendored principle. `dot-scout` reads this single file to resolve active principles and emit the review files in one pass, without walking hundreds of individual namespace files. Example entries:

```
CODE-SEC-VALIDATE-INPUT|1|Validate all input at every system boundary; never trust external data.
DDD-AGGREGATE|2|Enforce business invariants within a single aggregate boundary per transaction.
```

**Why commit `.agents/principles-catalog/`?** The installed commands (`dot-scout`, `dot-audit`) read it from inside the project. Committing it means the commands work for every team member - even without access to the `.principles` repo - and CI gets the same principle data.

It holds the groups, layers, `index.tsv` and the per-namespace `.context-*.md` files. The individual principle files are not copied; only what the commands read at runtime.

---

## 5. Claude Code

If you select Claude Code in the installer, slash commands are written to `<dir>/.claude/commands/`. Claude Code discovers these automatically when opened in that project directory.

**Review file:** If you enable Claude Code Review, `dot-scout` writes a `REVIEW.md` at the git root, grouped into Critical, Important and Style sections. Claude Code Review reads it automatically.

Run `dot-scout` once per project to populate `.principles` files and emit the review files:

```
# Claude / Copilot:
/dot-scout
/dot-audit     ← review against active principles

# Codex:
$dot-scout
$dot-audit
```

---

## 6. GitHub Copilot

Copilot CLI and the Copilot IDE extensions (VS Code, JetBrains, Visual Studio) read the skills from `.agents/skills/` natively, so no Copilot-specific files are written. Copilot CLI exposes them as `@dot-scout` and `@dot-audit`; the IDE extensions as `/skills:dot-scout` and `/skills:dot-audit`.

**Review files:** After `dot-scout`, one file per active `@group` is written to `.github/instructions/` with `applyTo:` frontmatter listing the file globs for that group. Copilot Code Review activates each file only when reviewing paths that match its globs - keeping each file within the context budget.

---

## 7. Codex

Codex reads repo skills from `.agents/skills/`, which every install writes. After install, invoke the workflows as `$dot-scout` and `$dot-audit` in Codex CLI or the Codex IDE extension.

---

## 8. Uninstall

```bash
# Remove all .principles assets from a project
./uninstall.sh <project-dir>
```

The uninstaller:
- Removes the generated review files: `.github/instructions/*.instructions.md` and `REVIEW.md` (only files with the `<!-- generated by dot-scout -->` marker; files you wrote yourself are kept)
- Removes `.claude/commands/dot-scout.md` and `dot-audit.md`
- Removes `.agents/skills/dot-scout/` and `dot-audit/`
- Removes `.agents/principles-catalog/`
- Cleans up legacy assets: `.claude/rules/` files from older `dot-scout` versions, `.github/skills/`, `.github/prompts/`, `.principles-catalog/`, `.ai/`, compiled blocks from `AGENTS.md`/`CLAUDE.md`/`copilot-instructions.md`
- Removes legacy `~/.principles` if present from an older install

On Windows, use `uninstall.ps1` or `uninstall.cmd` with the same arguments.

---

## 9. Extra Catalogs

You can plug in your own principle namespaces - corporate standards, team conventions, or personal rules - alongside the built-in catalog, without forking this repo.

### How it works

An **extra catalog** is a directory with the same structure as the `principles/` repo:

```
my-principles/
├── principles/
│   └── acme/                ← your namespace (IDs become ACME-*)
│       ├── catalog.yaml     ← required
│       ├── .context-audit.md  ← compiled violations for /dot-audit
│       └── acme-api-style.md  ← individual principle files
└── groups/
    └── acme-backend.yaml    ← optional @group alias
```

Three sources are merged automatically when you run `install.sh vendor` or the interactive installer:

| Order | Source | How |
|-------|--------|-----|
| 1 | **User config** | `~/.principles-extra` - one path per line, applies to all your projects |
| 2 | **Project config** | `<project-dir>/.principles-extra` - one path per line, committed with the project |
| 3 | **CLI flag** | `--extra-catalog <path>` - repeatable, for one-off and CI use |

All sources are additive. Built-in namespaces (`solid`, `gof`, `ddd`, etc.) are always present and cannot be overridden.

### Using extra principles

After vendoring, use IDs and groups from your extra catalog in any `.principles` file:

```
# In <project>/.principles  or any subdirectory .principles
@acme-backend
ACME-API-STYLE
PTAC-PLAIN-TEXT-FIRST
```

### Conflict rules

- **Duplicate namespaces**: the first-registered source wins, in the order above (built-in first, then user config, project config, CLI). A warning is printed; the duplicate is skipped and its principles stay out of `index.tsv`.
- **Duplicate groups**: same rule - first wins.
- Extra catalogs cannot override built-in namespaces.

---

## 10. Installing an Extra Catalog

Follow the steps below to set up an extra catalog globally, per-project, or both.

### Corporate setup

**Step 1** - Create a shared principles repo:

```bash
# Clone the extra-catalog template
cp -r /path/to/dot-principles/templates/extra-catalog ~/acme-principles
cd ~/acme-principles
git init && git add . && git commit -m "Initial ACME principles"
# Push to your internal git host
```

**Step 2** - Rename the namespace and add your principles:

```
acme-principles/
  principles/
    acme/
      catalog.yaml             ← description: "ACME Engineering Standards"
      .context-audit.md        ← compiled violations
      acme-api-style.md        ← ID: ACME-API-STYLE
      acme-error-handling.md   ← ID: ACME-ERROR-HANDLING
  groups/
    acme-backend.yaml          ← @acme-backend group
```

**Step 3** - Each developer clones the repo and registers it:

```bash
# Clone to a known path
git clone https://git.acme.com/acme-principles ~/acme-principles

# Register for all projects (user-level)
echo ~/acme-principles >> ~/.principles-extra
```

Or register per-project (committed to the repo):

```bash
echo /shared/acme-principles >> my-project/.principles-extra
```

**Step 4** - Re-vendor after each update to `acme-principles`:

```bash
cd /path/to/dot-principles && ./install.sh vendor ~/projects/my-project
```

### Individual / personal setup

```bash
# Clone the template
cp -r /path/to/dot-principles/templates/extra-catalog ~/.personal-principles

# Add your own principles to principles/<your-namespace>/
# Register globally
echo ~/.personal-principles >> ~/.principles-extra

# Re-vendor any project
cd /path/to/dot-principles && ./install.sh vendor ~/projects/my-project
```

See [`github.com/dot-principles/example-catalog`](https://github.com/dot-principles/example-catalog) for a complete working example (Plain-Text-as-Code namespace) you can fork or clone as a starting point.

### Both at the same time

Corporate and personal catalogs work simultaneously - just register both:

```
# ~/.principles-extra
~/acme-principles
~/.personal-principles
```

Both are merged into `.agents/principles-catalog/` at vendor time. As long as namespaces are unique (e.g., `acme/` vs `personal/`), there are no conflicts.

### Versioning your extra catalog

An extra catalog is just a directory - treat it as a git repo:

```bash
cd ~/acme-principles
git add principles/acme/acme-0001.md
git commit -m "Add ACME-0001: API versioning standard"
git push
```

Each developer pulls updates and re-vendors their projects. CI environments clone the repo at a pinned SHA for reproducibility.

---

## 11. CLI Flag and Windows

### CLI flag (one-off or CI)

```bash
./install.sh vendor my-project --extra-catalog ~/acme-principles
./install.sh vendor my-project --extra-catalog ~/acme-principles --extra-catalog ~/.personal-principles
```

### Windows notes

Extra catalog paths passed to `--extra-catalog` are automatically converted from backslash to forward-slash format by `install.ps1` and `install.cmd`. Paths stored in `.principles-extra` config files are **not** pre-processed by those wrappers, so use forward slashes or tilde notation:

```
# ~/.principles-extra or <project>/.principles-extra
~/acme-principles
C:/Users/YourName/personal-principles
```

> **PowerShell example**
> ```powershell
> # Git Bash / WSL via install.ps1
> ./install.ps1 vendor my-project --extra-catalog C:\Users\YourName\acme-principles
> ```
>
> **cmd.exe example**
> ```cmd
> install.cmd vendor my-project --extra-catalog C:\Users\YourName\acme-principles
> ```

Backslashes in `--extra-catalog` paths are converted automatically; backslashes inside config files are also normalized by `install.sh` at read time.

---

## 12. After installing

Open your AI tool and run the commands. Tip: to try it without commitment, install on a throwaway branch and delete the branch afterwards.

```
# Claude / Copilot:
/dot-scout              → detect project profile, create .principles files, emit review files
/dot-audit              → review code with severity-categorized findings
/dot-audit DDD on src/  → force specific principles, ignoring .principles files

# Codex:
$dot-scout / $dot-audit
```

See [README.md](README.md) for a full walkthrough and examples.
