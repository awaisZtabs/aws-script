# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Basic EC2 instance - example instance
resource "aws_instance" "example" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
}


# Security Group for TURN server - allows SSH access and all outbound traffic
resource "aws_security_group" "turn_sg_new" {
  name        = "turn-sg-2"
  description = "Allow SSH access"

  # Allow SSH inbound traffic from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Main application server EC2 instance with user data script
resource "aws_instance" "turn_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name              = var.key_name
  vpc_security_group_ids = [aws_security_group.turn_sg_new.id]

  # Execute user data script on instance launch
  user_data = file("userdata.sh")

  tags = {
    Name = "turn-server"
  }
}
# S3 bucket for project storage with versioning enabled
resource "aws_s3_bucket" "project_bucket" {
  bucket        = var.s3_bucket_name  # Define in terraform.tfvars
  force_destroy = true

  tags = {
    Name        = "ProjectBucket"
    Environment = "Dev"
  }
}

# Enable versioning on the S3 bucket for data protection
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.project_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB table for storing messages with pay-per-request billing
resource "aws_dynamodb_table" "messages" {
  name         = "messages"
  billing_mode = "PAY_PER_REQUEST"  # Cost-effective for variable workloads
  hash_key     = "id"

  # Define the primary key attribute
  attribute {
    name = "id"
    type = "S"  # String type
  }

  tags = {
    Name        = "MessagesTable"
    Environment = "Dev"
  }
}

# IAM role for Lambda function execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  # Trust policy allowing Lambda service to assume this role
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

# Attach basic Lambda execution policy to the role
resource "aws_iam_role_policy_attachment" "git" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function for handling HTTP requests
resource "aws_lambda_function" "hello_lambda" {
  function_name    = "HelloLambda"
  role            = "arn:aws:iam::602873375259:role/RoleForLambdaModLabRole"  # Using existing lab role
  handler         = "index.handler"                                          # Entry point: index.js exports.handler
  runtime         = "nodejs18.x"                                            # Node.js 18.x runtime
  filename        = "${path.module}/hello_lambda.zip"                       # Source code package
  source_code_hash = filebase64sha256("${path.module}/hello_lambda.zip")    # Detect code changes
}
# SNS topic for infrastructure alerts and notifications
resource "aws_sns_topic" "alerts" {
  name = "infra-alerts-topic"
}

# Email subscription for SNS alerts
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "awaisali11159@gmail.com"  # Email address for notifications
}

# CloudWatch alarm for monitoring high CPU utilization on EC2 instance
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2                              # Number of periods to evaluate
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120                            # 2-minute intervals
  statistic           = "Average"
  threshold           = 70                             # 70% CPU threshold
  alarm_description   = "This metric monitors high CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]    # Send notification to SNS topic
  
  # Monitor specific EC2 instance
  dimensions = {
    InstanceId = aws_instance.turn_ec2.id
  }
}
# SQS queue for asynchronous task processing
resource "aws_sqs_queue" "project_queue" {
  name = "project-task-queue"

  tags = {
    Environment = "Dev"
    Purpose     = "Queue for async task processing"
  }
}

# EFS (Elastic File System) for shared storage across multiple instances
resource "aws_efs_file_system" "project_fs" {
  creation_token = "project-fs-token"
  
  tags = {
    Name        = "ProjectEFS"
    Environment = "Dev"
  }
}

# Mount targets for EFS in multiple subnets for high availability
resource "aws_efs_mount_target" "project_fs_mount" {
  for_each = toset([var.subnet_id_1, var.subnet_id_2])  # Create mount targets in multiple subnets

  file_system_id  = aws_efs_file_system.project_fs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.turn_sg_new.id]  # Use existing security group
}

# Security Group for Application Load Balancer - allows HTTP traffic
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = var.vpc_id

  # Allow HTTP inbound traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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
# Application Load Balancer for distributing incoming traffic
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false                          # Internet-facing load balancer
  load_balancer_type = "application"                  # Application Load Balancer (Layer 7)
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids                 # Deploy across multiple subnets

  tags = {
    Name = "app-lb"
  }
}

# Target group for load balancer to route traffic to EC2 instances
resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health check configuration for target instances
  health_check {
    path                = "/"           # Health check endpoint
    protocol            = "HTTP"
    matcher             = "200"         # Expected HTTP response code
    interval            = 30            # Health check interval in seconds
    timeout             = 5             # Health check timeout in seconds
    healthy_threshold   = 2             # Number of consecutive successful checks
    unhealthy_threshold = 2             # Number of consecutive failed checks
  }

  tags = {
    Name = "app-tg"
  }
}
# Attach EC2 instance to the target group
resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.turn_ec2.id
  port             = 80
}

# Load balancer listener to handle incoming requests
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  # Forward all requests to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


# RDS PostgreSQL database instance
resource "aws_db_instance" "app_db" {
  allocated_storage      = 20                                        # Storage in GB
  engine                 = "postgres"                                # PostgreSQL engine
  # engine_version       = "15.3"                                   # Commented out to use default
  instance_class         = "db.t3.micro"                            # Cost-effective instance type
  db_name                = "appdb"                                   # Database name
  username               = var.db_username                          # Master username from variables
  password               = var.db_password                          # Master password from variables
  parameter_group_name   = "default.postgres15"                     # Default parameter group
  skip_final_snapshot    = true                                     # Skip snapshot on deletion (dev environment)
  publicly_accessible    = true                                     # Allow public access
  vpc_security_group_ids = [aws_security_group.turn_sg_new.id]      # Use existing security group
  db_subnet_group_name   = aws_db_subnet_group.app_db_subnet_group.name  # Subnet group for multi-AZ

  tags = {
    Name = "AppRDS"
  }
}

# DB subnet group for RDS to span multiple availability zones
resource "aws_db_subnet_group" "app_db_subnet_group" {
  name       = "app-db-subnet-group"
  subnet_ids = var.subnet_ids  # Multiple subnets for high availability

  tags = {
    Name = "App DB Subnet Group"
  }
}
# API Gateway v2 (HTTP API) for REST endpoints
resource "aws_apigatewayv2_api" "http_api" {
  name          = "project-http-api"
  protocol_type = "HTTP"  # HTTP API (cheaper and faster than REST API)
}

# Default stage for API Gateway with auto-deployment
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"        # Default stage name
  auto_deploy = true              # Automatically deploy changes
}

# Output the API Gateway URL for external access
output "api_gateway_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
# ECR repository for storing Docker images
resource "aws_ecr_repository" "app_repo" {
  name = "my-docker-app"
}

# CodeBuild project for building Docker images from GitHub source
resource "aws_codebuild_project" "docker_build" {
  name = "docker-build"
  
  # Source configuration - pulls code from GitHub
  source {
    type     = "GITHUB"
    location = "https://github.com/awaisZtabs/webee"
  }
  
  # No build artifacts stored (images go to ECR)
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  # Build environment configuration
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"          # Small instance for cost efficiency
    image          = "aws/codebuild/standard:5.0"     # Standard CodeBuild image
    type           = "LINUX_CONTAINER"                # Linux container environment
    privileged_mode = true                            # Required for Docker builds
  }
  
  service_role = "arn:aws:iam::602873375259:role/LabRole"  # IAM role for CodeBuild
}
