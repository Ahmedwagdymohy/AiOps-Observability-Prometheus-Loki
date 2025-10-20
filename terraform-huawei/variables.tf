# Huawei Cloud Access Credentials
variable "access_key" {
  description = "Huawei Cloud Access Key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Huawei Cloud Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Huawei Cloud Region"
  type        = string
  default     = "ap-southeast-1"  # Singapore region (same as API)
}

# Project Configuration
variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "Ai-Ops"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# CCE Cluster Configuration
variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.28"  # Use stable version
}

variable "cluster_flavor" {
  description = "CCE cluster flavor (cce.s1.small for cost saving)"
  type        = string
  default     = "cce.s1.small"
}

# Node Pool Configuration
variable "node_flavor" {
  description = "ECS flavor for worker nodes (small for cost saving)"
  type        = string
  default     = "c6.large.2"  # 2 vCPUs, 4GB RAM
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2  # Minimum for HA
}

variable "node_disk_size" {
  description = "System disk size in GB"
  type        = number
  default     = 50
}

# Container Registry
variable "enable_swr" {
  description = "Enable SWR (Software Repository for Container)"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "AIOps"
    ManagedBy   = "Terraform"
    Environment = "Prototype"
    Purpose     = "AI-Monitoring-Competition"
  }
}

