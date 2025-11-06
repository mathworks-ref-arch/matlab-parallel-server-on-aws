#!/usr/bin/env bash

# Copyright 2024-2025 The MathWorks, Inc.

# Get token for IMDSV2 access
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")

INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)

# Set the mw-state tag to 'down'
aws ec2 create-tags --resources "${INSTANCE_ID}" --tags Key=mw-state,Value=down
