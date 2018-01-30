locals {
  name = "k8s"
  hosted_zone = "bendrucker.io"
  asset_dir = "${var.output_directory}/${local.name}"
}

data "aws_route53_zone" "internal" {
  name = "${local.hosted_zone}"
}

module "kubernetes" {
  source = "git::https://github.com/poseidon/typhoon//aws/container-linux/kubernetes?ref=2fa1840c30d5ea0304519026f66a62fde29ee573"

  providers = {
    aws = "aws.default"
    local = "local.default"
    null = "null.default"
    template = "template.default"
    tls = "tls.default"
  }

  dns_zone = "${local.hosted_zone}"
  dns_zone_id = "${data.aws_route53_zone.internal.zone_id}"

  cluster_name = "${local.name}"
  controller_count = 1
  worker_count = 1
  ssh_authorized_key = "${file("~/.ssh/id_rsa.pub")}"

  asset_dir = "${local.asset_dir}"
}

module "kuberntes-resources" {
  source = "./k8s"

  kubeconfig = "${local.asset_dir}/auth/kubeconfig"
}
