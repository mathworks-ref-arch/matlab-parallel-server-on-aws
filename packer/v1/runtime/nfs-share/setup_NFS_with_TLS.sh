#!/usr/bin/env bash
#
# Copyright 2024-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -uo pipefail

SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")
setup_nfs_log="/var/log/mathworks/setup_nfs.log"

source "${SCRIPT_DIR}"/setup_NFS_with_TLS_functions.sh

# Function to display usage
Usage() {
  echo "Usage: $0 [-f NFS folder path] [-p NFS proxy port] [-s NFS server options] [-m NFS client (mount) options]"
  exit $1
}

main() {

    # Default values
    local path="/mathworks/nfs-share"
    local port=20443
    local serveropts=""
    local mountopts=""

    while getopts "p:f:hs:m:" opt; do
      case "${opt}" in
        f)
          path="$OPTARG"
          ;;
        p)
          port="$OPTARG"
          ;;
        s)
          serveropts="$OPTARG"
          ;;
        m)
          mountopts="$OPTARG"
          ;;
        h)
          Usage 0
          ;;
        \?)
          Usage 1
          ;;
      esac
    done

    # Shift off the options and optional --.
    shift $((OPTIND -1))

    setup_logging $setup_nfs_log
    setup_NFS_with_TLS_main "$path" "$port" "$serveropts" "$mountopts" || return 1
}

main "$@"
