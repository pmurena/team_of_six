#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

echo "⚡ PARSING PROJECT META"
"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "META" "$TOS_PARSE_DIR" "TARGET_PROJECT" "TITLE" "BODY"

PROJECT=$(cat "$TOS_PARSE_DIR/1/TARGET_PROJECT.txt" 2>/dev/null)
BODY=$(cat "$TOS_PARSE_DIR/1/BODY.txt" 2>/dev/null)

if [[ -z "$PROJECT" ]]; then
    echo "🚨 [ERROR] create project: Missing TARGET_PROJECT in META block." >&2
    exit 1
fi

truncate -s 0 "$TOS_INPUT"

echo "🚀 CREATING GITHUB REPOSITORY: $PROJECT"
PROJECT_DIR="$TOS_SANDBOX/$PROJECT"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

git init -q
git checkout -b main -q
git remote add origin "https://github.com/${SUDO_USER}/${PROJECT}.git" 2>/dev/null || true
gh repo create "$PROJECT" --public --description "$BODY" --source=. --remote=origin --push
