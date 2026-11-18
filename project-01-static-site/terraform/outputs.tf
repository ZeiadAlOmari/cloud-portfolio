output "bucket_name" {
  description = "Private S3 bucket holding the site content"
  value       = aws_s3_bucket.website.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "website_url" {
  description = "Public site URL (HTTPS via CloudFront)"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}
