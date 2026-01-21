#!/bin/zsh
set -e
echo "🧹 Purging V55 System Artifacts..."
[ -f /etc/sudoers.d/team_of_six ] && sudo rm /etc/sudoers.d/team_of_six
rm -rf "$HOME/.team_of_six"
rm -f "$HOME/.local/bin/team_of_six"
id "team_of_six" &>/dev/null && sudo userdel team_of_six
getent group team_of_six &>/dev/null && sudo groupdel team_of_six
echo "✅ Purge Complete."
