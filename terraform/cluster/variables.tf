# Declare a variable name for cluster

variable "cluster_name" {
  description = "ECS cluster"
  type = string
  default = "main"
}
