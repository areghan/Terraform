variable region {}
variable access_key {}
variable secret_key {}
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable availability_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable my_public_key {}


provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# VPC- ZAIN VPC
resource "aws_vpc" "zain_vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

# SUBNET
resource "aws_subnet" "subnet-A" {
  vpc_id     = aws_vpc.zain_vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.env_prefix}-subnet-A"
  }
}

#IGW
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.zain_vpc.id

  tags = {
    Name = "${var.env_prefix}-IGW"
  }
}


#ROUTE TABLE

resource "aws_route_table" "Public-route-table" {
  vpc_id = aws_vpc.zain_vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "${var.env_prefix}-Route_table"
  }
}

#SUBNET ASSOCIATION
resource "aws_route_table_association" "Public-subnet-associate" {
  subnet_id      = aws_subnet.subnet-A.id 
  route_table_id = aws_route_table.Public-route-table.id
}


#FIREWALLS

resource "aws_security_group" "ssh-group" {
  name        = "SG"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.zain_vpc.id

  ingress {
    description      = "SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    ingress {
    description      = "HTTPS from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.env_prefix}-Sg"
  }
}

# Deploy an EC2 instance
data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_key_pair" "ssh-key" {
    key_name = "dev-key"
    public_key = var.my_public_key
  
}

resource "aws_instance" "APP-SERVER" {
  ami = data.aws_ami.amzn-linux-2023-ami.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.subnet-A.id
  vpc_security_group_ids = [ aws_security_group.ssh-group.id ]
  availability_zone = var.availability_zone
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  user_data = file("entry-script.sh")


  tags = {
    Name = "${var.env_prefix}-server"
  }
}



output "aws_ami_id" {
    value = data.aws_ami.amzn-linux-2023-ami
}