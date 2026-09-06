terraform {
  backend "s3" {
    bucket       = "permission-tfstate-767397659229"
    key          = "pulse-ecs/permissions/terraform.tfstate" # distinct from envs/prod's key on purpose
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
