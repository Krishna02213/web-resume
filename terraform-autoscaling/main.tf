resource "aws_vpc" "main" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "autoscaling-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = {
    a = {
      cidr = "10.30.1.0/24"
      az   = "ap-south-1a"
    }
    b = {
      cidr = "10.30.2.0/24"
      az   = "ap-south-1b"
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "autoscaling-subnet-${each.key}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "autoscaling-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "autoscaling-public-routes"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name   = "autoscaling-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "website" {
  name   = "autoscaling-website-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "website" {
  key_name = "autoscaling-website-key"

  public_key = file(
    pathexpand("~/.ssh/id_ed25519_portfolio_ec2.pub")
  )
}

resource "aws_instance" "seed" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public["a"].id
  vpc_security_group_ids = [aws_security_group.website.id]
  key_name               = aws_key_pair.website.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt-get update
    apt-get install -y docker.io
    systemctl enable --now docker
  EOF

  depends_on = [aws_route_table_association.public]

  tags = {
    Name = "autoscaling-seed-server"
  }
}

resource "terraform_data" "deploy_website" {
  triggers_replace = [aws_instance.seed.id]

  connection {
    type        = "ssh"
    host        = aws_instance.seed.public_ip
    user        = "ubuntu"
    private_key = file(pathexpand("~/.ssh/id_ed25519_portfolio_ec2"))
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "mkdir -p /home/ubuntu/portfolio"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/../docker/"
    destination = "/home/ubuntu/portfolio"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/ubuntu/portfolio",
      "sudo docker build -t portfolio:1.0 .",
      "sudo docker run --rm portfolio:1.0 nginx -t",
      "sudo docker rm -f portfolio || true",
      "sudo docker run -d --name portfolio --restart unless-stopped -p 80:80 portfolio:1.0",
      "curl --fail --retry 10 --retry-connrefused --retry-delay 2 http://localhost/ -o /dev/null"
    ]
  }
}

resource "aws_ami_from_instance" "website" {
  name               = "autoscaling-website-v1"
  source_instance_id = aws_instance.seed.id

  depends_on = [terraform_data.deploy_website]

  tags = {
    Name = "autoscaling-website-v1"
  }
}

resource "aws_launch_template" "website" {
  name_prefix   = "autoscaling-website-"
  image_id      = aws_ami_from_instance.website.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.website.key_name

  vpc_security_group_ids = [aws_security_group.website.id]

  monitoring {
    enabled = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -eux
    systemctl enable --now docker
    docker start portfolio
  EOF
  )
}

resource "aws_lb" "website" {
  name               = "autoscaling-website-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]

  subnets = [
    for subnet in aws_subnet.public : subnet.id
  ]

  depends_on = [aws_route_table_association.public]
}

resource "aws_lb_target_group" "website" {
  name        = "autoscaling-website-targets"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.website.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.website.arn
  }
}

resource "aws_autoscaling_group" "website" {
  name             = "autoscaling-website-asg"
  min_size         = var.min_servers
  desired_capacity = var.min_servers
  max_size         = var.max_servers

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances"
  ]

  vpc_zone_identifier = [
    for subnet in aws_subnet.public : subnet.id
  ]

  target_group_arns         = [aws_lb_target_group.website.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180
  default_instance_warmup   = 120

  launch_template {
    id      = aws_launch_template.website.id
    version = aws_launch_template.website.latest_version
  }

  tag {
    key                 = "Name"
    value               = "autoscaling-website-server"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_autoscaling_policy" "requests" {
  enabled                = true
  name                   = "scale-by-website-requests"
  autoscaling_group_name = aws_autoscaling_group.website.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.requests_per_server

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.website.arn_suffix}/${aws_lb_target_group.website.arn_suffix}"
    }
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "scale-by-cpu-${var.cpu_target_percent}-percent"
  autoscaling_group_name = aws_autoscaling_group.website.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.cpu_target_percent

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

output "website_url" {
  value = "http://${aws_lb.website.dns_name}"
}

# Keep the image-building server stopped after its AMI is available.
resource "aws_ec2_instance_state" "seed" {
  instance_id = aws_instance.seed.id
  state       = "stopped"

  depends_on = [aws_ami_from_instance.website]
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.website.name
}
