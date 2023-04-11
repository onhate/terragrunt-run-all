include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules//terraform-codebuild"
}

locals {
  common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  
  tf_deployment_roles = [
    "arn:aws:iam::${local.common_vars.deployment_account_id}:role/${local.common_vars.terraform_deployment_role_name}"
  ]
  tf_state_roles = [
    "arn:aws:iam::${local.common_vars.deployment_account_id}:role/${local.common_vars.terraform_administrator_role_name}"
  ]
}

dependency "logging_bucket" {
  config_path = "../logging-bucket"
  mock_outputs = {
    s3_bucket_id = "mock-logging-bucket-name"
  }
}

dependency "artifacts_bucket" {
  config_path = "../artifacts-bucket"
  mock_outputs = {
    s3_bucket_id = "mock-artifacts-bucket-name"
  }
}

inputs = {
  codebuild_project_name = "accounts-terraform-apply"
  buildspec = "src/buildspec-apply.yaml"

  assume_role_arns = concat(local.tf_deployment_roles, local.tf_state_roles)

  logging_bucket_id    = dependency.logging_bucket.outputs.s3_bucket_id
  artifacts_bucket_id  = dependency.artifacts_bucket.outputs.s3_bucket_id
}
