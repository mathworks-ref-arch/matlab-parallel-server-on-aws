#!/usr/bin/env bash
#
# Copyright 2022-2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

sudo mkdir -p /opt/mathworks/
sudo mv /tmp/startup/ /opt/mathworks/
chmod -R +x /opt/mathworks/startup/*.sh
