#!/bin/bash

# Copyright 2017-2018 The MathWorks, Inc.

function pollS3 {
    START=$(date -u +%s)
    while ! aws s3 ls $1
    do
        echo $2
        NOW=$(date -u +%s)
        if ((NOW - START > $3)); then
            return 1
        fi
        sleep 1
    done
}

function curlWithRetry {
    NUM_ATTEMPTS=3
    RETRY_DELAY=1
    # The --fail flag for curl prevents errors being printed on the output.
    # This allows us to determine from empty output that something has gone
    # wrong rather than having to attempt to parse the output from curl.
    for ATTEMPT in $(seq $NUM_ATTEMPTS)
    do
        ATTEMPT_COUNTER=$ATTEMPT
        OUTPUT=$(curl --fail --silent $1)
        if [ -n "$OUTPUT" ]; then
            echo "$OUTPUT"
            return 0
        else
            sleep $RETRY_DELAY
        fi
    done
    return 1
}

function preWarmMATLAB {
    PARALLEL="/usr/bin/parallel -j64 -m --nice 10 --arg-file"
    LOG_DIR="/var/log"
    MATLAB_DIR="${MLROOT:-/mnt/matlab}"
    MDCS_UTIL_DIR="$MATLAB_DIR/toolbox/distcomp/bin/util"

    warmup_files2read_file="$MDCS_UTIL_DIR/warmup_opened_files.txt"
    # Doing "eval" on the background process so the location where the stdout and stderr go to will show up in /var/log/syslog
    if [ -n "$warmup_files2read_file" ] ; then
        eval "$PARALLEL $warmup_files2read_file /usr/bin/stat {} > $LOG_DIR/mjs_warmup_files2read.log 2>&1 &"
        eval "$PARALLEL $warmup_files2read_file /bin/cat      {} > /dev/null 2>&1 &"
    fi

    warmup_files2stat_file="$MDCS_UTIL_DIR/warmup_stated_files.txt"
    if [ -n "$warmup_files2stat_file" ] ; then
        eval "$PARALLEL $warmup_files2stat_file /usr/bin/stat {} > $LOG_DIR/mjs_warmup_files2stat.log 2>&1 &"
    fi
}

echo "===Setting up MDCS==="

set -x

# The MATLAB snapshot and database location have been specified in the template.
# The database volume is optional, so we need to check if the device exists or
# not before trying to mount it.
sudo mkdir /mnt/matlab
if [ -b /dev/xvdm ]; then
    sudo mount /dev/xvdm /mnt/matlab
elif [ -b /dev/nvme1n1 ]; then
    sudo mount /dev/nvme1n1 /mnt/matlab
fi

# We make the directory whether or not the volume is attached to the instance,
# and use that location in both cases.
# This is a blank disk and needs a filesystem
sudo mkdir /mnt/database
if [ -b /dev/xvdh ]; then
    sudo mkfs -t ext4 /dev/xvdh
    sudo mount /dev/xvdh /mnt/database
elif [ -b /dev/nvme2n1 ]; then
    sudo mkfs -t ext4 /dev/nvme2n1
    sudo mount /dev/nvme2n1 /mnt/database
fi

preWarmMATLAB &

cd /mnt/matlab/toolbox/distcomp/bin
PUBLIC_HOSTNAME=$(curlWithRetry http://169.254.169.254/latest/meta-data/public-hostname)
# If the VPC is not configured to assign public DNS hostnames then this
# will be empty. We require a public hostname so error if that's the case.
if [ $? != 0 ]; then
    echo "Failed to get the public hostname of this instance from the meta-data."
    exit 1
fi

LOCAL_HOSTNAME=$(curlWithRetry http://169.254.169.254/latest/meta-data/local-hostname)
if [ $? != 0 ]; then
    echo "Failed to get the local hostname of this instance from the meta-data."
    exit 1
fi

SECURITY_DIR=/var/lib/mdce/security

if [ ${NODE_TYPE} == HEADNODE ]; then
    # The hostname for the mdce process on the headnode must be the
    # public hostname. This is embedded in the RMI proxies that are
    # used by MATLAB clients to communicate with MJS.
    HOSTNAME_TO_USE=${PUBLIC_HOSTNAME}

    # Workers get the HEADNODE_NAME and the HEADNODE_PRIVATE_IP passed in from
    # the environment. On the headnode itself we need to get them from the
    # metadata
    HEADNODE_NAME=${PUBLIC_HOSTNAME}
    HEADNODE_PRIVATE_IP=$(curlWithRetry http://169.254.169.254/latest/meta-data/local-ipv4)
    if [ $? != 0 ]; then
        echo "Failed to get the headnode's local ip from the meta-data."
        exit 1
    fi
    INSTANCE_ID=$(curlWithRetry http://169.254.169.254/latest/meta-data/instance-id)
    if [ $? != 0 ]; then
        echo "Failed to get the instance id from the meta-data."
        exit 1
    fi

    CERT_FILE=/tmp/cert

    echo "===Creating secret and profile==="
    sudo mkdir -p ${SECURITY_DIR}
    sudo ./createSharedSecret -file ${SECURITY_DIR}/secret
    sudo ./generateCertificate -secretfile ${SECURITY_DIR}/secret -certfile ${CERT_FILE}

    # The S3 bucket is created via the cloud formation template and
    # it is not always immediately available. Wait here for it to
    # exist before attempting to copy anything into it.
    TIMEOUT=60
    if ! pollS3 ${S3_BUCKET} "Waiting for s3 bucket to be created" $TIMEOUT
    then
        echo "${S3_BUCKET} was not found within $TIMEOUT seconds."
        exit 1
    fi

    # The shared secret is sensitive data, so we use the --sse flag
    # to enable server-side encryption of the secret.
    aws s3 cp --sse AES256 ${SECURITY_DIR}/secret ${S3_BUCKET}

    # We do not want the secret to be visible by any non-root user.
    sudo chmod 600 ${SECURITY_DIR}/secret

    ./createProfile -name "${JOB_MANAGER_NAME}" -host ${HEADNODE_NAME} -certfile ${CERT_FILE} -outfile "/tmp/${PROFILE_NAME}"

    echo "===Uploading profile to S3==="
    aws s3 cp "/tmp/${PROFILE_NAME}" ${S3_BUCKET}
else
    # The workers to not expose RMI proxies outside the cluster,
    # therefore it is fine, and preferable to use the local
    # host name of the worker node as the hostname for mdce.
    HOSTNAME_TO_USE=${LOCAL_HOSTNAME}

    # It can take time for the headnode to format the database's
    # filesystem. Wait for up to 10 minutes for the shared secret
    # to appear before giving up.
    TIMEOUT=600
    if ! pollS3 ${S3_BUCKET}/secret "Shared secret not found in ${S3_BUCKET}" $TIMEOUT
    then
        echo "The shared secret was not found in ${S3_BUCKET} within $TIMEOUT seconds."
        exit 1
    fi
    sudo mkdir -p ${SECURITY_DIR}
    sudo aws s3 cp --sse AES256 ${S3_BUCKET}/secret ${SECURITY_DIR}/secret
    sudo chmod 600 ${SECURITY_DIR}/secret
fi

# All communication to the headnode from any node in the cluster should
# use the internal IP address. To make sure this always happens we add an
# entry to the /etc/hosts file mapping the headnode's public name to its
# internal IP address.
sudo echo ${HEADNODE_PRIVATE_IP} ${HEADNODE_NAME} >> /etc/hosts

echo "===Starting MDCE==="
# In order to form a Parallel Pool the client needs to be able to connect
# directly to at least one of the workers in the pool. Since the worker
# has been configured to use the local hostname, we need to specify the
# external hostname as an override value for the client to use when
# forming a pool.
export MDCE_OVERRIDE_EXTERNAL_HOSTNAME=${PUBLIC_HOSTNAME}
export MDCE_OVERRIDE_INTERNAL_HOSTNAME=${LOCAL_HOSTNAME}

# Create a context for MHLM
export MHLM_CONTEXT="MDCS_AWS_${RELEASE_DATE}"

sudo -E ./mdce start -usemhlm -hostname ${HOSTNAME_TO_USE} -usesecurecommunication -untrustedclients \
    -sharedsecretfile ${SECURITY_DIR}/secret -workerproxiespoolconnections -enablepeerlookup -loglevel 2 \
    -checkpointbase /mnt/database

if [ ${NODE_TYPE} == HEADNODE ]; then
	echo "===Starting Job Manager==="
	./startjobmanager -name "${JOB_MANAGER_NAME}" -certificate ${CERT_FILE}

else
    echo "===Starting workers==="
    WORKER_NAME=${PUBLIC_HOSTNAME}_w
    ./startworker -name ${WORKER_NAME} -jobmanagerhost ${HEADNODE_NAME} -jobmanager "${JOB_MANAGER_NAME}" -num ${WORKERS_PER_NODE} 
fi

echo "===Successfully started MDCS==="

