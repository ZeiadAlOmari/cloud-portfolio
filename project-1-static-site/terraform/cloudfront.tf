# Get the AWS account ID
data "aws_caller_identity" "current" {}

# Origin Access Control: CloudFront signs every origin request (SigV4),
# so the bucket can stay private. Free.
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${aws_s3_bucket.website.id}-oac"
  description                       = "OAC for the portfolio static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # North America and Europe only (cheapest)
  http_version        = "http2and3"      # HTTP/3 is free (F-58)

  # S3 REST endpoint over HTTPS with OAC (replaces the http-only website endpoint)
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-oac-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-oac-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # The REST endpoint returns 403 (no ListBucket) or 404 for missing keys.
  # Serve index.html instead, preserving the old website ErrorDocument behaviour.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default *.cloudfront.net certificate: minimum TLS stays TLSv1 (F-55, cost decision:
  # raising it requires a custom domain + ACM certificate)
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
