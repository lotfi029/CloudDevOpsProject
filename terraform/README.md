# 3. Infrastructure Provisioning with Terraform

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Network Module (VPC, public & private subnets, IGW, NAT, Network ACL) | ✅ Done |
| Server Module (EC2 for Jenkins with Security Groups) | ✅ Done |
| EKS Module (EKS + 2 worker nodes in different private subnets & AZs) | ✅ Done |
| ECR Module | ✅ Done |
| S3 Terraform Backend state | ✅ Done |
| Terraform modules committed to repository | ✅ Done |

---

## Architecture

```
VPC  10.0.0.0/16
├── Public Subnet  us-east-1a  10.0.1.0/24  → Jenkins EC2, NAT Gateway
├── Public Subnet  us-east-1b  10.0.2.0/24  → Load Balancers
├── Private Subnet us-east-1a  10.0.3.0/24  → EKS Worker Node 1
└── Private Subnet us-east-1b  10.0.4.0/24  → EKS Worker Node 2
```

---

## Module Breakdown

### Network Module — `terraform/modules/network/`

| Resource | Details |
|----------|---------|
| `aws_vpc` | CIDR `10.0.0.0/16`, DNS enabled |
| `aws_subnet` (public ×2) | `10.0.1.0/24`, `10.0.2.0/24` — map public IP on launch |
| `aws_subnet` (private ×2) | `10.0.3.0/24`, `10.0.4.0/24` — no public IP |
| `aws_internet_gateway` | Attached to VPC |
| `aws_nat_gateway` | In public subnet[0], uses Elastic IP |
| `aws_route_table` (public) | Routes `0.0.0.0/0` → IGW |
| `aws_route_table` (private) | Routes `0.0.0.0/0` → NAT |
| `aws_network_acl` | Applied to all subnets, allows all inbound/outbound |

### Server Module — `terraform/modules/server/`

| Resource | Details |
|----------|---------|
| `aws_security_group` | Allows SSH (22), Jenkins UI (8080), all egress |
| `aws_instance` | Ubuntu 22.04, `t3.small`, 30GB gp3, tagged `Role=jenkins` |

### EKS Module — `terraform/modules/eks/`

| Resource | Details |
|----------|---------|
| `aws_iam_role` (cluster) | `AmazonEKSClusterPolicy` attached |
| `aws_eks_cluster` | Version `1.32`, private + public endpoint access |
| `aws_iam_role` (node) | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |
| `aws_eks_node_group` | 2 desired nodes, `t3.small`, spread across both private subnets/AZs |

### ECR Module — `terraform/modules/ecr/`

| Resource | Details |
|----------|---------|
| `aws_ecr_repository` | `clouddevops-app`, scan on push enabled |
| `aws_ecr_lifecycle_policy` | Retains last 10 images |

---

## S3 Backend

State is stored remotely in S3 with DynamoDB locking:

```hcl
backend "s3" {
  bucket         = "clouddevops-tfstate"
  key            = "terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "clouddevops-tfstate-lock"
  encrypt        = true
}
```

### One-time Backend Setup

```bash
aws s3api create-bucket --bucket clouddevops-tfstate --region us-east-1
aws s3api put-bucket-versioning \
  --bucket clouddevops-tfstate \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name clouddevops-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1
```

---

## Usage

```bash
cd terraform/

terraform init
terraform plan -var="key_name=jenkins-key"
terraform apply -var="key_name=jenkins-key"
```

## Outputs

| Output | Value |
|--------|-------|
| `jenkins_public_ip` | Public IP of Jenkins EC2 |
| `ecr_repository_url` | `108782058667.dkr.ecr.us-east-1.amazonaws.com/clouddevops-app` |
| `eks_cluster_name` | `clouddevops-eks` |
| `eks_cluster_endpoint` | EKS API server URL |

---

## Provisioned Resources (Actual)

| Resource | ID |
|----------|----|
| VPC | `vpc-0fe5e6f40d47e98b1` |
| EKS Cluster | `clouddevops-eks` |
| ECR Repository | `clouddevops-app` |
| Jenkins EC2 | `3.219.168.162` |