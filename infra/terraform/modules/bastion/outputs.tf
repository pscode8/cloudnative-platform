output "instance_id" {
  description = "The ID of the Bastion EC2 instance"
  value       = aws_instance.bastion.id
}