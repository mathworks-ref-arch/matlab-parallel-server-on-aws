# Copyright 2021-2025 The MathWorks, Inc.

from .os_interface import AbstractOSInterface
import logging

from .constants import (
    MATLAB_ROOT,
    MNT_ROOT,
)

logger = logging.getLogger("mwplatforminterfaces.linux_interface")


from pathlib import Path
import os


class LinuxInterface(AbstractOSInterface):
    """Class to interact with the MATLAB Job Scheduler on Linux."""

    def _get_matlabroot(self) -> Path:
        """Get the directory in which MATLAB is installed."""
        root = Path(MATLAB_ROOT)
        if not root.exists():
            root = Path(MNT_ROOT)
        return root

    def _get_maxworkers_flag(self) -> str:
        """Get the worker operating system to set when using resize update.

        Returns:
            maxworkers_flag (str): Flag for resize update.
        """
        return "-maxlinuxworkers"

    def _get_stopjobmanager_executable(self) -> Path:
        """Get the path of the stopjobmanager executable"""
        return self._get_parallel_bin_root() / "stopjobmanager"

    def _get_mjs_executable(self) -> Path:
        """Get the path of the stopworker executable"""
        return self._get_parallel_bin_root() / "mjs"

    def _get_nodestatus_executable(self) -> Path:
        """Get the path of the nodestatus executable"""
        return self._get_parallel_bin_root() / "nodestatus"

    def _get_resize_executable(self) -> Path:
        """Get the path of the resize executable"""
        return self._get_parallel_bin_root() / "resize"

    def _get_stopworker_executable(self) -> Path:
        """Get the path of the stopworker executable"""
        return self._get_parallel_bin_root() / "stopworker"

    def _get_worker_os(self) -> str:
        """Get the worker operating system to look for in the resize status
        output.

        Returns:
            worker_os (str): Operating system of the workers.
        """
        return "linux"

    def _stop_instance(self) -> bool:
        """
        Shuts down the head-node. In AWS, this automatically deallocates the instance.
        Returns:
            True: If the shutdown command succeeds.
            False: If shutdown operation fails.
        """

        try:
            os.system("sudo shutdown -h now")
        except Exception as e:
            logger.exception(
                "An error occurred while shutting down the instance: %s", e
            )

            return False
        return True
