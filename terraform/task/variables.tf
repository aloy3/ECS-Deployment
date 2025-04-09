variable "name" {
  description = "App name"
  type = string
}

variable "image_tag" {
  description = "Web App Image tag from ECR"
  type = string
}

variable "image_repository" {
  description = "Web App Image URI from ECR"
  type = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type = string
}

variable "vpc_id" {
  description = "VPC ID"
  type = string
}

variable "task_subnets" {
  description = "Subnets to deploy tasks to"
  type = list(string)
}

variable "alb_subnets" {
  description = "Subnets to deploy tasks to"
  type = list(string)
}

