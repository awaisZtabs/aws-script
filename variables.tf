variable "aws_region" {
default = "us-east-1"
}

variable "ami_id" {
default = "ami-0150ccaf51ab55a51"
}
variable "ami" {
  description = "The AMI ID to use"
  type        = string  # ✅ Correct type declaration
}
variable "instance_type" {
default = "t3.nano"
}

variable "key_name" {
  description = "The name of the AWS key pair"
}

variable "public_key_path" {
  description = "Path to the public key"
}

variable "s3_bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}
