# ABOUTME: Terraform outputs for CI/CD configuration.
# ABOUTME: These values are needed as GitHub repository secrets.

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation in CI/CD)"
  value       = aws_cloudfront_distribution.this.id
}

output "s3_bucket_name" {
  description = "S3 bucket name (deployment target for built assets)"
  value       = aws_s3_bucket.this.id
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.arn
}

output "site_url" {
  description = "Live website URL"
  value       = "https://${var.domain_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.this.domain_name
}
