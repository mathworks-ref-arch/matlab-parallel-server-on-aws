# Copyright 2026 The MathWorks, Inc.

"""
End-to-end smoke tests that check the deployed headnode.
"""

import json
import os

import pytest

from helpers import run_ssm_shell_checked

# Set by the pipeline when the AMI came from a previous release rather than a
# build in this run, and to the AMI it deployed.
MOCK_BUILD = os.environ.get("MOCK_BUILD", "").lower() == "true"
EXPECTED_AMI_ID = os.environ.get("EXPECTED_AMI_ID", "")

# nodestatus exits non-zero when it cannot reach the MJS service.
NODESTATUS = """
set -e
/usr/local/matlab/toolbox/parallel/bin/nodestatus -json
"""


@pytest.mark.skipif(
    MOCK_BUILD, reason="a mock build deploys an AMI this run did not produce"
)
@pytest.mark.skipif(not EXPECTED_AMI_ID, reason="EXPECTED_AMI_ID is not set")
def test_instance_booted_the_image_this_build_produced(ec2_client, instance_id):
    """The headnode is running the image this build produced."""
    image_id = ec2_client.describe_instances(InstanceIds=[instance_id])[
        "Reservations"
    ][0]["Instances"][0]["ImageId"]
    assert image_id == EXPECTED_AMI_ID, (
        f"Instance runs {image_id}, but this build produced {EXPECTED_AMI_ID}"
    )


def test_mjs_is_running(ssm_client, instance_id):
    """MJS is running on the headnode and its job manager reports running."""
    status = json.loads(run_ssm_shell_checked(ssm_client, instance_id, NODESTATUS))
    job_managers = status.get("jobManagers") or []
    assert job_managers, f"nodestatus reports no job manager: {status}"
    assert job_managers[0].get("status", "").lower() == "running", (
        f"Job manager is not running: {job_managers[0]}"
    )
