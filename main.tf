terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {}

# Create a VPC
resource "aws_vpc" "alb-vpc" {
    cidr_block = "11.12.0.0/16" 

    tags = {
        Name = "alb-vpc"
    }
}

# Create Subnets
resource "aws_subnet" "alb-subnet-a" {
    vpc_id = aws_vpc.alb-vpc.id
    cidr_block = "11.12.50.0/24"

    tags = {
        Name = "alb-subnet-a"
    }
}

resource "aws_subnet" "alb-subnet-b" {
    vpc_id = aws_vpc.alb-vpc.id
    cidr_block = "11.12.100.0/24"

    tags = {
        Name = "alb-subnet-b"
    }
}

# Create an internet gateway for public access
resource "aws_internet_gateway" "alb-igw" {
    vpc_id = aws_vpc.alb-vpc.id
    
    tags = {
        Name = "alb-igw"
    }
}

# Create route table
resource "aws_route_table" "alb-rt" {
    vpc_id = aws_vpc.alb-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.alb-igw.id
    }

    tags = {
      Name = "alb-rt"
    }
}

# associate subnets with route table
resource "aws_route_table_association" "alb-rt-subnet-a-assoc" {
    subnet_id = aws_subnet.alb-subnet-a.id
    route_table_id = aws_route_table.alb-rt.id
}

resource "aws_route_table_association" "alb-rt-subnet-b-assoc" {
    subnet_id = aws_subnet.alb-subnet-b.id
    route_table_id = aws_route_table.alb-rt.id
}

# create security group for ec2 instance
resource "aws_security_group" "alb-ec2-sg" {
    name = "alb-ec2-sg"
    description = "Allow HTTP access"
    vpc_id = aws_vpc.alb-vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "alb-ec2-sg-http-rule" {
    security_group_id = aws_security_group.alb-ec2-sg.id

    cidr_ipv4 = "0.0.0.0/0"
    from_port = 80
    ip_protocol = "tcp"
    to_port = 80
}

resource "aws_vpc_security_group_egress_rule" "alb-ec2-sg-internet-rule" {
    security_group_id = aws_security_group.alb-ec2-sg.id

    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "alb-ec2-sg-ssh-rule" {
    security_group_id = aws_security_group.alb-ec2-sg.id

    cidr_ipv4 = "0.0.0.0/0"
    from_port = 22
    ip_protocol = "tcp"
    to_port = 22
}

# ssh key-pair 
resource "aws_key_pair" "alb-ec2-a-key" {
    key_name = "ec2-a-key"
    public_key = file("~/.ssh/id_rsa.pub")
}


# create two ec2 instances (one in each subnet)
resource "aws_instance" "alb-ec2-a" {
    ami = "ami-0b6d9d3d33ba97d99"
    instance_type = "t2.micro"

    subnet_id = aws_subnet.alb-subnet-a.id
    security_groups = [aws_security_group.alb-ec2-sg.id]
    associate_public_ip_address = true

    key_name = aws_key_pair.alb-ec2-a-key.key_name

    user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    EOF
}

output "alb-ec2-a-public-ip" {
  value = aws_instance.alb-ec2-a.public_ip
}


