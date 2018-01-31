variable "name" {
  type = "string"
  description = "A name for the cluster"
}

variable "hosted_zone" {
  type = "string"
  description = "The hosted zone for the cluster"
}

variable "output_directory" {
  type = "string"
  description = "A directory where output files will be stored"
}
