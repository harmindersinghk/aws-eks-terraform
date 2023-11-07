variable "bucket_name" {
    type = string
    description = "Provide the name to give an S3 bucket for Terraform to deploy."
    default = "test1-2023-1-12-78"
}

resource "aws_s3_bucket" "tfstate_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "tfstatebucket"
  }
}