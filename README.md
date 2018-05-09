# MATLAB Distributed Computing Server on Amazon Web Services

# Requirements

Before starting, you will need the following:

- MATLAB Distributed Computing Server™ license. For more information, see [Configuring License in the Cloud](https://www.mathworks.com/support/cloud/configure-matlab-distributed-computing-server-licensing-on-the-cloud.html).
- MATLAB® R2018a and Parallel Computing Toolbox™ on your desktop.

- An Amazon Web Services™ (AWS) account with required permissions. To see what is required look at the [example policy](/doc/mdcs-on-aws-iam-policy.json). For more information about the services used see [Learn About MJS Cluster Architecture](#learn-about-mjs-cluster-architecture).

- An SSH Key Pair for your AWS account in the US East (N. Virginia) region. Create an SSH key pair if you do not already have one. For instructions [see the AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

# Costs
You are responsible for the cost of the AWS services used when you create cloud resources using this guide. Resource settings, such as instance type, will affect the cost of deployment. For cost estimates, see the pricing pages for each AWS service you will be using. Prices are subject to change.

# Introduction
The following guide will help you automate the process of launching MATLAB Distributed Computing Server and MATLAB job scheduler (MJS) on Amazon EC2 resources in your Amazon Web Services (AWS) account. For information about the architecture of this solution, see [Learn About MJS Cluster Architecture](#learn-about-mjs-cluster-architecture).

Use this reference architecture to control every aspect of your cloud resources. Alternatively, for an easier onramp, you can use [MathWorks Cloud Center](https://www.mathworks.com/help/cloudcenter/index.html) to manage the platform for you. Cloud Center is simpler but less configurable.

# Deployment Steps

## Step 1. Launch the Template

Click the **Launch Stack** button below to deploy the cloud resources on AWS. This will open the AWS console in your web browser.

[![alt text](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png "Start an MJS cluster using the template")](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://s3.amazonaws.com/mdcs-on-aws/MJS-Cluster-Template.json)

> Platform: Ubuntu Xenial (16.04)

> MATLAB Release: R2018a

## Step 2. Configure the Cloud Resources
After you click the Launch Stack button above, the “Create stack” page will open in your browser where you can configure the parameters. It is easier to complete the steps if you position these instructions and the AWS console window side-by-side.

1. Specify and check the defaults for these resource parameters:

    | Parameter label                                    | Description 
    | -------------------------------------------------- | ----------- 
    | **Stack name** (required)                              | Choose a name for the stack. This will be shown in the AWS console.
    | **Cluster name** (required)                            | Choose a name to use for the MJS cluster. This name will be shown in MATLAB when connected to the cluster.
    | **Number of worker instances** (required)              | Choose the number of AWS instances to start for the workers.
    | **Number of workers to start on each instance** (required) | Choose the number of MATLAB workers to start on each instance. Specify 1 worker for every 2 vCPUs, because this results in 1 worker per physical core. For example an m4.16xlarge instance has 64 vCPUs, so can support 32 MATLAB workers. See the [AWS documentation](https://aws.amazon.com/ec2/instance-types) for details on vCPUs for each instance type.
    | **Size (GB) of the database EBS volume** (optional)    | The size of the EBS volume to use for the MJS database. All job and task information, including input and output data will be stored on this volume and should therefore have enough capacity to store the expected amount of data. If this parameter is set to 0 no volume will be created and the root volume of the instance will be used for the MJS database.
    | **Instance type for the head node** (required)         | Choose the AWS instance type to use for the head node, which will run the MJS job manager. No workers will be started on this node, so this can be a smaller instance type than the worker nodes. All [AWS instance types](https://aws.amazon.com/ec2/instance-types) are supported.
    | **Instance type for the worker nodes** (required)      | Choose the AWS instance type to use for the workers. All [AWS instance types](https://aws.amazon.com/ec2/instance-types) are supported.
    | **Availability zone** (required)                       | Choose an [availability zone](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) to start cloud resources in.
    | **Name of SSH key** (required)                         | Choose the name of an existing EC2 KeyPair to allow SSH access to all the instances. If you do not have one, you can [follow the AWS instructions to create one.](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
    | **IP address range of client** (required)              | Specify your IP address range that can be used to access the resources and use the form x.x.x.x/x. In a web browser search for "my ip address", copy and paste the address into the input box. Append "/32" to restrict access to your address only, or specify a CIDR range.

2. Tick the box to accept that the template uses IAM roles. These roles allow:
  * the instances to transfer the shared secret information between the nodes, via the S3 bucket, to establish SSL encrypted communications
  * the instances to write the MJS cluster profile to the S3 bucket for secure access to the cluster from the client MATLAB
  * a custom lambda function to delete the contents of this S3 bucket when the stack is deleted

3. Click the **Create** button.

When you click Create, the MJS cluster is created using AWS CloudFormation templates.

# Step 3: Connect to Your Cluster From MATLAB

1. After clicking **Create** you will be taken to the Stack Detail page for your Stack. Wait for the Status to reach **CREATE\_COMPLETE**. This may take up to 10 minutes.
2. Select **Outputs**. The screen should look like the one in Figure 1.

    ![Stack Outputs On Completion](/doc/cloudformation-stack-creation-complete.png)

    *Figure 1: Stack Outputs On Completion*

3. Click the link next to **BucketURL** under **Outputs**.
4. Select the profile (**ClusterName.settings**) and click **Download**.
5. Open MATLAB.
6. In the Parallel drop-down menu in the MATLAB toolstrip select **Manage Cluster Profiles**.
7. Click **Import**.
8. Select the downloaded profile and click open.
9. Click **Set as Default**.
10. (Optional) Validate your cluster by clicking the **Validate** button.

After setting the cloud cluster as default, the next time you run a parallel language command (such as `parfor`, `spmd`, `parfeval` or `batch`) MATLAB connects to the cluster. The first time you connect, you will be prompted for your MathWorks account login. The first time you run a task on a worker it will take several minutes for the worker MATLAB to start. This delay is due to initial loading of data from the EBS volumes. This is a one-time operation, and subsequent tasks begin much faster.

Your cluster is now ready to use. It will remain running after you close MATLAB. Delete your cluster by following the instructions below.

**NOTE**: Use the profile and client IP address range to control access to your cloud resources. Anyone with this file can connect to your resources from a machine within the specified IP address range and run jobs on it.

# Additional Information
## Delete Your Cloud Resources
You can remove the CloudFormation stack and all associated resources when you are done with them. Note that there is no undo. After you delete the cloud resources you cannot use the downloaded profile again.

1. Select the Stack in the CloudFormation Stacks screen.  Select **Actions/Delete**.

     ![CloudFormation Stacks Output](/doc/cloudformation-delete-stack.png)

2. Confirm the delete when prompted.  CloudFormation will now delete resources which can take a few minutes.

## Troubleshooting
If your stack fails to create, check the events section of the CloudFormation console. It will indicate which resources caused the failure and why.

If the stack created successfully but you are unable to validate the cluster you may need to view the logs on the instances to diagnose the error. The logs are output to /var/log on the instance nodes, the files of interest are cloud-init.log, cloud-init-output.log, mathworks.log and all the logs under /var/log/mdce.

## Learn About MJS Cluster Architecture

Parallel Computing Toolbox and MATLAB Distributed Computing Server software let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/distcomp) and [MATLAB Distributed Computing Server](https://www.mathworks.com/help/mdce). 

The MJS is a built-in scheduler that ships with MATLAB Distributed Computing Server. The MJS process coordinates the execution of jobs, and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers.

AWS is a set of cloud services which allow you to build, deploy, and manage applications hosted in Amazon’s global network of data centres. This guide will help you launch a compute cluster running MDCS and MJS using compute, storage, and network services hosted by AWS. Find out more about the range of [cloud-based products offered by AWS](https://aws.amazon.com/products/). Services launched in AWS can be created, managed, and deleted using the AWS Management Console. For more information about the AWS Management Console, see [AWS Management Console](https://aws.amazon.com/documentation/awsconsolehelpdocs/). 

The MJS cluster and the resources required by it are created using [AWS CloudFormation templates](https://aws.amazon.com/cloudformation/). The cluster architecture created by the template is illustrated in Figure 2, it defines the resources below. For more information about each resource see the [AWS CloudFormation template reference.](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html) 

![Cluster Architecture](/doc/MJS_in_AWS_architecture.png?raw=true)

*Figure 2: Cluster Architecture*

### Networking resources
* VPC (AWS::EC2::VPC): The Amazon Virtual Private Cloud used by the cluster. Note that by default Amazon limits the number of VPCs you can create per region to 5, you may want to apply to increase this limit if you want to start several clusters simultaneously. The VPC includes the following components:
  * VPC Gateway Attachment (AWS::EC2::VPCGatewayAttachment)
  * Subnet (AWS::EC2::Subnet)
  * Route (AWS::EC2::Route)
  * RouteTable (AWS::EC2::RouteTable)
  * Internet Gateway (AWS::EC2::InternetGateway)
  * Subnet Route Table Association (AWS::EC2::SubnetRouteTableAssociation)
* Security Group (AWS::EC2::SecurityGroup): The security group defines the ports that are opened for ingress to the cluster:
  * 22: Required for SSH access to the cluster nodes.
  * 27350 – 27537 + (4 * number of workers): Required for communication from clients to the job scheduler and worker processes. The default maximum number of workers supported is 64, so the port range is 27350-27613.
* Internal Security Group Traffic Rule (AWS::EC2::SecurityGroupIngress): Opens access to network traffic between all cluster nodes internally.

### Instances
* Headnode instance (AWS::EC2::Instance): An EC2 instance for the cluster headnode. The MATLAB snapshot is mounted at /mnt/matlab and the job database is stored either locally on the root volume, or optionally, a separate EBS volume can be used which is mounted at /mnt/database. Communication between clients and the headnode is secured using SSL.
  * Database Volume (optional) (AWS::EC2::Volume): A separate EBS volume to store the MJS job database. This is optional, and if not chosen the root volume will be used for the job database.
  * Database Mount Point (optional) (AWS::EC2::VolumeAttachment): The mount point for the database volume, specified as /dev/sdh (which may be converted to /dev/xvdh on the instance depending on the OS).
* IAM Role for Cluster Instances (AWS::IAM::Role): A role allowing access to Amazon S3 from services running in EC2.
* Instance Profile for cluster instances (AWS::IAM::InstanceProfile): A profile for the cluster instances that associates them with the IAM role above.
* Worker Auto Scaling Group (AWS::AutoScaling::AutoScalingGroup): A scaling group for worker instances to be launched into. The scaling features are not currently used.
* Worker Launch Configuration (AWS::AutoScaling::LaunchConfiguration): A launch configuration for one or more worker nodes which each run one or more worker MATLAB processes. Communication between clients and workers is secured using SSL.

### S3 bucket
* Cluster S3 Bucket (AWS::S3::Bucket): An S3 bucket to facilitate sharing the shared secret required for workers to register and establish a secure connection with the job scheduler between the cluster nodes. The shared secret is encrypted in the bucket using server-side encryption. The cluster profile required to connect to the cluster from the MATLAB client is also uploaded to this bucket.
* IAM role for deletion of S3 bucket (AWS::IAM::Role): The S3 bucket cannot be automatically deleted by Cloud Formation unless it is empty. This role gives permissions for an AWS lambda function to empty the S3 bucket during shut down of the cluster.
* Lambda function to empty the S3 bucket (AWS::Lambda::Function): A lambda function that will empty the S3 bucket created above to allow Cloud Formation to successfully delete the S3 bucket when the cluster is shut down.
* Custom lambda dependency (Custom::LambdaDependency): A custom dependency used to trigger the lambda function when the Cloud Formation stack is deleted.

# Technical Support
Email: `cloud-support@mathworks.com`


