---
title: "Terraform"
description: "Quick reference for infrastructure as code with Terraform and OpenTofu."
updatedDate: 2026-03-30
---

## Workflow

```bash
# Initialize (download providers, modules)
terraform init

# Re-init with backend migration
terraform init -migrate-state

# Upgrade provider versions
terraform init -upgrade

# Format files
terraform fmt
terraform fmt -recursive

# Validate config
terraform validate

# Plan changes
terraform plan
terraform plan -out=tfplan            # save plan
terraform plan -target=aws_s3_bucket.data  # specific resource

# Apply changes
terraform apply
terraform apply tfplan                # apply saved plan
terraform apply -auto-approve         # skip confirmation

# Destroy
terraform destroy
terraform destroy -target=aws_lambda_function.api
```

## State

```bash
# List resources in state
terraform state list

# Show resource details
terraform state show aws_s3_bucket.data

# Move/rename resource
terraform state mv aws_s3_bucket.old aws_s3_bucket.new

# Remove from state (keep real resource)
terraform state rm aws_s3_bucket.imported

# Import existing resource into state
terraform import aws_s3_bucket.data my-bucket-name

# Pull remote state
terraform state pull > state.json

# Force unlock (stuck lock)
terraform force-unlock LOCK_ID

# Refresh state from real infrastructure
terraform refresh
```

## Variables

```hcl
# Variable declaration
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "tags" {
  type = map(string)
  default = {
    env = "prod"
  }
}

variable "instance_count" {
  type = number
  validation {
    condition     = var.instance_count > 0
    error_message = "Must be positive."
  }
}

# Sensitive variable
variable "db_password" {
  type      = string
  sensitive = true
}
```

```bash
# Pass variables
terraform apply -var="region=us-west-2"
terraform apply -var-file="prod.tfvars"

# Environment variables
export TF_VAR_region="us-west-2"
```

## Outputs

```hcl
output "bucket_arn" {
  value       = aws_s3_bucket.data.arn
  description = "S3 bucket ARN"
}

output "db_password" {
  value     = aws_db_instance.main.password
  sensitive = true
}
```

```bash
# View outputs
terraform output
terraform output bucket_arn
terraform output -json
```

## Locals

```hcl
locals {
  env    = terraform.workspace
  prefix = "${var.project}-${local.env}"
  common_tags = {
    project     = var.project
    environment = local.env
    managed_by  = "terraform"
  }
}

resource "aws_s3_bucket" "data" {
  bucket = "${local.prefix}-data"
  tags   = local.common_tags
}
```

## Data Sources

```hcl
# Look up existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_ssm_parameter" "api_key" {
  name = "/myapp/api-key"
}

# Use in resources
resource "aws_instance" "web" {
  ami = data.aws_ami.amazon_linux.id
}
```

## Resource Patterns

```hcl
# Count
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.azs[count.index]
}

# for_each (preferred over count for named resources)
resource "aws_iam_user" "users" {
  for_each = toset(var.user_names)
  name     = each.value
}

# Dynamic blocks
resource "aws_security_group" "web" {
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidrs
    }
  }
}

# Lifecycle
resource "aws_instance" "web" {
  # ...
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
    ignore_changes        = [tags]
  }
}

# Depends on (explicit)
resource "aws_instance" "web" {
  depends_on = [aws_iam_role_policy.web]
}
```

## Expressions

```hcl
# Conditional
instance_type = var.env == "prod" ? "t3.large" : "t3.micro"

# Splat
subnet_ids = aws_subnet.private[*].id

# for expression
upper_names = [for n in var.names : upper(n)]
name_map    = { for n in var.names : n => upper(n) }

# Filtering
prod_instances = [for i in var.instances : i if i.env == "prod"]

# String interpolation
name = "${var.project}-${var.env}-api"

# Heredoc
policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": []
  }
EOT

# Type conversion
tolist, toset, tomap, tonumber, tostring

# Null coalescing
value = var.custom_name != null ? var.custom_name : "default"
# or with coalesce
value = coalesce(var.custom_name, "default")
```

## Built-in Functions

```hcl
# String
join(", ", ["a", "b", "c"])
split(",", "a,b,c")
replace("hello", "l", "r")
trimspace("  hello  ")
format("Hello, %s!", var.name)
regex("^([a-z]+)", var.input)

# Collection
length(var.list)
contains(var.list, "value")
lookup(var.map, "key", "default")
merge(var.map1, var.map2)
flatten([["a"], ["b", "c"]])
keys(var.map)
values(var.map)
zipmap(keys, values)
distinct(var.list)

# Numeric
min(1, 2, 3)
max(1, 2, 3)
ceil(4.2)
floor(4.8)

# Encoding
jsonencode(var.obj)
jsondecode(var.json_string)
base64encode("hello")
base64decode("aGVsbG8=")

# Filesystem
file("${path.module}/script.sh")
filebase64("${path.module}/cert.pem")
templatefile("${path.module}/userdata.tftpl", { name = "web" })

# Networking
cidrsubnet("10.0.0.0/16", 8, 1)    # 10.0.1.0/24

# Crypto
sha256("content")
```

## Modules

```hcl
# Use a module
module "vpc" {
  source  = "./modules/vpc"
  # or from registry:
  # source  = "terraform-aws-modules/vpc/aws"
  # version = "~> 5.0"

  cidr = "10.0.0.0/16"
  azs  = ["us-east-1a", "us-east-1b"]
}

# Reference module output
resource "aws_instance" "web" {
  subnet_id = module.vpc.private_subnet_ids[0]
}
```

## Backend Configuration

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
```

## Workspaces

```bash
# List workspaces
terraform workspace list

# Create workspace
terraform workspace new staging

# Switch workspace
terraform workspace select prod

# Current workspace
terraform workspace show

# Delete workspace
terraform workspace delete staging
```

## Useful Patterns

```bash
# Show what would be destroyed
terraform plan -destroy

# Target specific resource
terraform apply -target=module.vpc

# Replace a specific resource
terraform apply -replace=aws_instance.web

# Generate import blocks (1.5+)
terraform plan -generate-config-out=generated.tf

# Console (interactive expression eval)
terraform console
> length(var.subnets)
> cidrsubnet("10.0.0.0/16", 8, 3)

# Graph (dependency visualization)
terraform graph | dot -Tpng > graph.png

# Taint (force recreation) - deprecated, use -replace
terraform taint aws_instance.web
```
