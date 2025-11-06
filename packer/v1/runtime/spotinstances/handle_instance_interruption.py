#!/usr/bin/env python3

# Copyright 2024-2025 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler
import sys

STATUS_SUCCESS = 0
STATUS_FAILED = 1


def main() -> int:
    """Check Spot Instance status and handle interruption event.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue
    """

    print("Retrieving spot instance interruption status ...")
    is_instance_marked_for_removal = (
        CloudInterface.is_spot_instance_marked_for_removal()
    )

    if not is_instance_marked_for_removal:
        print(
            "No action needed, because the instance is not flagged "
            "by AWS for removal."
        )
        return STATUS_SUCCESS

    print("The instance is flagged by AWS for removal. Stopping workers ...")
    print("Connecting to cluster ...")
    os_interface = OSInterface()
    sw_success = os_interface.stop_workers_locally()

    if sw_success:
        print("Stopped workers successfully.")
        return STATUS_SUCCESS

    print("Failed to stop workers.")
    return STATUS_FAILED


if __name__ == "__main__":
    # Create logger
    logger = logging.getLogger("mw.spot_interruption")
    log_file = "/var/log/mathworks/spot_interruption.log"
    log_handler = RotatingFileHandler(log_file, maxBytes=1e6, backupCount=5)
    log_handler.terminator = ""
    logger.addHandler(log_handler)
    logger.setLevel(logging.INFO)
    sys.stdout.write, sys.stderr.write = logger.info, logger.warning

    print(f"## Starting: {datetime.now():%Y-%m-%d %H:%M:%S}")
    status = main()
    print(f"## Finished: {datetime.now():%Y-%m-%d %H:%M:%S}\n")

    sys.exit(status)
