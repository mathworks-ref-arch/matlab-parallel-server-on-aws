#!/usr/bin/env bash

# Copyright 2024-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x

# Source the S3 helper functions
source "/opt/mathworks/startup/reusable-helper-scripts/s3_helpers.sh"

# This script configures the shared storage
# These paths will be owned by CLOUD_USER
TMP_MOUNT_PATH="/shared/tmp"

# Original S3 bucket variable with the 's3://' prefix
S3_BUCKET=${S3_BUCKET}
# Remove the 's3://' prefix to get just the bucket name
BUCKET_NAME="${S3_BUCKET#s3://}"

# Function to add a line to a file if it doesn't already exist
add_line_if_not_exists() {
    local line="$1"
    local file="$2"
    grep -qF -- "$line" "$file" || echo "$line" | sudo tee -a "$file"
}

# Function to mount EFS
mount_efs() {
    local mount_path="$1"
    local fs_id="$2"
    
    if [[ ! $(mountpoint -q "$mount_path") ]]; then
        echo "Mounting EFS $fs_id at $mount_path"
        mkdir -p "$mount_path"
        # Using EFS mount helper to mount the EFS with TLS encryption for data-in-transit.
        # EFS can also be mounted with IAM authentication, refer the below resources for more details.
        # https://docs.aws.amazon.com/efs/latest/ug/mounting-IAM-option.html
        # https://docs.aws.amazon.com/efs/latest/ug/iam-access-control-nfs-efs.html
        sudo mount -t efs -o tls,_netdev "$fs_id":/ "$mount_path"
        sudo chown -R ${CLOUD_USER}:${CLOUD_USER} "$mount_path"

        if [[ $? -eq 0 ]]; then
            add_line_if_not_exists "$fs_id:/ $mount_path efs tls,_netdev 0 0" /etc/fstab
        else
            echo "Failed to mount EFS $fs_id at $mount_path"
            return 1
        fi
    else
        echo "EFS already mounted at $mount_path"
    fi
}

# Setup shared storage on the headnode
if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
    echo "Setting up shared storage on headnode"

    # Setup EFS if selected
    if [[ ${ENABLE_SHARED_FS} == 'EFS' ]] && [[ -n "${EFS_FILE_SYSTEM_ID}" ]]; then
        mount_efs "$PERSISTED_MOUNT_PATH" "$EFS_FILE_SYSTEM_ID"
    fi

    # Setup EBS-based persisted storage
    if [[ ${ENABLE_SHARED_FS} == 'EBS' ]]; then
        /opt/mathworks/nfs-share/setup_NFS_with_TLS.sh -f "$PERSISTED_MOUNT_PATH" -p 20443
    fi

    # Wait for S3 bucket and mark temporary storage as available
    wait_for_s3_bucket "$S3_BUCKET"

    # Setup EBS for tmp storage if it exists and mark its existence in S3
    if [[ -d "$TMP_MOUNT_PATH" ]]; then
        /opt/mathworks/nfs-share/setup_NFS_with_TLS.sh -f "$TMP_MOUNT_PATH" -p 20443
        
        touch /tmp/TMP_EBS_EXIST
        upload_file_to_s3 "/tmp/TMP_EBS_EXIST" "${S3_BUCKET}"
    else
        touch /tmp/TMP_EBS_NOT_EXIST
        upload_file_to_s3 "/tmp/TMP_EBS_NOT_EXIST" "${S3_BUCKET}"
    fi

    # Clean up temporary files
    rm -f /tmp/TMP_EBS_*

else
    # Setup shared storage on worker nodes
    echo "Setting up shared storage on worker node"

    # Mount persisted EFS if selected
    if [[ ${ENABLE_SHARED_FS} == 'EFS' ]] && [[ -n "${EFS_FILE_SYSTEM_ID}" ]]; then
        mount_efs "$PERSISTED_MOUNT_PATH" "$EFS_FILE_SYSTEM_ID"
    fi

    # Mount persisted shared EBS from headnode
    if [[ ${ENABLE_SHARED_FS} == 'EBS' ]]; then
        /opt/mathworks/nfs-share/setup_NFS_with_TLS.sh -f "$PERSISTED_MOUNT_PATH" -p 20443
    fi

    # Check TMP storage status and attempt to mount it if it exists on headnode
    wait_for_s3_bucket "$S3_BUCKET"
    # result=$(find_multiple_objects_in_S3_bucket "${BUCKET_NAME}" "pattern" "TMP_EBS_")
    result=$(exponential_backoff 2 30 5 find_multiple_objects_in_S3_bucket "${BUCKET_NAME}" "pattern" "TMP_EBS_")
    status=$?

    if [[ $status -eq 0 && $result == *"TMP_EBS_EXIST"* ]]; then
        /opt/mathworks/nfs-share/setup_NFS_with_TLS.sh -f "${TMP_MOUNT_PATH}" -p 20443
    elif [[ $status -eq 0 && $result == *"TMP_EBS_NOT_EXIST"* ]]; then
        echo "No TMP storage to set up"
    else
        echo "Unable to determine TMP storage status"
    fi

fi

echo "Shared storage setup completed"