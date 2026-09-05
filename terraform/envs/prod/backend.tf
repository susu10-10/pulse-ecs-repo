terraform {
  backend "s3" {
    bucket       = "pulse-ecs-tfstate-767397659229"
    key          = "pulse-ecs/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}