terraform {
  
backend "s3" {
    bucket         = "terraform-state-web-app-bucket-2.0"  # must be globally unique
    key            = "web-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locking"
  }


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }

  
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "terraform-state-web-app-bucket-2.0" # REPLACE WITH YOUR BUCKET NAME
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "terraform_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto_conf" {
  bucket        = aws_s3_bucket.terraform_state.bucket 
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_instance" "instance-1" {
  ami                    = "ami-0ec10929233384c7f"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.allow_tcp_8080.id]
  user_data              = <<-EOF
              #!/bin/bash
              echo "Hello, World 1" > index.html
              python3 -m http.server 8080 &
              EOF
  tags = {
    Name = "Ubuntu-1"
  }
}

resource "aws_instance" "instance-2" {
  ami                    = "ami-0ec10929233384c7f"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.allow_tcp_8080.id]
  user_data              = <<-EOF
              #!/bin/bash
              echo "Hello, World 2" > index.html
              python3 -m http.server 8080 &
              EOF
  tags = {
    Name = "Ubuntu-2"
  }
}



resource "aws_lb" "web-lb" {
  name               = "web-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tcp_80.id]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

}



resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-web-lb.arn
  }
}

resource "aws_lb_target_group" "tg-web-lb" {
  name     = "tg-web-lb"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom.id
}

resource "aws_lb_target_group_attachment" "instance-1" {
  target_group_arn = aws_lb_target_group.tg-web-lb.arn
  target_id        = aws_instance.instance-1.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "instance-2" {
  target_group_arn = aws_lb_target_group.tg-web-lb.arn
  target_id        = aws_instance.instance-2.id
  port             = 8080
}



resource "aws_vpc" "custom" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom.id
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.custom.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  #name = "public-subnet"
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.custom.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.custom.id
  cidr_block = "10.0.3.0/24"
  #name = "private-subnet"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.custom.id
  #name = "public-rt"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.custom.id
  #name = "private-rt"
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "allow_tcp_8080" {
  name        = "allow_tcp_8080"
  description = "Allow TCP inbound 8080 traffic"
  vpc_id      = aws_vpc.custom.id
}

resource "aws_security_group" "allow_tcp_80" {
  name        = "allow_tcp_80"
  description = "Allow TCP inbound 80 traffic"
  vpc_id      = aws_vpc.custom.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tcp_ec2" {
  security_group_id            = aws_security_group.allow_tcp_8080.id
  referenced_security_group_id = aws_security_group.allow_tcp_80.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ec2" {
  security_group_id = aws_security_group.allow_tcp_8080.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_tcp_lb" {
  security_group_id = aws_security_group.allow_tcp_80.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_lb" {
  security_group_id = aws_security_group.allow_tcp_80.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}