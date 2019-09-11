resource "aws_s3_bucket" "bucket" {
  bucket = var.name

  lifecycle_rule {
    id      = "glacier-archive"
    enabled = true

    transition {
      days          = 1
      storage_class = "GLACIER"
    }
  }
}
