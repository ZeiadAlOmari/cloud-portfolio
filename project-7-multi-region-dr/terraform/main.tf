data "aws_caller_identity" "current" {}

# Managed policy so every request reaches the origin: makes failover visible per request
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  primary_bucket   = "portfolio-dr-primary-${local.account_id}"
  secondary_bucket = "portfolio-dr-secondary-${local.account_id}"
}

# ---------------------------------------------------------------
# 1. Buckets: primary (us-east-1) and secondary (us-west-2)
# ---------------------------------------------------------------
resource "aws_s3_bucket" "primary" {
  bucket        = local.primary_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "secondary" {
  provider      = aws.secondary
  bucket        = local.secondary_bucket
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "secondary" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.secondary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is required on both sides for cross-region replication
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------
# 2. Cross-region replication: primary -> secondary
# ---------------------------------------------------------------
data "aws_iam_policy_document" "replication_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "replication" {
  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.primary.arn]
  }

  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.primary.arn}/*"]
  }

  statement {
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
    resources = ["${aws_s3_bucket.secondary.arn}/*"]
  }
}

resource "aws_iam_role" "replication" {
  name               = "portfolio-dr-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_trust.json
}

resource "aws_iam_role_policy" "replication" {
  name   = "portfolio-dr-replication"
  role   = aws_iam_role.replication.id
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.secondary,
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id       = "replicate-site-page"
    status   = "Enabled"
    priority = 1

    # Only the site page replicates. region.txt is deliberately left out so each
    # bucket keeps its own marker file, which shows which region answered a request.
    filter {
      prefix = "index.html"
    }

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD"
    }
  }
}

# ---------------------------------------------------------------
# 3. Content
# ---------------------------------------------------------------
# Created only after replication is configured, because S3 replicates new objects only
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.primary.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-EOT
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Multi-Region DR Demo</title></head>
    <body style="font-family:sans-serif;max-width:40rem;margin:3rem auto">
      <h1>Multi-Region DR Demo</h1>
      <p>This page is replicated from us-east-1 to us-west-2 and served through CloudFront with automatic origin failover.</p>
      <p>Open <a href="/region.txt">/region.txt</a> to see which region answered.</p>
    </body>
    </html>
  EOT

  depends_on = [aws_s3_bucket_replication_configuration.primary_to_secondary]
}

resource "aws_s3_object" "region_primary" {
  bucket       = aws_s3_bucket.primary.id
  key          = "region.txt"
  content_type = "text/plain"
  content      = "Served from PRIMARY region: us-east-1\n"
}

resource "aws_s3_object" "region_secondary" {
  provider     = aws.secondary
  bucket       = aws_s3_bucket.secondary.id
  key          = "region.txt"
  content_type = "text/plain"
  content      = "Served from SECONDARY region: us-west-2\n"
}

# ---------------------------------------------------------------
# 4. CloudFront with origin group (automatic failover)
# ---------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "dr" {
  name                              = "portfolio-dr-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "dr" {
  enabled             = true
  comment             = "Project 7 multi-region DR demo"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.primary.bucket_regional_domain_name
    origin_id                = "primary"
    origin_access_control_id = aws_cloudfront_origin_access_control.dr.id
  }

  origin {
    domain_name              = aws_s3_bucket.secondary.bucket_regional_domain_name
    origin_id                = "secondary"
    origin_access_control_id = aws_cloudfront_origin_access_control.dr.id
  }

  origin_group {
    origin_id = "dr-group"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "primary"
    }

    member {
      origin_id = "secondary"
    }
  }

  default_cache_behavior {
    target_origin_id       = "dr-group"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ---------------------------------------------------------------
# 5. Bucket policies: only this CloudFront distribution may read
# ---------------------------------------------------------------
data "aws_iam_policy_document" "primary" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.primary.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.dr.arn]
    }
  }

  # Failure injection: an explicit Deny overrides the Allow above, so CloudFront
  # gets a 403 from the primary origin and fails over to the secondary region
  dynamic "statement" {
    for_each = var.simulate_primary_outage ? [1] : []

    content {
      sid       = "SimulatedOutageDenyCloudFront"
      effect    = "Deny"
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.primary.arn}/*"]

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }
    }
  }
}

data "aws_iam_policy_document" "secondary" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.secondary.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.dr.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "primary" {
  bucket     = aws_s3_bucket.primary.id
  policy     = data.aws_iam_policy_document.primary.json
  depends_on = [aws_s3_bucket_public_access_block.primary]
}

resource "aws_s3_bucket_policy" "secondary" {
  provider   = aws.secondary
  bucket     = aws_s3_bucket.secondary.id
  policy     = data.aws_iam_policy_document.secondary.json
  depends_on = [aws_s3_bucket_public_access_block.secondary]
}
