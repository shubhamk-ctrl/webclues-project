provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                         = "ami-053b12d3152c0cc71"  # Ubuntu Server 20.04 LTS (us-west-2)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.main.id
  key_name                    = var.key_name
  associate_public_ip_address = true  # Ensure the instance gets a public IP

  vpc_security_group_ids      = [aws_security_group.main.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y ansible

              # Create directory for playbook and files
              mkdir -p /root/webcluse/sourcecode

              # Write the playbook
              cat << 'ANSIBLE_PLAYBOOK' > /root/webcluse/playbook.yml
              ${file("${path.module}/playbook.yml")}
              ANSIBLE_PLAYBOOK

              # Copy local files to instance
              cat << 'APP_JS' > /root/webcluse/sourcecode/app.js
              ${file("${path.module}/sourcecode/app.js")}
              APP_JS

              cat << 'PACKAGE_JSON' > /root/webcluse/sourcecode/package.json
              ${file("${path.module}/sourcecode/package.json")}
              PACKAGE_JSON

              cat << 'NGINX_CONFIG' > /root/webcluse/sourcecode/nginx_config
              ${file("${path.module}/sourcecode/nginx_config")}
              NGINX_CONFIG

              sudo ansible-playbook /root/webcluse/playbook.yml

              EOF

  tags = {
    Name = "Nginx-Web-Server"
  }
}

output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

