terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# These data sources read existing dependencies. They do not adopt ownership.
data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnet" "existing" {
  id = var.subnet_id
}

data "aws_security_group" "existing" {
  id = var.security_group_id
}

data "aws_key_pair" "existing" {
  key_name = var.key_name
}

data "aws_ami" "ubuntu" {
  owners = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "portfolio" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.existing.id
  vpc_security_group_ids      = [data.aws_security_group.existing.id]
  key_name                    = data.aws_key_pair.existing.key_name
  associate_public_ip_address = true
  monitoring                  = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.instance_name}-root"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  # Match the original instance and avoid unlimited-mode surplus credit charges.
  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = var.instance_name
  }

  lifecycle {
    precondition {
      condition = (
        data.aws_subnet.existing.vpc_id == data.aws_vpc.existing.id &&
        data.aws_security_group.existing.vpc_id == data.aws_vpc.existing.id
      )
      error_message = "The existing subnet and security group must belong to the specified VPC."
    }
  }
}

output "instance_id" {
  description = "ID of the new Terraform-managed EC2 instance."
  value       = aws_instance.portfolio.id
}

output "public_ip" {
  description = "Public IPv4 address; may change after stopping and starting the instance."
  value       = aws_instance.portfolio.public_ip
}

output "private_ip" {
  description = "Private address assigned within the existing subnet."
  value       = aws_instance.portfolio.private_ip
}

output "availability_zone" {
  description = "Availability zone inherited from the existing subnet."
  value       = aws_instance.portfolio.availability_zone
}

output "ssh_command" {
  description = "Connect from your Mac using the existing private key."
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.portfolio.public_ip}"
}
