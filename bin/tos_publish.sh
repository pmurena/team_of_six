#!/bin/zsh
set -e
while [[ "$#" -gt 0 ]]; do case $1 in -m) MSG="$2"; shift ;; esac; shift; done
[ -z "$MSG" ] && exit 1
source "$HOME/.team_of_six/tos_config"
unset GITHUB_TOKEN
source "$HOME/.team_of_six/.token"
sudo -u "$AI_USER" zsh <<SANDBOX
    export GITHUB_TOKEN='$GITHUB_TOKEN'
    cd "$(pwd)"
    git config --local url."https://x-access-token:\$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
    git add . && git commit -m "$MSG" && git push
SANDBOX
echo "✅ Published."
