provider "aws" {
  region  = "ap-south-1"
}

variable "cidr_tags" {
  description = "Defining cidr and tags of vpc and subnets"
  type        = list
}

variable "az" {
  description = "availability zones in region"
  type        = list
}


resource "aws_vpc" "prod_vpc" {
  cidr_block           = var.cidr_tags[0].vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {
    Name = var.cidr_tags[0].Name
  }
}

resource "aws_subnet" "prod_subnet_1" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.cidr_tags[1].subnet_1_cidr
  availability_zone = var.az[0]
  tags = {
    Name = var.cidr_tags[1].Name
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "prod_subnet_2" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.cidr_tags[2].subnet_2_cidr
  availability_zone = var.az[1]
  tags = {
    Name = var.cidr_tags[2].Name
  }
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "IG" {
  vpc_id = aws_vpc.prod_vpc.id
}

resource "aws_route_table" "subnet1_route" {
  vpc_id = aws_vpc.prod_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
  }
}

resource "aws_route_table" "subnet2_route" {
  vpc_id = aws_vpc.prod_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
  }
}

resource "aws_route_table_association" "RouteAss1" {
  subnet_id      = aws_subnet.prod_subnet_1.id
  route_table_id = aws_route_table.subnet1_route.id
}

resource "aws_route_table_association" "RouteAss2" {
  subnet_id      = aws_subnet.prod_subnet_2.id
  route_table_id = aws_route_table.subnet2_route.id
}

resource "aws_security_group" "SG_for_instance" {
  name        = "allow_traffic"
  description = "Allow web,ssh inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id
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
}

resource "aws_instance" "name" {
    ami = "ami-0bcf5425cdc1d8a85"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    subnet_id= aws_subnet.prod_subnet_1.id
    security_groups = [ aws_security_group.SG_for_instance.id ]
    key_name = "Manu"
    user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install httpd -y
                sudo systemctl start httpd
                sudo systemctl enable httpd
                echo "Welcome from Terraform" > /var/www/html/index.html
                EOF
    tags = {
      Name = "Production"
    }
}
