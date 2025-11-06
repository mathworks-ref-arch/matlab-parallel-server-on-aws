# Copyright 2024-2025 The MathWorks, Inc.
# File to store constants that are used throughout modules of the mwplatforminterfaces package.

# AWS IMDS URL: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
IMDS_URL = "http://169.254.169.254"

# Time after launch before the node is considered fully running
GRACE_PERIOD_MINUTES = 5

# Tag for checking the idle timeout for a node
IDLE_TIMEOUT_TAG = "mwWorkerIdleTimeoutMinutes"

# Default value for the IDLE_TIMEOUT_TAG tag
IDLE_TIMEOUT_DEFAULT = 10

# Tag for checking the shutdown mode for the cluster
CLUSTER_TERMINATION_TAG = "mw-autoshutdown"

# Tag for checking the cluster readiness
MW_STATE_TAG = "mw-state"

# MATLAB installation directories
MATLAB_ROOT="/usr/local/matlab"
MNT_ROOT="/mnt/matlab"
MATLAB_ROOT_WIN="C:\\Program Files\\MATLAB"
