resource "aws_ssm_parameter" "this" {
  name  = "${module.this.id}-${var.parameter_name}"
  type  = "String"
  value = var.parameter_value

  tags = module.this.tags
}
