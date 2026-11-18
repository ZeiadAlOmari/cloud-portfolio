output "web_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "app_private_ip" {
  description = "Private IP of the app server"
  value       = aws_instance.app.private_ip
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "nat_public_ip" {
  description = "Public IP of the NAT instance"
  value       = aws_instance.nat.public_ip
}