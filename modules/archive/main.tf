resource "aws_s3_bucket" "bucket" {
  bucket = var.name
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "glacier-archive"
    status = "Enabled"

    filter {
      prefix = "Archive"
    }

    transition {
      days          = 1
      storage_class = "GLACIER"
    }
  }
}
