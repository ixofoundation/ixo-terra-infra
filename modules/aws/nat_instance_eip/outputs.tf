output "public_ip" {
  value = aws_eip.nat_instance.public_ip
}

output "allocation_id" {
  value = aws_eip.nat_instance.allocation_id
}
