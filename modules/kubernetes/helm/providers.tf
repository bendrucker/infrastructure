provider "helm" {
  kubernetes {
    host = "${var.api_server}"
    cluster_ca_certificate = "${var.ca_certificate}"
    client_certificate = "${var.client_certificate}"
    client_key = "${var.client_key}"
  }
}
