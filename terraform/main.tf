terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "clouddevops-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "clouddevops-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source               = "./modules/network"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "server" {
  source           = "./modules/server"
  project_name     = var.project_name
  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_ids[0]
  key_name         = var.key_name
}

module "eks" {
  source             = "./modules/eks"
  project_name       = var.project_name
  private_subnet_ids = module.network.private_subnet_ids
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}