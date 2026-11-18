data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_key_pair" "project5" {
  key_name   = "project5-k3s-key"
  public_key = file("~/.ssh/project5-key.pub")
}

resource "aws_security_group" "k3s_sg" {
  name        = "project5-k3s-sg"
  description = "Allow SSH and NodePort traffic for the k3s demo"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes NodePort (web-service)"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project5-k3s-sg"
  }
}

resource "aws_instance" "k3s_node" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.project5.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  user_data = <<-EOT
    #!/bin/bash
    # Add 1GB swap: a t3.micro only has 1GB RAM, and k3s plus our app pods
    # need more headroom than that alone provides.
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Install k3s without Traefik, ServiceLB, or metrics-server: none of
    # these are needed since web-service uses a plain NodePort, and
    # skipping them frees significant memory on this small instance.
    curl -sfL https://get.k3s.io | sh -s - --disable traefik --disable servicelb --disable metrics-server

    mkdir -p /home/ec2-user/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
    chown -R ec2-user:ec2-user /home/ec2-user/.kube
    sed -i "s/127.0.0.1/$(hostname -I | awk '{print $1}')/" /home/ec2-user/.kube/config
  EOT

  tags = {
    Name = "project5-k3s-node"
  }
}
