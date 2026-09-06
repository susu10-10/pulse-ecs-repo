variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "pulse-ecs"
}

variable "owner" {
  type    = string
  default = "susu10-10"
}

variable "owner_id" {
  type = string
}

variable "repo" {
  type    = string
  default = "pulse-ecs-repo"
}

variable "repo_id" {
  type = string
}
