#!/usr/bin/env bash
#
# Copyright 2023-2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

UBUNTU_VERSION=$(lsb_release -rs | tr -d '.')

# Install patched glibc for ubuntu focal(20.04) - See https://github.com/mathworks/build-glibc-bz-19329-patch
if [[ $UBUNTU_VERSION -eq 2004 ]]; then
        cd /tmp
        wget -q https://github.com/mathworks/build-glibc-bz-19329-patch/releases/download/ubuntu-focal/all-packages.tar.gz
        tar -x -f all-packages.tar.gz --wildcards libc-bin_*.deb libc6_*.deb locales-all*.deb locales_*.deb nscd_*.deb
        sudo apt-get install --yes --no-install-recommends ./*.deb
fi
