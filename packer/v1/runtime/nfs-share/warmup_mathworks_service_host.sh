#!/usr/bin/env bash
#
# Copyright 2025 The MathWorks, Inc.

# Print commands for logging purposes, including timestamps.
PS4='+ [\d \t] '
set -x

MSH_ROOT_PATH="/opt/MathWorks/ServiceHost"
MATLAB_ROOT="$(dirname $(dirname $(readlink -f $(which matlab))))"

if [[ -d "${MSH_ROOT_PATH}" ]] && [[ -n "${MATLAB_ROOT}" ]]; then
    "${MATLAB_ROOT}/bin/glnxa64/MATLABStartupAccelerator" 64 "$MSH_ROOT_PATH" <(find "$MSH_ROOT_PATH" -type f) /var/log/mshsa.log
    echo 'MSH warm up done.'
fi
