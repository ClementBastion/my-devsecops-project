terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  #Backend S3 pour stocker le state en équipe
  #Décommenter après avoir créé le bucket manuellement
  backend "s3" {
    bucket         = "myftpdr-terraform-state"
    key            = "devsecops/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "myftpdr-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devsecops"
    }
  }
}
