resource "aws_iam_role" "role" {
  name               = replace(title(var.role_name), "/-| /", "")
  assume_role_policy = var.assume_role_policy_json

  tags = module.this.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = length(var.policies.role_policy_arn) > 0 ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = var.policies.role_policy_arn
}

resource "aws_iam_role_policy" "this" {
  count  = length(var.policies.role_policy_json) > 0 ? 1 : 0
  name   = "${aws_iam_role.role.name}Policy"
  role   = aws_iam_role.role.name
  policy = var.policies.role_policy_json
}
