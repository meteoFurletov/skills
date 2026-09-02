output "public_ip" {
  description = "The Elastic IP — stable across stop/start and resizes."
  value       = aws_eip.workstation.public_ip
}

output "instance_id" {
  value = aws_instance.workstation.id
}

output "ssh_command" {
  # Official Ubuntu AMIs disable root SSH; you land as `ubuntu`, which has
  # passwordless sudo. (Several other providers' images default to root —
  # worth remembering when copying instructions between them.)
  value = "ssh -i ~/.ssh/${var.name} ubuntu@${aws_eip.workstation.public_ip}"
}
