#!/bin/bash
# Patch Name: V58 Unified Publication Matrix
# Location: patches/v58_unified_matrix.sh
# Purpose: Unifies the CLI loop, replaces commit_msg/pr_summary with title/body, and dynamically routes Issue/PR/Comment creation via GitHub CLI.

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$PATCH_DIR/../bin" && pwd)"
BASE_DIR="$(cd "$PATCH_DIR/.." && pwd)"
AGENTS_ROOT="$(cd "$BASE_DIR/../llm_agents" && pwd)"

echo "🚀 Applying V58 Unified Publication Matrix Upgrade..."

# --- 1. OVERWRITE: tos_controller.sh (Unified Loop) ---
echo "⚙️  1. Updating Controller (Unified Loop)..."
cat << 'EOF' > "$BASE_DIR/tos_controller.sh"
#!/bin/zsh
# Team of Six - Global Controller V58

TOS_CONFIG="$HOME/.team_of_six/tos_config"
TOS_TOKEN="$HOME/.team_of_six/.token"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$TOS_CONFIG" ] || [ ! -f "$TOS_TOKEN" ]; then
    echo "❌ Error: V58 configuration missing."
    exit 1
fi

source "$TOS_CONFIG"
source "$TOS_TOKEN"
export GH_TOKEN=$GITHUB_TOKEN

case "$1" in
    "wrapper")
        shift
        "$REPO_ROOT/bin/tos_wrapper.sh" "$@"
        ;;
    "publish")
        shift
        "$REPO_ROOT/bin/tos_publish.sh" "$@"
        ;;
    "new")
        shift
        "$REPO_ROOT/bin/tos_project_creator.sh" "$@"
        ;;
    "")
        echo "🔄 Executing Unified Loop (Wrapper -> Publish)..."
        "$REPO_ROOT/bin/tos_wrapper.sh" && "$REPO_ROOT/bin/tos_publish.sh"
        ;;
    *)
        echo "Usage: team_of_six [wrapper|new|publish] or run without args for unified loop."
        ;;
esac
EOF

# --- 2. OVERWRITE: bin/tos_wrapper.sh (The Title/Body Mutex) ---
echo "🔒 2. Updating Wrapper (Title/Body Mutex)..."
cat << 'EOF' > "$BIN_DIR/tos_wrapper.sh"
#!/bin/zsh
# Team of Six - Wrapper V58
set -o pipefail

HOST_HOME="$HOME"
TOS_DIR="$HOST_HOME/.team_of_six"
source "$TOS_DIR/tos_config" || exit 1

TARGET_DIR="$(pwd)"
INPUT_ABS="$TOS_DIR/tos_input.sh"
LOG_ABS="$TOS_DIR/tos_output.log"

TITLE_FILE="$TARGET_DIR/.tos/title"
BODY_FILE="$TARGET_DIR/.tos/body"

if [ ! -d "$TARGET_DIR/.tos" ]; then
    echo "⛔ ERROR: .tos/ context missing."
    exit 1
fi

# [V58 MUTEX]
if [ -s "$TITLE_FILE" ] || [ -s "$BODY_FILE" ]; then
    echo "⛔ EXECUTION BLOCKED: Unpublished state detected."
    echo "The AI has already prepared an output. It must be published to GitHub before assigning a new task."
    exit 1
fi

echo "# --- ⚡ TASK INPUT --- $(date)" >> "$LOG_ABS"
cat "$INPUT_ABS" >> "$LOG_ABS"

sudo -u "$AI_USER" zsh <<SANDBOX >> "$LOG_ABS" 2>&1
    cd "$TARGET_DIR" || exit 1
    if [ -s "$INPUT_ABS" ]; then
        source "$INPUT_ABS"
    fi
SANDBOX

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && truncate -s 0 "$INPUT_ABS"
exit $EXIT_CODE
EOF

# --- 3. OVERWRITE: bin/tos_publish.sh (The Dynamic Matrix Governor) ---
echo "⚖️  3. Updating Publisher (Dynamic Action Matrix)..."
cat << 'EOF' > "$BIN_DIR/tos_publish.sh"
#!/bin/zsh
# Team of Six - Publisher V58 (The Governor)
set -e

TOS_DIR="$HOME/.team_of_six"
source "$TOS_DIR/tos_config"
source "$TOS_DIR/.token" || { echo "❌ GITHUB_TOKEN missing"; exit 1; }

TARGET_DIR="$(pwd)"

HAS_REF=false;    [ -s "$TARGET_DIR/.tos/ref" ] && HAS_REF=true
HAS_BRANCH=false; [ -s "$TARGET_DIR/.tos/branch" ] && HAS_BRANCH=true
HAS_TITLE=false;  [ -s "$TARGET_DIR/.tos/title" ] && HAS_TITLE=true
HAS_BODY=false;   [ -s "$TARGET_DIR/.tos/body" ] && HAS_BODY=true

if [ "$HAS_BODY" = false ]; then
    echo "⛔ PUBLISH FAILED: Missing .tos/body. The AI must provide context for the action."
    exit 1
fi

echo "🚀 Governor: Evaluating State & Routing to GitHub..."

sudo -u "$AI_USER" GITHUB_TOKEN="$GITHUB_TOKEN" zsh <<SANDBOX
    cd "$TARGET_DIR"
    BODY=\$(cat .tos/body)

    # Git Auth
    git config user.name "Team of Six"
    git config user.email "team_of_six@internal"
    git config url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

    # --- 1. CODEBASE MODIFICATION (PR ROUTE) ---
    if [ "$HAS_BRANCH" = true ]; then
        if [ "$HAS_TITLE" = false ]; then
            echo "⛔ PUBLISH FAILED: Code changes require a .tos/title for the commit message."
            exit 1
        fi
        
        BRANCH=\$(cat .tos/branch)
        TITLE=\$(cat .tos/title)

        echo "📦 Branch detected. Committing and pushing..."
        git checkout -B "\$BRANCH"
        git add .
        git commit -m "\$TITLE" -m "\$BODY"
        git push -u origin "\$BRANCH"

        if [ "$HAS_REF" = true ]; then
            REF=\$(cat .tos/ref)
            echo "💬 Updating PR #\$REF..."
            gh pr comment "\$REF" --body "\$BODY"
        else
            echo "✨ Creating new Pull Request..."
            NEW_REF=\$(gh pr create --title "\$TITLE" --body "\$BODY" --head "\$BRANCH" | grep -oE '[0-9]+$')
            echo "\$NEW_REF" > .tos/ref
        fi

    # --- 2. DISCUSSION ONLY (ISSUE ROUTE) ---
    else
        echo "📝 No branch detected. Routing to GitHub Issues..."
        if [ "$HAS_REF" = true ]; then
            REF=\$(cat .tos/ref)
            echo "💬 Commenting on Issue #\$REF..."
            gh issue comment "\$REF" --body "\$BODY"
        else
            if [ "$HAS_TITLE" = false ]; then
                echo "⛔ PUBLISH FAILED: Creating a new issue requires a .tos/title."
                exit 1
            fi
            echo "✨ Creating new Issue..."
            NEW_REF=\$(gh issue create --title "\$TITLE" --body "\$BODY" | grep -oE '[0-9]+$')
            echo "\$NEW_REF" > .tos/ref
        fi
    fi
SANDBOX

# Unlock Mutex
> "$TARGET_DIR/.tos/title"
> "$TARGET_DIR/.tos/body"
# Clean up legacy V57 files if they exist
rm -f "$TARGET_DIR/.tos/commit_msg" "$TARGET_DIR/.tos/pr_summary.md" 2>/dev/null

echo "✅ Published & Synced to GitHub. Sandbox unlocked for next task."
EOF

# --- 4. UPDATE: Agent Protocol Documentation ---
echo "📚 4. Updating Agent Documentation..."
AGENT_FILE="$AGENTS_ROOT/agents/team_of_six.md"
if [ -f "$AGENT_FILE" ]; then
    # Inject the new Mutex definition into the agent prompt
    sed -i '/## I. Context Hygiene & Constraints/i \
## The Output Mutex (V58)\n\
To finish a task, you MUST write your output to the `.tos/` directory using these files:\n\
* `.tos/title`: The summary (used for Commit Subject or Issue/PR Title).\n\
* `.tos/body`: The detailed explanation (used for Commit Body or Issue/PR Comment).\n\
* `.tos/branch`: (Optional) Write the feature branch name here if you are modifying code.\n\
* `.tos/ref`: (Managed by System) Contains the current Issue/PR ID. Do not modify it.\n\
If you fail to write `.tos/body`, the system will block.\n\n' "$AGENT_FILE"
    echo "✅ Agent definition updated."
fi

chmod +x "$BASE_DIR/tos_controller.sh" "$BIN_DIR"/*.sh
echo "✅ V58 Unified Publication Matrix applied successfully!"
