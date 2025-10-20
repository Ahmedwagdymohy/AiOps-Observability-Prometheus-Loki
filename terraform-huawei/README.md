# Terraform - Huawei Cloud Kubernetes Cluster

This directory contains Terraform configurations to deploy a cost-optimized Kubernetes cluster on Huawei Cloud CCE (Cloud Container Engine) for the AIOps prototype.

## 📋 What Gets Created

### Infrastructure Components

1. **VPC Network**
   - VPC: `10.0.0.0/16`
   - Subnet: `10.0.1.0/24`
   - Security Group with rules for K8s, SSH, and NodePort services

2. **CCE Kubernetes Cluster**
   - **Flavor**: `cce.s1.small` (cost-optimized)
   - **Version**: Kubernetes v1.28
   - **Type**: VirtualMachine
   - **Authentication**: RBAC
   - **Network**: Overlay L2
   - **EIP**: Public IP for external access

3. **Node Pool**
   - **Node Flavor**: `c6.large.2` (2 vCPUs, 4GB RAM)
   - **Node Count**: 2 nodes (minimum for HA)
   - **OS**: EulerOS 2.9
   - **Root Disk**: 50GB SSD
   - **Data Disk**: 100GB SSD (for Docker)
   - **Runtime**: Docker

4. **SWR (Container Registry)**
   - Organization for your Docker images
   - Private repository for `aiops-processor`
   - Integrated with CCE cluster

### 💰 Cost Estimate

**Monthly cost: ~$115/month**

- CCE Cluster (small): ~$30
- Worker Nodes (2x c6.large.2): ~$60
- EIP + Bandwidth (5Mbps): ~$10
- Storage (SSD): ~$15
- SWR: Free

*Note: Actual costs may vary based on usage and region*

## 🚀 Quick Start

### Prerequisites

1. **Huawei Cloud Account**
   - Sign up at https://www.huaweicloud.com/intl/en-us/
   - Complete identity verification

2. **Access Keys**
   - Go to Console -> My Credentials -> Access Keys
   - Create new access key
   - Save Access Key ID and Secret Access Key

3. **Terraform**
   ```bash
   # Install Terraform
   brew install terraform  # macOS
   # or download from https://www.terraform.io/downloads
   ```

### Step 1: Configure Credentials

```bash
cd terraform-huawei

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your credentials
nano terraform.tfvars
```

Fill in:
```hcl
access_key = "YOUR_ACCESS_KEY_ID"
secret_key = "YOUR_SECRET_ACCESS_KEY"
region     = "ap-southeast-1"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

Review the resources that will be created.

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes 10-15 minutes.

### Step 5: Get Cluster Access

After deployment completes, you'll see output with cluster information.

**Download kubeconfig:**

**Option A: Via Huawei Cloud Console**
1. Go to https://console.huaweicloud.com/cce
2. Click on your cluster name
3. Go to "Access" tab
4. Click "Download kubeconfig"

**Option B: Via CLI** (if you have Huawei Cloud CLI installed)
```bash
hcloud cce cluster download-certificates \
  --region ap-southeast-1 \
  --cluster-id <CLUSTER_ID>
```

**Set kubeconfig:**
```bash
export KUBECONFIG=/path/to/downloaded/kubeconfig.json
kubectl cluster-info
kubectl get nodes
```

## 📦 Deploy AIOps to Cluster

### Step 1: Build and Push Docker Image

```bash
cd ..

# Get registry URL from Terraform output
terraform -chdir=terraform-huawei output aiops_image_url

# Build image
docker build -t <IMAGE_URL> -f kubernetes/Dockerfile .

# Login to SWR
docker login -u ap-southeast-1@<YOUR_USERNAME> swr.ap-southeast-1.myhuaweicloud.com
# Password: Enter your Huawei Cloud login password

# Push image
docker push <IMAGE_URL>
```

### Step 2: Update Kubernetes Deployment

Edit `kubernetes/aiops-processor/deployment.yaml`:
```yaml
image: swr.ap-southeast-1.myhuaweicloud.com/<ORG>/aiops-processor:latest
```

### Step 3: Deploy to Cluster

```bash
cd kubernetes

# Create namespaces
kubectl apply -f namespace.yaml

# Deploy monitoring stack
kubectl apply -f prometheus/
kubectl apply -f alertmanager/
kubectl apply -f loki/
kubectl apply -f promtail/
kubectl apply -f grafana/

# Deploy AIOps processor
kubectl apply -f aiops-processor/

# Deploy demo apps
kubectl apply -f demo-apps/

# Verify
kubectl get pods -n monitoring
kubectl get pods -n demo-apps
```

## 🌐 Access Services

### Option A: Port Forwarding (Development)

```bash
# Grafana
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# AIOps API
kubectl port-forward svc/aiops-processor 8000:8000 -n monitoring
```

### Option B: NodePort (Recommended for Huawei Cloud)

Services are already configured as LoadBalancer, but NodePort is cheaper.

```bash
# Get node IPs
kubectl get nodes -o wide

# Get NodePort
kubectl get svc -n monitoring

# Access via: http://<NODE_IP>:<NODEPORT>
```

### Option C: ELB Load Balancer (Production)

For production, services marked as `LoadBalancer` will get Huawei Cloud ELB automatically.

```bash
# Get external IPs
kubectl get svc -n monitoring
kubectl get svc -n demo-apps

# Access via the EXTERNAL-IP
```

## 🔧 Management

### View Resources

```bash
# Cluster info
terraform output

# Kubernetes resources
kubectl get all -n monitoring
kubectl get all -n demo-apps

# Node details
kubectl top nodes
kubectl describe nodes
```

### Scale Nodes

Edit `terraform.tfvars`:
```hcl
node_count = 3  # Increase to 3 nodes
```

Apply changes:
```bash
terraform apply
```

### Update Cluster

```bash
# Modify any .tf files or variables
terraform plan
terraform apply
```

## 🧹 Cleanup

### Option A: Destroy Everything

```bash
# Delete Kubernetes resources first
kubectl delete namespace monitoring
kubectl delete namespace demo-apps

# Destroy infrastructure
terraform destroy
```

Type `yes` when prompted.

### Option B: Partial Cleanup

To keep the cluster but remove some resources:

```bash
# Remove specific resources
terraform destroy -target=huaweicloud_cce_node_pool.aiops_node_pool

# Or scale down nodes
# Edit terraform.tfvars: node_count = 0
terraform apply
```

## 📊 Monitoring Costs

**In Huawei Cloud Console:**
1. Go to Billing Center
2. View Cost Analysis
3. Filter by project tags

**Keep costs low:**
- Use `pay-per-use` billing (already configured)
- Stop/delete cluster when not in use
- Use minimum node count (2)
- Use small instance types
- Monitor bandwidth usage

## 🔒 Security Best Practices

1. **Never commit terraform.tfvars**
   - Already in .gitignore
   - Contains sensitive credentials

2. **Rotate Access Keys**
   - Rotate every 90 days
   - Huawei Cloud Console -> My Credentials

3. **Use IAM Policies**
   - Create IAM user with minimum permissions
   - Don't use root account credentials

4. **Enable Audit Logging**
   - Enable CTS (Cloud Trace Service) in Huawei Cloud

5. **Network Security**
   - Security groups are configured
   - Consider VPN for admin access
   - Use private endpoints when possible

## 📝 Terraform Files Overview

- `provider.tf` - Terraform and provider configuration
- `variables.tf` - Input variables and defaults
- `vpc.tf` - VPC, subnet, security groups
- `cce-cluster.tf` - Kubernetes cluster and node pool
- `swr.tf` - Container registry
- `outputs.tf` - Output values and commands
- `terraform.tfvars.example` - Example configuration
- `terraform.tfvars` - Your actual configuration (gitignored)

## 🆘 Troubleshooting

### Authentication Failed

```bash
# Verify credentials
terraform plan

# Check access key permissions in Huawei Cloud Console
# Required permissions: CCE, VPC, ECS, SWR
```

### Cluster Creation Failed

```bash
# Check quota limits
# Huawei Cloud Console -> Service Quotas

# Common issues:
# - EIP quota exceeded
# - ECS quota exceeded
# - Region not available
```

### Can't Connect to Cluster

```bash
# Verify kubeconfig
kubectl config view

# Check cluster status in console
# Wait for cluster to be "Available"

# Check security group rules
# Ensure your IP is allowed to access port 6443
```

### Pods Not Starting

```bash
# Check node status
kubectl get nodes
kubectl describe node <NODE_NAME>

# Check pod status
kubectl get pods -n monitoring
kubectl describe pod <POD_NAME> -n monitoring
kubectl logs <POD_NAME> -n monitoring
```

## 📚 Additional Resources

- [Huawei Cloud CCE Documentation](https://support.huaweicloud.com/intl/en-us/cce/index.html)
- [Terraform Huawei Provider](https://registry.terraform.io/providers/huaweicloud/huaweicloud/latest/docs)
- [Kubernetes on Huawei Cloud](https://support.huaweicloud.com/intl/en-us/qs-cce/cce_qs_0001.html)
- [SWR Documentation](https://support.huaweicloud.com/intl/en-us/swr/index.html)

## 💡 Tips

- Start small, scale as needed
- Use spot instances if available (not in this config)
- Enable cluster autoscaling for production
- Set up monitoring alerts for costs
- Use Huawei Cloud credits from competition
- Test in dev region first (ap-southeast-1)

---

**Need help?** Check the main project documentation or Huawei Cloud support.

