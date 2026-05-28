terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # State local — ce bootstrap est appliqué une seule fois par un admin
}

provider "aws" {
  region = "eu-west-3"
}
