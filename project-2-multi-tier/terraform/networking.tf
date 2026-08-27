# -----------------------------------------------
# VPC
# -----------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "project-2-vpc"
  }
}

# -----------------------------------------------
# Internet Gateway (allows public subnets to reach the internet)
# -----------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "project-2-igw"
  }
}

# -----------------------------------------------
# Public Subnets (for Nginx / web tier)
# -----------------------------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

# -----------------------------------------------
# Private Subnets (for app tier and database)
# -----------------------------------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-b"
  }
}

# -----------------------------------------------
# Isolated Subnets (for database — no internet access at all)
# -----------------------------------------------
resource "aws_subnet" "isolated_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "isolated-subnet-a"
  }
}

resource "aws_subnet" "isolated_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "isolated-subnet-b"
  }
}

# -----------------------------------------------
# Public Route Table (routes internet traffic through the IGW)
# -----------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------
# NAT Instance (free tier alternative to NAT Gateway)
# Gets a public IP so private subnets can reach the internet
# -----------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "nat" {
  name        = "nat-instance-sg"
  description = "Allow traffic from private subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24", "10.0.20.0/24", "10.0.21.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nat-instance-sg"
  }
}

resource "aws_instance" "nat" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check      = false

  user_data = <<-EOF
    #!/bin/bash
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  EOF

  tags = {
    Name = "nat-instance"
  }
}

# -----------------------------------------------
# Private Route Table (routes internet through NAT instance)
# -----------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block  = "0.0.0.0/0"
    network_interface_id = aws_instance.nat.primary_network_interface_id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------
# DB Subnet Group (tells RDS which subnets to use)
# -----------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "project-2-db-subnet-group"
  subnet_ids = [aws_subnet.isolated_a.id, aws_subnet.isolated_b.id]

  tags = {
    Name = "project-2-db-subnet-group"
  }
}