# Profiling and benchmarking need Linux on real hardware: perf with hardware
# counters, eBPF, ptrace on system binaries, and steadier timing than a laptop
# gives. Agents running the performance plugin get disposable Graviton
# instances for that, launched and terminated by a CLI in dotfiles over a
# session of a couple of hours. This member account keeps those instances and
# their bill apart from the management account and from agents.
#
# Unlike agents, the in-account resources live here rather than in an app
# repo's terraform root. The launcher is a shell tool with no root of its own,
# and what it needs is a handful of fixed resources that rarely change. A
# workspace and run role for them would need iam:PassRole and instance profile
# management, a wider grant than everything it would manage.

resource "aws_organizations_account" "performance" {
  name  = "performance"
  email = "bvdrucker+aws-performance@gmail.com"

  # See agents.tf: the service default, named by bootstrap's
  # MemberAccountAccess grant.
  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

# A forgotten instance is the cost that matters here. The instance TTL in the
# launch template is the first line of defense. The budget catches whatever
# gets past it, hours late, since AWS refreshes budget data a few times a day.
resource "aws_budgets_budget" "performance" {
  provider = aws.performance

  name         = "performance-monthly"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["bvdrucker@gmail.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["bvdrucker@gmail.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["bvdrucker@gmail.com"]
  }
}

locals {
  # Graviton 4 families up to 16xlarge, plus the smaller bare-metal size for
  # full PMU access. The 24xlarge and 48xlarge sizes cost more than a
  # benchmark needs.
  performance_instance_types = [
    for pair in setproduct(
      ["c8g", "m8g", "r8g"],
      ["medium", "large", "xlarge", "2xlarge", "4xlarge", "8xlarge", "12xlarge", "16xlarge", "metal-24xl"],
    ) : join(".", pair)
  ]
}

# Service control policies bind every principal in the account, including the
# AdministratorAccess permission set, so the guardrails hold for agents and
# humans alike. Only the management account can change them.
data "aws_iam_policy_document" "performance_guardrails" {
  # Global services are exempt, following the AWS example region policy. Their
  # calls can carry a region other than us-east-1 without running anything
  # there.
  statement {
    sid    = "DenyOutsideUsEast1"
    effect = "Deny"

    not_actions = [
      "account:*",
      "budgets:*",
      "ce:*",
      "cloudfront:*",
      "cur:*",
      "ec2:DescribeRegions",
      "health:*",
      "iam:*",
      "organizations:*",
      "pricing:*",
      "route53:*",
      "s3:GetAccountPublic*",
      "s3:ListAllMyBuckets",
      "s3:PutAccountPublic*",
      "sts:*",
      "support:*",
      "trustedadvisor:*",
    ]

    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = ["us-east-1"]
    }
  }

  statement {
    sid       = "DenyLargeInstances"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "StringNotEquals"
      variable = "ec2:InstanceType"
      values   = local.performance_instance_types
    }
  }

  # Resizing a stopped instance would otherwise step around the launch check.
  statement {
    sid       = "DenyLargeResize"
    effect    = "Deny"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "ec2:Attribute/InstanceType"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "ec2:Attribute/InstanceType"
      values   = local.performance_instance_types
    }
  }

  # Instances here are disposable, and the reaper terminates or stops them on a
  # schedule. Termination protection fails its TerminateInstances call, and stop
  # protection its StopInstances. Setting either attribute to false stays
  # allowed, so protection can still be cleared. The Service Authorization
  # Reference types these keys as strings.
  statement {
    sid       = "DenyTerminationProtection"
    effect    = "Deny"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]

    condition {
      test     = "StringEqualsIgnoreCase"
      variable = "ec2:Attribute/DisableApiTermination"
      values   = ["true"]
    }
  }

  statement {
    sid       = "DenyStopProtection"
    effect    = "Deny"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]

    condition {
      test     = "StringEqualsIgnoreCase"
      variable = "ec2:Attribute/DisableApiStop"
      values   = ["true"]
    }
  }

  # RunInstances has no condition key for DisableApiTermination or
  # DisableApiStop, in the request or the launch template, so an instance can
  # still launch protected. The reaper clears protection before it acts.

  # Fleets and Auto Scaling launch through service-linked roles, which SCPs do
  # not bind, so the instance type check above never sees their launches. The
  # purchases commit to a year or more of spend in one call.
  statement {
    sid    = "DenyIndirectLaunchesAndCommitments"
    effect = "Deny"

    actions = [
      "autoscaling:*",
      "ec2:AllocateHosts",
      "ec2:CreateCapacityReservation",
      "ec2:CreateFleet",
      "ec2:PurchaseHostReservation",
      "ec2:PurchaseReservedInstancesOffering",
      "ec2:PurchaseScheduledInstances",
      "ec2:RequestSpotFleet",
      "savingsplans:*",
    ]

    resources = ["*"]
  }
}

resource "aws_organizations_policy" "performance_guardrails" {
  name        = "performance-guardrails"
  description = "Limits the performance account to us-east-1 and modest Graviton instances."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.performance_guardrails.json
}

resource "aws_organizations_policy_attachment" "performance_guardrails" {
  policy_id = aws_organizations_policy.performance_guardrails.id
  target_id = aws_organizations_account.performance.id
}

# Instances reach Session Manager outbound through the default VPC's public
# subnets. Nothing listens for inbound traffic, and no NAT gateway or VPC
# endpoint bills by the hour while no instance is running.
resource "aws_default_vpc" "performance" {
  provider = aws.performance
}

resource "aws_security_group" "performance_instance" {
  provider = aws.performance

  name        = "performance-instance"
  description = "Egress only. Access is through Session Manager."
  vpc_id      = aws_default_vpc.performance.id
}

resource "aws_vpc_security_group_egress_rule" "performance_instance" {
  provider = aws.performance

  security_group_id = aws_security_group.performance_instance.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_iam_policy_document" "performance_instance_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "performance_instance" {
  provider = aws.performance

  name               = "performance-instance"
  path               = "/managed/"
  assume_role_policy = data.aws_iam_policy_document.performance_instance_trust.json
}

resource "aws_iam_role_policy_attachment" "performance_instance_ssm" {
  provider = aws.performance

  role       = aws_iam_role.performance_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "performance_instance" {
  provider = aws.performance

  name = "performance-instance"
  path = "/managed/"
  role = aws_iam_role.performance_instance.name
}

# The launcher finds this by name and overrides the instance type per run.
resource "aws_launch_template" "performance" {
  provider = aws.performance

  name                   = "performance"
  update_default_version = true

  # Resolved at launch, so every instance boots the current Amazon Linux 2023
  # arm64 image, SSM agent included, without a plan here to bump it.
  image_id      = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
  instance_type = "c8g.xlarge"

  instance_initiated_shutdown_behavior = "terminate"

  # With shutdown set to terminate, this bounds a forgotten instance to four
  # hours. A launcher that passes its own user data replaces this script and
  # has to carry the TTL itself. `sudo shutdown -c` cancels it on a session
  # that runs long.
  user_data = base64encode(<<-EOT
    #!/bin/sh
    shutdown -h +240
  EOT
  )

  iam_instance_profile {
    arn = aws_iam_instance_profile.performance_instance.arn
  }

  vpc_security_group_ids = [aws_security_group.performance_instance.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "performance" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "performance" }
  }
}
