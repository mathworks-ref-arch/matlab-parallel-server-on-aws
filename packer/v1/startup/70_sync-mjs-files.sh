#!/usr/bin/env bash

# Copyright 2022-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x

# Source the S3 helper functions
source "/opt/mathworks/startup/reusable-helper-scripts/s3_helpers.sh"

if [[ ! -d "${SECURITY_ROOT}" ]]; then
    mkdir -p "${SECURITY_ROOT}"
    chown -R ${CLOUD_USER}:${CLOUD_USER} "${SECURITY_ROOT}"
    chmod 700 "${SECURITY_ROOT}"
fi

# Create shared secret file and set MATLAB client verification
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html
if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then

    MJS_HOSTNAME=${PUBLIC_HOSTNAME}

    echo "===Creating secret and profile==="
    if [[ "${MATLAB_RELEASE}" > 'R2022a' ]]; then
        PROFILE_FILE="/tmp/${JOB_MANAGER_NAME}.mlsettings"
    else
        # In MATLAB R2022a and older, the cluster profile is not an mlsettings file
        PROFILE_FILE="/tmp/${JOB_MANAGER_NAME}.settings"
    fi

    cd ${MATLAB_ROOT}/toolbox/parallel/bin
    if [[ ! -f "${SECRET_FILE}" ]] || [[ ! -f "${CERT_FILE}" ]]; then
        sudo -E -u ${CLOUD_USER} ./createSharedSecret -file ${SECRET_FILE}
        sudo -E -u ${CLOUD_USER} ./generateCertificate -secretfile ${SECRET_FILE} -certfile ${CERT_FILE}
    fi

    # The command is not being run as root, instead sudo -E -u ${CLOUD_USER} allows for creatProfile to be run as ${CLOUD_USER}
    sudo -E -u ${CLOUD_USER} ./createProfile -name "${JOB_MANAGER_NAME}" -host ${MJS_HOSTNAME} -certfile ${CERT_FILE} -outfile "${PROFILE_FILE}"

    echo "===Uploading files to S3 bucket==="
    # Wait for S3 bucket to appear.
    wait_for_s3_bucket ${S3_BUCKET}

    upload_file_to_s3 "${SECRET_FILE}" ${S3_BUCKET}
    upload_file_to_s3 "${PROFILE_FILE}" ${S3_BUCKET}
    upload_file_to_s3 "${CERT_FILE}" ${S3_BUCKET}

    # Upload default admin password if present
    if [[ -f "${MJS_ADMIN_PASSWORD_FILE}" ]]; then
        upload_file_to_s3 "${MJS_ADMIN_PASSWORD_FILE}" "${S3_BUCKET}"
    fi

else

    echo "===Retrieving secret from S3 bucket==="
    # Initial delay 2s, max delay 30s, retry for ~10 minutes (20 retries)
    if exponential_backoff 2 30 20 find_object_in_S3_bucket "${S3_BUCKET}" "secret"; then
        download_file_from_s3 "${S3_BUCKET}/secret" "${SECRET_FILE}"
        chown ${CLOUD_USER}:${CLOUD_USER} ${SECRET_FILE}
    else
        echo "The shared secret was not found in ${S3_BUCKET}"
        exit 1
    fi

fi
