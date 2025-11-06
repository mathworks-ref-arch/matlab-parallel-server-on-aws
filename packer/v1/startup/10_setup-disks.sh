#!/usr/bin/env bash

# Copyright 2022-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x

# Make EBS volumes available (including NVMe instance store volumes)
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html

echo "Starting disk setup script"

# Configuration
FSTYPE=xfs

# Initialize counters and flags
data_idx=0
ebs_idx=0
first_nvme_found=false
shared_ebs_mounted=false
SHARED_EBS_SIZE=$((SHARED_EBS_VOLUME_SIZE * 1024 * 1024 * 1024)) # Convert GB to bytes

if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
    echo "HEADNODE_INSTANCE_TYPE=${HEADNODE_INSTANCE_TYPE}"
    echo "WORKERNODE_INSTANCE_TYPE=${WORKERNODE_INSTANCE_TYPE}"
fi

# Function to create and mount filesystem
create_and_mount_fs() {
    local disk=$1
    local mountpoint=$2

    echo "Creating file system on ${disk}"
    mkfs -t ${FSTYPE} ${disk}
    partprobe ${disk}

    echo "Mounting ${disk} at ${mountpoint}"
    mkdir -p ${mountpoint}
    mount ${disk} ${mountpoint}
    chown -R ${CLOUD_USER}:${CLOUD_USER} ${mountpoint}
    chmod 1777 ${mountpoint}

    echo "Adding mount entry to /etc/fstab for ${disk}"
    UUID=$(blkid -o value -s UUID ${disk})
    echo "UUID=${UUID} ${mountpoint} ${FSTYPE} defaults,nofail 0 2" >> /etc/fstab
}

# Main disk processing loop
echo "Scanning for disks..."
df -Th
for DISK in $(lsblk -dpn -o NAME); do
    echo "Processing disk: ${DISK}"
    DISK_SERIAL=$(lsblk -d -o SERIAL $DISK | grep -v SERIAL)
    DISK_SIZE=$(lsblk -dn -o SIZE --bytes ${DISK} | awk '{print $1}')
    echo "Processing disk ${DISK} with serial ${DISK_SERIAL} and size ${DISK_SIZE} bytes"

    # Skip disks with existing file systems, except for the EBS volume on the headnode when recovered from a snapshot
    if [[ $(file -bs "${DISK}") != 'data' ]]; then
        if [[ "${NODE_TYPE}" == 'HEADNODE' ]] &&
            [[ -n "${MJS_DATA_EBS_SNAPSHOT_ID}" ]] &&
            [[ "${DISK_SIZE}" -eq "${SHARED_EBS_SIZE}" ]]; then
            echo "Recovered disk with size ${DISK_SIZE} is recovered from EBS snapshot ${MJS_DATA_EBS_SNAPSHOT_ID}. This disk will be mounted at next steps. Your mjs path will be ${CHECKPOINT_ROOT}."
        else
            echo "Disk ${DISK} already has a file system and it's not the shared persistent disk. Skipping."
            continue
        fi
    fi

    # Identify disk type
    echo "Identifying disk type for ${DISK}"
    MODEL_NUMBER=$(nvme id-ctrl ${DISK} -o json | jq -r '.mn')
    echo "Model number: ${MODEL_NUMBER}"

    # Set mount point based on disk type and node type
    if [[ ${MODEL_NUMBER} == *'Amazon EC2 NVMe Instance Storage'* ]]; then
        echo "NVMe instance storage detected"
        if [[ ${NODE_TYPE} == 'HEADNODE' ]] && [[ $first_nvme_found == "false" ]]; then
            MOUNTPOINT=/shared/tmp
            echo "First NVMe on headnode, setting mountpoint to ${MOUNTPOINT}"
            first_nvme_found=true
        else
            MOUNTPOINT=/mnt/localnvme${data_idx}
            echo "Additional NVMe, setting mountpoint to ${MOUNTPOINT}"
            data_idx=$((data_idx+1))
        fi
    else
        echo "EBS volume detected"
        echo "Disk size: ${DISK_SIZE} bytes, Shared EBS size: ${SHARED_EBS_SIZE} bytes"

        if [[ ${NODE_TYPE} == 'HEADNODE' ]] &&
           [[ ${ENABLE_SHARED_FS} == 'EBS' ]] &&
           [[ $shared_ebs_mounted == "false" ]] && 
           [[ ${DISK_SIZE} -eq ${SHARED_EBS_SIZE} ]]; then
            MOUNTPOINT=$PERSISTED_MOUNT_PATH
            echo "Shared EBS volume detected, setting mountpoint to ${MOUNTPOINT}"
            shared_ebs_mounted=true
        else
            MOUNTPOINT=/mnt/localebs${ebs_idx}
            echo "Standard EBS volume, setting mountpoint to ${MOUNTPOINT}"
            ebs_idx=$((ebs_idx+1))
        fi
    fi

    # Create and mount the file system
    create_and_mount_fs ${DISK} ${MOUNTPOINT}
done

df -Th
echo "Disk setup completed"