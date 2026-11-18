terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region
provider "aws" {
  region = "us-east-1"
}

# Secondary (disaster recovery) region
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}
