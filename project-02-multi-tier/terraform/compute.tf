# -----------------------------------------------
# Key Pair for SSH access
# -----------------------------------------------
resource "aws_key_pair" "deployer" {
  key_name   = "project-2-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# -----------------------------------------------
# App Server (Private Subnet)
# Runs the Flask application
# -----------------------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install python3 -y
    pip3 install flask psycopg2-binary

    mkdir -p /opt/app
    cd /opt/app

    cat > app.py << 'APPEOF'
    from flask import Flask, jsonify
    import psycopg2
    import os

    app = Flask(__name__)

    DB_HOST = "${aws_db_instance.main.endpoint}".split(":")[0]
    DB_NAME = "appdb"
    DB_USER = "dbadmin"
    DB_PASS = "${random_password.db_password.result}"

    @app.route("/")
    def home():
        return jsonify({
            "status": "running",
            "message": "Multi-Tier Application",
            "tier": "app",
            "architecture": {
                "web_tier": "Nginx reverse proxy",
                "app_tier": "Flask on EC2",
                "db_tier": "PostgreSQL on RDS"
            }
        })

    @app.route("/health")
    def health():
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASS,
                connect_timeout=5
            )
            conn.close()
            return jsonify({"status": "healthy", "database": "connected"})
        except Exception as e:
            return jsonify({"status": "unhealthy", "database": str(e)}), 503

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=5000)
    APPEOF

    cat > /etc/systemd/system/flask-app.service << 'SVCEOF'
    [Unit]
    Description=Flask App
    After=network.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/app
    ExecStart=/usr/bin/python3 app.py
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SVCEOF

    systemctl daemon-reload
    systemctl enable flask-app
    systemctl start flask-app
  EOF

  tags = {
    Name = "app-server"
  }
}

# -----------------------------------------------
# Web Server (Public Subnet)
# Runs Nginx as reverse proxy to the app server
# -----------------------------------------------
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install nginx1 -y

    cat > /etc/nginx/conf.d/app.conf << 'NGINXEOF'
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://${aws_instance.app.private_ip}:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
    NGINXEOF

    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "web-server"
  }
}