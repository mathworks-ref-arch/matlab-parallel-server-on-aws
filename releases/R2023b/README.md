# MATLAB Parallel Server  on Amazon Web Services (Linux VM)

## Step 1. Deploy the Template

Click the **Launch Stack** button for your desired region below to deploy the cloud resources on Amazon&reg; Web Services (AWS&reg;). This opens the AWS console in your web browser.

| Region | Launch Link |
| --------------- | ----------- |
| **us-east-1** | [![alt text](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png "Start an cluster using the template")](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://mdcs-on-aws.s3.amazonaws.com/R2023b/mjs-cluster-template.json) |
| **us-west-2** | [![alt text](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png "Start an cluster using the template")](https://us-west-2.console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?templateURL=https://mdcs-on-aws.s3.amazonaws.com/R2023b/mjs-cluster-template.json) |
| **eu-west-1** | [![alt text](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png "Start an cluster using the template")](https://eu-west-1.console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?templateURL=https://mdcs-on-aws.s3.amazonaws.com/R2023b/mjs-cluster-template.json) |
| **ap-northeast-1** | [![alt text](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png "Start an cluster using the template")](https://ap-northeast-1.console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/create/review?templateURL=https://mdcs-on-aws.s3.amazonaws.com/R2023b/mjs-cluster-template.json) |

To deploy the cluster in a region not listed above, see [Deploy Cluster in a Custom Region](#deploy-cluster-in-a-custom-region).

## Step 2. Configure the Cloud Resources
Clicking the **Launch Stack** button above opens the “Quick create stack” page in your browser. You can configure the parameters on this page. It is easier to complete the steps if you position these instructions and the AWS console window side by side.

1. Specify a stack name in the AWS CloudFormation console. The name must be unique within your AWS account.

2. Specify and check the defaults for these resource parameters:

| Parameter label | Description |
| --------------- | ----------- |
| **VPC to deploy this stack to** | ID of an existing VPC in which to deploy this stack. |
| **Subnets for the head node and worker nodes** | List of existing public subnets IDs for the head node and workers. |
| **CIDR IP address range of client** | Comma-separated list of IP address ranges that will be allowed to connect to the cluster. Each IP CIDR should be formatted as \<ip_address>/\<mask>. The mask determines the number of IP addresses to include. A mask of 32 is a single IP address. Example of allowed values: 10.0.0.1/32 or 10.0.0.0/16,192.34.56.78/32. This calculator can be used to build a specific range: https://www.ipaddressguide.com/cidr. You may need to contact your IT administrator to determine which address is appropriate. |
| **Name of SSH key** | Name of an existing EC2 KeyPair to allow SSH access to all the instances. See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html for details on creating these. |
| **Cluster name** | Name to use for this cluster. This name is shown in MATLAB as the cluster profile name. |
| **Instance type for the head node** | AWS instance type to use for the head node, which runs the job manager. No workers start on this node, so this can be a smaller instance type than the worker nodes. By default, the heap memory for the job manager is set between 1024 MiB and a maximum of half of the instance memory, depending on the total number of MATLAB workers. See https://aws.amazon.com/ec2/instance-types for a list of instance types. Must be available in the Availability Zone of the first subnet in the configured list. |
| **Custom AMI ID (Optional)** | ID of a custom Amazon Machine Image (AMI) in the target region (optional). Ensure that the custom machine image is compatible with the provided CloudFormation template. The ID should start with 'ami-'. |
| **Enable shared storage across cluster** | Option indicating what type of shared storage to use for the cluster. This storage is shared among all worker nodes and persists between cluster runs. You can choose between two types of persisted storage: Elastic File System (EFS) or Elastic Block Store (EBS). For more information, see https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws. |
| **Storage size for the MATLAB Job Scheduler database and shared storage** | Size in GiB of the shared EBS volume containing MATLAB Job Scheduler and user data. All job and task information, including input and output data, is stored on this volume and should therefore have enough capacity to store the expected amount of data. |
| **Instance type for the worker nodes** | AWS instance type to use for the workers. By default, the heap memory for all worker process is set between 1024 MiB and a maximum of a quarter of the instance memory, depending on the number of MATLAB workers on the instance. See https://aws.amazon.com/ec2/instance-types for a list of instance types. |
| **Use Spot Instances for worker nodes** | Option indicating whether to enable AWS Spot instances for worker nodes. For more information, refer to the FAQ section in the deployment README. |
| **Number of worker nodes** | Number of AWS instances to start for the workers to run on. |
| **Minimum number of worker nodes** | Minimum number of AWS instances running at all times. |
| **Maximum number of worker nodes** | Maximum number of AWS instances running at all times. |
| **Number of workers to start on each node** | Number of MATLAB workers to start on each instance. Specify 1 worker per physical core (1 worker for every 2 vCPU). For example an m4.16xlarge instance has 64 vCPUs, so can support 32 MATLAB workers. See https://aws.amazon.com/ec2/instance-types for details on vCPUs for each instance type. |
| **Level of logs to be generated by MJS** | Log level controls the amount of detail in the logs generated by MJS, ranging from '0-Off' (no logging aside from essential system messages) to '6-Highest' (full debug mode). To diagnose any cluster issues with support engineers, increase the log level. Log levels above '3-Medium' can reduce performance. |
| **License Manager for MATLAB connection string** | Optional License Manager for MATLAB, specified as a string in the form \<port>@\<hostname>. If not specified, use online licensing. If specified, the network license manager (NLM) must be accessible from the specified VPC and subnets. To use the private hostname of the NLM host instead of the public hostname, specify the security group ID of the NLM host in the AdditionalSecurityGroup parameter. For more information, see https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-aws. |
| **Configure cloudwatch logging for the MATLAB Parallel Server instances** | Flag indicating whether cloudwatch logging for the MATLAB Parallel Server instances is enabled. |
| **Additional security group to place instances in** | ID of an additional (optional) Security Group for the instances to be placed in. Often the License Manager for MATLAB's Security Group. |
| **Security level** | Security level for the cluster. Level 0: Any user can access any jobs and tasks. Level 1: Accessing other users' jobs and tasks issues a warning. However, all users can still perform all actions. Level 2: Users must enter a password to access their jobs and tasks. The job owner can grant access to other users. |
| **Enable instance autoscaling** | Flag indicating whether instance autoscaling is enabled. For more information about autoscaling, refer to the Use Autoscaling section in the deployment README. |
| **AutomaticallyTerminateCluster** | Option to auto-terminate the cluster after a few hours or when idle. When the cluster is terminated, all worker nodes are deleted and the headnode is stopped. Select 'Never' to disable auto-termination now but you can enable it later. Select 'Disable auto-termination' to fully disable this feature. For more information, refer to 'Automatically terminate the MATLAB Parallel Server cluster' section in the deployment README. |
| **Scheduling algorithm** | Scheduling algorithm for the job manager. 'standard' spreads communicating jobs across as few worker machines as possible to reduce communication overheads and fills in unused spaces on worker machines with independent jobs. Suitable for good behaviour for a wide range of uses including autoscaling. 'loadBalancing' distributes load evenly across the cluster to give as many resources as possible to running jobs and tasks when the cluster is underutilized. |
| **Create EBS Snapshot on Stack Deletion** | (Optional) Select 'Yes' to create an EBS snapshot with the MATLAB Job Scheduler database when you delete the stack. If you have enabled EBS shared storage, this data will also be included. Note that this incurs additional AWS costs. For more information, refer to the FAQ section in the deployment README. |
| **Custom Tag for Snapshot** | (Optional) Custom tag value to help you identify the EBS snapshot created during stack deletion. Applicable only if you enable creating an EBS snapshot on deletion. Tag key is 'mw-ConfigId'. |
| **EBS Snapshot ID** | (Optional) ID of the EBS snapshot to restore MATLAB Job Scheduler data from a previous cluster. Ensure to use the same 'Cluster name' and MATLAB version as your previous cluster. The snapshot must be in the same region as your current deployment. To deploy a new cluster without restoring any data, leave this field blank. For further details, refer to the FAQ section in the deployment README. |
| **Optional user inline command** | Provide an optional inline shell command to run on machine launch. For example, to set an environment variable CLOUD=AWS, use this command excluding the angle brackets: \<echo -e "export CLOUD=AWS" \| tee -a /etc/profile.d/setenvvar.sh>. To run an external script, use this command excluding the angle brackets: \<wget -O /tmp/my-script.sh "https://example.com/script.sh" && bash /tmp/my-script.sh>. Find the logs at '/var/log/mathworks/user-data.log' and '/var/log/mathworks/startup.log'. |


3. Tick the box to accept that the template uses Identity and Access Management (IAM) roles. These roles allow:
    * The instances to transfer the shared secret information between the nodes, via the Amazon S3&trade; bucket, to establish SSL encrypted communications.
    * The instances to write the cluster profile to the S3 bucket for secure access to the cluster from the client MATLAB&reg;.
    * A custom lambda function to delete the contents of this S3 bucket when you delete the stack.

4. Tick the box to accept that the template will auto expand [nested stacks](#nested-stacks).

5. Click the **Create** button.

When you click **Create**, the cluster is created using AWS CloudFormation templates.

## Step 3: Connect to Your Cluster From MATLAB

1. After clicking **Create stack**, you are taken to the **Stack details** page for your Stack. Wait for the Status to reach **CREATE\_COMPLETE**. This may take up to 10 minutes.
2. Select **Outputs**.

    ![Stack Outputs On Completion](../../img/cloudformation-stack-creation-complete.png)

3. Click the link next to **BucketURL** under **Value**.
4. Select the profile (**ClusterName.mlsettings**) and click **Download**.
5. Open MATLAB.
6. In the Parallel drop-down menu in the MATLAB toolstrip, select **Create and Manage Clusters**.
7. Click **Import**.
8. Select the downloaded profile, and click **Open**.
9. Click **Set as Default**.
10. (Optional) Validate your cluster by clicking the **Validate** button.

After setting the cloud cluster as default, the next time you run a parallel language command (such as `parfor`, `spmd`, `parfeval` or `batch`), MATLAB connects to the cluster. The first time you connect, you are prompted for your MathWorks&reg; account login. The first time you run a task on a worker, it takes several minutes for the worker MATLAB to start. This delay is due to initial loading of data from the EBS volumes. This is a one-time operation, and subsequent tasks begin much faster.

Your cluster is now ready to use. 

**NOTE**: Use the profile and client IP address range to control access to your cloud resources. Anyone with the profile file can connect to your resources from a machine within the specified IP address range and run jobs on it.

Your cluster remains running after you close MATLAB. To delete your cluster, follow these instructions.

## Delete Your Cloud Resources

You can remove the CloudFormation stack and all associated resources when you are done with them. Note that you cannot recover resources once they are deleted. After you delete the cloud resources, you cannot use the downloaded profile again.

1. Select your stack in the CloudFormation Stacks screen. Select **Delete**.

     ![CloudFormation Stacks Delete](../../img/cloudformation-delete-stack.png)

2. Confirm the delete when prompted. CloudFormation then deletes your resources within a few minutes.

# Additional Information

## Port Requirements

Before you can use your MATLAB Parallel Server cluster, you must configure certain required ports on the cluster and client firewall. These ports allow your client machine to connect to the cluster headnode and facilitate communication between the cluster nodes. 

### Cluster Nodes 

For details about the port requirements for cluster nodes, see this information from MathWorks® Support Team on MATLAB Answers: [How do I configure MATLAB Parallel Server using the MATLAB Job Scheduler to work within a firewall?]( https://www.mathworks.com/matlabcentral/answers/94254-how-do-i-configure-matlab-parallel-server-using-the-matlab-job-scheduler-to-work-within-a-firewall). 

Additionally, if your client machine is outside the cluster’s network, then you must configure the network security group of your cluster to allow incoming traffic from your client machine on the following ports. For information on how to configure your network security group, see [Configure security group rules](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-security-group-rules.html). To troubleshoot, see this [page](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstancesConnecting.html). 

| Required ports                | Description                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------- |
| TCP 27350 to 27358 + 4*N      | For connecting to the job manager on the cluster headnode and to the worker nodes for parallel pools. Calculate the required ports based on N, the maximum number of workers on any single node across the entire cluster.  |
| TCP 443                       |If you are using online licensing, you must open this port for outbound communication from all cluster machines. If you’re using Network License Manager instead, then you must configure ports as listed on [Network License Manager for MATLAB on Amazon Web Services](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-aws?tab=readme-ov-file#networking-resources). |
| TCP 22                        |  SSH access to the cluster nodes.                                                      |

*Table 1: Outgoing port requirements*

## CloudWatch Logs and Metrics
CloudWatch logs enables you to access logs from all the resources in your stack in a single place. To use CloudWatch logs, enable the feature "Configure cloudwatch logging for the MATLAB instance" while deploying the stack. Once you deploy the stack, you can access your logs and metrics in the "Outputs" of the stack by clicking the link next to "CloudWatchLogs" and  "CloudWatchMetrics", respectively. Note that if you delete the stack, the CloudWatch logs are also deleted but the CloudWatch metrics persist. For more information, see [What is Amazon CloudWatch Logs?](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html).

## Use Autoscaling

To optimize the number of Amazon EC2&reg; instances running MATLAB workers, enable autoscaling by setting `Enable instance autoscaling` to `Yes` when you create the stack. Autoscaling is optional and is disabled by default.

When autoscaling is disabled, the AWS Auto Scaling group deploys `Number of worker nodes` instances. To change the number of worker nodes, use the AWS Management Console.

If you enable autoscaling, the [desired capacity](https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-capacity-limits.html) of the AWS Auto Scaling group is regulated by the number of workers needed by the cluster. The number of Amazon EC2 instances is initially set at `Number of worker nodes`. This number fluctuates between the `Minimum` and `Maximum number of worker nodes`. To change these limits after you create the stack, use the AWS Management Console. To change the amount of time idle nodes are preserved, adjust the value of the tag `mwWorkerIdleTimeoutMinutes`.

To disable autoscaling in a deployed stack, redeploy the stack with autoscaling disabled.

## Automatically terminate the MATLAB Parallel Server cluster

Use the `Automatically Terminate Cluster` parameter while deploying the cluster to manage costs efficiently. You can choose one of these options:

* `Disable auto-termination` (default): No auto-termination. Use this option to fully disable this feature.
* `Never`: No auto-termination but can be enabled after deployment.
* `When cluster is idle`: Terminates the cluster when it is idle for about 10 minutes (30 minutes at startup).
* `After x hours`: Terminates the cluster after 'x' hours (where `x` is between 1 and 24).

When the cluster is auto-terminated, the head-node EC2 instance is stopped and all worker EC2 instances in the Auto-Scaling group are deleted. To use the cluster again, restart the head-node.

To modify the termination policy after deploying the cluster, edit the value of the tag `mw-autoshutdown` that is attached to the head-node. Set the value of the tag to either `never`, `on_idle`, or `After x hours`, where x must be an integer between 1 and 24.

## Cluster File System and Storage

### Cluster Shared Storage

* **Persisted Storage:** If you have enabled the shared storage, the cluster offers persisted shared storage mounted at `/shared/persisted`. This storage is shared among all worker nodes and persists between cluster runs. You can choose between two types of persisted storage:
  - **Amazon EFS (Elastic File System):** Fully managed, scalable file storage that can grow and shrink automatically.
  - **Amazon EBS (Elastic Block Store):** Block-level storage volumes that can be attached to EC2 instances.

* **Temporary Storage:** Temporary shared storage is available at `/shared/tmp`. This storage is shared among worker nodes but is not retained between cluster runs. Use it for temporary and intermediate data that you need to access from multiple worker nodes. The storage size varies with instance type and is only available for instances with ephemeral storage (NVMe instance store).

### Local Machine Storage

* **Instance Storage:** Depending on the selected EC2 instance type, some instances may have local, ephemeral storage. When available, NVMe instance store volumes are mounted at `/mnt/localnvme*`. Additional EBS volumes are mounted at `/mnt/localebs*`. The availability and size of instance storage vary based on the EC2 instance type chosen. Use this storage for temporary, instance-specific data processing but not for persistent data storage.


### Cost Considerations

* **EFS:** Billed based on the amount of data stored and the throughput used. This option is cost-effective when your workloads vary and when you need to scale storage independently of compute resources. For details, see [EFS Pricing (AWS)](https://aws.amazon.com/efs/pricing/).
* **EBS:** Charged by the amount of provisioned storage, regardless of how much is actually used. This option is more cost-effective for predictable, steady-state workloads. For details, see [EFS Pricing (AWS)](https://aws.amazon.com/ebs/pricing/).
* **Ephemeral Storage:** This option is included in the EC2 instance price, making it cost-effective for temporary storage needs.

Consider your workload characteristics, data access patterns, and budget when choosing between EFS and EBS for persisted storage. The cluster setup allows flexibility in storage configuration to optimize for your specific requirements and cost constraints.



## MATLAB Job Scheduler Configuration

By default, MATLAB Job Scheduler (MJS) is configured to manage a wide range of cluster uses.

To change the MJS configuration for advanced use cases, replace the default `mjs_def` with your own file using the template parameter `OptionalUserCommand`. This overwrites all MJS startup parameters, except for *DEFAULT_JOB_MANAGER_NAME*, *HOSTNAME*, and *SHARED_SECRET_FILE*. To learn more about the MJS startup parameters and to edit them, see [Define MATLAB Job Scheduler Startup Parameters](https://www.mathworks.com/help/matlab-parallel-server/define-startup-parameters.html).
For example, to retrieve and use your edited `mjs_def` from a storage service (e.g. Amazon S3), set the `OptionalUserCommand` to the following:
```
wget --output-document=/usr/local/matlab/toolbox/parallel/bin/mjs_def.sh https://<your_bucket>.s3.amazonaws.com/mjs_def.sh && rm /opt/mathworks/startup/*_edit-mjs-def.sh
```

## Nested Stacks

This CloudFormation template uses nested stacks to reference templates used by multiple reference architectures. For details, see the [MathWorks Infrastructure as Code Building Blocks](https://github.com/mathworks-ref-arch/iac-building-blocks) repository.

## Deploy Cluster in a Custom Region

MathWorks provides prebuilt Amazon Machine Images (AMIs) only in the regions listed in [Step 1. Deploy the Template](#step-1-deploy-the-template). To deploy a cluster in a different region, follow these steps.

1. **Copy AMI into your account**: Use this AWS quick-create link to copy the latest MATLAB Parallel Server AMI on Linux into your AWS account. Clicking the link opens a CloudFormation template with prepopulated fields. Set the AWS region in the AWS console to your desired region and deploy the template to copy the AMI. Copying takes 5 to 15 minutes. You are responsible for the costs associated with the storage of this AMI and its snapshots in your AWS account. To save costs, delete this AMI and the snapshots if you no longer need it.

    [![alt text](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png "Copy an AMI into your AWS account")](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://mathworks-reference-architectures-templates.s3.amazonaws.com/copy-ami-lambda/v1/0/0/copy-ami-lambda.yml&stackName=Copy-of-MATLAB-Parallel-Server-R2023b-AMI&param_SourceAmiId=ami-04630fafd2f0ee2b5&param_SourceRegion=us-east-1&param_AmiName=Copy%20of%20MATLAB%20Parallel%20Server%20Linux%20R2023b&param_ReferenceTag=https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws&param_MWTemplateUrl=https://mdcs-on-aws.s3.amazonaws.com/R2023b/mjs-cluster-template.json)

2. **Deploy a cluster using your copied AMI**: After your copy is complete and your AMI is ready, use the `LaunchClusterWithCopiedAmi` link in the outputs tab to deploy a cluster in your desired region. You can also share this link or the Custom AMI ID with others in your AWS account to allow them to deploy clusters using the same AMI.

### Delete the Copied AMI
When you deploy a cluster using an AMI, new worker instances are created from that AMI. Delete the AMI from your account only after you have finished using all clusters based on it. To delete the AMI, navigate to the copied AMI in the AWS console using the link in the Outputs tab of the stack. Choose `Actions`, then `Deregister AMI`. Select the option `Delete associated snapshots` to also delete the associated snapshot.

## Troubleshooting

If your stack fails to create, check the events section of the CloudFormation console. This section indicates which resources caused the failure and why.

If you are unable to validate the cluster after creating the stack, check the logs on the instances to diagnose the error.

When using SSH to connect to the instance, login as `ubuntu`.

The logs are output to /var/log on the instance nodes; the files of interest are cloud-init.log, cloud-init-output.log and all the logs under /var/log/mathworks/.

----

Copyright 2024-2025 The MathWorks, Inc.

----