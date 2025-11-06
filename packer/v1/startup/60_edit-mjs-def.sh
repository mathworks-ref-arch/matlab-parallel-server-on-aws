#!/usr/bin/env bash

# Copyright 2022-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x


# This script defines MATLAB Job Scheduler Startup Parameters
# https://www.mathworks.com/help/matlab-parallel-server/define-startup-parameters.html


#######################################
# Edit the MJS startup parameters in the mjs_def
# Arguments:
#   Parameter Name
#   Parameter Value
# Returns:
#   0 if parameter was set successfully, non-zero on error.
#######################################
edit_mjs_def () {
    local parameter_name="$1"
    local parameter_value="$2"

    sed -i "s|^#${parameter_name}=.*|${parameter_name}=\"${parameter_value}\"|" "${MJS_DEF_FILE}"
    if ! (grep -q "^${parameter_name}=" "${MJS_DEF_FILE}"); then
        echo "Failed to set parameter ${parameter_name}"
        exit 1
    fi
}

# Set folder used to store mjs checkpoint folders
edit_mjs_def 'CHECKPOINTBASE' "${CHECKPOINT_ROOT}"

# Set MATLAB Job Scheduler Cluster Security Level
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html
if [[ -n "${SECURITY_LEVEL}" ]]; then
    edit_mjs_def 'SECURITY_LEVEL' "${SECURITY_LEVEL}"

    # Generate default password for ADMIN_USER at Security Level 2 and 3
    if [[ "${SECURITY_LEVEL}" -ge '2' && ! -f "${MJS_ADMIN_PASSWORD_FILE}" ]]; then
        MJS_ADMIN_PASSWORD_ROOT=$(dirname ${MJS_ADMIN_PASSWORD_FILE})
        if [[ ! -d "${MJS_ADMIN_PASSWORD_ROOT}" ]]; then
            mkdir -p "${MJS_ADMIN_PASSWORD_ROOT}"
            chown -R ${CLOUD_USER}:${CLOUD_USER} "${MJS_ADMIN_PASSWORD_ROOT}"
            chmod 700 "${MJS_ADMIN_PASSWORD_ROOT}"
        fi
        cat /dev/urandom | tr -dc 'A-Za-z0-9$-_.+!*()' | fold -w 32 | head -n 1 > ${MJS_ADMIN_PASSWORD_FILE}
    fi
fi

# Set Encrypted Communication
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html#bsohndi-1
edit_mjs_def 'USE_SECURE_COMMUNICATION' 'true'

# Set Cluster Command Verification
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html#mw_ca721746-0154-4d20-9a6e-753bed4d4058
# For releases MATLAB R2023a and later, this variable makes the mjs service verify each command with the secret file before execution.
if [[ "${MATLAB_RELEASE}" > 'R2022b' ]]; then
    edit_mjs_def 'REQUIRE_SCRIPT_VERIFICATION' 'true'
fi

# Require MATLAB clients to present a certificate to connect to the job manager
edit_mjs_def 'REQUIRE_CLIENT_CERTIFICATE' 'true'

# Increase heap memory available to MJS
# https://www.mathworks.com/help/matlab-parallel-server/customize-startup-parameters.html
MEMORY_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
    JOB_MANAGER_MAXIMUM_MEMORY_MB=$(( 1024 + 5*MAX_NODES*WORKERS_PER_NODE ))
    if (( JOB_MANAGER_MAXIMUM_MEMORY_MB > MEMORY_MB/2 )); then
        JOB_MANAGER_MAXIMUM_MEMORY_MB=$(( MEMORY_MB/2 ))
    fi

    edit_mjs_def 'JOB_MANAGER_MAXIMUM_MEMORY' "${JOB_MANAGER_MAXIMUM_MEMORY_MB}m"

else
    WORKER_MAXIMUM_MEMORY_MB=$(( 1024 + 64*WORKERS_PER_NODE ))
    if (( WORKER_MAXIMUM_MEMORY_MB > MEMORY_MB/4 )); then
        WORKER_MAXIMUM_MEMORY_MB=$(( MEMORY_MB/4 ))
    fi

    edit_mjs_def 'WORKER_MAXIMUM_MEMORY' "${WORKER_MAXIMUM_MEMORY_MB}m"
fi

# Use a license that is managed online.
if [[ -z ${MLM_LICENSE_FILE} ]]; then
    edit_mjs_def 'USE_ONLINE_LICENSING' 'true'
fi

# Set up MJS Cluster for Auto-Resizing
# https://www.mathworks.com/help/matlab-parallel-server/set-up-your-mjs-cluster-for-resizing.html
if [[ ${NODE_TYPE} == 'HEADNODE' && ${ENABLE_AUTOSCALING} == 'Yes' ]]; then
    if [[ "${MATLAB_RELEASE}" > 'R2021b' ]]; then
        edit_mjs_def 'MAX_LINUX_WORKERS' "$((MAX_NODES*WORKERS_PER_NODE))"
    else
        echo 'WARNING: Auto-Resizing is only available for R2022a and later'
    fi
fi

# Set scheduling algorithm for the job manager
if [[ -n "${SCHEDULING_ALGORITHM}" ]]; then
    if [[ "${MATLAB_RELEASE}" > 'R2023a' ]]; then
        edit_mjs_def 'SCHEDULING_ALGORITHM' "${SCHEDULING_ALGORITHM}"
    else
        echo 'WARNING: Selecting the scheduling algorithm is only available for R2023b and later'
    fi
fi
