# Terraform AWS Machine Add-On - VM Module

This Terraform module creates EC2 instances that integrate seamlessly with the networking infrastructure created by the `terraform-aws-tenantdemo` module. It uses **HCP Vault Secrets** to automatically retrieve networking details and provision VMs in the correct network configuration.

## Overview

This module acts as a **Waypoint Add-On** that:
- Consumes networking infrastructure details from HCP Vault Secrets
- Creates EC2 instances in the appropriate subnets and security groups
- Automatically configures instances with the correct IAM roles and tags
- Generates SSH key pairs for secure access

## HCP Vault Secrets Integration

The module automatically retrieves the following secrets from HCP Vault Secrets:

### Network Configuration
- `vpc_id`: VPC where instances will be created
- `vpc_cidr_block`: Network CIDR block
- `private_subnet_ids`: Private subnet IDs for backend instances
- `public_subnet_ids`: Public subnet IDs for frontend instances
- `all_subnet_ids`: All available subnet IDs

### Security and Access
- `app_security_group_id`: Pre-configured security group for applications
- `instance_role_name`: IAM role for EC2 instances

### Environment Details
- `environment`: Environment name (dev, prod, etc.)
- `project_name`: Project identifier
- `common_tags`: Standardized resource tags

## Usage

### Required Variables

```hcl
# HCP Configuration (must match networking module)
waypoint_application = "your-waypoint-app-name"
ddr_user_hcp_project_resource_id = "your-hcp-project-id"

# HCP Authentication (for Terraform Cloud/Enterprise)
hcp_client_id = "your-hcp-service-principal-client-id"
hcp_client_secret = "your-hcp-service-principal-client-secret"

# AWS Configuration
aws_region = "us-east-1"
```

### Example Usage

```hcl
module "vm_addon" {
  source = "./vm-addon"
  
  # HCP Configuration (same as networking module)
  waypoint_application = "my-app"
  ddr_user_hcp_project_resource_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  
  # VM Configuration
  aws_region = "us-west-2"
  instance_types = {
    flavor1 = "t3.micro"
    flavor2 = "t3.small"
  }
  root_volume_size = 20
  assign_elastic_ips = true
  enable_monitoring = false
}
```

### Customizable Options

```hcl
# Instance Types
instance_types = {
  flavor1 = "t3.micro"    # Instance 1 type
  flavor2 = "t3.small"    # Instance 2 type
}

# Storage Configuration
root_volume_size = 20      # Root volume size in GB

# Network Configuration
assign_elastic_ips = true  # Assign public IPs

# Monitoring
enable_monitoring = false  # Detailed CloudWatch monitoring
cpu_alarm_threshold = 80   # CPU alarm threshold
```

## Deployment Flow

1. **Deploy Networking Module**: First deploy the `terraform-aws-tenantdemo` module
2. **Automatic Secret Population**: Networking details are automatically stored in HCP Vault Secrets
3. **Deploy VM Add-On**: This module reads the secrets and creates VMs in the correct network
4. **Immediate Connectivity**: VMs are created with proper security groups and IAM roles

## Instance Configuration

The module creates **2 EC2 instances** with the following configuration:

### Instance 1
- **Name**: `{project_name}-{environment}-instance-1`
- **Type**: Configurable via `instance_types.flavor1`
- **Subnet**: First private subnet (or first available subnet)
- **Security Group**: Application security group from networking module
- **IAM Role**: Instance role from networking module

### Instance 2
- **Name**: `{project_name}-{environment}-instance-2`
- **Type**: Configurable via `instance_types.flavor2`
- **Subnet**: Second private subnet (or second available subnet)
- **Security Group**: Application security group from networking module
- **IAM Role**: Instance role from networking module

## Outputs

The module provides several useful outputs:

```hcl
# Instance Information
instance_ids                    # List of EC2 instance IDs
instance_private_ips           # Private IP addresses
instance_details               # Structured instance information

# Access Information
key_pair_name                  # SSH key pair name
private_key_pem                # Private key (sensitive)
ssh_connection_helper          # SSH connection guidance

# Integration Status
hcp_vault_secrets_connected    # Confirms HCP connection
infrastructure_details        # Retrieved infrastructure info
```

## SSH Access

The module automatically generates an SSH key pair. To connect to instances:

1. **Retrieve the private key**:
   ```bash
   terraform output -raw private_key_pem > instance-key.pem
   chmod 400 instance-key.pem
   ```

2. **Connect via SSH**:
   ```bash
   ssh -i instance-key.pem ec2-user@<instance-public-ip>
   ```

3. **Or use SSM Session Manager** (if in private subnets):
   ```bash
   aws ssm start-session --target <instance-id>
   ```

## Prerequisites

1. **Networking module deployed**: The `terraform-aws-tenantdemo` module must be deployed first
2. **HCP Vault Secrets populated**: Networking details must be available in HCP Vault Secrets
3. **AWS credentials**: Configured for the target AWS account
4. **HCP Service Principal**: Created and configured with proper permissions
5. **HCP credentials**: Service principal credentials configured as Terraform variables

## Integration with Waypoint

This module is designed to work as a **Waypoint Add-On**:

1. **Template Phase**: Deploy networking infrastructure via Waypoint
2. **Add-On Phase**: This module consumes the secrets and creates VMs
3. **Automatic Scaling**: Can be used multiple times for different workloads
4. **Environment Consistency**: All VMs inherit consistent network configuration

## Security Features

- **Private Key Management**: SSH keys generated and managed securely
- **IAM Integration**: Instances use predefined IAM roles with least privilege
- **Security Groups**: Pre-configured application security groups
- **Network Isolation**: Instances deployed in appropriate subnet tiers
- **Secrets Management**: All sensitive data handled via HCP Vault Secrets

## Module Dependencies

This module depends on:
- `app.terraform.io/hashicorp-ignacio-test/ec2-instances/aws` - Core EC2 instance module
- Networking infrastructure created by `terraform-aws-tenantdemo`
- HCP Vault Secrets containing networking details

## Troubleshooting

### Common Issues

1. **"Secret not found"**: Ensure the networking module is deployed first
2. **"Invalid subnet"**: Check that subnets exist in the specified region
3. **"Access denied"**: Verify HCP project permissions
4. **"Instance launch failed"**: Check AWS service quotas and limits
5. **"unable to create HCP api client: no valid credentials available"**: This occurs when HCP authentication fails in automated environments
   - **Solution**: Configure HCP service principal credentials (`hcp_client_id` and `hcp_client_secret`)
   - **Cause**: The HCP provider is trying to use interactive authentication (browser) in a headless environment
   - **Prevention**: Always use service principal authentication for CI/CD pipelines and Terraform Cloud

### HCP Service Principal Setup

For automated deployments (Terraform Cloud/Enterprise/Waypoint), you need to create an HCP service principal:

1. **Create Service Principal**:
   - Go to HCP Console → Access Control (IAM) → Service Principals
   - Click "Create service principal"
   - Name it (e.g., "terraform-vm-addon-sp")
   - Save the Client ID and Client Secret

2. **Assign Permissions**:
   - Assign the service principal to your HCP project
   - Grant `Contributor` or `Viewer` role (minimum required for Vault Secrets access)

3. **Configure Variables**:
   - Set `hcp_client_id` and `hcp_client_secret` as sensitive variables in your Terraform workspace
   - These credentials enable non-interactive authentication 