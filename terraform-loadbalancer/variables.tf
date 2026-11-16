variable "instances" {
  description = "Settings for each EC2 instance"

  type = map(object({
    instance_type = string
    subnet        = string
  }))
}