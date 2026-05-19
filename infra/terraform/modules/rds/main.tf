# ── RDS PostgreSQL Module ────────────────────────────────────────
# Managed PostgreSQL — AWS handles: patching, backups, failover.
#
# SECURITY:
# - storage_encrypted: data at rest encrypted (required for HIPAA/PCI)
# - Security group: only port 5432 from VPC CIDR — RDS never on internet
# - No public IP: cannot be reached from outside VPC
# - Credentials in AWS Secrets Manager (not hardcoded)
#
# MongoDB ransomware (2017): 26k DBs wiped because port 27017
# was open to 0.0.0.0/0. This config prevents that entirely.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# ── Random Password ──────────────────────────────────────────────
# Generates a strong random password at apply time.
# Never hardcode DB passwords — they end up in state files and git.
# This gets stored in Secrets Manager (see below).
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?" # Exclude chars that break conn strings
}

# ── Secrets Manager ──────────────────────────────────────────────
# Stores DB credentials securely. Apps retrieve at runtime.
# In Phase 6 we replace this with Vault dynamic credentials.
# Dynamic creds = each pod gets a unique short-lived password.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/${var.environment}/db"
  description             = "RDS PostgreSQL credentials"
  recovery_window_in_days = 7 # 7-day window before permanent deletion

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "appuser"
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.database_name
    # Full connection string for apps that need it
    url = "postgresql://appuser:${random_password.db.result}@${aws_db_instance.main.address}:5432/${var.database_name}"
  })
}

# ── Subnet Group ─────────────────────────────────────────────────
# Tells RDS which subnets it can use.
# Multi-AZ: RDS primary in one subnet, standby in another AZ.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-db-subnet-group"
    ManagedBy = "terraform"
  })
}

# ── Security Group ───────────────────────────────────────────────
# Firewall for RDS. ONLY allows postgres port FROM inside the VPC.
# Nothing from the internet. Nothing from other VPCs.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL - VPC internal access only"
  vpc_id      = var.vpc_id

  # Allow postgres only from within the VPC
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Only VPC internal traffic
    # NOT 0.0.0.0/0 — that would be internet accessible
  }

  # Allow all outbound — RDS needs to call AWS services
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-rds-sg"
    ManagedBy = "terraform"
  })
}

# ── RDS Parameter Group ──────────────────────────────────────────
# Database configuration — tune PostgreSQL for your workload.
# log_connections: logs every new connection (audit trail).
# shared_preload_libraries: pg_stat_statements for query performance.
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-pg16"
  family = "postgres${var.postgres_version}"

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "pending-reboot" # ← add this
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "pending-reboot" # ← add this
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot" # ← add this
  }

  tags = var.tags
}

# ── RDS Instance ─────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.allocated_storage_gb * 5 # Autoscale up to 5x
  storage_type          = "gp3"                        # gp3 = faster and cheaper than gp2

  db_name  = var.database_name
  username = "appuser"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  # SECURITY: encrypted at rest — required for any compliance standard
  storage_encrypted = true

  # No public IP — only reachable from inside VPC
  publicly_accessible = false

  # Automated daily backups
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00" # 3-4 AM UTC — low traffic

  # Maintenance window for OS/engine patches
  maintenance_window = "Mon:04:00-Mon:05:00"

  # Prevent accidental deletion via terraform destroy
  # In prod this should be true. Set to false for dev to save costs.
  deletion_protection = var.environment == "prod" ? true : false

  # Skip final snapshot for dev (saves time), take one for prod
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final" : null

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}
