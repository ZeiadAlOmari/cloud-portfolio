terraform {
  required_version = ">= 1.11"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
  backend "s3" {
    bucket       = "cloud-portfolio-tfstate-gt35g4p1"
    key          = "p10/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags { tags = { Project = "p10-serverless-v2", ManagedBy = "terraform" } }
}
