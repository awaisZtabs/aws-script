# AWS Infrastructure Services Documentation

## AWS Services Used

### 1. Compute Services
- **EC2 Instances** (`aws_instance`)
  - `example` instance (basic instance)
  - `turn_ec2` instance (main application server with user data script)
- **Lambda Function** (`aws_lambda_function`)
  - `HelloLambda` function with Node.js 18.x runtime

### 2. Storage Services
- **S3 Bucket** (`aws_s3_bucket`)
  - Project bucket with versioning enabled
- **EFS (Elastic File System)** (`aws_efs_file_system`)
  - Shared file system with mount targets in multiple subnets

### 3. Database Services
- **DynamoDB** (`aws_dynamodb_table`)
  - `messages` table with pay-per-request billing
- **RDS PostgreSQL** (`aws_db_instance`)
  - `appdb` database (db.t3.micro instance)

### 4. Networking & Load Balancing
- **Application Load Balancer** (`aws_lb`)
  - Internet-facing ALB for distributing traffic
- **Target Groups** (`aws_lb_target_group`)
  - Health checks configured for HTTP traffic
- **Security Groups** (`aws_security_group`)
  - `turn_sg_new`: SSH access and general traffic
  - `alb_sg`: HTTP traffic for load balancer

### 5. API & Integration Services
- **API Gateway v2** (`aws_apigatewayv2_api`)
  - HTTP API with auto-deploy stage
- **SQS Queue** (`aws_sqs_queue`)
  - Task queue for async processing

### 6. Monitoring & Notifications
- **CloudWatch** (`aws_cloudwatch_metric_alarm`)
  - CPU utilization monitoring for EC2
- **SNS Topic** (`aws_sns_topic`)
  - Email alerts for infrastructure monitoring

### 7. DevOps & Container Services
- **ECR Repository** (`aws_ecr_repository`)
  - Docker image repository
- **CodeBuild** (`aws_codebuild_project`)
  - CI/CD pipeline for Docker builds

### 8. IAM & Security
- **IAM Roles** (`aws_iam_role`)
  - Lambda execution role with basic execution policy

## Service Communication Flow

### 1. Web Traffic Flow
```
Internet → ALB (port 80) → Target Group → EC2 Instance (turn_ec2)
```
- Users access the application through the Application Load Balancer
- ALB performs health checks and routes traffic to the EC2 instance

### 2. API Integration
```
API Gateway HTTP API → Lambda Function → DynamoDB/RDS
```
- API Gateway provides REST endpoints
- Lambda functions process requests and interact with databases

### 3. Data Storage Architecture
```
EC2 Instance ↔ RDS PostgreSQL (appdb)
EC2 Instance ↔ EFS (shared file storage)
Lambda ↔ DynamoDB (messages table)
Applications → S3 Bucket (file storage)
```

### 4. Monitoring & Alerting
```
EC2 CPU Metrics → CloudWatch Alarm → SNS Topic → Email Alert
```
- CloudWatch monitors EC2 CPU utilization
- When threshold (70%) is exceeded, SNS sends email notifications

### 5. Async Processing
```
Applications → SQS Queue → Lambda/EC2 (workers)
```
- SQS queue handles asynchronous task processing

### 6. CI/CD Pipeline
```
GitHub Repository → CodeBuild → ECR Repository
```
- CodeBuild pulls code from GitHub and builds Docker images
- Images are pushed to ECR for deployment

## Security Configuration

- **Network Security**: Security groups control inbound/outbound traffic
- **Database Security**: RDS is in a private subnet group with security group protection
- **IAM Security**: Lambda has minimal required permissions
- **EFS Security**: Mount targets secured with security groups

## Key Integration Points

1. **Database Connectivity**: EC2 instances can connect to both RDS and DynamoDB
2. **File Sharing**: EFS provides shared storage across multiple availability zones
3. **Load Distribution**: ALB ensures high availability and traffic distribution
4. **Monitoring**: Integrated CloudWatch monitoring with SNS notifications
5. **API Layer**: API Gateway provides managed REST endpoints
6. **Async Processing**: SQS enables decoupled, scalable task processing

## Architecture Benefits

This architecture provides a comprehensive, scalable infrastructure with:
- High availability through load balancing
- Proper monitoring and alerting
- Secure network configuration
- Scalable storage solutions
- Automated CI/CD pipeline
- Integration between services for optimal performance

## Cost Optimization Notes

- DynamoDB uses pay-per-request billing for cost efficiency
- EC2 instances use t3.nano for development/testing
- RDS uses db.t3.micro for cost-effective database hosting
- S3 versioning enabled for data protection
- EFS provides shared storage to reduce redundancy

## Monitoring & Alerts

- **CPU Monitoring**: CloudWatch alarm triggers at 70% CPU utilization
- **Email Notifications**: SNS sends alerts to awaisali11159@gmail.com
- **Health Checks**: ALB performs regular health checks on EC2 instances
- **Log Management**: Lambda basic execution logs through CloudWatch
