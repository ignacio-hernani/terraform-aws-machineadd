# HCP and Waypoint Configuration Variables
variable "waypoint_application" {
  description = "Waypoint application name"
  type        = string
}

variable "ddr_user_hcp_project_resource_id" {
  description = "HCP project resource ID for the user"
  type        = string
}

# Old HCP Authentication (if not using environment variables)
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


variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Compute-specific variables
variable "instance_types" {
  description = "Instance types for different flavors"
  type        = map(string)
  default = {
    flavor1 = "t3.micro"
    flavor2 = "t3.small"
  }
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
