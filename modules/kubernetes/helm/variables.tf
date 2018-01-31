variable "api_server" {
  type = "string"
  description = "URL of Kubernetes API server"
}

variable "ca_certificate" {
  type = "string"
  description = "CA certificate"
}

variable "client_certificate" {
  type = "string"
  description = "Client user certificate"
}

variable "client_key" {
  type = "string"
  description = "Client user key"
}
