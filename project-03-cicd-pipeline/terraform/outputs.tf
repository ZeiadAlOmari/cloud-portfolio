output "instance_public_ip" {
  description = "Public IP of the CI/CD server"
  value       = aws_instance.cicd.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.cicd.id
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_instance.cicd.public_ip}"
}