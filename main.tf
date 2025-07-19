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

# resource "aws_iam_role" "lambda_exec_role" {
#   name = "lambda-exec-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "git" {
#   role       = aws_iam_role.lambda_exec_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

# resource "aws_lambda_function" "hello_lambda" {
#   function_name = "HelloLambda"
#   role          = "arn:aws:iam::602873375259:role/RoleForLambdaModLabRole"
#   handler       = "index.handler"
#   runtime       = "nodejs18.x"
#   filename      = "${path.module}/hello_lambda.zip"
#   source_code_hash = filebase64sha256("${path.module}/hello_lambda.zip")
# }
resource "aws_sns_topic" "alerts" {
  name = "infra-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "awaisali11159@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "This metric monitors high CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn] # <--- updated line
  dimensions = {
    InstanceId = aws_instance.turn_ec2.id
  }
}
resource "aws_sqs_queue" "project_queue" {
  name = "project-task-queue"

  tags = {
    Environment = "Dev"
    Purpose     = "Queue for async task processing"
  }
}

resource "aws_efs_file_system" "project_fs" {
  creation_token = "project-fs-token"
  tags = {
    Name        = "ProjectEFS"
    Environment = "Dev"
  }
}

resource "aws_efs_mount_target" "project_fs_mount" {
  for_each = toset([var.subnet_id_1, var.subnet_id_2])

  file_system_id  = aws_efs_file_system.project_fs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.turn_sg_new.id]
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "alb-sg"
  }
}
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "app-lb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "app-tg"
  }
}
resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.turn_ec2.id
  port             = 80
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


resource "aws_db_instance" "app_db" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15.3"
  instance_class       = "db.t3.micro"
  db_name                  = "appdb"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.turn_sg_new.id]
  db_subnet_group_name = aws_db_subnet_group.app_db_subnet_group.name

  tags = {
    Name = "AppRDS"
  }
}

resource "aws_db_subnet_group" "app_db_subnet_group" {
  name       = "app-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "App DB Subnet Group"
  }
}
resource "aws_apigatewayv2_api" "http_api" {
  name          = "project-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
