output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = module.ec2_instances.instance_ids
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value       = module.ec2_instances.private_ips
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.main.key_name
  sensitive   = true
}

output "private_key_pem" {
  description = "Private key in PEM format (sensitive)"
  value       = tls_private_key.main.private_key_pem
  sensitive   = true
}

output "instance_details" {
  description = "Detailed instance information"
  value = {
    for idx, id in module.ec2_instances.instance_ids :
    "${local.project_name}-${local.environment}-instance-${idx + 1}-${random_string.identifier.result}" => {
      instance_id   = id
      private_ip    = module.ec2_instances.private_ips[idx]
      instance_type = var.instance_type
      subnet_id     = length(local.private_subnet_ids) > idx % length(local.private_subnet_ids) ? local.private_subnet_ids[idx % length(local.private_subnet_ids)] : local.all_subnet_ids[idx % length(local.all_subnet_ids)]
    }
  }
  sensitive = true
}

output "instance_summary" {
  description = "Summary of instance distribution"
  value = {
    total_instances = var.vm_count
    instance_type   = var.instance_type
    subnets_used    = length(local.private_subnet_ids) > 0 ? "private_subnets" : "all_subnets"
  }
  sensitive = true
}

output "public_ip_note" {
  description = "Information about accessing public IPs"
  value       = "To view public IPs, use: aws ec2 describe-instances --instance-ids ${join(" ", module.ec2_instances.instance_ids)} --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' --output table"
}

output "ssh_connection_helper" {
  description = "Helper information for SSH connections"
  value = {
    key_location = "Save the private key to a file and chmod 400"
    username     = "ec2-user (for Amazon Linux)"
    connect_via  = var.assign_elastic_ips ? "Use public IP from AWS Console or CLI" : "Use SSM Session Manager or bastion host"
    instances    = [for idx in range(var.vm_count) : "${local.project_name}-${local.environment}-instance-${idx + 1}-${random_string.identifier.result}"]
  }
  sensitive = true
}

# Debug output to verify HCP Vault Secrets connection
output "hcp_vault_secrets_connected" {
  description = "Confirms connection to HCP Vault Secrets"
  value       = "Connected to HCP Vault Secrets app: ${var.waypoint_application}"
}

# Infrastructure details retrieved from secrets
output "infrastructure_details" {
  description = "Infrastructure details retrieved from HCP Vault Secrets"
  value = {
    vpc_id               = local.vpc_id
    environment          = local.environment
    project_name         = local.project_name
    subnet_count         = length(local.all_subnet_ids)
    private_subnet_count = length(local.private_subnet_ids)
  }
  sensitive = true
}

