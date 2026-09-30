# Contributing

> **Scope:** Principles contributed here must be **established, widely recognized concepts** from the software engineering literature - named principles, published patterns, or documented practices backed by authoritative sources. They must not duplicate what is already in the catalog.
>
> If your principle is original, company-specific, domain-niche, or doesn't have an authoritative published source, keep it in your own **extra catalog** (see [INSTALL.md §10](INSTALL.md#10-installing-an-extra-catalog)) rather than submitting a PR. No fork is needed.

## Requirements

Start with the [principle template](principles/TEMPLATE.md).

Every new principle must have:

- A clear principle description in your own words
- At least one verifiable published source (book with ISBN, paper with DOI, or authoritative URL)
- Correct layer assignment (1 = universal, 2 = contextual, 3 = risk-elevated)
- **`**Summary:**` field** - one actionable sentence (max ~15 words) that states what the principle requires, written as a rule (e.g., *"Depend on abstractions, never on concrete implementations."*). Placed after `**Applies-to:**` in the file header. Required for all new principles. **This field is extracted verbatim into `.agents/principles-catalog/index.tsv` by `install.sh vendor` and used directly in per-group principle files that AI agents see - quality matters. It must be an accurate, tight, actionable rule.**
- At least one "Violations to detect" entry
- No significant overlap with an existing principle in the catalog
- **Code auditability** - Every principle must have at least one violation identifiable by reading the codebase. Principles whose violations are entirely process-based (e.g., "do X before writing code"), runtime-observable, or dependent on external org/environment context are not accepted. Use `**Audit-scope:** limited` for principles that are partially auditable. See `principles/AUDIT-SCOPE.md` for examples of the boundary.
- **No redundancy** - Do not add a principle already covered by an existing one, even from a different angle or name. Review `catalog.yaml` before submitting. Redundant submissions will not be accepted.

### Principle file header format

The opening header of every principle file must follow this order exactly:

```markdown
**Layer:** [1 | 2 | 3]
**Categories:** [comma-separated]
**Applies-to:** [all | comma-separated contexts]
**Summary:** [One actionable sentence - max ~15 words, written as a rule]
```

**What makes a good Summary:**
- State what the principle *requires*, not what it avoids: *"Depend on abstractions, never on concrete implementations."*
- Imperative or declarative phrasing, no weasel words
- Short enough to appear in a per-group principle file without wrapping
- Read the existing principles for tone - *"Handle only one failure mode per catch block."*, *"Every public API endpoint must be rate-limited."*

## Process

1. Copy `principles/TEMPLATE.md` to the appropriate category directory
2. Fill in all sections - see [DESIGN.md Section 6](DESIGN.md#6-principle-file-schema) for the full schema
3. Derive the ID from the file path - see [DESIGN.md Section 5](DESIGN.md#5-id-derivation)
4. Add the principle to relevant groups in `groups/`
5. If the principle has grep-able violations, add an `## Inspection` section and update the namespace's `.context-inspect.md` - see [DESIGN.md "Inspection - When to Add"](DESIGN.md#-inspection--when-to-add) for guidance
6. Submit a pull request with:
   - The principle file
   - Group file updates (if any)
   - `.context-inspect.md` updates (if applicable)
   - A brief rationale for the source choice

## Source Requirements

Acceptable:

- Books: full citation with ISBN (e.g., *Effective Java* by Bloch, 3rd ed., ISBN 978-0134685991)
- Papers: DOI or stable URL
- Authoritative specifications: RFC, OWASP, IEEE standard with URL

Not acceptable:

- Blog posts without named authors
- Stack Overflow answers
- Undated sources

## Contribution License

By submitting a pull request, you agree that:

- Contributions to `principles/` are licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- Contributions outside `principles/` (scripts, tooling, docs) are licensed under [MIT](https://opensource.org/licenses/MIT).

This matches the dual-license structure defined in [LICENSE](LICENSE).
