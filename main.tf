module "kubernetes" {
  source = "./modules/kubernetes"

  providers = {
    aws = "aws.default"
    local = "local.default"
    null = "null.default"
    template = "template.default"
    tls = "tls.default"
  }

  name = "kubernetes"
  hosted_zone = "bendrucker.io"

  output_directory = "./output"
}
