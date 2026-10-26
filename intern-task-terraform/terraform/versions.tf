terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Lets plan run against fake credentials without calling AWS (see task README).
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = { Project = var.name }
  }
}
