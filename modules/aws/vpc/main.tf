terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_bits, count.index)
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_bits, count.index + length(local.azs))
  availability_zone = local.azs[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# NAT Instance (used when nat_gateway_enabled = false, e.g. dev to save cost)
# AL2023 Nitro instances use ens5 not eth0 — interface is detected dynamically.
resource "aws_instance" "nat" {
  count         = var.env_config.nat_gateway_enabled ? 0 : 1
  ami           = data.aws_ami.nat_instance[0].id
  instance_type = "t3.nano"
  subnet_id     = aws_subnet.public[0].id

  source_dest_check           = false
  vpc_security_group_ids      = [aws_security_group.nat_instance[0].id]
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/nat-setup.log 2>&1
    set -ex

    # Detect primary interface dynamically (ens5 on Nitro, not eth0)
    ETH0=$(ip -4 route show default | awk '{print $5; exit}')
    echo "Configuring NAT on interface: $ETH0"

    # Enable IP forwarding persistently
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/90-nat.conf
    sysctl --system

    # Install iptables-services
    dnf install -y iptables-services

    # Enable service without starting it - starting would restore saved rules
    # and wipe the rules we're about to set
    systemctl enable iptables

    # Configure NAT masquerade
    iptables -F
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o $ETH0 -j MASQUERADE
    iptables -A FORWARD -j ACCEPT

    # Save rules now - iptables service will load these on reboot
    service iptables save

    echo "NAT setup complete on $ETH0"
  EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-instance"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Security Group for NAT Instance
resource "aws_security_group" "nat_instance" {
  count  = var.env_config.nat_gateway_enabled ? 0 : 1
  name   = "${var.project_name}-${var.environment}-nat-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-instance-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = var.env_config.nat_gateway_enabled ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Environment = var.environment
    Project     = var.project_name
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count         = var.env_config.nat_gateway_enabled ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.env_config.nat_gateway_enabled ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  dynamic "route" {
    for_each = var.env_config.nat_gateway_enabled ? [] : [1]
    content {
      cidr_block           = "0.0.0.0/0"
      network_interface_id = aws_instance.nat[0].primary_network_interface_id
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Private"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  count                = var.env_config.flow_logs_enabled ? 1 : 0
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  max_aggregation_interval = 60

  tags = {
    Name        = "${var.project_name}-${var.environment}-flow-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.env_config.flow_logs_enabled ? 1 : 0
  name              = "/vpc/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = var.env_config.retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-flow-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  count = var.env_config.flow_logs_enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc-flow-logs-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.env_config.flow_logs_enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-vpc-flow-logs-policy"
  role  = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}",
          "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
        ]
      }
    ]
  })
}

# Only queried when nat_gateway_enabled = false (NAT instance path).
# The old amzn-ami-vpc-nat-* AMIs were retired by AWS; using AL2023 instead
# with user data to configure iptables MASQUERADE (see aws_instance.nat).
data "aws_ami" "nat_instance" {
  count       = var.env_config.nat_gateway_enabled ? 0 : 1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
} 