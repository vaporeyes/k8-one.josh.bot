# ABOUTME: Core infrastructure for the k8-one blog: S3, CloudFront, ACM, Route 53, IAM.
# ABOUTME: Private S3 bucket accessed only via CloudFront OAC; GitHub Actions deploys via OIDC.

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_route53_zone" "this" {
  name         = var.route53_zone_name
  private_zone = false
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ---------------------------------------------------------------------------
# S3 bucket (private, versioned, no public access)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket = "${replace(var.domain_name, ".", "-")}-static-site"

  tags = {
    Name = "${var.domain_name} static site"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control (OAC)
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.domain_name}-oac"
  description                       = "OAC for ${var.domain_name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy: only CloudFront (via OAC) can read objects
data "aws_iam_policy_document" "s3_cloudfront" {
  statement {
    sid = "AllowCloudFrontOAC"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3_cloudfront.json
}

# ---------------------------------------------------------------------------
# ACM certificate (DNS-validated)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = var.domain_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ---------------------------------------------------------------------------
# CloudFront Function: rewrite URIs to index.html for clean URLs
# ---------------------------------------------------------------------------

resource "aws_cloudfront_function" "rewrite_uri" {
  name    = "${replace(var.domain_name, ".", "-")}-rewrite-uri"
  runtime = "cloudfront-js-2.0"
  comment = "Append index.html to directory-style URIs"
  publish = true

  code = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }
      return request;
    }
  EOF
}

# ---------------------------------------------------------------------------
# CloudFront distribution
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http3"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  aliases             = [var.domain_name]

  origin {
    origin_id                = "s3-${aws_s3_bucket.this.id}"
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.this.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_uri.arn
    }
  }

  # S3 returns 403 for missing keys; map to 404 page
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.this.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = var.domain_name
  }

  depends_on = [aws_acm_certificate_validation.this]
}

# ---------------------------------------------------------------------------
# Route 53 alias records -> CloudFront
# ---------------------------------------------------------------------------

resource "aws_route53_record" "a" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------------------------
# IAM role for GitHub Actions (OIDC)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-${replace(var.domain_name, ".", "-")}"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = {
    Name = "GitHub Actions deploy role for ${var.domain_name}"
  }
}

data "aws_iam_policy_document" "deploy_permissions" {
  statement {
    sid = "S3Deployment"

    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }

  statement {
    sid       = "CloudFrontInvalidation"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.this.arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "deployment-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy_permissions.json
}
