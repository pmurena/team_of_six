#!/bin/zsh

# --- Safety Check ---
echo "⚠️  DANGER ZONE: UNINSTALLING TEAM OF SIX"
echo "This will permanently delete:"
echo "  1. Sudoers rule (/etc/sudoers.d/team_of_six)"
echo "  2. System user & group (team_of_six)"
echo "  3. Local config (~/.team_of_six, ~/.local/bin/team_of_six)"
echo "  4. Storage data (/mnt/storage/team_of_six)"
echo ""
echo -n "Type 'DESTROY' to proceed: "
read CONFIRM

if [[ "$CONFIRM" != "DESTROY" ]]; then
    echo "Aborted."
    exit 1
fi

echo "\n🔥 Initiating removal sequence..."

# 1. Remove Sudoers Rule
if [ -f /etc/sudoers.d/team_of_six ]; then
    echo "Removing sudoers rule..."
    sudo rm /etc/sudoers.d/team_of_six
else
    echo "Sudoers rule not found (skipped)."
fi

# 2. Remove System User & Group
if id "team_of_six" &>/dev/null; then
    echo "Removing system user 'team_of_six'..."
    sudo userdel team_of_six
else
    echo "User 'team_of_six' not found (skipped)."
fi

# groupdel is usually handled by userdel, but we check to be sure
if getent group team_of_six &>/dev/null; then
    echo "Removing group 'team_of_six'..."
    sudo groupdel team_of_six
fi

# 3. Remove Local Files
echo "Cleaning local files..."
rm -rf ~/.team_of_six
rm -f ~/.local/bin/team_of_six

# 4. Remove Storage
if [ -d /mnt/storage/team_of_six ]; then
    echo "Wiping storage directory..."
    sudo rm -rf /mnt/storage/team_of_six
fi

echo "✅ Uninstall Complete. System is clean."
