# Create VPC for the cluster
resource "huaweicloud_vpc" "aiops_vpc" {
  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr
  tags = var.tags
}

# Create subnet
resource "huaweicloud_vpc_subnet" "aiops_subnet" {
  name       = "${var.project_name}-subnet"
  cidr       = var.subnet_cidr
  gateway_ip = cidrhost(var.subnet_cidr, 1)
  vpc_id     = huaweicloud_vpc.aiops_vpc.id
  
  # Enable DNS
  dns_list = ["100.125.1.250", "100.125.21.250"]
  
  tags = var.tags
}

# Create security group for cluster
resource "huaweicloud_networking_secgroup" "aiops_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for AIOps cluster"
}

# Allow SSH access (for debugging)
resource "huaweicloud_networking_secgroup_rule" "allow_ssh" {
  security_group_id = huaweicloud_networking_secgroup.aiops_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow SSH"
}

# Allow all outbound traffic
resource "huaweicloud_networking_secgroup_rule" "allow_all_outbound" {
  security_group_id = huaweicloud_networking_secgroup.aiops_sg.id
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow all outbound"
}

# Allow Kubernetes API server access
resource "huaweicloud_networking_secgroup_rule" "allow_k8s_api" {
  security_group_id = huaweicloud_networking_secgroup.aiops_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow Kubernetes API"
}

# Allow NodePort services (30000-32767)
resource "huaweicloud_networking_secgroup_rule" "allow_nodeport" {
  security_group_id = huaweicloud_networking_secgroup.aiops_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "Allow NodePort services"
}

# Allow internal cluster communication
resource "huaweicloud_networking_secgroup_rule" "allow_internal" {
  security_group_id = huaweicloud_networking_secgroup.aiops_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = var.vpc_cidr
  description       = "Allow internal VPC traffic"
}

