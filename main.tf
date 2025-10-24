# Creating a Simple Web

provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

# 1. Create key pair on AWS Console
# 2. Create vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc.html

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod-vpc"
  }
}

# 3. Create Internet Gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway.html

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}

resource "aws_egress_only_internet_gateway" "egw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 4. Create Custom Route Table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table.html

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.egw.id
  }

  tags = {
    Name = "prod-route-table"
  }
}

# 5. Create a Subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet.html

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# 7. Associate subnet with Route Table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association.html

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 8. Create Security Group to allow port 22(SSH), 80, 443
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group.html

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_web"
  }
}

# 9. Create a network interface with an ip in the subnet that was created in step 4
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface.html

resource "aws_network_interface" "web-server-andrew" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 10. Assign an elastic IP to the network interface created in step 7
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip.html

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-andrew.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# 11. Create Ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami               = "ami-0360c520857e3138f"
  instance_type     = "t3.micro"
  availability_zone = "us-east-1a"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-andrew.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }

}

# SSH through Mac (Terminal)
# cd Downloads
# chmod 400 "yourkeyname".pem
# ssh -i "yourkeyname".pem ubuntu@"IP Address"
