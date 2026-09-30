#!/usr/bin/env bash
# check-extra-index.sh - Verify that index.tsv only lists principles from extra-catalog
# namespaces that were actually vendored (no collisions, no TEMPLATE.md).
# Usage: ./tests/check-extra-index.sh [repo-root]
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TEST_ROOT="$(mktemp -d)"
PROJECT_DIR="$TEST_ROOT/project"
EXTRA_DIR="$TEST_ROOT/extra"
TEST_HOME="$TEST_ROOT/home"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$PROJECT_DIR" "$TEST_HOME" \
    "$EXTRA_DIR/principles/acme" \
    "$EXTRA_DIR/principles/solid"

write_principle() {
    local file="$1" id="$2"
    printf '%s\n' \
        "# $id - Test principle" \
        "" \
        "**Layer:** 2" \
        "**Categories:** test" \
        "**Applies-to:** all" \
        "**Summary:** Summary for $id." > "$file"
}

# Valid extra namespace: must be indexed.
printf '%s\n' 'description: "Acme test namespace"' > "$EXTRA_DIR/principles/acme/catalog.yaml"
write_principle "$EXTRA_DIR/principles/acme/acme-0001.md" "ACME-0001"

# Namespace that collides with a built-in one: skipped by vendoring, so must not be indexed.
printf '%s\n' 'description: "Colliding namespace"' > "$EXTRA_DIR/principles/solid/catalog.yaml"
write_principle "$EXTRA_DIR/principles/solid/solid-extra.md" "SOLID-COLLIDING"

# Template file shipped inside an extra catalog: must not be indexed.
write_principle "$EXTRA_DIR/principles/TEMPLATE.md" "TEMPLATE-ENTRY"

HOME="$TEST_HOME" bash "$REPO_ROOT/install.sh" vendor "$PROJECT_DIR" \
    --extra-catalog "$EXTRA_DIR" >/dev/null 2>&1

INDEX="$PROJECT_DIR/.agents/principles-catalog/index.tsv"
if [ ! -f "$INDEX" ]; then
    echo "FAIL [vendor] index.tsv was not generated"
    exit 1
fi

if ! grep -q '^ACME-0001|' "$INDEX"; then
    echo "FAIL [extra index] ACME-0001 from a vendored extra namespace is missing from index.tsv"
    exit 1
fi
if grep -q '^SOLID-COLLIDING|' "$INDEX"; then
    echo "FAIL [extra index] principle from a skipped (colliding) namespace leaked into index.tsv"
    exit 1
fi
if grep -q '^TEMPLATE-ENTRY|' "$INDEX"; then
    echo "FAIL [extra index] TEMPLATE.md from an extra catalog leaked into index.tsv"
    exit 1
fi

echo "OK  index.tsv lists only vendored extra-catalog principles."
