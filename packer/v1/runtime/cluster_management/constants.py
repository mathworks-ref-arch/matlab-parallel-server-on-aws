# Copyright 2024-2025 The MathWorks, Inc.

from typing import Dict, Type

# File to store constants that are used throughout modules of the Cluster Management program.

# Return statuses (int): Status code of the cluster management program.
STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
STATUS_CLUSTER_ISSUE = 2
STATUS_CLOUD_AND_CLUSTER_ISSUE = 3
STATUS_INTERNAL_READ_WRITE_ISSUE = 4

# Time to wait for a new cluster to become busy before considering it for termination
UNUSED_CLUSTER_TIMEOUT_SECONDS = 1800

# Cluster management program state variables
CLUSTER_READY_FOR_TERMINATION = "cluster_ready_for_termination"
WAS_MJS_BUSY = "was_mjs_busy"
FIRST_RUN_AFTER_REBOOT = "first_run_after_reboot"
LAST_TERMINATION_POLICY = "last_termination_policy"
LAST_OS_BOOT_TIME = "last_os_boot_time"
CLUSTER_AUTO_TERMINATED = "cluster_auto_terminated"
MIN_NODES_PRE_TERMINATION = "min_nodes_pre_termination"
MW_STATE_SET = "mw_state_set"
MW_STATE_COUNTER = "mw_state_counter"

# Type information for cluster management program state variables (needed for validation)
STATE_VARIABLES_TYPES: Dict[str, Type] = {
    CLUSTER_READY_FOR_TERMINATION: bool,
    WAS_MJS_BUSY: bool,
    FIRST_RUN_AFTER_REBOOT: bool,
    LAST_TERMINATION_POLICY: str,
    LAST_OS_BOOT_TIME: str,
    CLUSTER_AUTO_TERMINATED: bool,
    MIN_NODES_PRE_TERMINATION: str,
    MW_STATE_SET: bool,
    MW_STATE_COUNTER: str
}

# Cluster management program config variables. The are configuration parameters that should not be modified by the program.
AUTOSCALING_ENABLED = "autoscaling_enabled"
AUTOTERMINATION_ENABLED = "autotermination_enabled"
INITIAL_TERMINATION_POLICY = "initial_termination_policy"
INITIAL_DESIRED_CAPACITY = "initial_desired_capacity"
MJS_STATUS_LOG_FILE = "mjs_status_log_file"
