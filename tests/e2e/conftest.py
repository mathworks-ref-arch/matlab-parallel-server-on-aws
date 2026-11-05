# Copyright 2026 The MathWorks, Inc.

"""
Shared pytest fixtures and configuration for the MATLAB Parallel Server on AWS
end-to-end tests.
"""

import logging
import os

import boto3
import pytest

logger = logging.getLogger(__name__)


def pytest_addoption(parser):
    parser.addoption(
        "--stack-name",
        action="store",
        default=None,
        help="Name of the deployed CloudFormation stack to test against",
    )
    parser.addoption(
        "--aws-region",
        action="store",
        default=None,
        help="AWS region where the stack is deployed",
    )


def _get_config_value(request, option_name, env_var_name):
    value = request.config.getoption(f"--{option_name}")
    if value:
        logger.info(f"Configuration '{option_name}' loaded from CLI argument: {value}")
        return value
    value = os.environ.get(env_var_name)
    if value:
        logger.info(
            f"Configuration '{option_name}' loaded from environment variable {env_var_name}: {value}"
        )
        return value

    # Missing config is a can't-run condition, not a test failure: abort the session.
    pytest.exit(
        f"Missing configuration. Provide either --{option_name} or set {env_var_name} environment variable.",
        returncode=pytest.ExitCode.USAGE_ERROR,
    )


@pytest.fixture(scope="session")
def stack_name(request):
    return _get_config_value(request, "stack-name", "STACK_NAME")


@pytest.fixture(scope="session")
def aws_region(request):
    return _get_config_value(request, "aws-region", "AWS_REGION")


@pytest.fixture(scope="session")
def ec2_client(aws_region):
    return boto3.client("ec2", region_name=aws_region)


@pytest.fixture(scope="session")
def cf_client(aws_region):
    return boto3.client("cloudformation", region_name=aws_region)


@pytest.fixture(scope="session")
def ssm_client(aws_region):
    return boto3.client("ssm", region_name=aws_region)


@pytest.fixture(scope="session")
def instance_id(cf_client, stack_name):
    """The headnode, the stack's only EC2 instance. Workers are in the Auto Scaling group."""
    logger.info(f"Retrieving Instance ID for stack: {stack_name}")
    resources = cf_client.describe_stack_resources(StackName=stack_name)
    for resource in resources["StackResources"]:
        if resource["ResourceType"] == "AWS::EC2::Instance":
            value = resource["PhysicalResourceId"]
            logger.info(f"Instance ID retrieved: {value}")
            return value
    pytest.fail(f"Could not find an EC2 Instance in stack '{stack_name}'.")
