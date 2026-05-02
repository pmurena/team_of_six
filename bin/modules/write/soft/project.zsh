#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

echo "⚡ PARSING PROJECT META"
"$TOS_BIN/utils/parse_blocks.zsh" "$TOS_INPUT" "META" "$TOS_PARSE_DIR" "TARGET_PROJECT" "TITLE" "BODY"

PROJECT=$(cat "$TOS_PARSE_DIR/1/TARGET_PROJECT.txt" 2>/dev/null)
BODY=$(cat "$TOS_PARSE_DIR/1/BODY.txt" 2>/dev/null)

if [[ -z "$PROJECT" ]]; then
    echo "🚨 [ERROR] write project: Missing TARGET_PROJECT in META block." >&2
    exit 1
fi

truncate -s 0 "$TOS_INPUT"

echo "🚀 CREATING GITHUB REPOSITORY: $PROJECT"
PROJECT_DIR="$TOS_SANDBOX/$PROJECT"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

git init -q
git checkout -b main -q

git config user.name "Ghost"
git config user.email "ghost@teamofsix.local"
echo "# ${PROJECT}" > README.md
[[ -n "$BODY" ]] && echo "\n$BODY" >> README.md
git add README.md
git commit -m "chore: initial commit by Ghost" -q

# Notice: We removed the manual 'git remote add origin' line!
# We let the 'gh' CLI configure the true remote dynamically.
if ! gh repo create "$PROJECT" --private --description "$BODY" --source=. --remote=origin --push; then
    echo "🚨 [ERROR] write project: GitHub CLI failed to create and push the repository." >&2
    exit 1
fi

