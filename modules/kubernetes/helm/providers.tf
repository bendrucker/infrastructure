provider "helm" {
  kubernetes {
    host = "${var.api_server}"
    cluster_ca_certificate = "${base64decode(var.ca_certificate)}"
    client_certificate = "${base64decode(var.client_certificate)}"
    client_key = "${base64decode(var.client_key)}"
  }
}
