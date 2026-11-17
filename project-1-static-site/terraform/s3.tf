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
  #checkov:skip=CKV_AWS_18:Server access logs need a second bucket and storage (P8 F-56, cost decision)
  #checkov:skip=CKV_AWS_144:Cross-region replication shown in P7; doubles storage and transfer (cost decision)
  #checkov:skip=CKV_AWS_145:SSE-S3 used; a customer-managed KMS key costs about USD 1/month (cost decision)
  #checkov:skip=CKV2_AWS_62:No consumer for bucket event notifications on a static site (not applicable)
  #checkov:skip=CKV_AWS_21:TEMPORARY - versioning added in the first P9 pull request (P8 F-57)
  #checkov:skip=CKV2_AWS_61:TEMPORARY - lifecycle rule added in the first P9 pull request
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
