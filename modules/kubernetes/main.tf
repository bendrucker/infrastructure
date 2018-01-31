locals {
  asset_dir = "${var.output_directory}/${var.name}"
}

data "aws_route53_zone" "internal" {
  name = "${var.hosted_zone}"
}

module "typhoon" {
  source = "git::https://github.com/bendrucker/typhoon//aws/container-linux/kubernetes?ref=b041c1653a5627584ef794f104057be6c96af0fa"

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

module "helm" {
  source = "./helm"

  api_server = "${module.typhoon.api_server}"
  ca_certificate = "${module.typhoon.ca_cert}"
  client_certificate = "${module.typhoon.client_cert}"
  client_key = "${module.typhoon.client_key}"
}
