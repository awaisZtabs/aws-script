provider "aws" {
region = var.aws_region
}

resource "aws_instance" "example" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
}


resource "aws_security_group" "turn_sg" {
name = "turn-sg"
description = "Allow SSH access"

ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_instance" "turn_ec2" {
ami = var.ami_id
instance_type = var.instance_type
key_name =  var.key_name
vpc_security_group_ids = [aws_security_group.turn_sg.id]
user_data = file("userdata.sh")

tags = {
Name = "turn-server"
}
}