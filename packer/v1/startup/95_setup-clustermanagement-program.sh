#!/usr/bin/env bash

# Copyright 2024-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x

# Initialize cluster management data file.
termination_policy="${TERMINATION_POLICY}"

# Determine termination policy
if [[ "${TERMINATION_POLICY}" == "When cluster is idle" ]]; then
    termination_policy="on_idle"
elif [[ ! "${TERMINATION_POLICY}" =~ ^After\ [0-9]+\ hour[s]?$ ]]; then
    termination_policy="never"
fi

# Set auto_termination_flag based on user's choice
auto_termination_flag=$([[ "${TERMINATION_POLICY}" != 'Disable auto-termination' ]] && echo "true" || echo "false")

# Check if the current node is the HEADNODE
if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then

    # Update the cluster management data file with the appropriate settings.
    jq --arg desired_cap "${DESIRED_CAPACITY}" \
       --arg policy "$termination_policy" \
       --arg mjs_status_log_file "${MJS_STATUS_LOG_FILE}" \
       --argjson auto_termination_flag $auto_termination_flag \
       '.config.initial_desired_capacity=$desired_cap |
        .state.last_termination_policy=$policy |
        .config.initial_termination_policy=$policy |
        .config.mjs_status_log_file=$mjs_status_log_file |
        .config.autotermination_enabled=$auto_termination_flag' \
       ${CLUSTER_MANAGEMENT_DATA_FILE} > tmp.$$.json && mv tmp.$$.json ${CLUSTER_MANAGEMENT_DATA_FILE}

    # Set up MJS Cluster for Auto-Resizing
    # Reference: https://www.mathworks.com/help/matlab-parallel-server/set-up-your-mjs-cluster-for-resizing.html

    # Determine autoscaling_flag based on ENABLE_AUTOSCALING and MATLAB_RELEASE
    autoscaling_flag='false'
    if [[ ${ENABLE_AUTOSCALING} == 'Yes' ]] && [[ "${MATLAB_RELEASE}" > 'R2021b' ]]; then
        autoscaling_flag='true'
    elif [[ ${ENABLE_AUTOSCALING} == 'Yes' ]]; then
        echo 'WARNING: Auto-Resizing is only available for R2022a and later.'
    fi

    # Apply the autoscaling setting to the cluster management data file.
    jq --argjson flag "$autoscaling_flag" \
       '.config.autoscaling_enabled=$flag' \
       ${CLUSTER_MANAGEMENT_DATA_FILE} > temp.json && mv temp.json ${CLUSTER_MANAGEMENT_DATA_FILE}

    systemctl enable clustermanagement.timer
    systemctl start clustermanagement.timer
fi