output "instance_public_ip" {
value = aws_instance.turn_ec2.public_ip
}
output "db_endpoint" {
  value = aws_db_instance.app_db.endpoint
}
