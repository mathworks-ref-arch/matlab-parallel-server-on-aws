#!/usr/bin/env bash
#
# Copyright 2025 The MathWorks, Inc.

# Source the S3 helper functions
source "/opt/mathworks/startup/reusable-helper-scripts/s3_helpers.sh"

# This script is supposed to run only in the Headnode of the cluster.

retry_until_success() {
    local attempt=1
    local maxRetries=5
    local delay=2
    while (( attempt <= maxRetries )); do
        if "$@"; then
            echo "Command succeeded!"
            return 0
        else
            echo "Attempt $attempt failed."
        fi
        echo "Retrying in $delay seconds..."
        sleep $delay
        ((attempt++))
    done
    return 1
}

delete_S3_cert() {
    # Read the shared application data referring to S3 bucket and cert name
    [ ! -f /usr/share/mathworks/s3-bucket ] && echo "No S3 bucket file" && return 0
    local S3_BUCKET=$(cat /usr/share/mathworks/s3-bucket)
    [ ! -f /usr/share/mathworks/stunnel-cert-name ] && echo "No cert-name file found" && return 0
    local STUNNEL_CERT_NAME=$(cat /usr/share/mathworks/stunnel-cert-name)
    # Delete local cert first
    rm -f /etc/stunnel/"${STUNNEL_CERT_NAME}" || return 1
    # Delete S3 cert
    delete_object_from_s3 "${S3_BUCKET}/${STUNNEL_CERT_NAME}"

    # Delete nfs marker files from s3
    aws s3 rm ${S3_BUCKET} --recursive --exclude '*' --include '*.nfsmarker'
    return $?
}

main() {
    retry_until_success delete_S3_cert
}

main 
