#!/bin/zsh
# Team of Six - Project Creator
# V56.3 Refactor: Colocation Validation + Safety Guard

set -e
PROJECT_NAME=$1

# --- HELPER FUNCTIONS ---
log_error() { echo "⛔ ERROR: $1" >&2; }
log_success() { echo "✅ $1"; }

# --- 1. ARGUMENT VALIDATION ---
if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: team_of_six new <project_name>"
    exit 1
fi

# --- 2. SAFETY GUARD (Prevent Overwrite) ---
if [ -d "$PROJECT_NAME" ]; then
    log_error "Directory '$PROJECT_NAME' already exists. Aborting."
    exit 1
fi

# --- 3. COLOCATION VALIDATION (Tri-Repo) ---
TOS_DIR="$HOME/.team_of_six"
[ -f "$TOS_DIR/tos_config" ] && source "$TOS_DIR/tos_config"

if [[ ! -d "team_of_six" ]] || [[ ! -d "llm_agents" ]]; then
    log_error "Projects must be colocated with 'team_of_six' and 'llm_agents' (Zone Root)."
    echo "   Current Directory: $(pwd)"
    exit 1
fi

# --- 4. EXECUTION ---
mkdir -p "$PROJECT_NAME/.tos"
echo "Scaffolding" > "$PROJECT_NAME/.tos/state"
touch "$PROJECT_NAME/.tos/objections.md"

cat <<BACKLOG > "$PROJECT_NAME/.tos/features.md"
# 📋 Project Backlog: $PROJECT_NAME
* [ ] Initial Architecture (Current)
BACKLOG

# Ghost Ownership is implicit (files owned by creator)
log_success "Project '$PROJECT_NAME' initialized."
