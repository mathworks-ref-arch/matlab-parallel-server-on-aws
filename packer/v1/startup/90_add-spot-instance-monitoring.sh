#!/usr/bin/env bash

# Copyright 2024-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x

if [[ "$NODE_TYPE" == "WORKER" ]] && [[ "$USE_SPOT_INSTANCE" == "Yes" ]]; then
    echo "Enabling Spot Instance monitoring service ..."

    systemctl enable spotinstances.timer
    systemctl start spotinstances.timer
fi
