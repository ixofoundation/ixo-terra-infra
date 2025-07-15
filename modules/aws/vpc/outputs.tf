output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = var.env_config.nat_gateway_enabled ? aws_eip.nat[0].public_ip : null
}

output "vpc_flow_logs_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.env_config.flow_logs_enabled ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : null
} 