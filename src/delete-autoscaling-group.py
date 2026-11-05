# Copyright 2020-2021 The MathWorks, Inc.

import boto3
import cfnresponse

def lambda_handler(event, context):
    print(f"Region = {event['ResourceProperties']['Region']}")
    print(f"ASGName = {event['ResourceProperties']['ASGName']}")
    responseData = {}
    if event['RequestType'] == 'Delete':
        responseData['output'] = 'This was a delete event.'
        asg_client = boto3.client('autoscaling', region_name=event['ResourceProperties']['Region'])
        asg_response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[event['ResourceProperties']['ASGName']])
        asgClient = boto3.client('autoscaling', region_name=event['ResourceProperties']['Region'])
        for auto_scaling_group in asg_response['AutoScalingGroups']:
            for instance in auto_scaling_group['Instances']:
                asgClient.set_instance_protection(InstanceIds=[instance['InstanceId']], AutoScalingGroupName=event['ResourceProperties']['ASGName'], ProtectedFromScaleIn=False)
                print(f'Unprotected : {instance["InstanceId"]}')
    else:
        responseData['output'] = 'This was not a delete event.'
    cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, "CustomResourcePhysicalID")
