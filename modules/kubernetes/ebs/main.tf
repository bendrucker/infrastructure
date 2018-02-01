locals {
  yml = "${path.module}/ebs.yml"
}
resource "null_resource" "ebs" {
  triggers {
    ebs = "${file(local.yml)}"
  }
  provisioner "local-exec" {
    command = "KUBECONFIG=${var.kubeconfig} kubectl apply -f ${local.yml}"
  }

  provisioner "local-exec" {
    when = "destroy"
    command="KUBECONFIG=${var.kubeconfig} kubectl delete -f ${local.yml}"
  }
}
