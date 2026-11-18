terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Fixed public IP for the NAT instance, so its egress can be allowlisted.
# Follows the instance if it is replaced; prevent_destroy keeps the address.
resource "aws_eip" "nat_instance" {
  domain   = "vpc"
  instance = var.instance_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-instance-eip"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    prevent_destroy = true
  }
}
