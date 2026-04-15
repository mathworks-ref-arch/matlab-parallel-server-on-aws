#!/usr/bin/env python3

# Copyright 2022-2026 The MathWorks, Inc.
import logging

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
)

logger = logging.getLogger("cluster_management.autoscaling.health_check")

def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Evaluate orphaned nodes in the cluster.

    This routine looks for nodes that have been running for atleast 
    idle_timeout_seconds and are not registered with MJS or are in a suspended state. 
    These could be unhealthy nodes that are orphaned from MJS due to unexpected 
    reasons (user data execution failure, etc.).

    The routine will try to set their health status as Unhealthy. The cloud platform will
    then automatically replace the nodes with new ones to match the desired capacity.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        os_interface (OSInterface): Operating system specific implementation
        of AbstractOSInterface.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
    """
    # The idle timeout for workers is defined by the mwWorkerIdleTimeoutMinutes
    # tag defined in the cluster auto-scaling group resource
    idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()
    logger.debug("Idle timeout is %ss", idle_timeout_seconds)

    # Retrieve current nodes in the cluster that are running for
    # at least idle_timeout_seconds
    current_nodes = cloud_interface.get_worker_nodes(
        grace_period_seconds = idle_timeout_seconds
    )

    if not current_nodes:
        logger.info("There are no worker nodes running for more than %s seconds.",
                    idle_timeout_seconds)
        return STATUS_SUCCESS

    logger.debug("%d nodes running for more than %s seconds: %s",
                 len(current_nodes), idle_timeout_seconds, current_nodes)

    # Worker nodes where MATLAB workers have been suspended or stopped
    suspended_nodes = os_interface.get_suspended_nodes(current_nodes)

    logger.debug("%d suspended nodes: %s", len(suspended_nodes), suspended_nodes)

    # Retrieve nodes that are registered with MJS
    registered_worker_nodes = os_interface.get_worker_nodes()

    # We target nodes that are not registered with MJS
    current_unregistered_nodes = current_nodes - registered_worker_nodes

    logger.debug("%d unregistered nodes: %s",
                 len(current_unregistered_nodes),
                 current_unregistered_nodes
                )

    nodes_to_mark_unhealthy = suspended_nodes.union(current_unregistered_nodes)

    if not nodes_to_mark_unhealthy:
        logger.info("All nodes are healthy")
        return STATUS_SUCCESS

    logger.info("Marking suspended and unregistered nodes as unhealthy: %s",
                nodes_to_mark_unhealthy)
    nodes_were_marked = cloud_interface.set_nodes_unhealthy(nodes_to_mark_unhealthy)

    if not nodes_were_marked:
        logger.error("Failed to mark nodes as unhealthy")
        return STATUS_CLOUD_ISSUE

    return STATUS_SUCCESS
