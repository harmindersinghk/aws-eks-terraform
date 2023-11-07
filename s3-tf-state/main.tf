terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.47"
    }
  }
}


variable "bucket_name" {
    type = string
    description = "Provide the name to give an S3 bucket for Terraform to deploy."
}

resource "aws_s3_bucket" "tfstate_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "tfstatebucket"
  }
}