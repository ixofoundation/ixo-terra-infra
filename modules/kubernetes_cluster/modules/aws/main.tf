terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

locals {
  kubeconfig_filename = "${path.module}/kubeconfig-${var.environment}"
}

# Data source for existing VPC
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${var.environment}-vpc"]
  }
}

# Data source for private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

# Data source for public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cluster-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach required policies to cluster role
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Add additional policy for EKS 1.30+ requirements
resource "aws_iam_role_policy" "cluster_additional_policy" {
  name = "${var.cluster_name}-cluster-additional-policy"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-node-group-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach required policies to node group role
resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-cluster-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Group for EKS Node Group
resource "aws_security_group" "node_group" {
  name        = "${var.cluster_name}-node-group-sg"
  description = "Security group for EKS node group"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "Node to node communication (self)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow SSH access from within VPC (optional but helpful for debugging)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-node-group-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Additional security group rules to avoid circular dependencies
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow nodes to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node_group.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster_kubelet" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_group.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_group.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 443
  type                     = "ingress"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(data.aws_subnets.private.ids, data.aws_subnets.public.ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # Enable logging
  enabled_cluster_log_types = var.cluster_log_types

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy.cluster_additional_policy,
  ]
}

# EKS Node Group - Let EKS handle the launch template automatically
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = data.aws_subnets.private.ids

  instance_types = var.node_instance_types != null ? var.node_instance_types : var.env_config.node_instance_types
  ami_type       = var.node_ami_type
  capacity_type  = var.node_capacity_type
  disk_size      = var.node_disk_size != null ? var.node_disk_size : var.env_config.disk_size

  scaling_config {
    desired_size = var.node_desired_capacity != null ? var.node_desired_capacity : var.env_config.desired_capacity
    max_size     = var.node_max_capacity != null ? var.node_max_capacity : var.env_config.max_capacity
    min_size     = var.node_min_capacity != null ? var.node_min_capacity : var.env_config.min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  # Remote access configuration
  dynamic "remote_access" {
    for_each = var.node_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.node_key_name
      source_security_group_ids = var.node_security_group_ids
    }
  }

  tags = {
    Name        = "${var.cluster_name}-nodes"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
  ]
}

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# OIDC Identity Provider for EKS cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"] # EKS OIDC root CA thumbprint
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.cluster_name}-oidc-provider"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach EBS CSI Driver policy to the role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                 = aws_eks_cluster.main.name
  addon_name                   = "aws-ebs-csi-driver"
  addon_version                = var.ebs_csi_driver_version
  service_account_role_arn     = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi_driver_policy,
  ]
}

# IAM Role for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cluster-autoscaler-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Cluster Autoscaler
resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  name = "${var.cluster_name}-cluster-autoscaler-policy"
  role = aws_iam_role.cluster_autoscaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })
}

# Cluster Autoscaler Helm Release
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_chart_version

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }

  set {
    name  = "image.tag"
    value = "v${var.cluster_version}.0"
  }

  set {
    name  = "extraArgs.expander"
    value = "least-waste"
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role.cluster_autoscaler,
    aws_iam_role_policy.cluster_autoscaler_policy,
  ]
}

# Generate kubeconfig file
resource "local_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name   = aws_eks_cluster.main.name
    endpoint       = aws_eks_cluster.main.endpoint
    ca_certificate = aws_eks_cluster.main.certificate_authority[0].data
    region         = var.region
  })
  filename = local.kubeconfig_filename

  depends_on = [aws_eks_cluster.main]
}

# StorageClass resources using the EBS CSI driver
# GP3 Storage Class (Standard) - Default and recommended
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    fsType     = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# GP3 Storage Class (Fast) - Higher performance
resource "kubernetes_storage_class" "gp3_fast" {
  metadata {
    name = "gp3-fast"
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type       = "gp3"
    iops       = "10000"
    throughput = "500"
    fsType     = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# ST1 Storage Class (Bulk/Throughput Optimized HDD)
resource "kubernetes_storage_class" "st1" {
  metadata {
    name = "st1"
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type   = "st1"
    fsType = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# SC1 Storage Class (Cold HDD) - For infrequent access
resource "kubernetes_storage_class" "sc1" {
  metadata {
    name = "sc1"
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type   = "sc1"
    fsType = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# GP2 Storage Class using CSI driver (for compatibility)
resource "kubernetes_storage_class" "gp2_csi" {
  metadata {
    name = "gp2-csi"
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type   = "gp2"
    fsType = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
} 