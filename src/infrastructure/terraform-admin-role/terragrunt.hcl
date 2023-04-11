include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules//role"
}

locals {
    common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))

    terraform_state_bucket_name = "${local.common_vars.namespace}-${local.common_vars.name}-${local.common_vars.environment}-deployment-${local.common_vars.terraform_state_bucket}" 
}

inputs = {
  role_name = local.common_vars.terraform_administrator_role_name

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
      }
    ]
  })

  policies = {
    role_policy_arn = ""
    role_policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "AllowS3ActionsOnTerraformBucket",
          Action = ["s3:*"],
          Effect = "Allow",
          Resource = [
              "arn:aws:s3:::${local.terraform_state_bucket_name}",
              "arn:aws:s3:::${local.terraform_state_bucket_name}/*"
          ]
        },
        {
          Sid = "AllowCreateAndUpdateDynamoDBActionsOnTerraformLockTable",
          Action = [
              "dynamodb:PutItem",
              "dynamodb:GetItem",
              "dynamodb:DeleteItem",
              "dynamodb:DescribeTable",
              "dynamodb:CreateTable"
          ],
          Effect = "Allow",
          Resource = [
              "arn:aws:dynamodb:*:${local.common_vars.deployment_account_id}:table/${local.common_vars.terraform_state_dynamodb_table}",
          ]
        },
        {
          Sid = "AllowTagAndUntagDynamoDBActions",
          Action = [
              "dynamodb:TagResource",
              "dynamodb:UntagResource"
          ],
          Effect = "Allow",
          Resource = ["*"]
        }
      ]
    })
  }
}
