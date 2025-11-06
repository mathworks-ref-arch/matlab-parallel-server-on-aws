#!/usr/bin/env python3

# Copyright 2024-2025 The MathWorks, Inc.

import sys

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from autoscaling import autoscaling
from mwstate import set_mw_state
from utils import terminate_cluster
from utils import helpers
from cluster_management_interface import ClusterManagementProgramInterface


from constants import (
    STATUS_SUCCESS,
    STATUS_INTERNAL_READ_WRITE_ISSUE,
    CLUSTER_READY_FOR_TERMINATION,
    AUTOSCALING_ENABLED,
    AUTOTERMINATION_ENABLED,
)

from logging_config import setup_logger

logger = setup_logger("cluster_management")

def main() -> int:
    """Execute the cluster management program.

    The program has two routines that are executed according to the user's choice:
        1. Auto-scaling: Resize cluster based on workload. Executed if data['config']['autoscaling_enabled'] is True.
           This choice is saved in cluster management data JSON file.

        2. Termination policy routine:
            - Termination when idle: Terminate the whole cluster if MJS is idle for a certain amount of time, or,
            - Termination on schedule: Terminate the whole cluster after a certain amount of time decided by the user.

    Termination policies are dictated by the tag mw-autoshutdown in the head-node.

    Returns:
        status (int): Status code of program.
            0: Successful
            1: Faced an issue with cloud provider
            2: Faced an issue with cluster
            3: Faced an issue with both
            4: Faced an issue while reading/writing cluster management data json
    """
    # Initialize status variables
    autoscaling_status = STATUS_SUCCESS
    termination_routine_status = STATUS_SUCCESS
    cluster_termination_status = STATUS_SUCCESS

    logger.info("Connecting to the cloud computing platform...")
    cloud_interface = CloudInterface()

    logger.info("Connecting to cluster...")
    os_interface = OSInterface()

    logger.info("Reading the cluster management program data file...")
    cluster_management_interface = ClusterManagementProgramInterface()

    # Determine cluster readiness
    mw_cluster_status = set_mw_state.main(cloud_interface, os_interface, cluster_management_interface)

    # Start autoscaling if it is enabled
    if (
        cluster_management_interface.cluster_management_config[AUTOSCALING_ENABLED]
        and not cluster_management_interface.cluster_management_state[
            CLUSTER_READY_FOR_TERMINATION
        ]
        and os_interface.is_mjs_running()
    ):
        logger.debug("Starting autoscaling routine...")
        autoscaling_status = autoscaling.main(cloud_interface, os_interface)
        logger.debug("Completed autoscaling routine.")

    if cluster_management_interface.cluster_management_config[AUTOTERMINATION_ENABLED]:
        # Assess the termination policy set on the head-node and execute if set
        termination_routine_status = helpers.start_termination_routine(
            cloud_interface,
            cluster_management_interface,
        )

    if cluster_management_interface.update_state_file: 
        state_updated = cluster_management_interface.update_cluster_management_data_file()
        if not state_updated:
            logger.error("Unable to update cluster management data file. Exiting...")
            return STATUS_INTERNAL_READ_WRITE_ISSUE

    if cluster_management_interface.cluster_management_state[
        CLUSTER_READY_FOR_TERMINATION
    ]:
        logger.debug(
            "Cluster marked as ready for termination in the cluster management data file."
            " Starting cluster termination..."
        )
        cluster_termination_status = terminate_cluster.main(
            cloud_interface,
            os_interface,
            cluster_management_interface,
        )

        if cluster_termination_status == STATUS_SUCCESS:
            logger.debug("Attempting to deallocate the head-node...")
            headnode_deallocated = os_interface.shutdown_instance()
            if not headnode_deallocated:
                logger.debug("Failed to deallocate the head-node.")

    return max(
        mw_cluster_status, autoscaling_status, termination_routine_status, cluster_termination_status
    )


if __name__ == "__main__":
    logger.info("Starting cluster management program ...")
    status = main()
    logger.info("Finished cluster management program.\n\n")
    sys.exit(status)
