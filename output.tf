output "Controlplan_ip" {
    value = aws_instance.controlplan.public_ip
}

output "worknode1_ip" {
    value = aws_instance.workernodes[0].public_ip
}

output "worknode2_ip" {
    value = aws_instance.workernodes[1].public_ip
}