#!/usr/bin/env bash

# Copyright 2025 The MathWorks, Inc.

# Exit on any failure, treat unset substitution variables as errors
set -euo pipefail

install_prerequisites() {
    sudo apt-get -qq update
    sudo apt-get -qq install acl
}

create_cloud_user() {
    local cloud_user="$1"
    if id "${cloud_user}" &>/dev/null; then
        echo "${cloud_user} already exists"
    else
        sudo adduser --disabled-password --shell /bin/bash --gecos "" ${cloud_user}
        echo "${cloud_user} created successfully"
    fi
}

save_cloud_user_info() {
    local mw_shared_data_dir="$1"
    local cloud_username="$2"
    sudo mkdir -p ${mw_shared_data_dir}
    echo "CLOUD_USER=${cloud_username}" | sudo tee ${mw_shared_data_dir}/cloud-user.conf
}

setup_permissions() {
    local cloud_user="$1"
    local dir_name="$2"
    # Allow cloud_user to read/write/execute
    sudo setfacl -m u:${cloud_user}:rwx "${dir_name}"

    # Set default ACL to allow cloud_user to read/write/execute 
    # over new directories under given path
    sudo setfacl -d -m u:${cloud_user}:rwx "${dir_name}"
}

main() {
    local cloud_user="$1"
    local log_dir="$2"
    local mw_shared_data_dir="$3"
    install_prerequisites
    create_cloud_user "${cloud_user}"
    setup_permissions "${cloud_user}" "${log_dir}"
    save_cloud_user_info "${mw_shared_data_dir}" "${cloud_user}"
}

# Run the main function if the script is not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LOG_DIR="/var/log"
    MATHWORKS_SHARED_DATA_DIR="/usr/share/mathworks"
    # CLOUD_USER is set as an env variable for this build script
    main "${CLOUD_USER}" "${LOG_DIR}" "${MATHWORKS_SHARED_DATA_DIR}"
fi
