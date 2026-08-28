# HCP Terraform presents a workload identity token to AWS on every run, so the
# workspace needs no access key. The thumbprint list is omitted: app.terraform.io
# uses a well-known CA, and AWS verifies those without a pinned thumbprint.
resource "aws_iam_openid_connect_provider" "terraform" {
  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
}

data "aws_iam_policy_document" "terraform_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.terraform.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "app.terraform.io:aud"
      values   = ["aws.workload.identity"]
    }

    # Both conditions are required. The audience alone is identical for every HCP
    # Terraform organization, so without the subject any organization could assume
    # this role. The project segment is wildcarded because the workspace sits in the
    # default project and pinning it would mean tracking a name that carries no
    # security weight. The workspace name is pinned.
    condition {
      test     = "StringLike"
      variable = "app.terraform.io:sub"
      values   = ["organization:bendrucker:project:*:workspace:infrastructure:run_phase:*"]
    }
  }
}

# The /managed/ path lets the role's own IAM permissions be scoped by path, so it
# can create the roles the root module owns without being able to touch this one's
# peers outside the path.
resource "aws_iam_role" "terraform" {
  name               = "terraform"
  path               = "/managed/"
  assume_role_policy = data.aws_iam_policy_document.terraform_trust.json
}
