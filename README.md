# Using Terragrunt run-all in AWS CI/CD

This project relates to the Medium article [Using Terragrunt run-all in AWS CI/CD](https://medium.com/@oliver.schenk/using-terragrunt-run-all-in-aws-ci-cd-df2877bad198).

Please note that the AWS resources created by this project MAY NOT be free. Deploy at your own risk and destroy when no longer needed.

## Overview

This project is a demonstration of how to use Terraform and Terragrunt to create a CI/CD pipeline using CodeCommit, CodeBuild and CodePipeline. It speficially attempts to provide a solution for using the Terragrunt `run-all` command in order to create, update and delete resources cleanly. Whilst creating and updating resources is generally no problem for Terragrunt and Terraform change detection, deleting an entire Terragrunt `terragrunt.hcl` module file will cause Terragrunt to skip the module rather than delete it. This project also provides a possible solution for this.

## The .destroy file method

Let's say you created a reusable AWS SSM Parameter module in Terraform and you instantiated it with a Terragrunt module in a folder called `test-parameter`. To destroy this parameter you can't just simply delete the `terragrunt.hcl` file or the `test-parameter` folder that contains it.

To delete this module you will create a `.destroy` file inside the `test-parameter` folder and then push this to the CodeCommit respository. The CI/CD pipeline will then detect the `.destroy` file and run the `plan` and `apply` phases using the `-destroy` option. On a subsequent commit you can then safely remove the `test-parameter` folder and the files inside it.

## Requirements

To deploy this project your environment will need:

- AWS CLI
- An AWS Account
- Credentials for the above account with Admin rights either through access keys or SSO (see article on [SSO with Terraform and Terragrunt](https://medium.com/gitconnected/aws-single-sign-on-terraform-and-terragrunt-a8c22bb7cfa8))
- Terragrunt
- Terraform

## Architecture

This project deploys a single account CI/CD pipeline and makes use of CodeCommit, CodeBuild and CodePipeline. It is specifically tailored towards Terragrunt and Terraform.

The CodePipeline project has four stages:

- Source
- Plan
- Approval
- Apply

It sources the code from CodeCommit and calls two different CodeBuild projects to plan and then apply the resources. There is an approval stage in between, which will send you a notification via Email using SNS.

The CI/CD pipeline is triggered by a change in the `master` branch using an EventBridge rule and target.

There are two roles, one for depoyment (`TerraformDeploymentRole`) and one for managing Terraform state (`TerraformAdministratorRole`).

Finally, there are two S3 buckets, one for logging and one for build artifacts.

## Quick start

### Deploy

If this is a fresh deployment you should run the deploy script without any options.

```
./deploy.sh
```

However, there may be a reason why you would want to run it again from your local machine after the resources have already been deployed. In that case you should use remote state with the `-r` flag and you should probably avoid pushing the code into CodeCommit again using the `-p` flag.

```
./deploy.sh -r -p
```

Usage:
```
DESCRIPTION:
  Script for initializing resources in this project. See README for more details.
  *** MUST BE RUN WITH ADMIN CREDENTIALS FOR DEPLOYMENT ACCOUNT ***

USAGE:
  init.sh [-r] [-p]

OPTIONS
  -r   use remote state, can be used after the inital run
  -p   skip pushing code to remote repo
```

### Destroy

To destroy all the resources created in this project use the destroy script. This will also destroy the remote state resources.

```
./destroy.sh
```

Usage:
```
DESCRIPTION:
  Script for destroying resources in this project. See README for more details.
  *** MUST BE RUN WITH ADMIN CREDENTIALS FOR DEPLOYMENT ACCOUNT ***

USAGE:
  destroy.sh
```


