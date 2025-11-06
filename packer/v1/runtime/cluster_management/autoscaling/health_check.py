#!/usr/bin/env python3

# Copyright 2022-2025 The MathWorks, Inc.
import logging

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    STATUS_CLUSTER_ISSUE,
)

logger = logging.getLogger("cluster_management.autoscaling.health_check")


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Execute health check routine.

    The routine flags nodes that are in a bad state. A node is in a bad state
    if the worker group is in the 'Suspended' state. The cloud provider will
    then replace the affected nodes automatically.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        os_interface (OSInterface): Operating system specific implementation
        of AbstractOSInterface.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    current_nodes = cloud_interface.get_worker_nodes()
    if current_nodes is None:
        logger.error("There was an issue retrieving the worker nodes.")
        return STATUS_CLOUD_ISSUE

    logger.debug("Current nodes: %s", current_nodes)

    bad_nodes = os_interface.get_suspended_nodes(current_nodes)
    if bad_nodes is None:
        logger.error("There was an issue querying the worker nodes.")
        return STATUS_CLUSTER_ISSUE

    if bad_nodes:
        logger.debug("Marking nodes as unhealthy: %s", bad_nodes)
        nodes_were_marked = cloud_interface.set_nodes_unhealthy(bad_nodes)
        if nodes_were_marked:
            logger.info("Successfully marked nodes as unhealthy")
            return STATUS_SUCCESS
        else:
            logger.info("Failed to set nodes as unhealthy")
            return STATUS_CLOUD_ISSUE

    else:
        logger.info("All nodes are healthy")
        return STATUS_SUCCESS
