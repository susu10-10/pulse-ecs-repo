module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0.0"

  repository_name = "${var.project_name}/pulseservice"

  repository_image_tag_mutability = "MUTABLE"

  repository_image_scan_on_push = true
  repository_force_delete       = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 2 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 2
        }
        action = { type = "expire" }
      }
    ]
  })

  tags = var.tags
}
