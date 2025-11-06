# **Build Your Own Machine Image**

## **Introduction**
This guide shows how to build your own Amazon® Machine Image (AMI) using the same scripts that form the basis of the build process for MathWorks® prebuilt images.
You can use the scripts to install MATLAB® Parallel Server™, MATLAB toolboxes, and the other features detailed below.

A HashiCorp® Packer template generates the machine image.
The template is an HCL2 file that tells Packer which plugins (builders, provisioners, post-processors) to use, how to configure each of those plugins, and what order to run them in.
For more information about templates, see [Packer Templates](https://www.packer.io/docs/templates#packer-templates).



## **Requirements**
Before starting, you will need:
* A valid Packer installation later than 1.7.0. For more information, see [Install Packer](https://www.packer.io/downloads).
* AWS credentials with sufficient permission. For more information, see [Packer Authentication](https://www.packer.io/plugins/builders/amazon#authentication).

## **Costs**
You are responsible for the cost of the AWS services used when you create cloud resources using this guide. Resource settings, such as instance type, will affect the cost of deployment. For cost estimates, see the pricing pages for each AWS service you will be using. Prices are subject to change.

## **Quick Launch Instructions**
This section shows how to build the latest MATLAB Parallel Server machine image in your own AWS account. 

Pull the source code and navigate to the Packer folder.
```bash
git clone https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws
cd matlab-parallel-server-on-aws/packer/v1
```

Initialize Packer to install the required plugins.
You only need to do this once.
For more information, see [init command reference (Packer)](https://developer.hashicorp.com/packer/docs/commands/init).
```bash
packer init build-parallel-server-ami.pkr.hcl
```

Launch the Packer build with the default settings.
```bash
packer build build-parallel-server-ami.pkr.hcl
```
Packer writes its output, including the ID of the generated machine image, to a `manifest.json` file at the end of the build.
To use the built image with a MathWorks CloudFormation template, see [Deploy Machine Image](#deploy-machine-image).


## **How to Run the Packer Build**
This section describes the complete Packer build process and the different options for launching the build.

### **Build-Time Variables**
The [Packer template](https://github.mathworks.com/development/parallel-server-aws-refarch/tree/dev/packer/v1/build-parallel-server-ami.pkr.hcl) supports these build-time variables.
| Argument Name | Default Value | Description |
|---|---|---|
| [PRODUCTS](#customize-products-to-install)| MATLAB, MATLAB Parallel Server, MATLAB Production Server™, and all available toolboxes | Products to install, specified as a list of product names separated by spaces. For example, `MATLAB Simulink MATLAB_Parallel_Server MATLAB_Production_Server`.<br>MATLAB parallel server must be installed with MATLAB in order to deploy a parallel server cluster to the cloud. If no products are specified, the Packer build will install MATLAB with all available toolboxes. For more information, see [MATLAB Package Manager](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md).|
| [POLYSPACE_PRODUCTS](#customize-polyspace-products-to-install)| Polyspace® Bug Finder™ Server™ and Polyspace Code Prover™ Server™ | Polyspace products to install, specified as a list of product names separated by spaces. For example, `Polyspace_Bug_Finder_Server Polyspace_Code_Prover_Server`.<br/>If no products are specified, the Packer build will install Polyspace with Polyspace Bug Finder Server and Polyspace Code Prover Server. For more information, see [MATLAB Package Manager](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md).|
| SPKGS | List of Deep Learning Support Packages, specified in [release-config](https://github.mathworks.com/development/parallel-server-aws-refarch/tree/dev/packer/v1/release-config) | A list of support packages to install, specified as a list of support package names separated by spaces. For example, `Deep_Learning_Toolbox_Model_for_GoogLeNet_Network Deep_Learning_Toolbox_Model_for_ResNet-101_Network` |
| BASE_AMI | Default AMI ID refers to ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server. | The base AMI upon which the image is built, defaults to an official Canonical® Ubuntu® image. |
| VPC_ID | *unset* | VPC to assign to the Packer build instance. If no VPC is specified, the default VPC will be used.|
| SUBNET_ID | *unset* | Subnet to assign to the Packer build instance. If no subnet is specified, the subnet with the most free IPv4 addresses will be used.|
| INSTANCE_TAGS |{Name="Packer Builder", Build="MATLAB_Parallel_Server"} | Tags to add to the Packer build instance.|
| AMI_TAGS | {Name="Packer Build", Build="MATLAB_Parallel_Server", Type="matlab-parallel-server-on-aws"} | Tags to add to the machine image.|

For a full list of the variables used in the build, see the description fields in the
[Packer template](https://github.mathworks.com/development/parallel-server-aws-refarch/tree/dev/packer/v1/build-parallel-server-ami.pkr.hcl).



### **Customize Packer Build**
#### **Customize Products to Install**
Use the Packer build-time variable `PRODUCTS` to specify the list of products you want to install on the machine image. If unspecified, Packer will install MATLAB, MATLAB Parallel Server, MATLAB Production Server, and all the available toolboxes. Use the Packer build-time variable `POLYSPACE_PRODUCTS` to specify the list of Polyspace products you want to install on the machine image. If unspecified, Packer will install Polyspace Bug Finder Server and Polyspace Code Prover Server.

For example, install the latest version of MATLAB and Deep Learning Toolbox.
```bash
packer build -var="PRODUCTS=MATLAB MATLAB_Parallel_Server MATLAB_Production_Server Deep_Learning_Toolbox" build-parallel-server-ami.pkr.hcl
```

#### **Customize MATLAB Parallel Server Release to Install**
To use an earlier MATLAB Parallel Server release, you must use one of the variable definition files in the [release-config](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws/tree/master/packer/v1/release-config) folder. Although the files are available for MATLAB Parallel Server release R2021b and later, MathWorks recommends using MATLAB Parallel Server R2023a or later. This is because the Packer builds for earlier releases use Ubuntu 20.04, which is no longer supported by Canonical.

For example, install R2023a for MATLAB Parallel Server and all necessary and available toolboxes.
```bash
packer build -var-file="release-config/R2023a.pkrvars.hcl" build-matlab-parallel-server-ami.pkr.hcl
```
Command line arguments can also be combined. For example, install R2020a for MATLAB, MATLAB Parallel Server, MATLAB Production Server, and the Parallel Computing Toolbox only.
```bash
packer build -var-file="release-config/R2023a.pkrvars.hcl" -var="PRODUCTS=MATLAB MATLAB_Parallel_Server MATLAB_Production_Server Parallel_Computing_Toolbox" build-matlab-parallel-server-ami.pkr.hcl
```
Launch the customized image using the corresponding CloudFormation Template.
For instructions on how to use CloudFormation Templates, see the Deployment Steps
section on [MATLAB Parallel Server on Amazon Web Services](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws).
#### **Customize Multiple Variables**
You can set multiple variables in a [Variable Definition File](https://developer.hashicorp.com/packer/docs/templates/hcl_templates/variables#standard-variable-definitions-files).

For example, to generate a machine image with the most recent MATLAB installed with necessary and additional toolboxes in a custom VPC, create a variable definition file named `custom-variables.pkrvars.hcl` containing these variable definitions.
```
VPC_ID    = <any_VPC_id>
PRODUCTS  = "MATLAB MATLAB_Parallel_Server MATLAB_Production_Server Deep_Learning_Toolbox Parallel_Computing_Toolbox"
POLYSPACE_PRODUCTS = "Polyspace_Bug_Finder_Server Polyspace_Code_Prover_Server"
```

To specify a MATLAB release using a variable definition file, modify the variable definition file
in the [release-config](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws/tree/master/packer/v1/release-config)
folder corresponding to the desired release.

Save the variable definition file and include it in the Packer build command.
```bash
packer build -var-file="custom-variables.pkrvars.hcl" build-parallel-server-ami.pkr.hcl
```

### **Installation, Runtime, and Startup Scripts**
The Packer build executes scripts on the image builder instance during the build.
These scripts perform tasks such as
installing tools needed by the build (including gcc, wget, make, CloudWatch, cfn-signal),
installing MATLAB Parallel Server and toolboxes on the image using [MATLAB Package Manager](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md),
and cleaning up build leftovers (including bash history, SSH keys).

For the full list of scripts that the Packer build executes during the build, see the `BUILD_SCRIPTS` parameter in the
[Packer template](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws/tree/master/packer/v1/build-parallel-server-ami.pkr.hcl).
The prebuilt images that MathWorks provides are built using these scripts as a base, and additionally have support packages installed.

In addition to the build scripts above, the Packer build copies further scripts to the machine image,
to be used during startup and at runtime. These scripts perform tasks such as
mounting available storage, 
initializing CloudWatch logging (if this is chosen), 
performing MATLAB startup acceleration, 
setting up [MATLAB Job Scheduler](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws?tab=readme-ov-file#what-is-matlab-job-scheduler), 
and  setting up autoscaling scripts and cluster management scripts, 
among other utility tasks.

For the full list of startup and runtime scripts, see the `STARTUP_SCRIPTS` and the `RUNTIME_SCRIPTS` parameters in the
[Packer template](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-aws/tree/master/packer/v1/build-parallel-server-ami.pkr.hcl).


## Validate Packer Template
To validate the syntax and configuration of a Packer template, use the `packer validate` command. This command also checks whether the provided input variables meet the custom validation rules defined by MathWorks. For more information, see [validate Command](https://www.packer.io/docs/commands/validate#validate-command).

You can also use command line interfaces provided by Packer to inspect and format the template. For more information, see [Packer Commands (CLI)](https://www.packer.io/docs/commands).

## Deploy Machine Image
When the build finishes, Packer writes
the output to a `manifest.json` file, which contains these fields:
```json
{
  "builds": [
    {
      "name":,
      "builder_type": ,
      "build_time": ,
      "files": ,
      "artifact_id": ,
      "packer_run_uuid": ,
      "custom_data": {
        "release": ,
        "specified_products": ,
        "specified_spkgs": ,
        "specified_polyspace_products": ,
        "build_scripts": ,
      }
    }
  ],
  "last_run_uuid": ""
}
```

The `artifact_id` section shows the ID of the machine image generated by the most recent Packer build.

The CloudFormation templates provided by MathWorks for releases R2022b onwards include an optional custom machine image ID field, `CustomAmiId`.
If you do not specify a custom machine image ID, the template
launches a prebuilt image provided by MathWorks. To launch a custom machine image,
provide the `artifact_id` from the `manifest.json` file as the `CustomAmiId`.

For AMIs built with an earlier MATLAB release, replace the AMI ID in the
corresponding CloudFormation template with the AMI ID of your customized image.

If the build has been customized, for example by removing or modifying one or more of the included scripts,
the resultant machine image **may no longer be compatible** with the provided CloudFormation template. If the AMI has been created from the MATLAB on AWS offering, then the resultant machine image **may not be compatible** due to missing autoscaling scripts, job scheduler setup, and other customisations.
Compatibility can in some cases be restored by making corresponding modifications to the CloudFormation template.

## Technical Support
If you require assistance or have a request for additional features or capabilities, contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2025 The MathWorks, Inc.

----
