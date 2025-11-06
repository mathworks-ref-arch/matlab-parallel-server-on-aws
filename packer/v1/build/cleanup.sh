#!/usr/bin/env bash
#
# Copyright 2024-2025 The MathWorks, Inc.

# Exit on any failure
set -euo pipefail

# Clear build configuration files
sudo rm -rf /var/tmp/config/
sudo rm -rf /tmp/runtime/

# Clear SSH host keys
sudo rm -f /etc/ssh/ssh_host_*_key*
# Clear SSH local config (including authorized keys)
sudo rm -rf ~/.ssh/ /root/.ssh/

# Clear command history
rm -f ~/.bash_history ~/.sudo*

# Reset the system journal logs
sudo rm -rf /var/log/journal/*
sudo systemctl restart systemd-journald
