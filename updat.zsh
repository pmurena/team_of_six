#!/usr/bin/env zsh

echo "🛠️ Moving toolkit source inside @setup blocks..."

for file in tests/inf/*.zunit; do
    # 1. Delete any existing source lines for the toolkit
    sed -i '/sandbox_toolkit/d' "$file"
    
    # 2. Inject it immediately after the @setup { declaration
    sed -i '/@setup {/a \  source "${PWD}/tests/shared/sandbox_toolkit.zsh"' "$file"
    
    echo "✅ Aligned $file"
done

echo "🚀 Ready. Run: zunit tests/inf"
