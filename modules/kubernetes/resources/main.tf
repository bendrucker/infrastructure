data "archive_file" "resources" {
  type = "zip"
  source_dir = "${path.module}/resources/"
  output_path = "/tmp/${md5(path.module)}"
}

resource "null_resource" "apply-resources" {
  triggers {
    resources_sha = "${data.archive_file.resources.output_sha}"
  }

  provisioner "local-exec" {
    command = "cd '${path.module}' && KUBECONFIG='${var.kubeconfig}' ${path.module}/apply.sh"
  }
}
