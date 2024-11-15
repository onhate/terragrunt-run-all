locals {
  common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  terraform_state_bucket_name = "${local.common_vars.namespace}-${local.common_vars.name}-${local.common_vars.environment}-deployment-${local.common_vars.terraform_state_bucket}" 
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<EOF

provider "aws" {
  region = "${local.common_vars.environment}"
}
EOF
}

remote_state {
  backend = "local"
  config = {
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
