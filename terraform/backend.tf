# ABOUTME: S3 backend for Terraform remote state storage.
# ABOUTME: Update bucket and dynamodb_table to match your existing state infrastructure.

terraform {
  backend "s3" {
    use_lockfile = true
  }
}
