#!/usr/bin/env python3

# Copyright 2024-2025 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from cluster_management_interface import ClusterManagementProgramInterface
from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    STATUS_CLUSTER_ISSUE,
    STATUS_CLOUD_AND_CLUSTER_ISSUE,
    STATUS_INTERNAL_READ_WRITE_ISSUE,
    INITIAL_TERMINATION_POLICY,
    MJS_STATUS_LOG_FILE,
    LAST_TERMINATION_POLICY,
    MIN_NODES_PRE_TERMINATION,
)

import os

import logging

logger = logging.getLogger("cluster_management.utils.helpers.terminate_cluster")


def main(
    cloud_interface: CloudInterface,
    os_interface: OSInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """
    Execute the terminate cluster routine.

    Args:
        cloud_interface (CloudInterface): The interface to interact with the cloud services.
        os_interface (OSInterface): The interface to interact with the operating system.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns:
        status (int): Status code of program.
            0: Successful
            1: Faced an issue with cloud provider
            2: Faced an issue with cluster
            3: Faced an issue with both
            4: Faced an issue while reading/writing cluster management data json

    """
    # Initialize status variables
    cloud_issue, cluster_issue = False, False

    mjs_status_log_file = cluster_management_interface.cluster_management_config[
        MJS_STATUS_LOG_FILE
    ]
    initial_termination_policy = (
        cluster_management_interface.cluster_management_config[
            INITIAL_TERMINATION_POLICY
        ]
        or "never"
    )

    # Try scaling down the cluster to 0 nodes
    cloud_capacity = cloud_interface.get_cloud_capacity()
    current_nodes = cloud_capacity.current_nodes
    minimum_nodes = cloud_capacity.minimum_nodes

    if current_nodes:
        if minimum_nodes > 0:
            # Save the current min nodes to the state management file, we restore it when the
            # cluster is restarted
            cluster_management_interface.update_state(
                {MIN_NODES_PRE_TERMINATION: str(minimum_nodes)}
            )
            # Set min nodes to be zero, else ASG will not delete all instances
            logger.info("Setting cluster minimum capacity to zero.")
            if not cloud_interface.set_min_nodes(0):
                logger.debug("Failed to set minimum number of nodes to zero.")
                cloud_issue = True

        # Set desired capacity as zero
        logger.info("Setting desired capacity of the cluster to zero.")
        desired_capacity_set = cloud_interface.set_cloud_capacity(0)

        if not desired_capacity_set:
            logger.debug(
                "Failed to set desired capacity to 0 for the Auto-Scaling Group."
            )
            cloud_issue = True

        # Stop workers on all nodes and unprotect them
        logger.info("Stopping workers on cluster nodes...")
        worker_nodes = os_interface.get_worker_nodes()
        if worker_nodes:
            nodes_stopped = os_interface.stop_workers_on_nodes(worker_nodes)
            if nodes_stopped:
                logger.debug(f"Stopped workers on {len(nodes_stopped)} nodes")

                logger.info("Unprotecting cluster nodes...")
                nodes_unprotected = cloud_interface.set_nodes_protection(
                    nodes_stopped, False
                )

                if nodes_stopped != nodes_unprotected:
                    failed_nodes = nodes_stopped - nodes_unprotected
                    logger.debug(
                        f"Failed to unprotect {len(failed_nodes)} nodes: "
                        f"{failed_nodes}"
                    )
                    cloud_issue = True

                if nodes_unprotected:
                    logger.debug(f"Unprotected {len(nodes_unprotected)} nodes")

            if worker_nodes != nodes_stopped:
                failed_nodes = worker_nodes - nodes_stopped
                logger.debug(
                    f"Failed to stop workers on {len(failed_nodes)} nodes:"
                    f" {failed_nodes}. Skipping cluster termination."
                )
                cluster_issue = True

        # If all workers are stopped, ensure that all remaining nodes (if any; these can be unhealthy nodes not registered with MJS) are unprotected as well
        if not cluster_issue:
            unprotect_status = cloud_interface.unprotect_all_nodes()
            if not unprotect_status:
                logger.debug("Failed to unprotect all nodes in the Auto-Scaling Group.")
                cloud_issue = True

    if cluster_issue or cloud_issue:
        # If something went wrong, skip stopping essential services
        return termination_status(cloud_issue, cluster_issue)

    logger.debug("Stopping MATLAB Job Scheduler service...")
    jobmanager_stopped = os_interface.stop_job_manager()

    if jobmanager_stopped:
        mjs_stopped = os_interface.stop_mjs()

    if not mjs_stopped or not jobmanager_stopped:
        logger.debug(
            "Failed to stop MATLAB Job Scheduler on head-node. Skipping head-node termination."
        )
        cluster_issue = True

    # Delete mjs-status-transitions log file as it contains stale timestamps
    if os.path.exists(mjs_status_log_file):
        os.remove(mjs_status_log_file)
        logger.debug(f"Deleting {mjs_status_log_file} file...")

    logger.debug(
        f"Resetting the cluster termination policy to the initial choice: {initial_termination_policy}..."
    )

    policy_reset = cloud_interface.set_cluster_termination_policy(
        initial_termination_policy
    )
    if not policy_reset:
        logger.debug(
            "Failed to reset the cluster termination policy. Skipping head-node deallocation."
        )
        cloud_issue = True

    # Update the last termination policy in the cluster management data file as it might become stale
    # by the time the headnode is restarted in case the policy is a time-stamp
    cluster_management_interface.update_state(
        {LAST_TERMINATION_POLICY: initial_termination_policy}
    )

    # Update the cluster management data file before stopping the head-node
    if not cluster_management_interface.update_cluster_management_data_file():
        logger.error("Unable to update cluster management data file. Exiting...")
        return STATUS_INTERNAL_READ_WRITE_ISSUE

    return termination_status(cloud_issue, cluster_issue)


def termination_status(cloud_issue: bool, cluster_issue: bool) -> int:
    '''
    Helper function to compute appropriate exit status for the program.
    '''
    if cloud_issue and cluster_issue:
        return STATUS_CLOUD_AND_CLUSTER_ISSUE
    elif cloud_issue:
        return STATUS_CLOUD_ISSUE
    elif cluster_issue:
        return STATUS_CLUSTER_ISSUE
    else:
        return STATUS_SUCCESS
