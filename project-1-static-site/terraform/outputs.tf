output "website_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "website_url" {
  description = "S3 static website URL"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}
output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}