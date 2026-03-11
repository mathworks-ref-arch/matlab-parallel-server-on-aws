#!/usr/bin/env bash
#
# Copyright 2025 The MathWorks, Inc.

## Remove all existing lines for NFS mounts from /etc/exports
sudo tee /etc/exports < /dev/null