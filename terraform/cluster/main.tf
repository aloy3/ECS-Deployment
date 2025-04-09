# Define an ECS cluster resource

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

# Output the ECS Cluster ID after creation

output "ecs_cluster_id" {
  value = aws_ecs_cluster.this.id
}
