#!/usr/bin/env bash
#
# Copyright 2023-2026 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

cd ${TMP_DIR}/

if [[ ! -n $SPKGS ]]; then
     # If no SPKGS are designated for installation, skip this script
     echo "No SPKGS defined for installation, skipping install..."
     exit 0
fi

# Install and setup mpm.
# https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md
sudo apt-get -qq install \
  unzip \
  wget \
  ca-certificates
sudo wget --no-verbose https://www.mathworks.com/mpm/glnxa64/mpm
sudo chmod +x mpm

# If a source URL is provided, then use it to install MATLAB support packages.
release_arguments=""
source_arguments=""
if [[ -n "${SPKG_SOURCE_URL}" ]]; then
    source /var/tmp/config/matlab/mount-data-drive-utils.sh
    spkg_src_dir="/mnt/spkg_source"
    # This downloads the source artifacts to the mounted vol
    retrieve_artifacts "${SPKG_SOURCE_URL}" "${spkg_src_dir}"
    # Source directory must contain an archives folder that mpm uses for installing products
    archives_path=$(find "${spkg_src_dir}" -type d -name "archives" -print -quit)
    # Copy the VersionInfo.xml file to the archives directory to allow mpm to verify products to install
    sudo cp ${MATLAB_ROOT}/VersionInfo.xml $(dirname "${archives_path}")
    source_arguments="--source=${archives_path}"
else
    release_arguments="--release=${RELEASE}"
fi

# Define the support packages installation directory under CLOUD_USER_HOME
SPKG_ROOT="${CLOUD_USER_HOME}/Documents/MATLAB/SupportPackages"

# Use mpm to install support packages in the SPKGS variable
# into the target location. The mpm installation is deleted afterwards.
# The SPKGS variable should be a space separated list of support packages, with no surrounding quotes.
# Use quotes around the destination argument if it contains spaces.
sudo TMPDIR="${TMP_DIR}" \
  HOME=${CLOUD_USER_HOME} \
  ./mpm install \
  ${release_arguments} \
  ${source_arguments} \
  --destination ${MATLAB_ROOT} \
  --products ${SPKGS} \
  || (echo "MPM Installation Failure. See below for more information:" && cat ${TMP_DIR}/mathworks_root.log  && false)

sudo rm -f mpm ${TMP_DIR}/mathworks_root.log

sudo rm -rf ${CLOUD_USER_HOME}/.MathWorks
