# Replaces the static access key that bendrucker/terraform-aws-ec2-pricing has held
# as repo secrets since 2020. GitHub mints a token per workflow run and AWS trades
# it for short-lived credentials, so the repo stores nothing.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "ec2_pricing_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Without a subject condition the audience alone would let any repository on
    # GitHub assume this role. The wildcard covers every ref and pull request in the
    # one repository named here.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:bendrucker/terraform-aws-ec2-pricing:*"]
    }
  }
}

resource "aws_iam_role" "ec2_pricing" {
  name               = "terraform-aws-ec2-pricing"
  path               = "/managed/"
  assume_role_policy = data.aws_iam_policy_document.ec2_pricing_trust.json
}

# The Price List API is the module's entire reason to hold credentials. Its actions
# have no resource-level support.
data "aws_iam_policy_document" "ec2_pricing" {
  statement {
    actions = [
      "pricing:GetProducts",
      "pricing:DescribeServices",
      "pricing:GetAttributeValues",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_pricing" {
  name   = "pricing"
  role   = aws_iam_role.ec2_pricing.name
  policy = data.aws_iam_policy_document.ec2_pricing.json
}

output "ec2_pricing_role_arn" {
  description = "role-to-assume for the bendrucker/terraform-aws-ec2-pricing workflow"
  value       = aws_iam_role.ec2_pricing.arn
}
