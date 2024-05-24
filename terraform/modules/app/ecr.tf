module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.2.1"

  for_each = var.apps

  repository_name = "${var.company}_${each.key}"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        action = {
          type = "expire"
        }
        description  = "lifecycle"
        rulePriority = 1
        selection = {
          countNumber = 5
          countType   = "imageCountMoreThan"
          tagStatus   = "untagged"
        }
      }
    ]
  })

  tags = local.tags
}