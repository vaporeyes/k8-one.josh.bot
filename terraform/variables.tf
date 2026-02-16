# ABOUTME: Input variables for the blog infrastructure.
# ABOUTME: Domain, region, GitHub repo, and CloudFront configuration.

variable "aws_region" {
  description = "AWS region for all resources (us-east-1 required for ACM + CloudFront)"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Custom domain for the blog (must have a Route 53 hosted zone for the parent domain)"
  type        = string
  default     = "k8-one.josh.bot"
}

variable "route53_zone_name" {
  description = "Route 53 hosted zone name (parent domain)"
  type        = string
  default     = "josh.bot"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format for OIDC trust policy"
  type        = string
  default     = "vaporeyes/k8-one.josh.bot"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (must be globally unique)"
  type        = string
  default     = "k8-one-terraform-state"
}

variable "geo_restriction_locations" {
  description = "ISO 3166-1 alpha-2 country codes allowed to access the CloudFront distribution"
  type        = list(string)
  default     = ["US", "CA", "GB", "DE", "FR", "AU", "NZ", "JP"]
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100 = US/EU, PriceClass_200 = +Asia, PriceClass_All = global)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "Must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}
