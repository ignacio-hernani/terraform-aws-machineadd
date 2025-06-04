terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.99.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.104.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# HCP Provider Configuration
provider "hcp" {
  project_id = var.ddr_user_hcp_project_resource_id
}

# Data sources to fetch infrastructure details from HCP Vault Secrets
locals {
  all_secrets = [
    "vpc_id",
    "vpc_cidr_block",
    "private_subnet_ids",
    "public_subnet_ids",
    "all_subnet_ids",
    "app_security_group_id",
    "instance_role_name",
    "common_tags",
    "environment",
    "project_name"
  ]
}

data "hcp_vault_secrets_secret" "this" {
  for_each    = toset(local.all_secrets)
  app_name    = var.waypoint_application
  secret_name = each.key
}

# Local values to parse and use the infrastructure secrets
locals {
  # Parse infrastructure outputs from HCP Vault Secrets
  vpc_id                = data.hcp_vault_secrets_secret.this["vpc_id"].secret_value
  vpc_cidr_block        = data.hcp_vault_secrets_secret.this["vpc_cidr_block"].secret_value
  private_subnet_ids    = split(",", data.hcp_vault_secrets_secret.this["private_subnet_ids"].secret_value)
  public_subnet_ids     = split(",", data.hcp_vault_secrets_secret.this["public_subnet_ids"].secret_value)
  all_subnet_ids        = split(",", data.hcp_vault_secrets_secret.this["all_subnet_ids"].secret_value)
  app_security_group_id = data.hcp_vault_secrets_secret.this["app_security_group_id"].secret_value
  instance_role_name    = data.hcp_vault_secrets_secret.this["instance_role_name"].secret_value
  common_tags           = jsondecode(data.hcp_vault_secrets_secret.this["common_tags"].secret_value)
  environment           = data.hcp_vault_secrets_secret.this["environment"].secret_value
  project_name          = data.hcp_vault_secrets_secret.this["project_name"].secret_value
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

# Create key pair
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${local.project_name}-${local.environment}-keypair"
  public_key = tls_private_key.main.public_key_openssh

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-keypair"
    }
  )
}

# EC2 Instances Module
module "ec2_instances" {
  source  = "app.terraform.io/hashicorp-ignacio-test/ec2-instances/aws"
  version = "~> 1.0"

  environment  = local.environment
  project_name = local.project_name

  instances = [
    {
      name               = "${local.project_name}-${local.environment}-instance-1"
      instance_type      = var.instance_types["flavor1"]
      subnet_id          = length(local.private_subnet_ids) > 0 ? local.private_subnet_ids[0] : local.all_subnet_ids[0]
      security_group_ids = [local.app_security_group_id]
      iam_role_name      = local.instance_role_name
      user_data_file     = null
      tags               = merge(local.common_tags, { Name = "${local.project_name}-${local.environment}-instance-1" })
    },
    {
      name               = "${local.project_name}-${local.environment}-instance-2"
      instance_type      = var.instance_types["flavor2"]
      subnet_id          = length(local.private_subnet_ids) > 1 ? local.private_subnet_ids[1] : (length(local.all_subnet_ids) > 1 ? local.all_subnet_ids[1] : local.all_subnet_ids[0])
      security_group_ids = [local.app_security_group_id]
      iam_role_name      = local.instance_role_name
      user_data_file     = null
      tags               = merge(local.common_tags, { Name = "${local.project_name}-${local.environment}-instance-2" })
    }
  ]

  ami_id                    = data.aws_ami.amazon_linux.id
  key_name                  = aws_key_pair.main.key_name
  root_volume_size          = var.root_volume_size
  assign_elastic_ips        = var.assign_elastic_ips
  elastic_ip_allocation_ids = []
  create_dns_records        = false
  route53_zone_id           = null
  route53_zone_name         = "${local.project_name}-${local.environment}.internal"
  enable_monitoring         = var.enable_monitoring
  cpu_alarm_threshold       = var.cpu_alarm_threshold
  alarm_actions             = []
  create_instance_profiles  = true
  additional_volumes        = []
  kms_key_id                = null

  depends_on = [
    aws_key_pair.main
  ]
}
