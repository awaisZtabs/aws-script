variable "aws_region" {
default = "eu-central-1"
}

variable "ami_id" {
default = "ami-0cc293023f983ed53"
}

variable "instance_type" {
default = "t3.nano"
}

variable "key_name" {
description = "Name for EC2 key pair"
}

variable "public_key_path" {
description = "Path to your SSH public key (e.g., ~/.ssh/id_rsa.pub)"
}

