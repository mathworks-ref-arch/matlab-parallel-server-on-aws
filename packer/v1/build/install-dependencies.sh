#!/usr/bin/env bash
#
# Copyright 2022-2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

# Initialise apt
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

# Ensure essential utilities are installed
sudo apt-get -qq install gcc make unzip wget

cd /tmp

# Install AWS CLI
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -qq awscliv2.zip && rm awscliv2.zip
sudo ./aws/install
sudo rm -rf aws

# Download and install CloudWatch agent package
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/download-cloudwatch-agent-commandline.html
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
sudo rm amazon-cloudwatch-agent.deb

# Install NVMe cli
sudo apt-get -qq install nvme-cli

# Install jq
sudo apt-get -qq install jq

# Install xq
# https://github.com/sibprogrammer/xq
curl -sSL https://bit.ly/install-xq | sudo bash

# Disable Open Source nVidia Nouveau driver, if present.
DISABLE_NOUVEAU_FILE="disable_nouveau_driver.conf"
MODPROBE_TREE="/etc/modprobe.d/"

echo blacklist amd76x_edac > /tmp/${DISABLE_NOUVEAU_FILE}
echo blacklist vga16fb >> /tmp/${DISABLE_NOUVEAU_FILE}
echo blacklist rivafb >> /tmp/${DISABLE_NOUVEAU_FILE}
echo blacklist nvidiafb >> /tmp/${DISABLE_NOUVEAU_FILE}
echo blacklist rivatv >> /tmp/${DISABLE_NOUVEAU_FILE}
echo blacklist nouveau >> /tmp/${DISABLE_NOUVEAU_FILE}
echo blacklist lbm-nouveau >> /tmp/${DISABLE_NOUVEAU_FILE}
echo options nouveau modeset=0  >> /tmp/${DISABLE_NOUVEAU_FILE}
echo alias nouveau off  >> /tmp/${DISABLE_NOUVEAU_FILE}
echo alias lbm-nouveau off  >> /tmp/${DISABLE_NOUVEAU_FILE}
sudo mv /tmp/${DISABLE_NOUVEAU_FILE} ${MODPROBE_TREE}/
sudo chown root:root  ${MODPROBE_TREE}/${DISABLE_NOUVEAU_FILE}
sudo chmod 755  ${MODPROBE_TREE}/${DISABLE_NOUVEAU_FILE}
sudo update-initramfs -u

# Install nvidia-driver
if [[ -n "${NVIDIA_DRIVER_VERSION}" ]]; then
  sudo apt-get -y -qq install --no-install-recommends "nvidia-driver-${NVIDIA_DRIVER_VERSION}-server"
fi

# Install CloudFormation helper scripts
# https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-helper-scripts-reference.html
wget --no-verbose https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz
AWS_CFN_INSTALL_DIR=aws-cfn-bootstrap-latest
mkdir $AWS_CFN_INSTALL_DIR
tar -xzf aws-cfn-bootstrap-py3-latest.tar.gz -C $AWS_CFN_INSTALL_DIR --strip-components=1
(
  cd $AWS_CFN_INSTALL_DIR
  sudo python3 setup.py -q install --install-scripts /opt/aws/bin
)
sudo rm -rf aws-cfn-bootstrap-*

# Install amazon-efs-utils for mounting the Elastic File System
# https://github.com/aws/efs-utils
sudo apt-get update
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb

# Install stunnel and nfs-kernel-server for NFS share
sudo apt-get -qq install nfs-kernel-server nfs-common stunnel4 xxd
# Do not start on boot
sudo systemctl disable stunnel4 nfs-server
