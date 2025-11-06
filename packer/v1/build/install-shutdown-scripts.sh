#!/usr/bin/env bash

# Copyright 2024-2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euxo pipefail

# Install shutdown scripts
sudo cp -R /tmp/shutdown /opt/mathworks/
sudo chmod +x /opt/mathworks/shutdown/*.sh

sudo cp /var/tmp/config/shutdown/run-at-shutdown.service /etc/systemd/system/
sudo cp /var/tmp/config/shutdown/run-at-shutdown-scripts.sh /opt/mathworks/run-at-shutdown-scripts.sh

# Master script that calls other scripts under /opt/mathworks/shutdown during system shutdown
sudo chmod +x /opt/mathworks/run-at-shutdown-scripts.sh
sudo systemctl daemon-reload
