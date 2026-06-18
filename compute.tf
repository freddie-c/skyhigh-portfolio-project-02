# --- Look up the latest Amazon Linux 2023 AMI ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Web server EC2 instance ---
resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.web.id]

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Hello from Terraform!</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name    = "${var.project_name}-web"
    Project = var.project_name
  }
}