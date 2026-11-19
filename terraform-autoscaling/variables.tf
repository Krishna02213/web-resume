variable "instance_type" {
  description = "EC2 instance size"
  type        = string
}

variable "ssh_cidr" {
  description = "Your public IP address allowed to connect through SSH"
  type        = string
}