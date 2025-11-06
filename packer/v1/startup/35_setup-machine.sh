#!/usr/bin/env bash

# Copyright 2024-2025 The MathWorks, Inc.
PS4='+ [\d \t] '
set -x

# Enable custom shutdown service on headnode
if [[ "${NODE_TYPE}" == "HEADNODE" ]]; then
    systemctl enable run-at-shutdown.service
    systemctl start run-at-shutdown.service
fi
