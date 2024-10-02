provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Company     = "dreamcanvas"
      Owner       = "Todd"
      Provisioner = "Terraform"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.50.0"
    }
  }
  required_version = "1.8.5"
}