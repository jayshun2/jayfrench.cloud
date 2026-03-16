# resources.tf
# This file contains all non-networking resources


#------------------------------------------------------------------------
# S3 bucket configuration
#------------------------------------------------------------------------

# Public S3 Bucket for Website Hosting
resource "aws_s3_bucket" "dev_bucket" {
  bucket = "jayfrench.cloud"

  tags = {
    Name        = "main-bucket"
    Environment = "prod"
    Project     = "jayfrench.cloud"
  }
}

resource "aws_s3_bucket_website_configuration" "dev_bucket_website" {
  bucket = aws_s3_bucket.dev_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Allow Public Access to the Bucket
resource "aws_s3_bucket_public_access_block" "dev_bucket_block" {
  bucket = aws_s3_bucket.dev_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy to Allow Public Read Access to Objects
resource "aws_s3_bucket_policy" "dev_bucket_policy" {
  bucket = aws_s3_bucket.dev_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.dev_bucket.arn}/*"
      }
    ]
  })
  depends_on = [
    aws_s3_bucket_public_access_block.dev_bucket_block
  ]
}

# OAC Policy

resource "aws_s3_bucket_policy" "resume_site_policy" {
  bucket = aws_s3_bucket.dev_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.dev_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site_cdn.arn
          }
        }
      }
    ]
  })
}


#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------
# Cloudfront Configuration
#------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "site_oac" {
  name                              = "jfrench-cloudfront-oac"
  description                       = "Access control for CloudFront to reach S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site_cdn" {
  origin {
    domain_name = aws_s3_bucket.dev_bucket.bucket_regional_domain_name # this needs to match the bucket resource above "aws_s3_bucket.dev_bucket"
    origin_id   = "jayfrenchorigin"

    origin_access_control_id = aws_cloudfront_origin_access_control.site_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["jayfrench.cloud"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "jayfrenchorigin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = "arn:aws:acm:us-east-1:405634363712:certificate/2c99691a-d408-4edd-8bfb-be3c0869ad9e" # ARN is for jayfrench.cloud
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "CRC CloudFront"
  }
}

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------
# DynamoDB Configuration
#------------------------------------------------------------------------


#------------------------------------------------------------------------
# Lambda Configuration
#------------------------------------------------------------------------


#------------------------------------------------------------------------
# Route53 Configuration
#------------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name         = "jayfrench.cloud"
  private_zone = false
}

resource "aws_route53_record" "crc_site" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "jayfrench.cloud"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.site_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------