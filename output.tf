output "Controlplan_ip" {
    value = aws_instance.controlplan.public_ip
}

output "worknode1_ip" {
    value = aws_instance.workernodes[*].public_ip
}
