#!/usr/bin/env python3

# Copyright 2025 The MathWorks, Inc.

import logging

from mwplatforminterfaces import CloudInterface, OSInterface
from cluster_management_interface import ClusterManagementProgramInterface

from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    STATUS_CLUSTER_ISSUE,
    MW_STATE_COUNTER,
    MW_STATE_SET,
)

logger = logging.getLogger("cluster_management.mwstate")

def main(
    cloud_interface: CloudInterface,
    os_interface: OSInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """Evaluate cluster readiness and set the mw-state tag on the head node.
    The MATLAB Parallel Server Cluster is considered ready to receive jobs if:
        1. MJS is in the ready state.
        2. If desired capacity of the cloud scaling group is more than zero,
        at least one worker node should be registered with MJS.

    If the above conditions are met, the mw-state tag is set to "ready".
    The program will re-check the readiness for up to 10 attempts, with a delay
    of 60 seconds between each attempt. If conditions are not met after all 
    attempts are exhausted, tag is set to "timeout".

    Returns:
    status (int): Status code of program.
        0: Successful
        1: Faced an issue with cloud provider
        2: Faced an issue with cluster
    """
    # Boolean flag indicating if the state has already been set
    mw_state_set = cluster_management_interface.cluster_management_state[MW_STATE_SET]

    # If the mw-state tag is already set, no action is needed
    if mw_state_set:
        logger.info("Cluster status already set, exiting.")
        return STATUS_SUCCESS
    
    # mw_state_counter represents the number of attempts performed to determine cluster readiness
    mw_state_counter = int(cluster_management_interface.cluster_management_state[MW_STATE_COUNTER])
    
    # Approximately wait for 10 * 60 = 600s before setting the tag value as "timeout"
    # This program is expected to run every 60s
    # Edge case: If the user enters an OUC that is a long running operation then mw-state might timeout
    # since OUC runs before other startup scripts.
    if mw_state_counter > 10:
        logger.info("Timeout reached while determining cluster status.")
        tag_set = cloud_interface.set_mwstate_tag("timeout")
        if not tag_set:
            logger.error("Failed to set the mw-state tag to 'timeout'.")
            return STATUS_CLOUD_ISSUE
        cluster_management_interface.update_state({ MW_STATE_SET : True})
        return STATUS_SUCCESS
    
    # Increment the counter
    mw_state_counter += 1
    cluster_management_interface.update_state({ MW_STATE_COUNTER : str(mw_state_counter) })

    if not os_interface.is_jobmanager_running():
        logger.info("Job manager is not running, will re-check in next iteration.")
        return STATUS_CLUSTER_ISSUE
    
    # Retrieving cloud cluster capacity information
    cloud_capacity = cloud_interface.get_cloud_capacity()
    if cloud_capacity is None:
        logger.error("There was an issue retrieving cloud capacities, exiting.")
        return STATUS_CLOUD_ISSUE
    
    desired_capacity = cloud_capacity.desired_nodes

    # If the cloud cluster does not require any nodes, set the mw-state tag as ready
    if desired_capacity == 0:
        tag_set = cloud_interface.set_mwstate_tag("ready")
        if not tag_set:
            logger.error("Failed to set the mw-state tag to 'ready'.")
            return STATUS_CLOUD_ISSUE
        cluster_management_interface.update_state({MW_STATE_SET : True})
        return STATUS_SUCCESS

    # Get MJS capacities
    cluster_capacity = os_interface.get_cluster_capacity()
    if cluster_capacity is None:
        logger.error("There was an issue retrieving cluster capacities, exiting.")
        return STATUS_CLUSTER_ISSUE
    
    # Get the number of workers registered with MJS
    mjs_current_workers = cluster_capacity.current_workers
    if mjs_current_workers > 0:
        # If at least one worker is registered with MJS, set the mw-state tag as ready
        logger.info("Found a worker registered with MJS. Setting mw-state as ready")
        tag_set = cloud_interface.set_mwstate_tag("ready")
        if not tag_set:
            logger.error("Failed to set the mw-state tag to 'ready'.")
            return STATUS_CLOUD_ISSUE
        cluster_management_interface.update_state({MW_STATE_SET : True})
    else:
        logger.info("Cloud cluster's desired capacity is %d but MJS has no registered workers, will re-check in next iteration.", desired_capacity)

    return STATUS_SUCCESS
