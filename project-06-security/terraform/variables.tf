variable "trusted_user" {
  description = "IAM user allowed to assume the deployer role (must have MFA)"
  type        = string
  default     = "admin"
}

variable "allowed_regions" {
  description = "Regions the deployer role may use; all regional API calls elsewhere are denied"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}
