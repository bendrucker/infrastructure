# Enabling IAM Identity Center is a one-way console action with no Terraform
# resource behind it, and the first administrator assignment has to exist before
# anyone can authenticate to manage it. Both were done by hand and adopted here.
data "aws_ssoadmin_instances" "this" {}

locals {
  management_account_id = "278105230435"
  sso_instance_arn      = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id     = one(data.aws_ssoadmin_instances.this.identity_store_ids)
}

# The console generates the permission set ARN and the user ID, so the import
# blocks below read them back rather than hard-coding values that would have to be
# transcribed by hand. Terraform resolves data sources during plan, which is when
# import IDs are needed.
data "aws_ssoadmin_permission_set" "administrator" {
  instance_arn = local.sso_instance_arn
  name         = "AdministratorAccess"
}

data "aws_identitystore_user" "ben" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = "ben"
    }
  }
}

resource "aws_ssoadmin_permission_set" "administrator" {
  name         = "AdministratorAccess"
  instance_arn = local.sso_instance_arn

  session_duration = "PT12H"
}

import {
  to = aws_ssoadmin_permission_set.administrator
  id = "${data.aws_ssoadmin_permission_set.administrator.arn},${local.sso_instance_arn}"
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

import {
  to = aws_ssoadmin_managed_policy_attachment.administrator
  id = "arn:aws:iam::aws:policy/AdministratorAccess,${data.aws_ssoadmin_permission_set.administrator.arn},${local.sso_instance_arn}"
}

resource "aws_identitystore_user" "ben" {
  identity_store_id = local.identity_store_id

  user_name    = "ben"
  display_name = "Ben Drucker"

  name {
    given_name  = "Ben"
    family_name = "Drucker"
  }

  emails {
    value   = "bvdrucker@gmail.com"
    primary = true
  }
}

import {
  to = aws_identitystore_user.ben
  id = "${local.identity_store_id}/${data.aws_identitystore_user.ben.user_id}"
}

resource "aws_ssoadmin_account_assignment" "ben_management" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_user.ben.user_id
  principal_type = "USER"

  target_id   = local.management_account_id
  target_type = "AWS_ACCOUNT"

  # Once the IAM users are gone this assignment is the only way into the account
  # short of the root user. A plan that proposes replacing it is a plan that locks
  # everyone out.
  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = aws_ssoadmin_account_assignment.ben_management
  id = "${data.aws_identitystore_user.ben.user_id},USER,${local.management_account_id},AWS_ACCOUNT,${data.aws_ssoadmin_permission_set.administrator.arn},${local.sso_instance_arn}"
}

# Everyday access. ReadOnlyAccess rather than the job-function ViewOnlyAccess so
# that reading an object or a log line does not require escalating to
# AdministratorAccess, which stays available under its own profile.
resource "aws_ssoadmin_permission_set" "view" {
  name         = "View"
  instance_arn = local.sso_instance_arn

  session_duration = "PT12H"
}

resource "aws_ssoadmin_managed_policy_attachment" "view" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.view.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_account_assignment" "ben_management_view" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.view.arn

  principal_id   = aws_identitystore_user.ben.user_id
  principal_type = "USER"

  target_id   = local.management_account_id
  target_type = "AWS_ACCOUNT"
}
