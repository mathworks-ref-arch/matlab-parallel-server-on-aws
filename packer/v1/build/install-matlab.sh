#!/usr/bin/env bash
#
# Copyright 2023-2026 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

LOCAL_USER=ubuntu

# Create MATLAB Home directory in ~/Documents,
mkdir -p /home/${LOCAL_USER}/Documents/MATLAB/

# Configure MATLAB_ROOT directory
sudo mkdir -p "${MATLAB_ROOT}"
sudo chmod -R 755 "${MATLAB_ROOT}"

cd ${TMP_DIR}

# Install and setup mpm.
# https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md
sudo apt-get -qq install \
  unzip \
  wget \
  ca-certificates
sudo wget --no-verbose https://www.mathworks.com/mpm/glnxa64/mpm
sudo chmod +x mpm

# The mpm --doc flag is supported in R2022b and older releases only.
# To install doc for offline use, follow the steps in
# https://www.mathworks.com/help/releases/R2023a/install/ug/install-documentation-on-offline-machines.html
doc_flag=""
if [[ $RELEASE < 'R2023a' ]]; then
  doc_flag="--doc"
fi

# If a source URL is provided, then use it to install MATLAB and toolboxes
release_arguments=""
source_arguments=""
if [[ -n "${MATLAB_SOURCE_URL}" ]]; then
    source /var/tmp/config/matlab/mount-data-drive-utils.sh
    mount_dir="/mnt"
    source_dir="${mount_dir}/matlab_source"
    mount_device_name="/dev/sdf"
    # Create and mount additional volume to the instance
    mount_data_drive "${mount_dir}" "${mount_device_name}"
    # Download the source artifacts to the mounted volume
    retrieve_artifacts "${MATLAB_SOURCE_URL}" "${source_dir}"
    # Source directory must contain an archives folder that mpm uses for installing products
    archives_path=$(find "${source_dir}" -type d -name "archives" -print -quit)
    source_arguments="--source=${archives_path}"
else
    release_arguments="--release=${RELEASE}"
fi

# Set the support package installation location during install for R2025a and later.
# mpm supports --support-package-destination only for R2025a onward, and only for new
# installations that do not already have a support package location set. For R2024b and
# earlier, setup-spkg-root.sh configures the location separately.
spkg_destination_arguments=""
if [[ $RELEASE > 'R2024b' ]]; then
    spkg_destination_arguments="--support-package-destination=${CLOUD_USER_HOME}/Documents/MATLAB/SupportPackages"
fi

# Run mpm to install MATLAB and the toolboxes listed in the PRODUCTS variable
# into the target location. The mpm executable is deleted afterwards
# The PRODUCTS variable should be a space separated list of products, with no surrounding quotes
# Use quotes around the destination argument if it contains spaces
sudo TMPDIR="${TMP_DIR}" ./mpm install \
  ${doc_flag} \
  ${release_arguments} \
  ${source_arguments} \
  ${spkg_destination_arguments} \
  --destination="${MATLAB_ROOT}" \
  --products ${PRODUCTS} \
  || (echo "MPM Installation Failure. See below for more information:" && cat ${TMP_DIR}/mathworks_root.log && false)

sudo rm -f mpm ${TMP_DIR}/mathworks_root.log

# Add symlink to MATLAB
sudo ln -s "${MATLAB_ROOT}/bin/matlab" /usr/local/bin

# Set keyboard settings to windows flavor for any new user
sudo mkdir -p "/etc/skel/.matlab/${RELEASE}"

# Enable DDUX collection by default for the VM
cd "${MATLAB_ROOT}/bin/glnxa64"
sudo ./ddux_settings -s -c

sudo mkdir -p "${MATLAB_ROOT}/licenses"
sudo chmod 775 "${MATLAB_ROOT}/licenses"

# Config MHLM Client setting
sudo cp /var/tmp/config/matlab/mhlmvars.sh /etc/profile.d/
