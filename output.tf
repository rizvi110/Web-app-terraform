output "instance1_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.instance-1.public_ip

}

output "instance1_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.instance-1.private_ip

}

output "instance2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.instance-2.public_ip

}

output "instance2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.instance-2.private_ip

}

