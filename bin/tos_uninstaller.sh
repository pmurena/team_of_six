#!/bin/zsh
echo "🗑️  Team of Six: Full System Purge..."
sudo git config --system --unset-all safe.directory "*" || true
sudo umount /mnt/team_of_six || true
sudo sed -i '/team_of_six/d' /etc/fstab
sudo rm -rf /mnt/team_of_six
sudo userdel -r team_of_six || true
sudo groupdel team_of_six || true
sudo rm -f /usr/local/bin/team_of_six
echo "✅ System Purged."
