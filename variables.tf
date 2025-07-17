variable "aws_region" {
default = "us-east-1"
}

variable "ami_id" {
default = "ami-0150ccaf51ab55a51"
}

variable "instance_type" {
default = "t3.nano"
}

variable "key_name" {
description = "turn-key"
}

variable "public_key_path" {
description = "~/.ssh/turn-key.pub"
}

