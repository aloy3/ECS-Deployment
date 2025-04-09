terraform {
  backend "s3" {        # Specify the backend configuration for Terraform state storage
    bucket = "terraform-state-bucket321"
    key    = "ecs-cluster/terraform.tfstate"      # The key (path) within the S3 bucket for storing the state file
    region = "us-east-1"
    encrypt = true        # Enable encryption for the Terraform state file in S3 for security
    use_lockfile = true      # Use a lockfile to prevent concurrent writes to the state file (safety mechanism)
  }

  required_providers {
    aws = {               # Define the provider required for interacting with AW
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"      # using us-east-1 as it's the cheapest region
}


# Call ECS module to deploy cluster
module "ecs_cluster" {
  source = "./cluster"         # The 'source' attribute points to the location of the module. In this case, it's a local directory './cluster' 
}


# call task module to deploy the service
module "nginx_app_service" {
  source = "./task"         # The source specifies the location of the module, in this case, it's a local directory './task'
  name = "nginx-web-app"          # Name of the ECS task/service that will be created
  image_repository = "594928134774.dkr.ecr.us-east-1.amazonaws.com/nginx-web-app"       # The Amazon ECR repository where the Docker image for the app is stored
  image_tag = "05c9e9020872eccde036280db34ac3f0409b5f71"        # The specific tag of the Docker image to deploy
  cluster_id = module.ecs_cluster.ecs_cluster_id        # ECS Cluster ID where the service will be deployed, coming from the 'ecs_cluster' module output
  vpc_id = "vpc-0b3b9216d3eb991fd"          # The VPC ID in which the ECS task and load balancer will operate
  task_subnets = [                          # List of subnets where the ECS tasks will run. Public subnets are used to avoid needing a NAT Gateway
    "subnet-0eb2e76eaef773b61",
    "subnet-0ced50f6f757b32f6"
  ]
  alb_subnets = [                           # List of subnets for the ALB. These should be public subnets so the ALB can be accessed externally.
    "subnet-0eb2e76eaef773b61",
    "subnet-0ced50f6f757b32f6"
  ]
}
