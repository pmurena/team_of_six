#!/bin/zsh
# ==============================================================================
# Title: Trinity Workspace Activator
# Usage: tos <project> sync trinity <ID>
#
# Orchestrates workspace transitions via an Atomic Handover.
# Acquires the global lock, checks out the dedicated branch, and
# generates a Clean Room Snapshot of the context in the outbox.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="$1"
TRINITY_ID="$2"
[[ -z "$TRINITY_ID" ]] && { echo "Usage: tos <project> sync trinity <ID>"; exit 1; }

# Map Trinity 0 to the main branch
if [[ "$TRINITY_ID" == "0" ]]; then
    BRANCH_NAME="main"
else
    BRANCH_NAME="tos-work-$TRINITY_ID"
fi

export GH_PAGER=cat
export GH_PROMPT_DISABLED=1
export NO_COLOR=1

GLOBAL_LOCKS="$TOS_MNT_ROOT/.ipc/locks"

# --- Atomic Handover: Preserve Old State ---
# Find the current lock owned by this Architect for this project
for file in "$GLOBAL_LOCKS/${PROJECT_NAME}_trinity_"*.lock(N); do
    if [[ -f "$file" ]] && grep -q "$SUDO_USER" "$file"; then
        OLD_TRINITY=$(basename "$file" | sed -n 's/.*_trinity_\([0-9]*\)\.lock/\1/p')

        # If transitioning away from an active Hard-Lock, push work first
        if [[ "$OLD_TRINITY" != "$TRINITY_ID" && "$OLD_TRINITY" != "0" ]]; then
            echo "💾 Preserving current state of Trinity $OLD_TRINITY before transition..."
            cd "$TOS_SANDBOX/$PROJECT_NAME" 2>/dev/null && {
                git push origin "tos-work-$OLD_TRINITY" -q 2>/dev/null || true
            }
        fi
        break
    fi
done

# --- Lock Acquisition ---
"$TOS_BIN/utils/lock/acquire.zsh" "$PROJECT_NAME" "$TRINITY_ID" || exit 1

cd "$TOS_SANDBOX/$PROJECT_NAME" || exit 1

echo "🧹 Enforcing Remote Truth..."
git fetch origin --prune &>/dev/null
git reset --hard HEAD &>/dev/null
git clean -fd &>/dev/null

# Always update the local baseline
git checkout main &>/dev/null
git pull origin main &>/dev/null

if [[ "$TRINITY_ID" == "0" ]]; then
    echo "🚀 Routing Ghost to Sanctuary (Trinity 0 - Read-Only Baseline)"
else
    echo "🚀 Routing Ghost to Workspace: $BRANCH_NAME"
    if git rev-parse --verify "origin/$BRANCH_NAME" >/dev/null 2>&1; then
        git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME" &>/dev/null
    else
        git checkout -b "$BRANCH_NAME" &>/dev/null
    fi
fi

# --- Context Regeneration (Clean Room Snapshot) ---
echo "# TRINITY CONTEXT: #${TRINITY_ID} (Branch: $BRANCH_NAME)\n"
echo "TARGET_PROJECT=$PROJECT_NAME"
echo "TARGET_TRINITY=$TRINITY_ID"

if [[ "$TRINITY_ID" != "0" ]]; then
	gh issue view "$TRINITY_ID" --comments 2>&1

	if gh pr view "$BRANCH_NAME" &>/dev/null; then
		echo -e "\n## PULL REQUEST CONTEXT & COMMENTS"
		gh pr view "$BRANCH_NAME" --comments 2>&1
	fi
else
	echo "STATE: SANCTUARY (Main Branch / Baseline)"
	echo "WARNING: Write Code operations are strictly blocked in Trinity 0."
fi

echo -e "\n## CURRENT DIFF (origin/main...HEAD)"
git diff origin/main...HEAD

echo -e "\n## REPOSITORY SIGNATURE MAP"
if command -v ctags &>/dev/null; then
	ctags -x -R --exclude=.git . 2>/dev/null
else
	git ls-files
fi
