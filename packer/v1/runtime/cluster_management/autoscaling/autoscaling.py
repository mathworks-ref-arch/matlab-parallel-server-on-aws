#!/usr/bin/env python3

# Copyright 2022-2025 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from autoscaling import capacity_control
from autoscaling import health_check
from autoscaling import scale_in_protection

import logging

logger = logging.getLogger("cluster_management.autoscaling")


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Execute autoscaling routine.

    The routine has three stages:
        1. Capacity control: Update the cloud platform's desired capacity and
           MJS max capacity.
        2. Health check: Identifies nodes in an unhealthy state and requests
           their termination.
        3. Scale-in protection: Ensures that we do not terminate nodes with
           ongoing work.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    logger.info("# Starting capacity control")
    status_cc = capacity_control.main(cloud_interface, os_interface)
    logger.info("# Finished capacity control: %s", status_cc)

    logger.info("# Starting health check")
    status_hc = health_check.main(cloud_interface, os_interface)
    logger.info("# Finished health check: %s", status_hc)

    logger.info("# Starting scale-in protection")
    status_sp = scale_in_protection.main(cloud_interface, os_interface)
    logger.info("# Finished scale-in protection: %s", status_sp)

    return max(status_cc, status_hc, status_sp)
