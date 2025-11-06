# Copyright 2022-2025 The MathWorks, Inc.

from .os_interface import AbstractOSInterface

from pathlib import Path

from .constants import MATLAB_ROOT_WIN


class WindowsInterface(AbstractOSInterface):
    """Class to interact with the MATLAB Job Scheduler on Windows."""

    def _get_matlabroot(self) -> Path:
        """Get the directory in which MATLAB is installed."""
        release_root = Path(MATLAB_ROOT_WIN)
        return next(release_root.glob("R????[ab]"))

    def _get_maxworkers_flag(self) -> str:
        """Get the worker operating system to set when using resize update.

        Returns:
            maxworkers_flag (str): Flag for resize update.
        """
        return "-maxwindowsworkers"

    def _get_nodestatus_executable(self) -> Path:
        """Get the path of the nodestatus executable"""
        return self._get_parallel_bin_root() / "nodestatus.bat"

    def _get_resize_executable(self) -> Path:
        """Get the path of the resize executable"""
        return self._get_parallel_bin_root() / "resize.bat"

    def _get_stopworker_executable(self) -> Path:
        """Get the path of the stopworker executable"""
        return self._get_parallel_bin_root() / "stopworker.bat"

    def _get_worker_os(self) -> str:
        """Get the worker operating system to look for in the resize status
        output.

        Returns:
            worker_os (str): Operating system of the workers.
        """
        return "windows"
