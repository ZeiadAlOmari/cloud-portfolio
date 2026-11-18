# -----------------------------------------------
# Random password for the database
# -----------------------------------------------
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# -----------------------------------------------
# RDS PostgreSQL Instance (Free Tier)
# Single-AZ, smallest instance class
# -----------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "project-2-db"

  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "appdb"
  username = "dbadmin"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "project-2-db"
  }
}