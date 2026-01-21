#!/bin/zsh
# Team of Six - Wrapper V56 (Optimized)
set -o pipefail

HOST_HOME="$HOME"
TOS_DIR="$HOST_HOME/.team_of_six"
source "$TOS_DIR/tos_config" || exit 1

# [VARIABLE ISOLATION]
unset GITHUB_TOKEN
source "$TOS_DIR/.token" || exit 1

TARGET_DIR="$(pwd)"
INPUT_ABS="$TOS_DIR/tos_input.sh"
LOG_ABS="$TOS_DIR/tos_output.log"

# --- STREAMLINED BINARY GATE ---
if [ ! -d "$TARGET_DIR/.tos" ]; then
    echo "⚠️  PROJECT GATE: .tos/ folder not found in $TARGET_DIR"
    echo -n "Would you like to scaffold a new project here? (y/n): "
    read -r CHOICE
    
    if [[ "$CHOICE" != "y" && "$CHOICE" != "Y" ]]; then
        echo "⛔ Aborted."
        exit 1
    fi
    echo "🚀 Proceeding to sandbox for scaffolding..."
fi

# Ensure AI_USER has permissions (Cross-platform stat)
CURRENT_OWNER=$(stat -c '%U' "$TARGET_DIR" 2>/dev/null || stat -f '%Su' "$TARGET_DIR")
if [ "$CURRENT_OWNER" != "$AI_USER" ]; then
    sudo chown -R "$AI_USER:$AI_GROUP" "$TARGET_DIR"
    sudo chmod -R 775 "$TARGET_DIR"
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

# Execute logic as AI_USER
# We pass GITHUB_TOKEN via 'env' to ensure the sudo shell sees it
sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    cd "$TARGET_DIR" || exit 1
    
    if [ -f "$INPUT_ABS" ]; then
        PHASE=\${TOS_PHASE:-"General"}
        REQUEST=\${TOS_REQUEST:-"Manual implementation via tos_input.sh"}
        IS_SCAFFOLDING="false"

        source "$INPUT_ABS"
        
        # --- 3. POST-EXECUTION AUTOMATION ---
       
        # 3a. Update Local State
        if [ -d ".tos" ]; then
            echo "\$PHASE" > ".tos/state"
            echo "📈 Local State updated to: \$PHASE"
        fi

        # 3b. Scaffolding Check (Git)
        if [ ! -d ".git" ]; then
            echo "🌱 Initializing git repository..."
            git init -b main
            IS_SCAFFOLDING="true"
        fi

        # 3c. Auth Configuration
        git config --local url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
        git config --local user.email "team_of_six@internal"
        git config --local user.name "Team of Six"
        
        # 3d. Commit & Push Logic
        git add .
        
        # Only proceed if there are changes to commit
        if ! git diff --cached --quiet; then
            if [ "\$IS_SCAFFOLDING" = "true" ]; then
                BRANCH_NAME="main"
                git commit -m "scaff: tos_sandbox init new project - \$PHASE - \$REQUEST"
				REPO_NAME=\$(basename \$(pwd))
				gh repo create \$REPO_NAME --private --source=. --remote=origin --push
            else
                BRANCH_NAME="tos/feat-\$(date +%Y%m%d%H%M)"
                git checkout -b "\$BRANCH_NAME"
                git commit -m "feat: tos_sandbox PR - \$PHASE - \$REQUEST"
            fi

            # 3e. Remote Automation
            if git remote | grep -q 'origin'; then
                echo "Pushing to origin..."
                git push origin "\$BRANCH_NAME"
                if command -v gh &> /dev/null; then
                     gh pr create --title "tos_sandbox PR - \$BRANCH_NAME" --body "\$PHASE - \$REQUEST" --fill
                fi
            fi
        else
            echo "No changes detected. Skipping commit/push."
        fi
    fi
SANDBOX

# Cleanup
if [ $? -eq 0 ]; then
    truncate -s 0 "$INPUT_ABS"
    echo "✅ Task completed successfully."
fi
