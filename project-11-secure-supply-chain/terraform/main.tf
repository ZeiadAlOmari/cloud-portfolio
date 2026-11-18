# Project 11 deploy target: one free-tier instance with no SSH at all (no port 22, no key pair).
# Deployments arrive only as the p11-deploy SSM document, which verifies the image signature before running it.

locals {
  image          = "ghcr.io/zeiadalomari/cloud-portfolio/p11-app"
  signer         = "https://github.com/ZeiadAlOmari/cloud-portfolio/.github/workflows/p11-supply-chain.yml@refs/heads/main"
  oidc_issuer    = "https://token.actions.githubusercontent.com"
  cosign_version = "3.1.4"
  cosign_sha256  = "424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa" # cosign-linux-amd64 v3.1.4
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a"] # t3.micro isn't offered in every AZ (e.g. us-east-1e)
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------- Network: HTTP in, HTTPS out, nothing else ----------------
resource "aws_security_group" "web" {
  #checkov:skip=CKV_AWS_260:Public HTTP demo endpoint; TLS needs a domain or a load balancer (cost decision)
  name        = "p11-web"
  description = "P11: HTTP in for the demo app; HTTPS out for GHCR, Sigstore, SSM and OS updates. No SSH."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Demo app over HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "HTTPS only: GHCR, Sigstore, SSM endpoints, OS repositories"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- Instance identity: SSM agent only ----------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "p11-instance-role"
  description        = "P11 instance: SSM agent registration only"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "p11-instance-profile"
  role = aws_iam_role.instance.name
}

# ---------------- The instance ----------------
resource "aws_instance" "app" {
  #checkov:skip=CKV_AWS_88:Needs a public IP to serve the demo and reach GHCR/SSM without a NAT gateway (cost decision)
  #checkov:skip=CKV_AWS_126:Detailed monitoring is paid; basic 5-minute metrics are enough for a short demo
  #checkov:skip=CKV2_AWS_41:False positive; an instance profile is attached (iam_instance_profile)
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true
  ebs_optimized               = true
  monitoring                  = false
  user_data_replace_on_change = true

  # No key_name: there is no SSH key for this instance at all.

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1          # containers can't reach the instance credentials
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y docker
    systemctl enable --now docker
    curl -sSfL -o /tmp/cosign "https://github.com/sigstore/cosign/releases/download/v${local.cosign_version}/cosign-linux-amd64"
    echo "${local.cosign_sha256}  /tmp/cosign" | sha256sum -c -
    install -m 0755 /tmp/cosign /usr/local/bin/cosign && rm -f /tmp/cosign
    systemctl disable --now sshd || true
    echo "p11 bootstrap complete" > /var/log/p11-bootstrap.done
  EOT

  tags = { Name = "p11-app" }

  lifecycle {
    ignore_changes = [ami] # a newer AMI shouldn't replace a running demo instance
  }
}

# ---------------- The only deploy path: verify the signature, then run the digest ----------------
resource "aws_ssm_document" "deploy" {
  name            = "p11-deploy"
  document_type   = "Command"
  document_format = "YAML"
  content         = <<-DOC
    schemaVersion: "2.2"
    description: "P11: verify a signed image digest with cosign, then run it. Refuses anything not signed by the P11 workflow on main."
    parameters:
      Digest:
        type: String
        description: "Image digest to deploy (sha256:<64 hex>)"
        allowedPattern: "^sha256:[a-f0-9]{64}$"
    mainSteps:
      - action: aws:runShellScript
        name: verifyAndRun
        inputs:
          timeoutSeconds: "300"
          runCommand:
            - set -euo pipefail
            - export HOME=/root
            - test -f /var/log/p11-bootstrap.done || { echo "instance bootstrap not finished"; exit 1; }
            - REF="${local.image}@{{ Digest }}"
            - echo "verifying $REF"
            - if ! cosign verify --certificate-identity "${local.signer}" --certificate-oidc-issuer "${local.oidc_issuer}" "$REF" > /dev/null; then echo "REFUSED - no valid signature from the P11 workflow on main for {{ Digest }}"; exit 1; fi
            - echo "signature verified for {{ Digest }}"
            - docker pull "$REF"
            - docker rm -f p11-app > /dev/null 2>&1 || true
            - docker run -d --name p11-app --restart unless-stopped -p 80:8000 --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges -e IMAGE_DIGEST={{ Digest }} "$REF"
            - for i in $(seq 1 30); do curl -sf http://127.0.0.1/health > /dev/null && break; sleep 1; done
            - curl -sf http://127.0.0.1/health
            - docker ps --no-trunc --filter name=p11-app
            - curl -s http://127.0.0.1/ | grep -o '"image_digest":"[^"]*"'
  DOC
}
