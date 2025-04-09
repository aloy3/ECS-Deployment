# Define Terraform settings for the configuration

terraform {
  required_providers {
    aws = {                                 # Declare the AWS provider
      source  = "hashicorp/aws"                  # Source location of the provider
      version = ">= 5.0"
    }
  }
}
