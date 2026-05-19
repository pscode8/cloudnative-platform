# ── VPC Module ────────────────────────────────────────────────────
# The network foundation — everything else lives inside this VPC.
#
# Architecture:
#   Internet → IGW → Public Subnets (ALB) → Private Subnets (EKS, RDS)
#
# Security principle: Defence in depth.
# Public subnet: only ALB (load balancer) lives here.
# Private subnet: EKS nodes, RDS, Redis — never directly reachable.
# NAT Gateway: private resources can call outbound (pull images, updates)
#              but internet cannot reach them inbound.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── VPC ──────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # required for EKS — nodes need DNS
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
    # EKS requires this tag to discover the VPC
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  })
}

# ── Internet Gateway ─────────────────────────────────────────────
# The door between your VPC and the internet.
# Without this, nothing in public subnets can reach the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── Public Subnets ───────────────────────────────────────────────
# Spread across AZs for high availability.
# If us-east-2a goes down, us-east-2b and 2c still serve traffic.
# ALB (load balancer) lives here — it needs a public IP.
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Instances in public subnet get a public IP automatically
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
    Tier        = "public"
    # EKS uses this tag to know which subnets to put internet-facing LBs in
    "kubernetes.io/role/elb" = "1"
  })
}

# ── Private Subnets ──────────────────────────────────────────────
# No public IPs. No direct internet access.
# EKS worker nodes live here — they talk to the API server privately.
# RDS lives here — never reachable from the internet.
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
    Tier        = "private"
    # EKS uses this tag for internal load balancers
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ── Elastic IP for NAT Gateway ───────────────────────────────────
# Static public IP address for the NAT Gateway.
# Private subnet traffic goes: node → NAT → internet
# Internet only sees this one IP, not the nodes directly.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # EIP depends on IGW being attached to VPC first
  depends_on = [aws_internet_gateway.main]
}

# ── NAT Gateway ──────────────────────────────────────────────────
# Sits in the PUBLIC subnet, serves the PRIVATE subnets.
# Allows outbound internet (pull Docker images, OS updates)
# but BLOCKS all inbound — private resources stay private.
#
# COST NOTE: NAT Gateway costs ~$32/month + data transfer.
# For dev: consider nat_instance (t3.nano ~$3/mo) to save money.
# For prod: always use managed NAT Gateway — it's HA and patched.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # NAT lives in first public subnet

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-nat"
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  depends_on = [aws_internet_gateway.main]
}

# ── Route Tables ─────────────────────────────────────────────────
# Route table = routing rules for subnets.
# Public: 0.0.0.0/0 → IGW (full internet access)
# Private: 0.0.0.0/0 → NAT (outbound only, via NAT)

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── Route Table Associations ─────────────────────────────────────
# Link subnets to their route tables.
# Without this association, subnets use the VPC default route table.

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── VPC Flow Logs ─────────────────────────────────────────────────
# Logs ALL network traffic in/out of the VPC to CloudWatch.
# Essential for: security investigations, compliance, debugging.
# Attack scenario: someone portscanning your VPC → shows in flow logs.
resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL" # ACCEPT + REJECT — see both allowed and blocked
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-flow-log"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}"
  retention_in_days = 30 # Keep 30 days — balance cost vs audit needs

  tags = var.tags
}

resource "aws_iam_role" "flow_log" {
  name = "${var.project_name}-${var.environment}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}
