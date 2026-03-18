#!/bin/bash
# ==============================================================================
# team_of_six - Core Workflow Engine (v1.0.0 - Post-v57 Rewrite)
# ==============================================================================
# This engine enforces the new team_of_six workflow:
# Local Git Check -> Issue Creation -> Commit Management -> PR Generation
# ==============================================================================

set -e

# --- Configuration ---
MAIN_BRANCH="main" # Change to 'master' if necessary

# --- Helper: Print formatting ---
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

# ==============================================================================
# Module 1: System & Git State Checks
# ==============================================================================
check_environment() {
    # 1. Check if we are in a Git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        error "Not a Git repository. Please run this inside the project root."
    fi

    # 2. Check for GitHub CLI (required for issue/PR generation)
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI ('gh') is not installed or authenticated. Please install it."
    fi
    
    # 3. Check for uncommitted changes before starting new workflows
    if ! git diff-index --quiet HEAD --; then
        info "Warning: You have uncommitted local changes."
    fi
}

# ==============================================================================
# Module 2: Issue Creation & Branching
# ==============================================================================
create_issue() {
    local title="$1"
    if [ -z "$title" ]; then
        error "Provide an issue title: ./team_of_six.sh issue \"Your Issue Title\""
    fi

    info "Creating new issue: $title"
    
    # Create issue via GitHub CLI and capture the issue number
    # (Assuming interactive body prompt or you can pass --body)
    local issue_url=$(gh issue create --title "$title" --body "Generated via team_of_six workflow." | tail -n 1)
    local issue_num=$(echo "$issue_url" | awk -F'/' '{print $NF}')
    
    if [ -z "$issue_num" ]; then
        error "Failed to create issue."
    fi

    success "Issue #$issue_num created: $issue_url"

    # Enforce workflow: create and checkout a branch for this issue
    local branch_name="issue-${issue_num}-$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//')"
    
    git checkout -b "$branch_name"
    success "Checked out new workflow branch: $branch_name"
}

# ==============================================================================
# Module 3: Commit Wrapper
# ==============================================================================
create_commit() {
    local message="$1"
    if [ -z "$message" ]; then
        error "Provide a commit message: ./team_of_six.sh commit \"Your message\""
    fi

    local current_branch=$(git branch --show-current)
    if [ "$current_branch" == "$MAIN_BRANCH" ]; then
        error "Direct commits to $MAIN_BRANCH are not allowed in the team_of_six workflow."
    fi

    info "Staging all changes..."
    git add .

    info "Committing changes..."
    # Auto-append branch name (which contains issue #) to commit message for linking
    git commit -m "[$current_branch] $message"
    
    success "Changes committed successfully."
}

# ==============================================================================
# Module 4: PR Generation
# ==============================================================================
create_pr() {
    local current_branch=$(git branch --show-current)
    
    if [ "$current_branch" == "$MAIN_BRANCH" ]; then
        error "You are on $MAIN_BRANCH. Please checkout an issue branch to create a PR."
    fi

    info "Pushing branch '$current_branch' to remote..."
    git push -u origin "$current_branch"

    info "Generating Pull Request..."
    # Extract issue number from branch name to link the PR automatically
    local issue_num=$(echo "$current_branch" | grep -o -E '[0-9]+' | head -1)
    local pr_body="Resolves #$issue_num"

    gh pr create --title "Merge $current_branch" --body "$pr_body" --base "$MAIN_BRANCH"
    
    success "Pull Request created successfully."
}

# ==============================================================================
# Main Router
# ==============================================================================
COMMAND=$1
shift # Shift arguments so $@ contains only command arguments

case "$COMMAND" in
    issue)
        check_environment
        create_issue "$*"
        ;;
    commit)
        check_environment
        create_commit "$*"
        ;;
    pr)
        check_environment
        create_pr
        ;;
    status)
        check_environment
        info "Current Branch: $(git branch --show-current)"
        git status -s
        ;;
    *)
        echo "======================================================="
        echo " team_of_six workflow engine"
        echo "======================================================="
        echo "Usage: ./team_of_six.sh [command] [arguments]"
        echo ""
        echo "Commands:"
        echo "  issue \"Title\"   - Creates a GH issue and a linked branch"
        echo "  commit \"Msg\"    - Stages all files and commits to current branch"
        echo "  pr              - Pushes current branch and creates a PR"
        echo "  status          - Shows Git environment status"
        echo "======================================================="
        exit 1
        ;;
esac
