output "deployer_role_arn" {
  description = "Role to assume (with MFA) for day-to-day deployments"
  value       = aws_iam_role.deployer.arn
}

output "trail_bucket" {
  description = "S3 bucket holding CloudTrail logs"
  value       = aws_s3_bucket.trail.id
}

output "assume_role_command" {
  description = "Example: get short-lived credentials (replace MFA device ARN and code)"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.deployer.arn} --role-session-name deploy --serial-number <MFA_DEVICE_ARN> --token-code <6_DIGIT_CODE>"
}
