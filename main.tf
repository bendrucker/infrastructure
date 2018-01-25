module "k8s" {
  source = "./k8s"
  output_directory = "${var.output_directory}/k8s"
}
