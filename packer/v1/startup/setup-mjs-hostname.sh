#!/usr/bin/env bash

# Copyright 2026 The MathWorks, Inc.

# This script configures the hostnames used by headnode and workers for
# client-cluster (EXTERNAL_HOSTNAME) and intra-cluster (INTERNAL_HOSTNAME) communication
# Sourced by bash during user-data

# Initialize internal and external hostnames to be the local DNS name
INTERNAL_HOSTNAME="${LOCAL_HOSTNAME}"
EXTERNAL_HOSTNAME="${LOCAL_HOSTNAME}"

# Configure the external hostname of headnode that will be visible to workers.
# The HEADNODE_HOSTNAME variable is set in the cloud formation template's 
# user data section. It is available only in worker nodes' userdata environments
if [[ "${NODE_TYPE}" == 'WORKER' ]]; then
    HEADNODE_EXTERNAL_HOSTNAME="${HEADNODE_HOSTNAME}"
    if [[ "${COMMUNICATION_MODE}" == "PrivateDNS" ]]; then
        # When the communication mode is PrivateDNS, we must
        # ensure that we use the DNS search suffix returned by IMDS
        HEADNODE_EXTERNAL_HOSTNAME+=".${DNS_SEARCH_SUFFIX}"
    fi
fi

# Determine specific External/Internal Hostname overrides
if [[ -n "${PUBLIC_IPV4}" ]]; then
    # Public Cluster, default to using Public DNS name
    # for client communication for workers
    EXTERNAL_HOSTNAME="${PUBLIC_HOSTNAME}"
elif [[ "${MATLAB_RELEASE}" > "R2022b" ]] && [[ "${COMMUNICATION_MODE}" != "PrivateDNS" ]]; then
    # Private Cluster (R2023a+) using IPs instead of DNS
    EXTERNAL_HOSTNAME="${LOCAL_IPV4}"
    INTERNAL_HOSTNAME="${LOCAL_IPV4}"
fi
