# HCP and Waypoint Configuration Variables
variable "waypoint_application" {
  description = "Waypoint application name"
  type        = string
}

# variable "hcp_project_resource_id" {
#   description = "HCP project resource ID for the user"
#   type        = string
# }

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Compute-specific variables
variable "instance_type" {
  description = "EC2 instance type to use for all VMs. This is a required variable with no default value."
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "assign_elastic_ips" {
  description = "Whether to assign Elastic IPs to instances"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = false
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for CloudWatch alarms"
  type        = number
  default     = 80
}

# VM Count Variable
variable "vm_count" {
  description = "Number of VMs to create. This is a required variable with no default value."
  type        = number

  validation {
    condition     = var.vm_count > 0
    error_message = "The vm_count value must be greater than 0."
  }
}

# Old HCP Authentication (if not using environment variables)
# This is not working.

# variable "hcp_client_id" {
#  description = "HCP service principal client ID (optional if using env vars)"
#   type        = string
#   sensitive   = false
# }

# variable "hcp_client_secret" {
#   description = "HCP service principal client secret (optional if using env vars)"
#   type        = string
#   sensitive   = true
# }