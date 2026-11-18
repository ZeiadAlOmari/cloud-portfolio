output "instance_id" {
  value = aws_instance.app.id
}

output "url" {
  value = "http://${aws_instance.app.public_ip}"
}

output "deploy_document" {
  value = aws_ssm_document.deploy.name
}
