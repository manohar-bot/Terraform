provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIA3WBEMEMUKHML4U6I"
  secret_key = "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"
}

#1 Create a VPC

resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "Production"
  }
}

#2 Create an Internet Gateway

resource "aws_internet_gateway" "IG" {
  vpc_id = aws_vpc.prod_vpc.id
  tags = {
    Name = "IG"
  }
}

#3 Create Custom Route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
  }
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.IG.id
  }
  tags = {
    Name = "Production"
  }
}

#4 Create a Subnet

resource "aws_subnet" "prod-subnet" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Production"
  }
}

#5 Associate a subnet to the route table

resource "aws_route_table_association" "RouteAssociation" {
  subnet_id      = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

#6 Create a Security group to allow port 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
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

  tags = {
    Name = "allow_web_traffic"
  }
}

#7 Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "webserver-nic" {
  subnet_id       = aws_subnet.prod-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#8 Assign an elastic Ip to the network interface created in step 7

resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.webserver-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.IG]
  
}

#9 Create an amazon linux 2 server and install apache 

resource "aws_instance" "web-server-instance" {
    ami = "ami-068d43a544160b7ef"
    instance_type = "t2.micro"
    availability_zone = "ap-south-1a"
    key_name = "Manu"
    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.webserver-nic.id

    }
    user_data =  <<-EOF
                 #!/bin/bash
                 sudo yum update -y
                 sudo yum install httpd -y
                 sudo systemctl start httpd
                 sudo systemctl enable httpd
                 echo "Hi This is terraform practice" > /var/www/html/index.html
                 EOF
    tags = {
      "Name" = "Web-Server"
    }
                
}
