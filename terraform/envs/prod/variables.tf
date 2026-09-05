variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "pulse-ecs"
}

variable "environment" {
  description = "The environment to deploy to"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "pulse-ecs-AWS"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "domain_name" {
  description = "The custom domain name for the portfolio"
  type        = string
  default     = "suworks.me"
}

variable "owner_id" {
  description = <<-EOT
    Numeric GitHub owner ID. Confirm with:
      curl -s https://api.github.com/users/<owner> | grep '"id"'
  EOT
  type        = string
}

variable "repo" {
  description = "Repo name only, no owner prefix (e.g. \"pulse-ecs-repo\")."
  type        = string
  default     = "pulse-ecs-repo"
}

variable "repo_id" {
  description = <<-EOT
    Numeric GitHub repo ID. Confirm with:
      curl -s https://api.github.com/repos/<owner>/<repo> | grep '"id"'
    (take the FIRST "id" field in the response, that's the repo's own id)
  EOT
  type        = string
}

variable "owner" {
  description = "GitHub org or username that owns the repo (e.g. \"susu10-10\")."
  type        = string
  default     = "susu10-10"
}
