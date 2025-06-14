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

# For automated environments (Waypoint/TFC), set these environment variables in the UI:
# HCP_PROJECT_ID    = "your-hcp-project-id"
# HCP_CLIENT_ID     = "your-service-principal-client-id"
# HCP_CLIENT_SECRET = "your-service-principal-client-secret"

# VM Configuration
vm_count = 3       # Required: Number of VMs to create (no default value)
instance_type = "t3.micro"  # Required: EC2 instance type for all VMs (no default value)

# AWS Configuration
aws_region = "us-east-1"
```

### Example Usage

```hcl
module "vm_addon" {
  source = "./vm-addon"
  
  # HCP Configuration (same as networking module)
  waypoint_application = "my-app"
  # hcp_project_resource_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  
  # VM Configuration
  vm_count = 4              # Creates 4 identical VMs
  instance_type = "t3.micro"  # All VMs will use this instance type
  
  # Optional Configuration
  aws_region = "us-west-2"
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

The module creates a dynamic number of EC2 instances based on the `vm_count` variable:

### Instance Configuration
- **Name Pattern**: `{project_name}-{environment}-instance-{number}-{random_suffix}`
- **Instance Type**: All instances use the same type specified by `instance_type`
- **Subnet Distribution**: Round-robin across private subnets (or all subnets if no private subnets available)
- **Security Group**: Application security group from networking module
- **IAM Role**: Instance role from networking module
- **Tags**: Inherited from common tags plus instance-specific Name tag

### Subnet Distribution
- Instances are distributed across available private subnets in a round-robin fashion
- If no private subnets are available, falls back to all available subnets
- Distribution ensures even spread of instances across AZs

## Outputs

The module provides several useful outputs:

### Instance Information (Non-Sensitive)
```hcl
instance_ids                    # List of EC2 instance IDs
instance_private_ips           # Private IP addresses
public_ip_note                # Helper command for viewing public IPs
hcp_vault_secrets_connected   # Confirms HCP connection
```

### Sensitive Information
```hcl
instance_details              # Detailed instance information (sensitive)
instance_summary             # Instance distribution summary (sensitive)
key_pair_name               # SSH key pair name (sensitive)
private_key_pem            # Private key in PEM format (sensitive)
ssh_connection_helper      # SSH connection details (sensitive)
infrastructure_details    # Infrastructure details from HCP Vault Secrets (sensitive)
```

> **Note**: Sensitive outputs are marked as such to prevent accidental exposure of infrastructure details. Access these values using appropriate methods like `terraform output -json` or in your automation tools.

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
   - **Solution**: Configure HCP service principal credentials as environment variables: 
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
   - Set `HCP_CLIENT_ID` and `HCP_CLIENT_SECRET` as environment variables in your Terraform
   - These credentials enable non-interactive authentication 