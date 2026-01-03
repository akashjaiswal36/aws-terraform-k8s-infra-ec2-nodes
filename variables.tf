variable "region" {
    type = string
    default = "ap-south-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {
  default = "aws-key"
}

variable "num_workernodes" {
    default = 2
}