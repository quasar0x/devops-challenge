locals {
  app_dir    = "${path.module}/../../intern-task-app"
  dockerfile = file("${local.app_dir}/Dockerfile")

  # Port the app binds to, read from its Dockerfile so the two tasks can't drift.
  app_port = tonumber(regex("PORT=(\\d+)", local.dockerfile)[0])

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    admin_user     = var.admin_user
    ssh_public_key = var.ssh_public_key == null ? "" : var.ssh_public_key
    ssh_cidr       = var.ssh_allowed_cidr
    app_port       = local.app_port
    dockerfile_b64 = base64encode(local.dockerfile)
    app_py_b64     = filebase64("${local.app_dir}/app/app.py")
  })
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# A subnet is only public if its route table sends 0.0.0.0/0 to an internet
# gateway attached to the VPC, and instances in it get a public IP.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name        = "${var.name}-sg"
  description = "SSH from one CIDR, app port from anywhere"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.name}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH from the admin CIDR only"
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "intern-task-app"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = local.app_port
  to_port           = local.app_port
}

# Egress is limited to what bootstrap needs: apt (80/443) and pulling the
# base image from Docker Hub (443). DNS and NTP go to the VPC resolver and
# the Amazon time service, which security groups don't filter.
resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "apt mirrors"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "apt and Docker Hub"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = local.user_data

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = var.name }

  lifecycle {
    # cloud-init only runs user_data on first boot, so a diff on it can't
    # change a running instance. To roll out a new bootstrap on purpose:
    #   terraform apply -replace=aws_instance.app
    ignore_changes = [user_data]
  }
}
