output "instance_public_ip" {
  description = "Public IP of the k3s node"
  value       = aws_instance.k3s_node.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the k3s node"
  value       = "ssh -i ~/.ssh/project5-key ec2-user@${aws_instance.k3s_node.public_ip}"
}

output "web_service_url" {
  description = "URL for the web-service once deployed (NodePort 30080)"
  value       = "http://${aws_instance.k3s_node.public_ip}:30080"
}
