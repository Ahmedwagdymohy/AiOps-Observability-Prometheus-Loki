# SWR (Software Repository for Container) - Huawei's Container Registry
# This is where you'll push your Docker images

resource "huaweicloud_swr_organization" "aiops_org" {
  count = var.enable_swr ? 1 : 0
  
  name = replace(var.project_name, "-", "")  # SWR org names can't have dashes
}

# Create repository for aiops-processor
resource "huaweicloud_swr_repository" "aiops_processor" {
  count = var.enable_swr ? 1 : 0
  
  organization = huaweicloud_swr_organization.aiops_org[0].name
  name         = "aiops-processor"
  description  = "AIOps Processor Docker Image"
  category     = "linux"
  is_public    = false
}

# Output the registry URL
output "swr_registry_url" {
  value       = var.enable_swr ? "swr.${var.region}.myhuaweicloud.com" : null
  description = "SWR Registry URL"
}

output "swr_organization" {
  value       = var.enable_swr ? huaweicloud_swr_organization.aiops_org[0].name : null
  description = "SWR Organization Name"
}

output "aiops_image_url" {
  value       = var.enable_swr ? "swr.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.aiops_org[0].name}/aiops-processor:latest" : null
  description = "Full Docker image URL for AIOps Processor"
}

