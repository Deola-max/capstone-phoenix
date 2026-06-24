variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "my_public_ip" {
  type        = string
  description = "Your home IP address with /32 for secure SSH access"
}
