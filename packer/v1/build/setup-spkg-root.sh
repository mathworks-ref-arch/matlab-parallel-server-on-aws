#!/usr/bin/env bash
#
# Copyright 2024-2026 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

# Sets up sproot to force mpm to install SPKGS in a custom location

# This is currently required in this refarch despite installing to the deafult location
# to ensure MATLAB reads the support packages correctly.
# This may not be required when installation bugs (likely with mpm) are fixed. Please confirm periodically.

DEFAULT_SPKG_ROOT="${CLOUD_USER_HOME}/Documents/MATLAB/SupportPackages"

# For MATLAB R2025a and later, the support package location is set during the MATLAB
# install via mpm's --support-package-destination flag (see install-matlab.sh), so this
# script only needs to configure the legacy XML setting for R2024b and earlier.
if [[ $RELEASE < 'R2025a' ]]; then
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><SupportPackageRootSettings><Setting name=\"sproot\">${DEFAULT_SPKG_ROOT}/$RELEASE</Setting></SupportPackageRootSettings>" | sudo tee "${MATLAB_ROOT}/toolbox/local/supportpackagerootsetting.xml" > /dev/null
fi
