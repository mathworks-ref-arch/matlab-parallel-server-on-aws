#!/usr/bin/env python3

# Copyright 2024-2025 The MathWorks, Inc.
import os
from datetime import datetime, timezone
import logging

from mwplatforminterfaces import CloudInterface

from cluster_management_interface import ClusterManagementProgramInterface
from constants import (
    STATUS_SUCCESS,
    STATUS_CLUSTER_ISSUE,
    WAS_MJS_BUSY,
    MJS_STATUS_LOG_FILE,
    CLUSTER_READY_FOR_TERMINATION,
    CLUSTER_AUTO_TERMINATED,
    UNUSED_CLUSTER_TIMEOUT_SECONDS,
)

logger = logging.getLogger("cluster_management.terminationpolicies.terminate_on_idle")



def main(
    cloud_interface: CloudInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """Execute terminate on idle routine.

    The routine checks the last line of the mjs_status_transitions.log file. If it says that MJS is idle, calculate the time delta
    between now and the timestamp in the last line. If the time delta is greater than the idle timeout, then terminate
    the cluster i.e. delete all the nodes in the cluster and then deallocate the head-node.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    mjs_status_log_path = cluster_management_interface.cluster_management_config[
        MJS_STATUS_LOG_FILE
    ]

    # If MJS was never busy, then we set the idle timeout to at least UNUSED_CLUSTER_TIMEOUT_SECONDS
    # This is done to ensure that the user gets enough time to submit their first job before termination begins.
    idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()
    if not cluster_management_interface.cluster_management_state[WAS_MJS_BUSY]:
        idle_timeout_seconds = max(idle_timeout_seconds, UNUSED_CLUSTER_TIMEOUT_SECONDS)

    if not os.path.isfile(mjs_status_log_path):
        logger.debug("~ Failed to find file %s. Skipping cluster termination as MJS state is not known.", mjs_status_log_path)
        return STATUS_CLUSTER_ISSUE
    
    with open(mjs_status_log_path, "r", encoding="utf-8") as file:
        state_change_records = file.readlines()
        if state_change_records:
            last_recorded_state = state_change_records[-1]
        else:
            # Handle the case where the file is empty
            logger.warning("MJS status log file is empty. Unable to determine MJS state.")
            return STATUS_CLUSTER_ISSUE

    if "MJS busy" in last_recorded_state:
        logger.info("> MJS is busy. Skipping cluster termination.")
        return STATUS_SUCCESS

    # MJS logs state as "MJS idle since: <timestamp> UTC"
    idle_timestamp_str = last_recorded_state.split("since: ")[1].split(" UTC")[0]
    
    idle_timestamp = datetime.strptime(idle_timestamp_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
    time_delta = int((datetime.now(timezone.utc) - idle_timestamp).total_seconds())

    logger.info("> MJS has been idle for %s seconds. Total timeout is %s seconds.", time_delta, idle_timeout_seconds)

    if time_delta > idle_timeout_seconds:
        logger.info("> MJS has been idle for more than the timeout. Marking cluster as ready for termination in the cluster management data file.")
        cluster_management_interface.update_state({
            CLUSTER_READY_FOR_TERMINATION: True,
            CLUSTER_AUTO_TERMINATED: True,
        })
    else:
        logger.info("> MJS has been idle for less than the timeout. Skipping cluster termination.")

    return STATUS_SUCCESS
