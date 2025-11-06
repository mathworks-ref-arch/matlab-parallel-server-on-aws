# Copyright 2024-2025 The MathWorks, Inc.

import json
import logging
import os
from typing import Dict
from types import MappingProxyType
from datetime import datetime

import psutil

from constants import (
    WAS_MJS_BUSY,
    FIRST_RUN_AFTER_REBOOT,
    LAST_OS_BOOT_TIME,
    STATE_VARIABLES_TYPES,
    MJS_STATUS_LOG_FILE,
    CLUSTER_READY_FOR_TERMINATION,
    MW_STATE_SET,
    MW_STATE_COUNTER,
)

logger = logging.getLogger("cluster_management.cluster_management_interface")

class ClusterManagementProgramInterface:
    """
    Class to interact with the cluster management program data file.
    """

    def __init__(self):
        """
        Read the cluster management data file and initialize values if the
        program is running for the first time after a reboot.
        """
        # Flag to check if the state needs to change
        self.update_state_file = False

        try:
            current_script_dir = os.path.dirname(os.path.realpath(__file__))
            # Define the path to the cluster management data JSON file
            self.__cluster_management_data_file_path = os.path.join(
                current_script_dir, "data", "cluster_management_data.json"
            )

            self._cluster_management_data = self._read_cluster_management_data_file()

            if not self._cluster_management_data:
                raise ValueError("Failed to read cluster management program data")

            self._cluster_management_config = self._cluster_management_data["config"]
            self._cluster_management_state = self._cluster_management_data["state"]

            # If these methods call self.update_state() then self.update_state_file will be set to True
            self._initialize_state_after_reboot()
            self._record_if_mjs_was_busy()
            if self.update_state_file:
                # Update the file only when state changes
                self.update_cluster_management_data_file()
                
        except Exception as e:
            logger.error("Initialization failed: %s", str(e))
            raise RuntimeError("ClusterManagementProgramInterface initialization failed") from e

    @property
    def cluster_management_state(self):
        '''Return the cluster management program state dictionary.'''
        return self._cluster_management_state

    @property
    def cluster_management_config(self):
        '''Return a read-only view of the cluster management configuration.'''
        return MappingProxyType(self._cluster_management_config)

    def update_state(self, updates: Dict) -> None:
        """
        Update the program state with validation for multiple key-value pairs.
        Raise exception if the update fails.

        Returns:
            None: This method only updates the program state dictionary.

        Note:
            This method does not automatically persist changes to the data file.
            The file will only be updated when update_cluster_management_data_file()
            is called.
        """
        logger.debug(
            "Updating cluster management program state with the following value(s):"
        )
        
        for key, value in updates.items():
            try:
                if key not in self._cluster_management_state:
                    raise KeyError(
                        f"Key: {key} not found in the cluster management data dictionary."
                    )
                expected_type = STATE_VARIABLES_TYPES.get(key)
                if expected_type and not isinstance(value, expected_type):
                    raise ValueError(
                        f"Invalid value for {key}: Must be a {expected_type.__name__}."
                    )
            except Exception as e:
                logger.exception(
                    "An error occurred while updating the cluster management state file: %s",
                    e
                )

            logger.debug(" - %s: %s", key, value)

            self._cluster_management_state[key] = value
            self.update_state_file = True


    def _read_cluster_management_data_file(self) -> Dict:
        """
        Read the cluster management state from a JSON file.

        Returns:
            Dict: A dictionary containing the state and config of the cluster management program.
                Returns an empty dictionary if an error occurs.
        """
        try:
            # Read existing data from the file
            with open(self.__cluster_management_data_file_path, "r", encoding="utf-8") as file:
                data = json.load(file)
            return data

        except FileNotFoundError:
            logger.error(
                "Cluster management data file not found at %s",
                self.__cluster_management_data_file_path
            )

        except json.JSONDecodeError:
            logger.error(
                "Cluster management data file contains invalid JSON at %s",
                self.__cluster_management_data_file_path
            )

        return {}

    def _record_if_mjs_was_busy(self) -> None:
        """
        Check if MJS was ever busy by retrieving recorded states in mjs_state_transitions.log file.
        If yes, update the cluster_management_state to record the same.

        Returns:
            None: This method only updates the state dictionary if needed.

        Note:
            This method does not automatically persist changes to the data file.
            The file will only be updated when update_cluster_management_data_file()
            is called.
        """
        if self._cluster_management_config[MJS_STATUS_LOG_FILE]:
            if not self._cluster_management_state[WAS_MJS_BUSY]:
                try:
                    with open(
                        self._cluster_management_config[MJS_STATUS_LOG_FILE], "r", encoding="utf-8"
                    ) as file:
                        log_content = file.read()
                    if "MJS busy" in log_content:
                        logger.debug(
                            "MJS found to be busy. Recording this in the cluster management data file."
                        )
                        self.update_state({WAS_MJS_BUSY: True})
                except FileNotFoundError:
                    pass

    def _initialize_state_after_reboot(self) -> None:
        """
        Initialize state variables if first run post reboot. Raise exception
        if the method fails.

        Returns:
            None: This method only updates the state dictionary if needed.

        Note:
            This method does not automatically persist changes to the data file.
            The file will only be updated when update_cluster_management_data_file()
            is called.
        """
        try:
            if self._is_first_run_after_reboot():
                logger.debug(
                    "This is the first run after a reboot. Initializing program state variables..."
                )
                self.update_state(
                    {
                        FIRST_RUN_AFTER_REBOOT: True,
                        CLUSTER_READY_FOR_TERMINATION: False,
                        WAS_MJS_BUSY: False,
                        MW_STATE_SET: False,
                        MW_STATE_COUNTER: "0"
                    }
                )
                mjs_status_log_file = self._cluster_management_config[
                    MJS_STATUS_LOG_FILE
                ]
                if os.path.exists(mjs_status_log_file):
                    logger.debug(
                        "Deleting %s as it may contain stale timestamps. "
                        "MJS will recreate the logs once it is up and running.",
                        mjs_status_log_file
                    )
                    os.remove(mjs_status_log_file)
            else:
                if self._cluster_management_state[FIRST_RUN_AFTER_REBOOT]:
                    self.update_state({FIRST_RUN_AFTER_REBOOT: False})
        except Exception as e:
            logger.exception(
                "An error occurred while initializing state file after reboot: %s",
                e
            )
            raise RuntimeError from e

    def _is_first_run_after_reboot(self) -> bool:
        """
        Check if the cluster_management program is running for the first time after a reboot.

        Returns: (bool) True if recorded boot time in the last program run 
        is different from the current run, else, False.

        Note:
            This method does not automatically persist changes to the data file.
            The file will only be updated when update_cluster_management_data_file()
            is called.
        """

        current_boot_timestamp = psutil.boot_time()
        current_boot_time = datetime.fromtimestamp(current_boot_timestamp)
        current_boot_time_str = current_boot_time.strftime("%Y-%m-%d %H:%M:%S")
        last_boot_time_str = self._cluster_management_state[LAST_OS_BOOT_TIME]

        if not last_boot_time_str:
            # This is the first run after deployment, not a reboot
            self.update_state({LAST_OS_BOOT_TIME: current_boot_time_str})
            return False

        # Convert last boot time string to a timestamp
        last_boot_time = datetime.strptime(last_boot_time_str, "%Y-%m-%d %H:%M:%S")
        last_boot_timestamp = last_boot_time.timestamp()

        # psutil can sometimes report slight deviations in boot time
        # Check if the difference is within the tolerance level of 5 seconds
        if abs(current_boot_timestamp - last_boot_timestamp) > 5:
            # Boot time can only change when OS is rebooted
            self.update_state({LAST_OS_BOOT_TIME: current_boot_time_str})
            return True

        return False

    def update_cluster_management_data_file(self) -> bool:
        """
        Update the cluster management data JSON file.

        Returns:
            bool: True if the file was successfully updated, False otherwise.
        """
        try:
            # Write the updated data back to the file
            with open(self.__cluster_management_data_file_path, "w", encoding="utf-8") as file:
                json.dump(self._cluster_management_data, file, indent=2)
                # Reset the state change flag once the changes are commited to disk
                self.update_state_file = False
            return True
        except Exception as e:
            logger.exception(
                "Encountered an error while updating the cluster management state json: %s",
                e
            )

        return False
