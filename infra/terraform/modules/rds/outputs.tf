# ── RDS Module Outputs ───────────────────────────────────────────

output "db_endpoint" {
  description = "RDS endpoint hostname — apps connect here"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "PostgreSQL port (always 5432)"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "secret_arn" {
  description = "Secrets Manager ARN — pods use IRSA to read this secret"
  value       = aws_secretsmanager_secret.db.arn
}
