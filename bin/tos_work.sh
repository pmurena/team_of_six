#!/bin/zsh

# --- 0. Load Global Error Trapping ---
if [[ -f "$TOS_CONF/error_trap.sh" ]]; then
    source "$TOS_CONF/error_trap.sh"
fi

REF=$1

if [[ -z "$REF" ]]; then
    logger -t tos_ghost -p user.err "Failed: No REF provided to tos_work.sh"
    echo "Usage: tos <project_name> work <issue_or_pr_id_or_branch>"
    exit 1
fi

# 1. Arm the Ghost
if [[ -f "$TOS_GIT_TOKEN" ]]; then
    export GH_TOKEN=$(cat "$TOS_GIT_TOKEN")
else
    logger -t tos_ghost -p user.err "Authentication Failed: $TOS_GIT_TOKEN not found."
    echo "🚨 ERROR: Ghost has no GitHub credentials."
    exit 1
fi

export GH_PAGER=cat
export GH_PROMPT_DISABLED=1
export NO_COLOR=1

cd "$TOS_WORKING_DIR" || {
    logger -t tos_ghost -p user.err "Failed to cd into $TOS_WORKING_DIR"
    exit 1
}

# --- STAGE 1: Fetch Remote Truth ---
logger -t tos_ghost -p user.info "Fetching Remote Truth for REF: $REF in $TOS_WORKING_DIR"
git fetch origin --prune &>/dev/null

# --- STAGE 2: Enforce Strict Remote Truth (Wipeout Strategy) BEFORE Checkout ---
DIRTY_FILES=$(git status --porcelain 2>/dev/null)
if [[ -n "$DIRTY_FILES" ]]; then
    logger -t tos_ghost -p user.warn "Dirty sandbox detected. Logging artifacts marked for destruction:"
    
    echo "$DIRTY_FILES" | while read -r line; do
        # ${line:3} strips the 2-character git status code and the space
        logger -t tos_ghost -p user.warn "  -> Purging: ${line:3}"
    done
    
    echo "⚠️  Warning: Uncommitted Ghost artifacts detected. Sandbox has been purged to match remote truth."
fi

# 1. Annihilate any uncommitted modified tracked files
git reset --hard HEAD &>/dev/null
# 2. Obliterate any untracked garbage files/folders
git clean -fd &>/dev/null

# --- STAGE 3: Align Sandbox (Checkout & Sync) ---
logger -t tos_ghost -p user.info "Checking out REF $REF locally..."
# Smart checkout: Handle PR IDs (e.g., '8') or Branches (e.g., 'main')
if [[ "$REF" =~ ^[0-9]+$ ]]; then
    gh pr checkout "$REF" &>/dev/null || git checkout "$REF" &>/dev/null
else
    git checkout "$REF" &>/dev/null
    # Force local branch to perfectly mirror the origin, just in case local was clean but stale
    git reset --hard "origin/$REF" &>/dev/null || git pull origin "$REF" --ff-only &>/dev/null
fi

# --- STAGE 4: Generate the Outbox (Dual-Routing output to Buffer and Journal) ---
{
    echo "# WORK CONTEXT: $REF\n"

    echo "## TARGET DETAILS & THREAD"
    if ! PR_OUTPUT=$(gh pr view "$REF" --comments 2>&1); then
        logger -t tos_ghost -p user.warn "PR $REF not found. Trying Issue view."
        if ! ISSUE_OUTPUT=$(gh issue view "$REF" --comments 2>&1); then
            logger -t tos_ghost -p user.info "No PR/Issue found for $REF. Working directly on branch."
            echo "Working directly on branch: $REF"
        else
            echo "$ISSUE_OUTPUT"
        fi
    else
        echo "$PR_OUTPUT"
        
        echo -e "\n## PR REVIEWS (MAIN SUMMARIES)"
        REV_OUTPUT=$(gh pr view "$REF" --json reviews --jq '.reviews[]? | select(.body != "") | "--- \nReview by \(.author.login) (\(.state)):\n\(.body)\n"' 2>/dev/null)
        [[ -n "$REV_OUTPUT" ]] && echo "$REV_OUTPUT"
        
        echo -e "\n## PR INLINE CODE COMMENTS"
        # Using Unicode \u0060 for backticks to prevent Markdown parsing truncation bugs
        INLINE_OUTPUT=$(gh api "repos/:owner/:repo/pulls/$REF/comments" --jq '.[]? | "--- \nFile: \(.path)\nReviewer: \(.user.login)\n\nCode Snippet:\n\u0060\u0060\u0060diff\n\(.diff_hunk)\n\u0060\u0060\u0060\n\nComment: \(.body)\n"' 2>/dev/null)
        [[ -n "$INLINE_OUTPUT" ]] && echo "$INLINE_OUTPUT"
    fi
    
    echo -e "\n## CURRENT DIFF (origin/main...HEAD)"
    git diff origin/main...HEAD
    
    # --- FULL SOURCE OF MODIFIED FILES ---
    echo -e "\n## FULL SOURCE OF MODIFIED FILES"
    # git diff --name-only gets the file paths. --diff-filter=d ensures we don't try to cat deleted files.
    for file in $(git diff --name-only --diff-filter=d origin/main...HEAD 2>/dev/null); do
        if [[ -f "$file" ]]; then
            echo -e "\n### File: \`$file\`"
            echo '\u0060\u0060\u0060'
            cat "$file"
            echo '\u0060\u0060\u0060'
        fi
    done
    
    # --- EXPLICITLY REQUESTED FILES ---
    shift
    if [[ $# -gt 0 ]]; then
        echo -e "\n## EXPLICITLY REQUESTED FILES"
        for req_file in "$@"; do
            if [[ -f "$req_file" ]]; then
                echo -e "\n### File: \`$req_file\`"
                echo '\u0060\u0060\u0060'
                cat "$req_file"
                echo '\u0060\u0060\u0060'
            else
                logger -t tos_ghost -p user.warn "Requested file $req_file not found."
                echo "⚠️ Warning: Requested file $req_file not found."
            fi
        done
    fi

    # --- THE REPOSITORY RADAR ---
    echo -e "\n## REPOSITORY SIGNATURE MAP"
    echo "The following is the complete list of functions and structures. If you need to see the full source code of any file not provided above, ask the Architect to run 'tos <project> peek <filepath>'."
    
    if command -v ctags &> /dev/null; then
        ctags -x -R --exclude=.git . 2>/dev/null
    else
        logger -t tos_ghost -p user.warn "Missing Dependency: 'ctags' not found. Falling back to 'git ls-files'."
        echo "⚠️ Warning: 'ctags' (Universal Ctags) is not installed. Signature Map unavailable."
        git ls-files
    fi
    
} > "$TOS_CONTEXT"

logger -t tos_ghost -p user.info "Context successfully staged at $TOS_CONTEXT"
echo "✅ Context staged at $TOS_CONTEXT"
