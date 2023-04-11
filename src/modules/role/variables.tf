variable "role_name" {}
variable "assume_role_policy_json" {}

variable "policies" {
  type = object({
    role_policy_arn  = string
    role_policy_json = string
  })

  default = {
    role_policy_arn  = ""
    role_policy_json = ""
  }

  validation {
    condition     = length(var.policies.role_policy_arn) > 0 || length(var.policies.role_policy_json) > 0
    error_message = "You must provide a policy either using ARN or JSON."
  }
}
