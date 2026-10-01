# Extending

You do not need to fork this repository to make `.principles` useful for your team.

The built-in catalog is the shared public baseline. Your organization can layer its own principles on top.

## What extension looks like

Create an extra catalog directory that follows the same structure as `principles/` in this repo.

That catalog can contain:

- organization-specific principles
- domain rules that are too local for the shared public catalog
- team conventions backed by your own internal standards

## Register the extra catalog

You can register an extra catalog at several levels:

```bash
# User-level
echo ~/acme-principles >> ~/.principles-extra

# Per-project
echo /shared/acme-principles >> my-project/.principles-extra

# One-off vendoring
./install.sh vendor my-project --extra-catalog ~/acme-principles
```

Corporate and personal catalogs can coexist. If two catalogs define the same namespace or group, the first registered wins (built-in, then user, project, CLI), and the duplicate is skipped with a warning.

## Using an extra catalog in an organization

An organization can give every team the same standards in four steps:

1. Keep the catalog in a shared git repository, for example `acme-principles`, starting from [`templates/extra-catalog/`](https://github.com/dot-principles/dot-principles.github.io/tree/main/templates/extra-catalog).
2. Give it one unique namespace (for example `acme/`, so IDs become `ACME-*`) and one or more groups (for example `acme-backend`) that bundle your principles with the built-in ones.
3. Register it in each project's `.principles-extra`, so the registration travels with the repo.
4. Reference the group from the project's root `.principles`:

```text
@acme-backend
!ACME-LEGACY-ONLY-RULE
```

The usual hierarchy still applies: a subdirectory can add more groups or exclude a rule where the local context differs. Re-run `./install.sh vendor <project>` after updating the catalog, and pin the catalog to a tag or commit in CI for reproducible results.

To make some principles required and give teams a documented way to pause others, see [Governance](governance.md).

## When to extend instead of contributing upstream

Use an extra catalog when the rule is:

- specific to your company or product
- specific to your domain
- based on an internal standard rather than a published shared source

Contribute upstream when the principle belongs to the public software engineering literature and would help many teams, not just your own.

## Deep reference and examples

- [`templates/extra-catalog/`](https://github.com/dot-principles/dot-principles.github.io/tree/main/templates/extra-catalog)
- [`example-catalog`](https://github.com/dot-principles/example-catalog)
- [`INSTALL.md` §9 - Extra Catalogs](https://github.com/dot-principles/dot-principles.github.io/blob/main/INSTALL.md#9-extra-catalogs)
- [`INSTALL.md` §10 - Installing an Extra Catalog](https://github.com/dot-principles/dot-principles.github.io/blob/main/INSTALL.md#10-installing-an-extra-catalog)
- [`DESIGN.md` section 11](https://github.com/dot-principles/dot-principles.github.io/blob/main/DESIGN.md#11-adding-a-new-namespace)