terraform {
  backend "s3" {
    bucket       = "cloud-portfolio-tfstate-gt35g4p1"
    key          = "p1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
