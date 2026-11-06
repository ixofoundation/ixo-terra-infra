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
  kubeconfig_filename = "${path.module}/kubeconfig-${coalesce(var.kubeconfig_name, var.environment)}"
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

  lifecycle {
    ignore_changes = [ingress]
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

  lifecycle {
    ignore_changes = [ingress]
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

  # Only rendered when set: the attribute is computed, so leaving it out is no diff on a
  # cluster built with the default, while setting it on an existing cluster replaces it.
  dynamic "kubernetes_network_config" {
    for_each = var.service_ipv4_cidr != null ? [1] : []
    content {
      service_ipv4_cidr = var.service_ipv4_cidr
    }
  }

  # Enable logging
  enabled_cluster_log_types = var.cluster_log_types

  # Only rendered when a mode is set, so clusters that do not opt in see no diff.
  dynamic "access_config" {
    for_each = var.authentication_mode != null ? [1] : []
    content {
      authentication_mode = var.authentication_mode
      # ForceNew in the provider: it must match what the cluster was created with (true,
      # the provider default) or Terraform replaces the whole cluster.
      bootstrap_cluster_creator_admin_permissions = true
    }
  }

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy.cluster_additional_policy,
  ]

  lifecycle {
    precondition {
      condition     = length(var.cluster_admin_arns) == 0 || contains(["API_AND_CONFIG_MAP", "API"], coalesce(var.authentication_mode, "CONFIG_MAP"))
      error_message = "cluster_admin_arns needs authentication_mode API_AND_CONFIG_MAP or API."
    }
  }
}

# Cluster-admin access entries. The node group role is deliberately absent: it stays in
# aws-auth (valid in API_AND_CONFIG_MAP), and EKS manages any EC2_LINUX entry for it.
resource "aws_eks_access_entry" "cluster_admin" {
  for_each = toset(var.cluster_admin_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = toset(var.cluster_admin_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.cluster_admin[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# EKS Node Group - Let EKS handle the launch template automatically
# Launch template for the "-lt" node groups, so instances, volumes and ENIs get tags.
resource "aws_launch_template" "nodes" {
  count                  = length(var.node_launch_template_tags) > 0 ? 1 : 0
  name_prefix            = "${var.cluster_name}-nodes-"
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda" # AL2023 root device
    ebs {
      volume_size           = var.node_disk_size != null ? var.node_disk_size : var.env_config.disk_size
      volume_type           = var.node_root_volume_type
      delete_on_termination = true
    }
  }

  # Exactly what EKS's own generated template sets for these AL2023 nodes: IMDSv2 required,
  # hop limit 1.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.node_metadata_hop_limit
  }

  dynamic "tag_specifications" {
    for_each = ["instance", "volume", "network-interface"]
    content {
      resource_type = tag_specifications.value
      tags = merge(var.node_launch_template_tags, {
        Name        = "${var.cluster_name}-node"
        Environment = var.environment
        Project     = var.project_name
      })
    }
  }

  tags = var.node_launch_template_tags
}

resource "aws_eks_node_group" "main" {
  # Legacy (pre-launch-template) group; removed once its "-lt" twin has taken over.
  count           = var.node_legacy_groups ? 1 : 0
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

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Optional ON_DEMAND group next to the main one, so a development cluster can keep a
# floor of capacity that a Spot reclaim cannot take (stateful pods, pv-migrate windows).
resource "aws_eks_node_group" "on_demand" {
  count           = var.node_legacy_groups && var.on_demand_node_count > 0 ? 1 : 0
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ondemand"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = data.aws_subnets.private.ids

  instance_types = var.on_demand_node_instance_types
  ami_type       = var.node_ami_type
  capacity_type  = "ON_DEMAND"
  disk_size      = var.node_disk_size != null ? var.node_disk_size : var.env_config.disk_size

  scaling_config {
    desired_size = var.on_demand_node_count
    max_size     = var.on_demand_node_count
    min_size     = var.on_demand_node_count
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.cluster_name}-ondemand"
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
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_node_group.main_lt,
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
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled"             = "true"
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

  set = [
    {
      name  = "autoDiscovery.clusterName"
      value = var.cluster_name
    },
    {
      name  = "awsRegion"
      value = var.region
    },
    {
      name  = "rbac.serviceAccount.name"
      value = "cluster-autoscaler"
    },
    {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.cluster_autoscaler.arn
    },
    {
      name  = "extraArgs.expander"
      value = "least-waste"
    },
    {
      name  = "extraArgs.balance-similar-node-groups"
      value = "true"
    },
    {
      name  = "extraArgs.skip-nodes-with-system-pods"
      value = "false"
    },
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_node_group.main_lt,
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
    aws_profile    = var.aws_profile
    aws_cli_path   = var.aws_cli_path
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
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = merge({
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    fsType     = "ext4"
  }, var.storage_class_parameters)

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# GP3 Storage Class (Fast) - Higher performance
resource "kubernetes_storage_class" "gp3_fast" {
  metadata {
    name = "gp3-fast"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = merge({
    type       = "gp3"
    iops       = "10000"
    throughput = "500"
    fsType     = "ext4"
  }, var.storage_class_parameters)

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# ST1 Storage Class (Bulk/Throughput Optimized HDD)
resource "kubernetes_storage_class" "st1" {
  metadata {
    name = "st1"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = merge({
    type   = "st1"
    fsType = "ext4"
  }, var.storage_class_parameters)

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# SC1 Storage Class (Cold HDD) - For infrequent access
resource "kubernetes_storage_class" "sc1" {
  metadata {
    name = "sc1"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = merge({
    type   = "sc1"
    fsType = "ext4"
  }, var.storage_class_parameters)

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# GP2 Storage Class using CSI driver (for compatibility)
resource "kubernetes_storage_class" "gp2_csi" {
  metadata {
    name = "gp2-csi"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = merge({
    type   = "gp2"
    fsType = "ext4"
  }, var.storage_class_parameters)

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Template-based twins of "main" and "on_demand" (same types, capacity, AMI type, sizes).
resource "aws_eks_node_group" "main_lt" {
  count           = length(aws_launch_template.nodes)
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes-lt"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = data.aws_subnets.private.ids

  instance_types = var.node_instance_types != null ? var.node_instance_types : var.env_config.node_instance_types
  ami_type       = var.node_ami_type
  capacity_type  = var.node_capacity_type

  launch_template {
    id      = aws_launch_template.nodes[0].id
    version = aws_launch_template.nodes[0].latest_version
  }

  scaling_config {
    desired_size = var.node_desired_capacity != null ? var.node_desired_capacity : var.env_config.desired_capacity
    max_size     = var.node_max_capacity != null ? var.node_max_capacity : var.env_config.max_capacity
    min_size     = var.node_min_capacity != null ? var.node_min_capacity : var.env_config.min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.cluster_name}-nodes-lt"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_node_group" "on_demand_lt" {
  count           = length(aws_launch_template.nodes) > 0 && var.on_demand_node_count > 0 ? 1 : 0
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ondemand-lt"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = data.aws_subnets.private.ids

  instance_types = var.on_demand_node_instance_types
  ami_type       = var.node_ami_type
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.nodes[0].id
    version = aws_launch_template.nodes[0].latest_version
  }

  scaling_config {
    desired_size = var.on_demand_node_count
    max_size     = var.on_demand_node_count
    min_size     = var.on_demand_node_count
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.cluster_name}-ondemand-lt"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
  ]
}

# One group per AZ so a replacement node comes back next to its EBS volumes.
data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

resource "aws_eks_node_group" "db_lt" {
  for_each        = length(aws_launch_template.nodes) > 0 && var.db_nodes_per_az > 0 ? { for s in data.aws_subnet.private : s.availability_zone => s.id } : {}
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-db-${each.key}"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = [each.value]

  instance_types = var.db_node_instance_types
  ami_type       = var.node_ami_type
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.nodes[0].id
    version = aws_launch_template.nodes[0].latest_version
  }

  scaling_config {
    desired_size = var.db_nodes_per_az
    max_size     = var.db_nodes_per_az
    min_size     = var.db_nodes_per_az
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "ixo.world/pool" = "db"
  }

  taint {
    key    = "ixo.world/pool"
    value  = "db"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name        = "${var.cluster_name}-db-${each.key}"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
  ]
}
