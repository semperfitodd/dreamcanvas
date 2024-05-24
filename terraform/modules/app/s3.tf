data "aws_iam_policy_document" "app" {
  statement {
    effect  = "Allow"
    actions = ["s3:Get*", "s3:List*"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    resources = [
      module.app_s3_bucket.s3_bucket_arn,
      "${module.app_s3_bucket.s3_bucket_arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "site" {
  statement {
    effect = "Allow"
    principals {
      identifiers = module.cdn.cloudfront_origin_access_identity_iam_arns
      type        = "AWS"
    }
    actions   = ["s3:GetObject"]
    resources = ["${module.site_s3_bucket.s3_bucket_arn}/*"]
  }
}

locals {
  mime_types = {
    "css"  = "text/css"
    "html" = "text/html"
    "ico"  = "image/ico"
    "jpg"  = "image/jpeg"
    "js"   = "application/javascript"
    "json" = "application/json"
    "map"  = "application/octet-stream"
    "png"  = "image/png"
    "svg"  = "image/svg+xml"
    "txt"  = "text/plain"
  }
}

module "app_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1.2"

  bucket = "${var.company}-${var.environment}-app-${random_string.this.result}"

  attach_public_policy = true
  attach_policy        = true
  policy               = data.aws_iam_policy_document.app.json

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  expected_bucket_owner = data.aws_caller_identity.current.account_id

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [{
    id      = "expire-objects"
    enabled = true

    expiration = {
      days = 1
    }
  }]

  tags = local.tags
}

module "site_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1.2"

  bucket = local.site_domain

  attach_public_policy = true
  attach_policy        = true
  policy               = data.aws_iam_policy_document.site.json

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  expected_bucket_owner = data.aws_caller_identity.current.account_id

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_s3_object" "website-object" {
  for_each = fileset(var.site_directory, "**/*")

  bucket       = module.site_s3_bucket.s3_bucket_id
  key          = each.value
  source       = "${var.site_directory}/${each.value}"
  etag         = filemd5("${var.site_directory}/${each.value}")
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1])

  tags = local.tags
}

resource "random_string" "this" {
  length = 4

  lower   = true
  numeric = true
  special = false
  upper   = false
}
