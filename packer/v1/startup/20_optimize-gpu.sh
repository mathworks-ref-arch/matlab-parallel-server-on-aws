#!/usr/bin/env bash

# Copyright 2022-2025 The MathWorks, Inc.

# Achieve best performance on NVIDIA GPU instances.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/optimize_gpu.html

if [[ ${OPTIMIZE_GPU} == 'Yes' ]]; then

    nvidia-persistenced

    INSTANCE_TYPE=$(curl -fs --retry 3 http://169.254.169.254/latest/meta-data/instance-type)
    case ${INSTANCE_TYPE} in
        g2*)
            nvidia-smi --auto-boost-default=0
            ;;
        g3*)
            nvidia-smi --auto-boost-default=0
            nvidia-smi -ac 2505,1177
            ;;
        g4dn*)
            nvidia-smi -ac 5001,1590
            ;;
        g5*)
            nvidia-smi -ac 6250,1710
            ;;
        p2*)
            nvidia-smi --auto-boost-default=0
            nvidia-smi -ac 2505,875
            ;;
        p3*)
            nvidia-smi -ac 877,1530
            ;;
        p4de*)
            nvidia-smi -ac 1593,1410
            ;;
        p4d*)
            nvidia-smi -ac 1215,1410
            ;;
    esac
fi
