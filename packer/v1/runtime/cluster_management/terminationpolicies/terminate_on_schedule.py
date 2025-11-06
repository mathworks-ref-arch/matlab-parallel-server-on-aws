#!/usr/bin/env python3

# Copyright 2024-2025 The MathWorks, Inc.
from datetime import datetime, timezone, timedelta
import logging

from mwplatforminterfaces import CloudInterface

from cluster_management_interface import ClusterManagementProgramInterface

from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    LAST_TERMINATION_POLICY,
    CLUSTER_READY_FOR_TERMINATION,
    CLUSTER_AUTO_TERMINATED,
)

logger = logging.getLogger(
    "cluster_management.terminationpolicies.terminate_on_schedule"
)


def main(
    cloud_interface: CloudInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """Execute terminate on schedule routine.

    The routine terminates the cluster and the head node once the scheduled time is reached.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.
        cluster_management_state["last_termination_policy"] should be a timestamp in the
        form '%a, %d %b %Y %H:%M:%S %Z' or string of type 'After x hours'.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
    """
    valid_datetime_format = "%a, %d %b %Y %H:%M:%S"
    current_time = datetime.now(timezone.utc)
    autoshutdown_schedule = cluster_management_interface.cluster_management_state[
        LAST_TERMINATION_POLICY
    ]

    if autoshutdown_schedule.startswith("After"):
        # If autoshutdown_schedule is in the form 'After x hours', 
        # calculate the termination time and set it as the mw-autoshutdown tag on the head node
        shutdown_after_hours = int(autoshutdown_schedule.split()[1])
        autoshutdown_timestamp = current_time + timedelta(hours=shutdown_after_hours)
        
        timestamp_set = cloud_interface.set_cluster_termination_policy(
            autoshutdown_timestamp.strftime(valid_datetime_format) + " GMT"
        )
        if not timestamp_set:
            logger.error(
                "Failed to update the cluster termination policy tag in the headnode."
            )
            return STATUS_CLOUD_ISSUE
    else:
        # This means the given string is in RFC 1123 format. Convert the same to datetime object.
        autoshutdown_timestamp = (
            datetime.strptime(autoshutdown_schedule, valid_datetime_format + " %Z")
        ).replace(tzinfo=timezone.utc)

    # Check if current time in UTC is greater than the timestamp
    if current_time > autoshutdown_timestamp:
        logger.info(
            "Autoshutdown schedule reached. Marking cluster as ready for termination in the cluster management data file."
        )
        cluster_management_interface.update_state(
            {CLUSTER_READY_FOR_TERMINATION: True, CLUSTER_AUTO_TERMINATED: True}
        )
    else:
        time_left = autoshutdown_timestamp - current_time
        total_minutes = time_left.total_seconds() // 60
        logger.info(
            "Autoshutdown schedule not reached. Time left before termination: %d minute(s). Exiting...",
            int(total_minutes)
        )

    return STATUS_SUCCESS
