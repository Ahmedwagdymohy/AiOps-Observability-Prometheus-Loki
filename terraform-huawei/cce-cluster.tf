# Create CCE (Cloud Container Engine) Cluster
resource "huaweicloud_cce_cluster" "aiops_cluster" {
  name                   = "${var.project_name}-cluster"
  flavor_id              = var.cluster_flavor
  vpc_id                 = huaweicloud_vpc.aiops_vpc.id
  subnet_id              = huaweicloud_vpc_subnet.aiops_subnet.id
  cluster_version        = var.cluster_version
  container_network_type = "overlay_l2"
  
  # Authentication mode
  authentication_mode = "rbac"
  
  # Cluster type: VirtualMachine (cheaper than BareMetal)
  cluster_type = "VirtualMachine"
  
  # Billing mode: pay-per-use for prototype
  billing_mode = 0
  
  # Enable EIP for external access
  eip = huaweicloud_vpc_eip.cluster_eip.address
  
  # Tags
  tags = merge(var.tags, {
    Name = "${var.project_name}-cluster"
  })
}

# Create Elastic IP for cluster access
resource "huaweicloud_vpc_eip" "cluster_eip" {
  publicip {
    type = "5_bgp"
  }
  
  bandwidth {
    name        = "${var.project_name}-cluster-bandwidth"
    size        = 5  # 5 Mbps (minimum)
    share_type  = "PER"
    charge_mode = "traffic"  # Pay per traffic (cheaper)
  }
  
  tags = var.tags
}

# Create Node Pool
resource "huaweicloud_cce_node_pool" "aiops_node_pool" {
  cluster_id         = huaweicloud_cce_cluster.aiops_cluster.id
  name              = "${var.project_name}-node-pool"
  os                = "EulerOS 2.9"
  flavor_id         = var.node_flavor
  availability_zone = data.huaweicloud_availability_zones.available.names[0]
  
  # Initial node count
  initial_node_count = var.node_count
  
  # Auto-scaling (disabled for cost saving)
  scall_enable             = false
  min_node_count           = var.node_count
  max_node_count           = var.node_count
  scale_down_cooldown_time = 100
  priority                 = 1
  
  # Root volume
  root_volume {
    size       = var.node_disk_size
    volumetype = "SSD"  # SSD for better performance
  }
  
  # Data volume for Docker
  data_volumes {
    size       = 100
    volumetype = "SSD"
  }
  
  # Node configuration
  runtime = "docker"
  
  # Billing
  billing_mode = 0  # Pay-per-use
  
  # Taints (none for now)
  taints = []
  
  # Labels
  labels = {
    "node-role" = "worker"
    "project"   = "aiops"
  }
  
  tags = var.tags
}

# Get available zones
data "huaweicloud_availability_zones" "available" {
  region = var.region
}

