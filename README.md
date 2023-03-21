# MATLAB Parallel Server on Amazon Web Services

# Requirements

Before starting, you will need the following:

* A MATLAB&reg; Parallel Server&trade; license. For more information on how to configure your license for cloud use, see [Configure MATLAB Parallel Server Licensing for Cloud Platforms](https://mathworks.com/help/matlab-parallel-server/configure-matlab-parallel-server-licensing-for-cloud-platforms.html). You can use either of:
    * A MATLAB Parallel Server license configured to use online licensing for MATLAB.
    * A network license manager for MATLAB hosting sufficient MATLAB Parallel Server licenses for your cluster. MathWorks&reg; provides a reference architecture to deploy a suitable [Network License Manager for MATLAB on Azure](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-azure) or you can use an existing license manager.
* MATLAB&reg; and Parallel Computing Toolbox&trade; on your desktop.
* An Amazon Web Services&trade; (AWS) account with required permissions. For more information about the services used see [Learn About Cluster Architecture](#learn-about-cluster-architecture).
* A Key Pair for your AWS account in your chosen region. Create an SSH key pair if you do not already have one. For instructions [see the AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html).

# Costs
You are responsible for the cost of the AWS services used when you create cloud resources using this guide. Resource settings, such as instance type, will affect the cost of deployment. For cost estimates, see the pricing pages for each AWS service you will be using. Prices are subject to change.

# Introduction
The following guide will help you automate the process of launching MATLAB Parallel Server and MATLAB Job Scheduler, running on virtual machines, on Amazon EC2 resources with your Amazon Web Services (AWS) account. For information about the architecture of this solution, see [Learn About Cluster Architecture](#learn-about-cluster-architecture).
Use this reference architecture to control every aspect of your cloud resources. Alternatively, for a simpler but less customizable method of launching a MATLAB Parallel Server cluster in AWS, try [MathWorks Cloud Center](https://mathworks.com/help/cloudcenter/mathworks-cloud-center.html).

This reference architecture has been reviewed and qualified by AWS.

![AWS Qualified Software badge](img/aws-qualified-software.png)

# Deployment Steps

To view instructions for deploying the MATLAB Parallel Server reference architecture, select a MATLAB release:

| Linux | Windows |
| ----- | ------- |
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

Parallel Computing Toolbox and MATLAB Parallel Server software let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/parallel-computing) and [MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server/).

The MATLAB Job Scheduler is a built-in scheduler that ships with MATLAB Parallel Server. The scheduler coordinates the execution of jobs, and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers.

AWS is a set of cloud services which allow you to build, deploy, and manage applications hosted in Amazon’s global network of data centres. This guide will help you launch a compute cluster using compute, storage, and network services hosted by AWS. Find out more about the range of [cloud-based products offered by AWS](https://aws.amazon.com/products/). Services launched in AWS can be created, managed, and deleted using the AWS Management Console. For more information about the AWS Management Console, see [AWS Management Console](https://aws.amazon.com/documentation/awsconsolehelpdocs/).

The MATLAB Job Scheduler and the resources required by it are created using [AWS CloudFormation templates](https://aws.amazon.com/cloudformation/). This diagram illustrates the cluster architecture created by the template, it defines the resources below. For more information about each resource see the [AWS CloudFormation template reference.](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)

![Cluster Architecture](img/MJS_in_AWS_architecture.png?raw=true)

### Networking resources
* Security Group (AWS::EC2::SecurityGroup): The security group defines the ports that are opened for ingress to the cluster:
* Internal Security Group Traffic Rule (AWS::EC2::SecurityGroupIngress): Opens access to network traffic between all cluster nodes internally.

### Instances
* Headnode instance (AWS::EC2::Instance): An EC2 instance for the cluster headnode. The job database is stored on an EBS volume attached to this instance. Communication between clients and the headnode is secured using SSL.
* IAM Role for Cluster Instances (AWS::IAM::Role): A role allowing access to Amazon S3 from services running in EC2.
* Instance Profile for cluster instances (AWS::IAM::InstanceProfile): A profile for the cluster instances that associates them with the IAM role above.
* Worker Auto Scaling Group (AWS::AutoScaling::AutoScalingGroup): A scaling group for worker instances to be launched into.
* Worker Launch Configuration (AWS::EC2::LaunchTemplate): A launch template for one or more worker nodes which each run one or more worker MATLAB processes. Communication between clients and workers is secured using SSL.

### S3 bucket
* Cluster S3 Bucket (AWS::S3::Bucket): An S3 bucket to facilitate sharing the shared secret required for workers to register and establish a secure connection with the job scheduler between the cluster nodes. The shared secret is encrypted in the bucket using server-side encryption. The cluster profile required to connect to the cluster from the MATLAB client is also uploaded to this bucket.
* IAM role for deletion of S3 bucket (AWS::IAM::Role): The S3 bucket cannot be automatically deleted by Cloud Formation unless it is empty. This role gives permissions for an AWS lambda function to empty the S3 bucket during shut down of the cluster.
* Lambda function to empty the S3 bucket (AWS::Lambda::Function): A lambda function that will empty the S3 bucket created above to allow Cloud Formation to successfully delete the S3 bucket when the cluster is shut down.
* Custom lambda dependency (Custom::LambdaDependency): A custom dependency used to trigger the lambda function when the Cloud Formation stack is deleted.

## FAQ

### What skills or specializations do I need to use this Reference Architecture?

No programming or cloud experience required. 

### How long does this process take?

If you already have an AWS account set up and ready to use, you can start a MATLAB Parallel Server Reference Architecture cluster in less than 15 minutes. Startup time will vary depending on the size of your cluster.

### How do I manage limits? 

To learn about setting quotas, see [AWS Service Quotas](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html).

### How do I copy the VM image to a different region?

You can copy the AMI for a certain MATLAB version to a target region of your choice.

* In the Releases folder of this repository, choose the MATLAB release that you want to copy. Download and open the CloudFormation template .json file for that release.
* Locate the Mappings section in the CloudFormation template. Copy the AMI ID for one of the existing regions, for example, us-east-1.
* To copy the AMI to your target region, [follow the instructions at Copying an AMI on the AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html).
* In the Mappings section of the CloudFormation template, add a new RegionMap pair corresponding to your target region. Insert the new AMI ID of the AMI in the target region.
* In your AWS Console, change your region to your target region. In the CloudFormation menu, select Create Stack > With new resources option. Provide the modified CloudFormation template.

You can now deploy the AMI in your target region using the AMI that you copied.

# Technical Support
If you require assistance or have a request for additional features or capabilities, please contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).