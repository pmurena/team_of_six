#!/bin/zsh
# ==============================================================================
# Architecture Pivot: Deployment-Driven Configuration
# ==============================================================================

echo "🚀 Initiating Architectural Pivot..."

# 1. Patch the Gateway (bin/tos.zsh)
echo "1️⃣ Patching bin/tos.zsh..."
# Remove the hardcoded TOS_MNT_ROOT calculation
sed -i 's/export TOS_MNT_ROOT="${BIN_DIR:h:h}"//g' bin/tos.zsh
# Update the config resolution to rely on physical relative pathing
sed -i 's|TOS_GLOBAL_CONF="${TOS_MNT_ROOT}/.local/conf/config"|TOS_GLOBAL_CONF="${BIN_DIR:h}/conf/config"|g' bin/tos.zsh
# Clean up leftover blank lines
sed -i '/^$/N;/^\n$/D' bin/tos.zsh

# 2. Patch the Test Scaffold (tests/shared/zunit_helpers/scaffold.zsh)
echo "2️⃣ Patching scaffold.zsh..."
# Add the main tos.zsh symlink so the sandboxed tests can execute it
if ! grep -q "tos.zsh" tests/shared/zunit_helpers/scaffold.zsh; then
    sed -i '/# 5. Symlink production utilities/i \
    # 4b. Symlink the main gateway\
    ln -sf "${PWD}/bin/tos.zsh" "${TOS_BIN}/tos.zsh"\
' tests/shared/zunit_helpers/scaffold.zsh
fi

# 3. Retarget Test Invocations
echo "3️⃣ Retargeting test invocations to the isolated sandbox..."
# Find all .zunit files and swap the execution path to the sandboxed binary
find tests -name "*.zunit" -type f | while read -r test_file; do
    sed -i 's|zsh bin/tos.zsh|zsh "${TOS_MNT_ROOT}/.local/bin/tos.zsh"|g' "$test_file"
    sed -i 's|export TOS_EXEC="${PWD}/bin/tos.zsh"|export TOS_EXEC="${TOS_MNT_ROOT}/.local/bin/tos.zsh"|g' "$test_file"
done

echo "✅ Pivot Complete!"
echo "⚠️  NOTE: Check inf/tos_deploy.zsh manually to ensure it writes 'export TOS_MNT_ROOT=...' into your config generation block."
