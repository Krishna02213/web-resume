variable "bucket_names" {
  description = "Unique names for the S3 buckets to create"
  type        = list(string)
  default = [
    "krishna-tf-practice-1",
    "krishna-tf-practice-2",
    "krishna-tf-practice-3",
  ]

  validation {
    condition     = length(var.bucket_names) == length(distinct(var.bucket_names))
    error_message = "Each bucket name must be unique in the list."
  }
}
