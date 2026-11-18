output "site_url" {
  description = "CloudFront URL for the DR demo site"
  value       = "https://${aws_cloudfront_distribution.dr.domain_name}"
}

output "primary_bucket" {
  description = "Primary bucket (us-east-1)"
  value       = aws_s3_bucket.primary.id
}

output "secondary_bucket" {
  description = "Secondary bucket (us-west-2)"
  value       = aws_s3_bucket.secondary.id
}
