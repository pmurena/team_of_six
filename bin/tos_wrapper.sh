#!/bin/zsh
set -o pipefail
HOST_HOME="$HOME"
TOS_DIR="$HOST_HOME/.team_of_six"
source "$TOS_DIR/tos_config" || exit 1

# [VARIABLE ISOLATION] Clear any existing token before loading authorized one
unset GITHUB_TOKEN
source "$TOS_DIR/.token" || exit 1

TARGET_DIR="$(pwd)"
INPUT_ABS="$TOS_DIR/tos_input.sh"
LOG_ABS="$TOS_DIR/tos_output.log"

if [ ! -d "$TARGET_DIR/.tos" ]; then
    echo "⛔ SAFETY BLOCK: No .tos/ folder detected."
    exit 1
fi

if [ "$(stat -c '%U' "$TARGET_DIR")" != "$AI_USER" ]; then
    sudo chown -R "$AI_USER:$AI_GROUP" "$TARGET_DIR"
    sudo chmod -R 775 "$TARGET_DIR"
fi

echo "# --- ⚡ TASK INPUT ---" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

# Execute logic as AI_USER
sudo -u "$AI_USER" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    # 1. Identity & Auth
    export GITHUB_TOKEN='$GITHUB_TOKEN'
    cd "$TARGET_DIR"
    git config --local url."https://x-access-token:\\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
    git config --local user.email "agent@teamofsix.bot"
    git config --local user.name "Team of Six (V56)"
    
    # 2. Sandbox Hygiene
    export HOME=\$(mktemp -d -t tos_sandbox.XXXXXXXXXX)
    
    # 3. Execution
    if [ -f "$INPUT_ABS" ]; then
        # source input to ingest TOS_PHASE and TOS_REQUEST
        source "$INPUT_ABS"
        
        # --- 4. POST-EXECUTION AUTOMATION ---
        echo "\n🔍 Post-Execution: Checking Repository State..."
        
        # Fallback Defaults (Mechanical Gates alignment)
        PHASE=\${TOS_PHASE:-"General"}
        REQUEST=\${TOS_REQUEST:-"Manual implementation via tos_input.sh"}
        
        # 4a. Update Local State (Physics of State)
        # Persist the current phase so it is 'given' for the next session
        if [ -d ".tos" ]; then
            echo "\$PHASE" > ".tos/state"
            echo "📈 Local State updated to: \$PHASE"
        fi

        # 4b. Scaffolding Check
        if [ ! -d ".git" ]; then
            echo "🌱 Scaffolding detected. Initializing git repository..."
            git init
            git add .
            git commit -m "chore: initial scaffolding via Team of Six"
        fi

        # 4c. PR Automation
        BRANCH_NAME="tos/feat-\$(date +%Y%m%d%H%M)"
        echo "🚀 Preparing Automated PR on branch: \$BRANCH_NAME"
        
        git checkout -b "\$BRANCH_NAME"
        git add .
        
        if ! git diff --cached --quiet; then
            git commit -m "feat: tos_sandbox PR - \$PHASE - \$REQUEST"
            
            if git remote | grep -q 'origin'; then
                git push origin "\$BRANCH_NAME"
                gh pr create --title "tos_sandbox PR - \$BRANCH_NAME" \\
                             --body "\$PHASE - \$REQUEST" \\
                             --reviewer "@repo-contributors" \\
                             --fill
            else
                echo "⚠️  PR Skipped: No remote 'origin' found."
            fi
        else
            echo "✅ No changes detected. Skipping PR."
        fi
    fi

    # Cleanup
    rm -rf "\$HOME"
SANDBOX

[ $? -eq 0 ] && truncate -s 0 "$INPUT_ABS"
