locals {
  hosted_zone = "bendrucker.io"
}

data "aws_route53_zone" "internal" {
  name = "${local.hosted_zone}"
}

module "kubernetes" {
  source = "git::https://github.com/poseidon/typhoon//aws/container-linux/kubernetes"

  providers = {
    aws = "aws.default"
  }

  dns_zone = "${local.hosted_zone}"
  dns_zone_id = "${data.aws_route53_zone.internal.zone_id}"

  cluster_name = "k8s"
  controller_count = 1
  worker_count = 1
  ssh_authorized_key = "${file("~/.ssh/id_rsa.pub")}"

  asset_dir = "${var.output_directory}"
}
