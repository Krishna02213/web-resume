variable "aws_region" {
  description = "AWS region containing the existing portfolio network."
  type        = string
}

variable "aws_profile" {
  description = "Locally authenticated AWS CLI profile; credentials stay outside this project."
  type        = string
}

variable "aws_account_id" {
  description = "Expected AWS account, to prevent deploying to a different account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Provide a 12-digit AWS account ID."
  }
}

variable "instance_name" {
  description = "Name tag for the new Terraform-managed instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type; matches the original t3.micro server."
  type        = string
}

variable "ami_id" {
  description = "Pinned Ubuntu 24.04 amd64 AMI matching the original server in this region."
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC to reuse, not create or manage."
  type        = string
}

variable "subnet_id" {
  description = "Existing public subnet to reuse."
  type        = string
}

variable "security_group_id" {
  description = "Existing security group with public HTTP and SSH restricted to the owner's IP."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name; the private key remains on your Mac."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local SSH key path, used only to display a connection command. Terraform does not read the key."
  type        = string
}

variable "root_volume_size" {
  description = "Encrypted gp3 root volume capacity in GiB."
  type        = number

  validation {
    condition     = var.root_volume_size >= 8 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "Root volume size must be a whole number of at least 8 GiB."
  }
}
