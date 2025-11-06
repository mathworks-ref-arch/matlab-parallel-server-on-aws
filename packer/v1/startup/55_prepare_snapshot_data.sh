#!/bin/bash

# Copyright 2025 The MathWorks, Inc.

# When MJS and shared data are restored from a snapshot, the snapshot data is validated for use by the current cluster:
# 1. Ensure that there is only one directory ending with "_jobmanager_storage" in CHECKPOINT_ROOT.
# 2. Compare the previous cluster name with the current cluster name; 
# 3. Delete all files and directories in CHECKPOINT_ROOT except those named "*_jobmanager_storage" and "job_history".


PS4='+ [\d \t] '
set -x

PREVIOUS_JOB_MANAGER_NAME=""

if [[ ${NODE_TYPE} == 'WORKER' ]];then
    echo "Skipping snapshot data preparation script for worker node."
    exit 0
fi

if [[ -z "${MJS_DATA_EBS_SNAPSHOT_ID}" ]]; then
    echo "MJS_DATA_EBS_SNAPSHOT_ID is not set. Skipping."
    exit 0
fi

cd "$CHECKPOINT_ROOT" || exit 0

# If there are more than 1 directory ending with "_jobmanager_storage", exit with error
count=$(find . -maxdepth 1 -type d -name "*_jobmanager_storage" | wc -l)
if [[ "$count" -gt 1 ]]; then
    echo "Error: Multiple job manager storage directories found in $CHECKPOINT_ROOT. Your snapshot data might be corrupted. Exiting with error."
    exit 1
fi

# Find previous cluster name
for dir in "$CHECKPOINT_ROOT"/*_jobmanager_storage; do
    if [[ -d "$dir" ]]; then
        PREVIOUS_JOB_MANAGER_NAME=$(basename "$dir" | sed 's/_jobmanager_storage//')
        echo "Previous cluster name was: $PREVIOUS_JOB_MANAGER_NAME"
        break
    fi
done

if [[ "$PREVIOUS_JOB_MANAGER_NAME" == "$JOB_MANAGER_NAME" ]]; then
    echo "Previous and new cluster names are the same."
else
    echo "Error: Previous and new cluster names are different."
    exit 1
fi

# Delete all files and folders except security, "*_jobmanager_storage" and "job_history"
sudo find "$CHECKPOINT_ROOT" -maxdepth 1 ! -name "security" ! -name "*_jobmanager_storage" ! -name "job_history" ! -name "$(basename "$CHECKPOINT_ROOT")" -exec rm -rf {} +
