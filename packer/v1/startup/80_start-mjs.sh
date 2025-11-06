#!/usr/bin/env bash

# Copyright 2022-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x pipefail

echo "===Setup directory permissions==="
# Set Access Control List to allow CLOUD_USER to read/write/execute on required directories
setfacl -m u:${CLOUD_USER}:rwx /var/run

echo "===Setting up Networking==="

# Ensure that all communication with the headnode occurs on the local network.
if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
    echo ${LOCAL_IPV4} ${PUBLIC_HOSTNAME} >> /etc/hosts
else
    echo ${HEADNODE_LOCAL_IP} ${HEADNODE_HOSTNAME} >> /etc/hosts
fi

# Ensure that the MATLAB client can connect directly to the workers. 
# This is a necessary condition to create parpools.
export MDCE_OVERRIDE_EXTERNAL_HOSTNAME=${PUBLIC_HOSTNAME}
export MDCE_OVERRIDE_INTERNAL_HOSTNAME=${LOCAL_HOSTNAME}

echo "===Starting MATLAB Job Scheduler==="

mkdir -p ${CHECKPOINT_ROOT}
chown -R ${CLOUD_USER}:${CLOUD_USER} ${CHECKPOINT_ROOT}
chmod 755 ${CHECKPOINT_ROOT}

if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
    # Hostname of the job manager.
    MJS_HOSTNAME=${PUBLIC_HOSTNAME}
else
    # Hostname of the worker node
    MJS_HOSTNAME=${LOCAL_HOSTNAME}
fi

MJS_OPTS=(
    -hostname "${MJS_HOSTNAME}"
    -loglevel ${CLUSTER_LOG_LEVEL%%[^0-9]*}
    -enablepeerlookup
    -sharedsecretfile "${SECRET_FILE}"
    -cleanPreserveJobs
)

if [[ "${TERMINATION_POLICY}" == "Never" || "${TERMINATION_POLICY}" == "When cluster is idle" ]]; then
    MJS_OPTS+=(
        -sendactivitynotifications
        -scriptroot "${MJS_BUSY_IDLE_SCRIPTS}"
    )
fi

cd ${MATLAB_ROOT}/toolbox/parallel/bin

# Start MJS as CLOUD_USER
sudo -E -u ${CLOUD_USER} ./mjs start "${MJS_OPTS[@]}"

if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
    echo "===Starting Job Manager==="

    if [[ -f "${MJS_ADMIN_PASSWORD_FILE}" ]]; then
        # Provide the password for the administrator account if one has been generated (Security Level 2 and 3)
        PARALLEL_SERVER_JOBMANAGER_ADMIN_PASSWORD=$(cat "${MJS_ADMIN_PASSWORD_FILE}")
        if [[ "{$MATLAB_RELEASE}" > 'R2023b' ]]; then
            export PARALLEL_SERVER_JOBMANAGER_ADMIN_PASSWORD
        else
            MDCEQE_JOBMANAGER_ADMIN_PASSWORD="${PARALLEL_SERVER_JOBMANAGER_ADMIN_PASSWORD}"
            export MDCEQE_JOBMANAGER_ADMIN_PASSWORD
        fi
    fi
    # Start Job Manager as CLOUD_USER
    sudo -E -u ${CLOUD_USER} ./startjobmanager -name "${JOB_MANAGER_NAME}" -certificate ${CERT_FILE}

else
    echo "===Starting workers==="
    # Start worker processes as CLOUD_USER
    sudo -E -u ${CLOUD_USER} ./startworker -jobmanagerhost ${HEADNODE_HOSTNAME} -jobmanager "${JOB_MANAGER_NAME}" -num ${WORKERS_PER_NODE}
fi

echo "===Done==="
