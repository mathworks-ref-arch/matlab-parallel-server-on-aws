#!/usr/bin/env bash
#
# Copyright 2024-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -uo pipefail

STUNNEL_CERT_NAME="stunnel-server-cert.pem"
# Set default value for the shared data directory
MATHWORKS_SHARED_DATA_DIR="${MATHWORKS_SHARED_DATA_DIR:=/usr/share/mathworks}"
MATHWORKS_REUSABLE_HELPERS_DIR="${MATHWORKS_REUSABLE_HELPERS_DIR:=/opt/mathworks/startup/reusable-helper-scripts/}"

# Get the username of the cloud user
source "${MATHWORKS_SHARED_DATA_DIR}/cloud-user.conf"

# Source the S3 helper functions
source "${MATHWORKS_REUSABLE_HELPERS_DIR}/s3_helpers.sh"

setup_logging() {
    logfile=$1
    # Set up log file
    mkdir -p $(dirname "$logfile")
    touch "${logfile}"

    # Print commands for logging purposes, including timestamps.
    exec 1>>"$logfile" 2>&1
}

replace_chars_with_octal() {
    printf '%s' "$1" | sed 's/ /\\040/g' | sed 's/'\''/\\047/g';
}

overwrite_stunnel_config() {
    # Args
    echo "(${FUNCNAME[0]}, $1, $2)"
    local path=$1
    local port=$2

    printf 'cert = /etc/stunnel/stunnel.pem\n' > /etc/stunnel/stunnel.conf || return 1
    printf '[nfs]\n' >> /etc/stunnel/stunnel.conf || return 1
    printf 'accept = 0.0.0.0:%b\n' "$port" >> /etc/stunnel/stunnel.conf || return 1
    printf 'connect = 127.0.0.1:%b\n' "$nfsport" >> /etc/stunnel/stunnel.conf || return 1
    printf 'sslVersionMin = TLSv1.3' >> /etc/stunnel/stunnel.conf || return 1
}

overwrite_stunnel_client_config() {
    # Args
    echo "(${FUNCNAME[0]}, $1, $2)"
    local path=$1
    local port=$2

    echo "Overriding stunnel configuration"
    printf 'client = yes\n' > /etc/stunnel/stunnel.conf || return 1
    printf 'CAfile = /etc/stunnel/%b\n' "${STUNNEL_CERT_NAME}" >> /etc/stunnel/stunnel.conf || return 1
    printf '[nfs-client]\n' >> /etc/stunnel/stunnel.conf || return 1
    printf 'accept = 127.0.0.1:%b\n' "$port" >> /etc/stunnel/stunnel.conf || return 1
    printf 'connect = %b:%b\n' "${HEADNODE_LOCAL_IP}" "$port" >> /etc/stunnel/stunnel.conf || return 1
}

add_NFS_server_config() {
    # Args
    echo "(${FUNCNAME[0]}, $1, $2)"
    local path="$1"
    local nfs_opts="$2"

    cleanpath=$(replace_chars_with_octal "${path}")
    local fsid=$((10000 + RANDOM % 90000))  # Generates a random 5-digit number
    if [ -z "${nfs_opts}" ]; then
        # default options:
        # - root_squash maps root to nobody on server (security)
        # - fsid sets the filesystem id of the export
        # - insecure allows non privileged (i.e. above 1024) ports to be used
        # - rw allows both read and write access
        local config_line="${cleanpath} 127.0.0.1(rw,root_squash,fsid=${fsid},insecure)"
    else
        local config_line="${cleanpath} 127.0.0.1(root_squash,fsid=${fsid},insecure,$nfs_opts)"
    fi

    # add config if not exist
    grep -qF -- "$config_line" /etc/exports || echo "$config_line" | sudo tee -a /etc/exports || return 1
}

# Idempotent
serve_NFS_with_TLS() {
    # Args
    echo "(${FUNCNAME[0]}, $1, $2, $3)"
    local path=$1
    local port=$2
    local nfs_opts=$3
    local nfsport=2049

    # Write the certificate name and the S3 bucket to disk for the shutdown script
    mkdir -p "${MATHWORKS_SHARED_DATA_DIR}" || return 1
    echo "${S3_BUCKET}" > "${MATHWORKS_SHARED_DATA_DIR}"/s3-bucket || return 1
    echo "${STUNNEL_CERT_NAME}" > "${MATHWORKS_SHARED_DATA_DIR}"/stunnel-cert-name || return 1

    # Do not regenerate certificate, if exists
    # This is safer rather than potentially having an inconsistent state between server and client
    if [ ! -f /etc/stunnel/"${STUNNEL_CERT_NAME}" ]; then
        # Generate certificate
        mkdir -p /etc/stunnel/ || return 1
        openssl req -new -x509 -days 365 -nodes -subj "/O=The MathWorks Ltd"  -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem || return 1
        chmod 600 /etc/stunnel/stunnel.pem || return 1

        # Extract certificate
        openssl x509 -in /etc/stunnel/stunnel.pem -out /etc/stunnel/"${STUNNEL_CERT_NAME}" || return 1
        chmod 600 /etc/stunnel/"${STUNNEL_CERT_NAME}" || return 1
    fi

    # Configure stunnel
    echo "Overriding stunnel configuration"
    overwrite_stunnel_config "$path" "$port" || return 1

    # Configure NFS for "path"
    echo "Overriding NFS configuration"
    add_NFS_server_config "$path" "$nfs_opts" || return 1

    mkdir -p "${path}" || return 1
    chmod 750 "${path}" || return 1
    chown --recursive "${CLOUD_USER}":"${CLOUD_USER}" "${path}" || return 1

    # Start NFS
    systemctl restart nfs-server || return 1

    # Start stunnel
    systemctl restart stunnel4 || return 1

    # List S3 bucket
    echo "Connect to s3"
    exponential_backoff 1 1 60 list_S3_bucket "${S3_BUCKET}" || return 1

    # Upload certificate to S3
    echo "Upload certificate to s3"
    upload_file_to_s3 "/etc/stunnel/${STUNNEL_CERT_NAME}" "${S3_BUCKET}" || return 1

    # Upload marker file to S3
    echo "Upload marker file to s3"
    hex_of_path=$(echo "${path}" | xxd -p)
    touch_file_in_s3 "${S3_BUCKET}"/"${hex_of_path}.nfsmarker" || return 1
}

mount_NFS_with_TLS() {
    echo "(${FUNCNAME[0]}, $1, $2, $3)"
    local path="$1"
    local port="$2"
    local nfs_opts="$3"

    # List S3 bucket to find cert
    exponential_backoff 2 128 8 find_object_in_S3_bucket "${S3_BUCKET}" "${STUNNEL_CERT_NAME}" || return 1

    # List S3 bucket to find marker file
    hex_of_path=$(echo "${path}" | xxd -p)
    exponential_backoff 2 128 8 find_object_in_S3_bucket "${S3_BUCKET}" "${hex_of_path}.nfsmarker" || return 1

    # Copy files from S3
    echo "Copy certificate file from S3"
    download_file_from_s3 "${S3_BUCKET}/${STUNNEL_CERT_NAME}" "/etc/stunnel/" || return 1

    # Configure stunnel
    overwrite_stunnel_client_config "$path" "$port" || return 1

    # Start stunnel
    systemctl restart stunnel4 || return 1

    # Connect to NFS (retry up to 10 minutes)
    echo "Mount NFS"
    mkdir -p "${path}" || return 1
    chmod 750 "${path}" || return 1
    chown --recursive "${CLOUD_USER}":"${CLOUD_USER}" "${path}" || return 1
    if [ -z "${nfs_opts}" ]; then
        # Default mount options are
        # - specified port
        # - protocol tcp
        # - retry up to 10 times
        mount -t nfs4 --options port="$port",proto=tcp,retry=10 127.0.0.1:"${path}" "${path}"
    else
        mount -t nfs4 --options port="$port",proto=tcp,retry=10,"${nfs_opts}" 127.0.0.1:"${path}" "${path}"
    fi

    if ! mountpoint -q "${path}"; then
        echo "Mount failed. Cleaning up local directory."
        rmdir "${path}"
        return 1
    fi

    echo "Successfully mounted ${path}"

}

# Argument #1 is path and #2 is port, #3 is server opts #4 is client opts
setup_NFS_with_TLS_main() {
    echo "(${FUNCNAME[0]}, $1, $2, $3, $4)"
    if [[ "${NODE_TYPE}" == 'HEADNODE' ]]; then
        serve_NFS_with_TLS "$1" "$2" "$3" || return 1
    else
        mount_NFS_with_TLS "$1" "$2" "$4" || return 1
    fi
}
