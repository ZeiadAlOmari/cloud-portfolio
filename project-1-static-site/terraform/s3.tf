# Random suffix to ensure bucket name is globally unique
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Private S3 bucket holding the site content.
# Project 8 remediation (F-04/F-05): the bucket is no longer public and no longer
# uses S3 static website hosting. CloudFront reads it through Origin Access
# Control (OAC) over HTTPS; direct S3 access is denied.
resource "aws_s3_bucket" "website" {
  bucket = "portfolio-site-${random_string.bucket_suffix.result}"
}

# Bucket policy: only this CloudFront distribution may read objects (OAC),
# and any request not using TLS is denied.
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOACReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# Block all public access. Applied after the OAC-only policy replaces the old
# public policy, so the change never blocks a policy it is about to remove.
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_policy.website]
}

# Upload index.html to the bucket
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/../site/index.html"
  content_type = "text/html"
}
