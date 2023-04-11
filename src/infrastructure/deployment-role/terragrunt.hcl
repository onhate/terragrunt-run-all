include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules//role"
}

locals {
    common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
}

inputs = {
  role_name = local.common_vars.terraform_deployment_role_name

  assume_role_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "DeploymentRoleAssumedByTerraform",
        Action = ["sts:AssumeRole"],
        Effect = "Allow",
        Principal = {
            AWS = "arn:aws:iam::${local.common_vars.deployment_account_id}:root"
        }
      },
    ]
  })

  policies = {
    role_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    role_policy_json = ""
  }
}
