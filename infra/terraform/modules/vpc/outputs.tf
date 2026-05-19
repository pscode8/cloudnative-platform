# ── VPC Module Outputs ───────────────────────────────────────────
# These are the 'return values' of this module.
# EKS module will do: module.vpc.private_subnet_ids
# RDS module will do: module.vpc.private_subnet_ids
# No hardcoded IDs anywhere — fully dynamic.

output "vpc_id" {
  description = "ID of the VPC — referenced by security groups and other resources"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC — used in security group rules"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets — ALB goes here"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets — EKS nodes, RDS, Redis go here"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of NAT Gateway — whitelist this in external services"
  value       = aws_eip.nat.public_ip
}
