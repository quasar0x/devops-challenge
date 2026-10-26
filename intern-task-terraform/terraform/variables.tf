variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "intern-task-app"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet. Must sit inside vpc_cidr."
  type        = string
  default     = "10.0.1.0/24"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS (amd64) AMI. user_data assumes Ubuntu (apt, ufw, systemd). AMI IDs are regional."
  type        = string
  default     = "ami-0360c520857e3138f"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  description = "The single CIDR allowed to SSH in, e.g. your own IP as x.x.x.x/32. No default on purpose."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "ssh_allowed_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "admin_user" {
  description = "Non root user created on the instance, with passwordless sudo."
  type        = string
  default     = "deploy"
}

variable "ssh_public_key" {
  description = "Public key authorised for admin_user. Leave null to create the user without SSH access."
  type        = string
  default     = null
}
