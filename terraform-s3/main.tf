resource "aws_s3_bucket" "practice" {
  for_each = { for name in var.bucket_names : name => name }

  bucket = each.value
}
