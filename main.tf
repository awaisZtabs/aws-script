provider "aws" {
region = var.aws_region
}

resource "aws_instance" "example" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
}


resource "aws_security_group" "turn_sg_new" {
name = "turn-sg-2"
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
vpc_security_group_ids = [aws_security_group.turn_sg_new.id]

user_data = file("userdata.sh")

tags = {
Name = "turn-server"
}
}
resource "aws_s3_bucket" "project_bucket" {
  bucket = var.s3_bucket_name  # Define in terraform.tfvars
  force_destroy = true

  tags = {
    Name        = "ProjectBucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.project_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "messages" {
  name         = "messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "MessagesTable"
    Environment = "Dev"
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# resource "aws_lambda_function" "hello_lambda" {
#   function_name = "HelloLambda"
#   role          = "arn:aws:iam::602873375259:role/RoleForLambdaModLabRole"
#   handler       = "index.handler"
#   runtime       = "nodejs18.x"
#   filename      = "${path.module}/hello_lambda.zip"
#   source_code_hash = filebase64sha256("${path.module}/hello_lambda.zip")
# }