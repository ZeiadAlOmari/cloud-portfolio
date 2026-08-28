# -----------------------------------------------
# Get latest Amazon Linux 2023 AMI
# -----------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# -----------------------------------------------
# Security Group
# -----------------------------------------------
resource "aws_security_group" "cicd" {
  name        = "cicd-server-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cicd-server-sg"
  }
}

# -----------------------------------------------
# SSH Key Pair
# -----------------------------------------------
resource "aws_key_pair" "deployer" {
  key_name   = "cicd-deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# -----------------------------------------------
# EC2 Instance
# -----------------------------------------------
resource "aws_instance" "cicd" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.cicd.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker git
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Docker Compose
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Clone the repo
    cd /opt
    git clone https://github.com/ZeiadAlOmari/cloud-portfolio.git app
    chown -R ec2-user:ec2-user /opt/app

    # Build and run the container
    cd /opt/app/project-3-cicd-pipeline/app
    docker build -t cicd-demo .
    docker run -d --name cicd-app -p 80:5000 --restart always cicd-demo
  EOF

  tags = {
    Name = "cicd-server"
  }
}