locals {
  common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  terraform_state_bucket_name = "${local.common_vars.namespace}-${local.common_vars.name}-${local.common_vars.environment}-deployment-${local.common_vars.terraform_state_bucket}" 
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<EOF
provider "aws" {
  alias  = "noassume"
  region = "${local.common_vars.environment}"
}

provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::${local.common_vars.deployment_account_id}:role/${local.common_vars.terraform_deployment_role_name}"
  }

  region = "${local.common_vars.environment}"
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket         = local.terraform_state_bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.common_vars.environment
    role_arn       = "arn:aws:iam::${local.common_vars.deployment_account_id}:role/${local.common_vars.terraform_administrator_role_name}"
    encrypt        = true
    dynamodb_table = local.common_vars.terraform_state_dynamodb_table
    s3_bucket_tags = {
      owner = "terraform"
      name  = "Terraform state storage"
    }
    dynamodb_table_tags = {
      owner = "terraform"
      name  = local.common_vars.terraform_state_dynamodb_table
    }
  }
  generate = {    
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.common_vars,
  { 
    terraform_state_bucket_name = local.terraform_state_bucket_name
    aws_region = local.common_vars.environment
  }
)
