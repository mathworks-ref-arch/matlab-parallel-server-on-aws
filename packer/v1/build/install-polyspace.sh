#!/usr/bin/env bash
#
# Copyright 2024-2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

# Install and setup mpm.
# https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md
sudo apt-get -qq install \
  unzip \
  wget \
  ca-certificates
wget --no-verbose https://www.mathworks.com/mpm/glnxa64/mpm
sudo chmod +x mpm

# If a source URL is provided, then use it to install Polyspace
release_arguments=""
source_arguments=""
if [[ -n "${MATLAB_SOURCE_URL}" ]]; then
    source_dir="/mnt/matlab_source"
    # Source directory must contain an archives folder that mpm uses for installing products
    archives_path=$(find "${source_dir}" -type d -name "archives" -print -quit)
    source_arguments="--source=${archives_path}"
else
    release_arguments="--release=${RELEASE}"
fi

# Use mpm for installing Polyspace. The MPM executable is then deleted
sudo ./mpm install \
  ${release_arguments} \
  ${source_arguments} \
  --destination="${POLYSPACE_ROOT}" \
  --products ${POLYSPACE_PRODUCTS} \
  || (echo "MPM Installation Failure. See below for more information:" && cat /tmp/mathworks_root.log && exit 1)
  
sudo rm -f mpm /tmp/mathworks_root.log

# If a source URL was provided, delete the source archive
if [[ -n "${MATLAB_SOURCE_URL}" ]]; then
    source /var/tmp/config/matlab/mount-data-drive-utils.sh
    mount_device_name="/dev/sdf"
    remove_data_drive "${source_dir}" "${mount_device_name}"
fi

# Point MATLAB Parallel Server at polyspace install
sudo sed -i "s|^# POLYSPACE_SERVER_ROOT=.*|POLYSPACE_SERVER_ROOT=${POLYSPACE_ROOT}|g" "${MATLAB_ROOT}/toolbox/parallel/bin/mjs_polyspace.conf"
