locals {
  asset_dir = "${var.output_directory}/${var.name}"
}

data "aws_route53_zone" "internal" {
  name = "${var.hosted_zone}"
}

module "typhoon" {
  source = "git::https://github.com/bendrucker/typhoon//aws/container-linux/kubernetes?ref=ce7954a3d30b19f65df45c7c270aa3df1de51045"

  providers = {
    aws = "aws"
    local = "local"
    null = "null"
    template = "template"
    tls = "tls"
  }

  dns_zone = "${var.hosted_zone}"
  dns_zone_id = "${data.aws_route53_zone.internal.zone_id}"

  cluster_name = "${var.name}"
  controller_count = 1
  worker_count = 1
  ssh_authorized_key = "${file("~/.ssh/id_rsa.pub")}"

  asset_dir = "${local.asset_dir}"
}

module "ebs" {
  source = "./ebs"

  kubeconfig = "${local.asset_dir}/auth/kubeconfig"
}

module "helm" {
  source = "./helm"

  api_server = "${module.typhoon.api_server}"
  ca_certificate = "${base64decode(module.typhoon.ca_cert)}"
  client_certificate = "${base64decode(module.typhoon.client_cert)}"
  client_key = "${base64decode(module.typhoon.client_key)}"
}
