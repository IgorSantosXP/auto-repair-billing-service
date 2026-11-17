provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Service   = var.service
      ManagedBy = "terraform"
      Repo      = "auto-repair-billing-service"
    }
  }
}

# Shared platform (EKS cluster and the per-environment SNS topic).
data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = "auto-repair-tfstate-814623398856"
    key    = "infra-k8s/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  cluster_name = data.terraform_remote_state.platform.outputs.cluster_name
  topic_arns   = data.terraform_remote_state.platform.outputs.events_topic_arns

  vpc_id             = data.terraform_remote_state.platform.outputs.vpc_id
  vpc_cidr           = data.terraform_remote_state.platform.outputs.vpc_cidr
  private_subnet_ids = data.terraform_remote_state.platform.outputs.private_subnet_ids
}
