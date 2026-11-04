# End-to-End Tests

This directory contains the end-to-end test suite for the MATLAB Parallel Server
on AWS (Linux) reference architecture that run against a live CloudFormation stack.

## What Is Tested

- The headnode runs the image this build produced (skipped on a mock build)
- MATLAB Job Scheduler (MJS) is running on the headnode and its job manager reports running

The tests do not start MATLAB or submit work to the scheduler, so no license is needed.

## Prerequisites

- A deployed CloudFormation stack from this reference architecture.
- AWS credentials with access to the stack, EC2, and SSM. These are read from the
  environment by boto3 (for example, supplied to a CI runner via OIDC).
- The headnode must be registered with SSM (a managed instance) so Run Command can
  reach it. The template grants the headnode role the permissions it needs for this.

## Configuration

Each value can be provided as a CLI option or an environment variable. When both
are set, the CLI option wins.

| Setting       | CLI option      | Environment variable    | Default     | Notes                                  |
| ------------- | --------------- | ----------------------- | ----------- | ---------------------------------------|
| Stack name    | `--stack-name`  | `STACK_NAME`            | _required_  | CloudFormation stack to test against.  |
| AWS region    | `--aws-region`  | `AWS_REGION`            | _required_  | Region the stack is deployed in.       |
| Built image | | `EXPECTED_AMI_ID` | unset | Image this build produced. The image check skips when it is unset or `MOCK_BUILD` is `true`. |

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Running

```bash
pytest --stack-name my-cluster-stack --aws-region us-east-1
```

Equivalently, using environment variables:

```bash
export STACK_NAME=my-cluster-stack
export AWS_REGION=us-east-1

pytest
```

## Notes
- Logs are captured and pytest replays them only for failing tests.

----

Copyright 2026 The MathWorks, Inc.

----
