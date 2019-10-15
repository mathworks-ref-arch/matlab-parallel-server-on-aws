# MATLAB Parallel Server on Amazon Web Services

# Requirements

Before starting, you will need the following:

- MATLAB Parallel Server™ license. For more information on how to configure your license for cloud use, see [MATLAB Parallel Server on the Cloud](https://www.mathworks.com/help/licensingoncloud/matlab-parallel-server-on-the-cloud.html)

- MATLAB® R2019a and Parallel Computing Toolbox™ on your desktop.

- An Amazon Web Services™ (AWS) account with required permissions. To see what is required look at the [example policy](../../matlab-parallel-server-on-aws-iam-policy.json). For more information about the services used see [Learn About Cluster Architecture](#learn-about-cluster-architecture).

- An SSH Key Pair for your AWS account in your chosen region (see [deployment option documentation](#choose-a-deployment-option) for supported regions, examples use `us-east-1`). Create an SSH key pair if you do not already have one. For instructions [see the AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

# Costs
You are responsible for the cost of the AWS services used when you create cloud resources using this guide. Resource settings, such as instance type, will affect the cost of deployment. For cost estimates, see the pricing pages for each AWS service you will be using. Prices are subject to change.

# Introduction
The following guide will help you automate the process of launching MATLAB Parallel Server and MATLAB Job Scheduler on Amazon EC2 resources in your Amazon Web Services (AWS) account. For information about the architecture of this solution, see [Learn About Cluster Architecture](#learn-about-cluster-architecture).

Use this reference architecture to control every aspect of your cloud resources. Alternatively, for an easier onramp, you can use [MathWorks Cloud Center](https://www.mathworks.com/help/cloudcenter/index.html) to manage the platform for you. Cloud Center is simpler but less configurable.

# Choose a Deployment Option
The MATLAB Parallel Server cloud reference architecture for AWS supports two license configurations: online licensing and a network license manager. For more information on how to configure your license for cloud use, see [MATLAB Parallel Server on the Cloud](https://www.mathworks.com/help/licensingoncloud/matlab-parallel-server-on-the-cloud.html).

* [Deploy MATLAB Parallel Server on AWS using Online Licensing](online-licensing-instructions.md)
* [Deploy MATLAB Parallel Server on AWS using Network License Manager](license-manager-instructions.md)

# Learn About Cluster Architecture

Parallel Computing Toolbox and MATLAB Parallel Server software let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/parallel-computing) and [MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server/).

The MATLAB Job Scheduler is a built-in scheduler that ships with MATLAB Parallel Server. The scheduler coordinates the execution of jobs, and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers.

AWS is a set of cloud services which allow you to build, deploy, and manage applications hosted in Amazon’s global network of data centres. This guide will help you launch a compute cluster using compute, storage, and network services hosted by AWS. Find out more about the range of [cloud-based products offered by AWS](https://aws.amazon.com/products/). Services launched in AWS can be created, managed, and deleted using the AWS Management Console. For more information about the AWS Management Console, see [AWS Management Console](https://aws.amazon.com/documentation/awsconsolehelpdocs/).

The MATLAB Job Scheduler and the resources required by it are created using [AWS CloudFormation templates](https://aws.amazon.com/cloudformation/). The cluster architecture created by the template is illustrated in Figure 2, it defines the resources below. For more information about each resource see the [AWS CloudFormation template reference.](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)

![Cluster Architecture](../../img/MJS_in_AWS_architecture.png?raw=true)

*Figure 2: Cluster Architecture*

### Networking resources
* VPC (AWS::EC2::VPC): The Amazon Virtual Private Cloud used by the cluster. Note that by default Amazon limits the number of VPCs you can create per region to 5. You can apply to increase this limit if you want to start several clusters simultaneously. The VPC includes the following components:
  * VPC Gateway Attachment (AWS::EC2::VPCGatewayAttachment)
  * Subnet (AWS::EC2::Subnet)
  * Route (AWS::EC2::Route)
  * RouteTable (AWS::EC2::RouteTable)
  * Internet Gateway (AWS::EC2::InternetGateway)
  * Subnet Route Table Association (AWS::EC2::SubnetRouteTableAssociation)
* Security Group (AWS::EC2::SecurityGroup): The security group defines the ports that are opened for ingress to the cluster:
  * 22: Required for SSH access to the cluster nodes.
  * 27350 – 27357 + (4 * number of workers): Required for communication from clients to the job scheduler and worker processes. The default maximum number of workers supported is 64, so the port range is 27350-27613.
* Internal Security Group Traffic Rule (AWS::EC2::SecurityGroupIngress): Opens access to network traffic between all cluster nodes internally.

### Instances
* Headnode instance (AWS::EC2::Instance): An EC2 instance for the cluster headnode. The MATLAB snapshot is mounted at /mnt/matlab and the job database is stored either locally on the root volume, or optionally, a separate EBS volume can be used which is mounted at /mnt/database. Communication between clients and the headnode is secured using SSL.
  * Database Volume (optional) (AWS::EC2::Volume): A separate EBS volume to store the job database. This is optional, and if not chosen the root volume will be used for the job database.
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

# Enhancement Request
Provide suggestions for additional features or capabilities using the following link: [https://www.mathworks.com/cloud/enhancement-request.html](https://www.mathworks.com/cloud/enhancement-request.html)

# Technical Support
Email: `cloud-support@mathworks.com`
