# Cluster Information
output "cluster_id" {
  value       = huaweicloud_cce_cluster.aiops_cluster.id
  description = "CCE Cluster ID"
}

output "cluster_name" {
  value       = huaweicloud_cce_cluster.aiops_cluster.name
  description = "CCE Cluster Name"
}

output "cluster_status" {
  value       = huaweicloud_cce_cluster.aiops_cluster.status
  description = "CCE Cluster Status"
}

output "cluster_version" {
  value       = huaweicloud_cce_cluster.aiops_cluster.cluster_version
  description = "Kubernetes Version"
}

output "cluster_endpoint" {
  value       = "https://${huaweicloud_vpc_eip.cluster_eip.address}:6443"
  description = "Kubernetes API Server Endpoint"
  sensitive   = false
}

output "cluster_eip" {
  value       = huaweicloud_vpc_eip.cluster_eip.address
  description = "Cluster Elastic IP"
}

# VPC Information
output "vpc_id" {
  value       = huaweicloud_vpc.aiops_vpc.id
  description = "VPC ID"
}

output "subnet_id" {
  value       = huaweicloud_vpc_subnet.aiops_subnet.id
  description = "Subnet ID"
}

# Node Pool Information
output "node_pool_id" {
  value       = huaweicloud_cce_node_pool.aiops_node_pool.id
  description = "Node Pool ID"
}

output "node_count" {
  value       = huaweicloud_cce_node_pool.aiops_node_pool.initial_node_count
  description = "Number of Worker Nodes"
}

output "node_flavor" {
  value       = var.node_flavor
  description = "Node Instance Flavor"
}

# Kubeconfig Command
output "kubeconfig_command" {
  value       = "Run this command to get kubeconfig:\nhcloud cce cluster download-certificates --region ${var.region} --cluster-id ${huaweicloud_cce_cluster.aiops_cluster.id}"
  description = "Command to download kubeconfig"
}

# Quick Access Commands
output "quick_access" {
  value = <<-EOT
  
  ================================================
  Cluster Access Information
  ================================================
  
  Cluster Name: ${huaweicloud_cce_cluster.aiops_cluster.name}
  Cluster ID: ${huaweicloud_cce_cluster.aiops_cluster.id}
  Kubernetes Version: ${var.cluster_version}
  Region: ${var.region}
  
  Cluster Endpoint: https://${huaweicloud_vpc_eip.cluster_eip.address}:6443
  
  ================================================
  Next Steps:
  ================================================
  
  1. Download kubeconfig:
     Go to Huawei Cloud Console -> CCE -> Clusters
     Click "${huaweicloud_cce_cluster.aiops_cluster.name}" -> Access -> Download kubeconfig
     
     Or use CLI:
     hcloud cce cluster download-certificates --region ${var.region} --cluster-id ${huaweicloud_cce_cluster.aiops_cluster.id}
  
  2. Set kubeconfig:
     export KUBECONFIG=/path/to/downloaded/kubeconfig.json
     
  3. Verify connection:
     kubectl cluster-info
     kubectl get nodes
  
  4. Build and push Docker image:
     docker build -t swr.${var.region}.myhuaweicloud.com/${var.enable_swr ? huaweicloud_swr_organization.aiops_org[0].name : "ORG"}/aiops-processor:latest -f kubernetes/Dockerfile .
     docker login -u ${var.region}@<your-username> swr.${var.region}.myhuaweicloud.com
     docker push swr.${var.region}.myhuaweicloud.com/${var.enable_swr ? huaweicloud_swr_organization.aiops_org[0].name : "ORG"}/aiops-processor:latest
  
  5. Deploy to cluster:
     cd kubernetes
     kubectl apply -f namespace.yaml
     kubectl apply -f prometheus/
     kubectl apply -f alertmanager/
     kubectl apply -f loki/
     kubectl apply -f promtail/
     kubectl apply -f grafana/
     kubectl apply -f aiops-processor/
     kubectl apply -f demo-apps/
  
  6. Access services (use NodePort or LoadBalancer):
     kubectl get svc -n monitoring
     kubectl get svc -n demo-apps
  
  ================================================
  Cost Estimation (Monthly):
  ================================================
  - CCE Cluster (small): ~$30
  - Worker Nodes (2x c6.large.2): ~$60
  - EIP + Bandwidth (5Mbps): ~$10
  - Storage (SSD): ~$15
  - SWR (Container Registry): Free
  
  Total: ~$115/month
  
  ================================================
  
  EOT
  description = "Quick access information and next steps"
}

# Resource Summary
output "resource_summary" {
  value = {
    cluster = {
      name    = huaweicloud_cce_cluster.aiops_cluster.name
      id      = huaweicloud_cce_cluster.aiops_cluster.id
      version = var.cluster_version
      flavor  = var.cluster_flavor
    }
    nodes = {
      count  = var.node_count
      flavor = var.node_flavor
      os     = "EulerOS 2.9"
    }
    network = {
      vpc_cidr    = var.vpc_cidr
      subnet_cidr = var.subnet_cidr
      eip         = huaweicloud_vpc_eip.cluster_eip.address
    }
    registry = {
      enabled = var.enable_swr
      url     = var.enable_swr ? "swr.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.aiops_org[0].name}" : null
    }
  }
  description = "Summary of created resources"
}

