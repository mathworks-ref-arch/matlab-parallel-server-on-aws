# MATLAB Parallel Server on Amazon Web Services

This repository enables you to automate the process of deploying MATLAB&reg; Parallel Server&trade; and MATLAB Job Scheduler on Amazon&reg; EC2&reg; resources using your Amazon Web Services (AWS&reg;) account. 

Use this repository to deploy a compute cluster using compute, storage, and network resources hosted by AWS. For information about the architecture of this solution, see [Learn About Cluster Architecture](#learn-about-cluster-architecture). Use this reference architecture to control every aspect of your cloud resources. Alternatively, for a simpler but less customizable method of deploying a MATLAB Parallel Server cluster in AWS, try [MathWorks Cloud Center](https://www.mathworks.com/help/cloudcenter/mathworks-cloud-center.html).

This reference architecture has been reviewed and qualified by AWS.

![AWS Qualified Software badge](img/aws-qualified-software.png)

# Requirements

Before starting, you need the following:

* A MATLAB Parallel Server license. You can use either:
    * A MATLAB Parallel Server license configured to use online licensing for MATLAB. For information on how to configure your license for cloud use, see [Configure MATLAB Parallel Server Licensing for Cloud Platforms](https://www.mathworks.com/help/matlab-parallel-server/configure-matlab-parallel-server-licensing-for-cloud-platforms.html)
    * A network license manager for MATLAB hosting sufficient MATLAB Parallel Server licenses for your cluster. MathWorks&reg; provides a reference architecture to deploy a suitable [Network License Manager for MATLAB on Amazon Web Services](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-aws), or you can use an existing license manager.
* MATLAB and Parallel Computing Toolbox&trade; on your desktop.
* An AWS account with required permissions.
* A key pair for your AWS account in your chosen region. For instructions on how to create an SSH key pair, see the AWS documentation on [Amazon EC2 key pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

# Costs

You are responsible for the cost of the AWS services you use when you create cloud resources using this repository. Resource settings, such as instance type, affects the cost of deployment. For cost estimates, see the pricing pages for each AWS service you use. Prices are subject to change.

# Deployment Steps

To view instructions for deploying the MATLAB Parallel Server reference architecture, select a MATLAB release:

| Linux | Windows |
| ----- | ------- |
| [R2024a](releases/R2024a/README.md) | [R2024a](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws-win/tree/master/releases/R2024a/README.md) |
| [R2023b](releases/R2023b/README.md) | [R2023b](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws-win/tree/master/releases/R2023b/README.md) |
| [R2023a](releases/R2023a/README.md) | [R2023a](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws-win/tree/master/releases/R2023a/README.md) |
| [R2022b](releases/R2022b/README.md) | [R2022b](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws-win/tree/master/releases/R2022b/README.md) |
| [R2022a](releases/R2022a/README.md) | [R2022a](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws-win/tree/master/releases/R2022a/README.md) |
| [R2021b](releases/R2021b/README.md) | [R2021b](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws-win/tree/master/releases/R2021b/README.md) |
| [R2021a](releases/R2021a/README.md) |  |
| [R2020b](releases/R2020b/README.md) |  |
| [R2020a](releases/R2020a/README.md) |  |
| [R2019b](releases/R2019b/README.md) |  |
| [R2019a\_and\_older](releases/R2019a_and_older/README.md) |  |


# Learn About Cluster Architecture

This diagram illustrates the cluster architecture created by the template. When you use the [AWS CloudFormation templates](https://aws.amazon.com/cloudformation/) in this repository, it creates the [MATLAB Job Scheduler](#what-is-matlab-job-scheduler) and the following resources. For more information about each resource, see [AWS CloudFormation template reference.](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)

![Cluster Architecture](img/MJS_in_AWS_architecture.png?raw=true)

### Networking Resources
* Security Group (AWS::EC2::SecurityGroup): A security group that defines the ports that are open for ingress to the cluster.
* Security Group Internal Traffic Rule (AWS::EC2::SecurityGroupIngress): A rule that opens access to network traffic between all cluster nodes internally.

### Compute Resources
* Headnode instance (AWS::EC2::Instance): An EC2 instance for the cluster headnode. The EBS volume attached to this instance stores the job database. The headnode communicates with the clients using a secure SSL connection.
* IAM Role for Cluster Instances (AWS::IAM::Role): A role allowing access to Amazon S3&trade; from services running in EC2.
* Instance Profile for cluster instances (AWS::IAM::InstanceProfile): A profile for the cluster instances that associates them with the IAM role above.
* Worker Auto Scaling Group (AWS::AutoScaling::AutoScalingGroup): A scaling group for worker instances to be deployed into.
* Worker Launch Configuration (AWS::EC2::LaunchTemplate): A launch template for one or more worker nodes which each run one or more worker MATLAB processes. Clients and workers communicate using a secure SSL connection.

### Storage Resources
* Cluster S3 Bucket (AWS::S3::Bucket): An S3 bucket that contains the shared secret required to register the workers and establish a secure connection with the job scheduler between the cluster nodes. The shared secret is encrypted in the bucket using server-side encryption. The bucket also contains the cluster profile required to connect to the cluster from the MATLAB client.
* IAM role for deletion of S3 bucket (AWS::IAM::Role): A role that allows an AWS lambda function to empty the S3 bucket during shut down of the cluster. CloudFormation can delete the S3 bucket only if it is empty.
* Lambda function to empty the S3 bucket (AWS::Lambda::Function): A lambda function to empty the S3 bucket created above to allow CloudFormation to successfully delete the S3 bucket when the cluster is shut down.
* Custom lambda dependency (Custom::LambdaDependency): A custom dependency to trigger the lambda function when the Cloud Formation stack is deleted.

## FAQ

### What can I do with MATLAB Parallel Server?

Parallel Computing Toolbox and MATLAB Parallel Server software let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more, see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/parallel-computing) and [MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server/). 

### What is MATLAB Job Scheduler?

MATLAB Job Scheduler is a built-in scheduler that ships with MATLAB Parallel Server. The scheduler coordinates the execution of jobs and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers. For more details, see [How Parallel Computing Toolbox Runs a Job](https://www.mathworks.com/help/parallel-computing/how-parallel-computing-products-run-a-job.html). The MATLAB Job Scheduler and the resources required by it are created using [AWS CloudFormation templates](https://aws.amazon.com/cloudformation/). 

### What is Amazon Web Services (AWS)?

AWS is a set of cloud services which allow you to build, deploy, and manage applications hosted in Amazon’s global network of data centers. Find out more about the range of [cloud-based products offered by AWS](https://aws.amazon.com/products/). Services deployed in AWS can be created, managed, and deleted using the AWS Management Console. For more information about the AWS Management Console, see [AWS Management Console](https://docs.aws.amazon.com/awsconsolehelpdocs/). 

### What skills or specializations do I need to use this Reference Architecture?

No programming or cloud experience required. 

### How long does it take to deploy the Reference Architecture?

If you already have an AWS account set up and ready to use, you can start a MATLAB Parallel Server Reference Architecture cluster in less than 15 minutes. Startup time varies depending on the size of your cluster.

### How do I manage limits for AWS services? 

To learn about setting quotas, see [AWS Service Quotas](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html).

### How do I copy the AMI to a different region?

You can copy the AMI for a certain MATLAB version to a target region of your choice.

* In the Releases folder of this repository, choose the MATLAB release that you want to copy. Download and open the CloudFormation template JSON file for that release.
* Locate the Mappings section in the CloudFormation template. Copy the AMI ID for one of the existing regions, for example, us-east-1.
* To copy the AMI to your target region, see the AWS documentation on [Copy an AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html).
* In the Mappings section of the CloudFormation template, add a new RegionMap pair corresponding to your target region. Insert the new AMI ID of the AMI in the target region.
* In your AWS Console, change your region to your target region. In the CloudFormation menu, select Create Stack > With new resources option. Provide the modified CloudFormation template.

You can now deploy the AMI in your target region using the AMI that you copied.

### What is an EC2 Spot Instance, and what factors should I consider before enabling it?

Spot instances allow you to use AWS EC2 Instances at a reduced cost. AWS uses Spot Instances to sell unused instances within their data centers. However, AWS can reclaim these instances at any time. For more details, see the AWS documentation on [Spot Instances](https://aws.amazon.com/ec2/spot/).

Before enabling Spot Instances, consider these three aspects:

* Pricing: Spot Instances offer discounts compared to On-Demand EC2 instances. The actual discount depends on the available unused capacity of the EC2 instance within the Availability Zone (AZ). For more details, refer to the AWS documentation.

* Behavior of your cluster when AWS reclaims a Spot Instance: Spot Instances are used only for the worker nodes, whereas the head node always uses an On-Demand instance. This is to ensure that you do not lose any user job and task information when an EC2 instance is reclaimed by AWS. If an EC2 Spot Instance for a worker is interrupted when it is running a task, the task is marked as failed. Jobs in the queue are run when a new worker instance is available. For more information, refer to [How Parallel Computing Toolbox Runs a Job](https://www.mathworks.com/help/parallel-computing/how-parallel-computing-products-run-a-job.html).

* Parameters for the VPC and subnet in this CloudFormation template: Each Availability Zone in a region has a different capacity available for Spot Instances. To increase the likelihood of obtaining Spot Instances for your cluster, ensure that your VPC has subnets in multiple Availability Zones in the region.

# Technical Support
If you require assistance or have a request for additional features or capabilities, contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2018 - 2024 The MathWorks, Inc.

----