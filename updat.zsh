#!/usr/bin/env bash
# =============================================================================
# TOS Architecture Refactoring Script
# PURPOSE: Migrates global helpers/fixtures into the 'shared' namespace 
#          and updates all internal file references.
# =============================================================================

set -e

echo "🏗️  Commencing architectural refactor..."

# 1. Scaffold the new 'shared' and 'system/fixtures' namespaces
mkdir -p tests/shared/payloads
mkdir -p tests/shared/zunit_helpers
mkdir -p tests/system/fixtures

# 2. Migrate the files
echo "📦 Moving payloads to tests/shared/payloads/..."
if [ -d "tests/fixtures/payloads" ]; then
    mv tests/fixtures/payloads/* tests/shared/payloads/ 2>/dev/null || true
fi

echo "📦 Moving helpers to tests/shared/zunit_helpers/..."
if [ -d "tests/helpers" ]; then
    mv tests/helpers/* tests/shared/zunit_helpers/ 2>/dev/null || true
fi

echo "📦 Moving system traps to tests/system/fixtures/..."
if [ -d "tests/system/traps" ]; then
    mv tests/system/traps/* tests/system/fixtures/ 2>/dev/null || true
fi

# 3. Purge the old, empty directories
echo "🧹 Cleaning up vestigial directories..."
rmdir tests/fixtures/payloads 2>/dev/null || true
rmdir tests/fixtures 2>/dev/null || true
rmdir tests/helpers 2>/dev/null || true
rmdir tests/system/traps 2>/dev/null || true

# 4. Update the internal code references (Find & Replace)
# We use .bak to ensure cross-platform compatibility between macOS (BSD sed) and Linux (GNU sed)
echo "📝 Rewiring internal imports across all tests..."

find tests -type f \( -name "*.zunit" -o -name "*.zsh" \) -exec sed -i.bak 's|tests/helpers|tests/shared/zunit_helpers|g' {} +
find tests -type f \( -name "*.zunit" -o -name "*.zsh" \) -exec sed -i.bak 's|tests/fixtures/payloads|tests/shared/payloads|g' {} +
find tests -type f \( -name "*.zunit" -o -name "*.zsh" \) -exec sed -i.bak 's|tests/system/traps|tests/system/fixtures|g' {} +

# Clean up the sed backup files
find tests -type f -name "*.bak" -delete

echo "✨ Refactoring complete! Your testing namespaces are now fully encapsulated."
