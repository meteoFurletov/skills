terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state is fine for a single personal box. Move to an S3 backend if
  # more than one machine will run `apply`, or if losing the laptop would mean
  # losing the ability to manage (or destroy) this instance.
}

provider "aws" {
  region = var.aws_region

  # No credentials block on purpose: the provider uses the standard AWS SDK
  # chain — env vars first (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY), then
  # ~/.aws/credentials. Run `aws configure` once and both Terraform and the
  # `aws` CLI pick the same credentials up.
}
