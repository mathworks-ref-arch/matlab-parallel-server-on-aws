#!/usr/bin/env bash
#
# Copyright 2022-2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

# Check Python version
PYTHON_VERSION=$(python3 --version | awk '{print $2}')
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

# Set the appropriate get-pip.py URL based on Python version and install pip
# https://pip.pypa.io/en/stable/installation/#get-pip-py
if [[ $PYTHON_MINOR -le 8 ]]; then
    echo "Using Python 3.${PYTHON_MINOR} specific pip installer"
    curl "https://bootstrap.pypa.io/pip/3.${PYTHON_MINOR}/get-pip.py" | sudo python3
else
    echo "Using default pip installer"
    curl https://bootstrap.pypa.io/get-pip.py | sudo python3
fi

# Create folder
sudo mkdir -p /opt/mathworks/

# Install mwplatforminterfaces package
echo "Installing mwplatforminterfaces package"
sudo cp -R /tmp/runtime/mwplatforminterfaces/ /opt/mathworks/
sudo python3 -m pip install -e /opt/mathworks/mwplatforminterfaces/

# Install cluster_management package
echo "Installing cluster_management package"
sudo cp -R /tmp/runtime/cluster_management/ /opt/mathworks/
sudo chmod +x /opt/mathworks/cluster_management/cluster_management.py
sudo chmod +x /opt/mathworks/cluster_management/terminationpolicies/mjs_status_scripts/busy
sudo chmod +x /opt/mathworks/cluster_management/terminationpolicies/mjs_status_scripts/idle

# Install spotinstances package
echo "Installing spotinstances package"
sudo cp -R /tmp/runtime/spotinstances/ /opt/mathworks/
sudo chmod +x /opt/mathworks/spotinstances/handle_instance_interruption.py

# Configure the service and timer.
echo "Configuring the service and timer"
sudo cp /var/tmp/config/cluster_management/clustermanagement.{service,timer} /etc/systemd/system/
sudo cp /var/tmp/config/spotinstances/spotinstances.{service,timer} /etc/systemd/system/

# Install NFS scripts
echo "Installing NFS scripts"
sudo cp -R /tmp/runtime/nfs-share /opt/mathworks/nfs-share
sudo chmod 755 /opt/mathworks/nfs-share/setup_NFS_with_TLS.sh
sudo chmod 755 /opt/mathworks/nfs-share/warmup_mathworks_service_host.sh
# Functions script is only ever sourced, so execute bit is not needed
sudo chmod 655 /opt/mathworks/nfs-share/setup_NFS_with_TLS_functions.sh

echo "Reloading systemctl daemon"
sudo systemctl daemon-reload
